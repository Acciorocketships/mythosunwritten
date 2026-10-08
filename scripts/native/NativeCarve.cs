// C# mirror of WaterPlan.carve_at (its body after the owner region lookup,
// WaterPlan._carve_region), PondStamp.carve_at / footprint_t / radius_at /
// island_excavation_weight / surface_y / bed_y and
// RiverTrace.retained_ground_weight, plus the batched heightfield sample of
// HeightfieldPlan._sample ([h - carve, carve, h]) for the region prefetch.
// Line for line, same double / float32 arithmetic in the same order (see
// GdMath.cs). NativeCarve.gd verifies every carve region it builds against the
// GDScript carve before the prefetch uses it.
//
// One script, two roles: an instance on which Build() succeeded IS one
// immutable carve region (WaterPlan keeps it in its region dictionary under
// "native"); the loader's own instance runs the batches. A region is
// reference counted with the dictionary that holds it, so an evicted region
// lives until the last batch using it returns (no handle table, no release,
// no use-after-release race). Region state is written once in Build, before
// WaterPlan publishes the dictionary under its lock, and only read after.
using System;
using System.Collections.Generic;
using Godot;
using static Story.Native.GdMath;

namespace Story.Native
{
    public partial class NativeCarve : RefCounted
    {
        sealed class Consts
        {
            public double TILE, SUPER, SPAWN_WATER_RADIUS, BANK_FEATHER, CARVE_FEATHER, CARVE_BED_EXTRA,
                CARVE_EXTRA_MAX_GRADE, BED_MIN, STOREY, SURFACE_RIDE, POND_STOREY, WOBBLE, SURFACE_DROP,
                RIM_FEATHER;
        }

        sealed class Trace
        {
            public V2[] Points = Array.Empty<V2>();
            public float[] Beds = Array.Empty<float>(), Widths = Array.Empty<float>();
            public double[] Bank = Array.Empty<double>();
            public GdPond? Pond;
            public V2[] BarVec = Array.Empty<V2>();      // center, axis per bar
            public double[] BarNum = Array.Empty<double>(); // half_length, half_width per bar
        }

        sealed class Region
        {
            public GdPond[] Ponds = Array.Empty<GdPond>();
            public int FirstX, FirstZ, Side;
            public int[] CellStart = Array.Empty<int>();
            public Trace[] SegTrace = Array.Empty<Trace>();
            public int[] SegIndex = Array.Empty<int>();
        }

        static volatile Consts? _consts;
        Region? _region;

        /// WaterPlan / PondStamp / WaterField constants. Returns "" or an error.
        public string Configure(Godot.Collections.Dictionary consts)
        {
            try
            {
                double D(string k)
                {
                    if (!consts.ContainsKey(k)) throw new ArgumentException("missing constant " + k);
                    return consts[k].AsDouble();
                }
                _consts = new Consts
                {
                    TILE = D("TILE"), SUPER = D("SUPER"), SPAWN_WATER_RADIUS = D("SPAWN_WATER_RADIUS"),
                    BANK_FEATHER = D("BANK_FEATHER"), CARVE_FEATHER = D("CARVE_FEATHER"),
                    CARVE_BED_EXTRA = D("CARVE_BED_EXTRA"), CARVE_EXTRA_MAX_GRADE = D("CARVE_EXTRA_MAX_GRADE"),
                    BED_MIN = D("BED_MIN"), STOREY = D("STOREY"), SURFACE_RIDE = D("SURFACE_RIDE"),
                    POND_STOREY = D("POND_STOREY"), WOBBLE = D("WOBBLE"), SURFACE_DROP = D("SURFACE_DROP"),
                    RIM_FEATHER = D("RIM_FEATHER"),
                };
                return "";
            }
            catch (Exception e)
            {
                _consts = null;
                return e.Message;
            }
        }

        // ------------------------------------------------------------ building

        /// Make this instance one carve region (see NativeCarve.gd._flatten).
        /// Returns "" or an error.
        public string Build(Godot.Collections.Dictionary flat)
        {
            try
            {
                Consts c = _consts ?? throw new InvalidOperationException("NativeCarve: Configure first");
                GdPond[] ponds = GdPond.ReadAll(flat["pond_vec"].AsVector2Array(),
                    flat["pond_num"].AsFloat64Array(), flat["pond_int"].AsInt64Array(), c.WOBBLE);
                var points = flat["trace_points"].AsGodotArray();
                var beds = flat["trace_beds"].AsGodotArray();
                var widths = flat["trace_widths"].AsGodotArray();
                var bank = flat["trace_bank"].AsGodotArray();
                var barVec = flat["bar_vec"].AsGodotArray();
                var barNum = flat["bar_num"].AsGodotArray();
                int[] tracePond = flat["trace_pond"].AsInt32Array();
                var traces = new Trace[tracePond.Length];
                for (int t = 0; t < traces.Length; t++)
                {
                    Vector2[] pts = points[t].AsVector2Array();
                    var v = new V2[pts.Length];
                    for (int i = 0; i < pts.Length; i++) v[i] = new V2(pts[i].X, pts[i].Y);
                    Vector2[] bv = barVec[t].AsVector2Array();
                    var bars = new V2[bv.Length];
                    for (int i = 0; i < bv.Length; i++) bars[i] = new V2(bv[i].X, bv[i].Y);
                    traces[t] = new Trace
                    {
                        Points = v,
                        Beds = beds[t].AsFloat32Array(),
                        Widths = widths[t].AsFloat32Array(),
                        Bank = bank[t].AsFloat64Array(),
                        Pond = tracePond[t] >= 0 ? ponds[tracePond[t]] : null,
                        BarVec = bars,
                        BarNum = barNum[t].AsFloat64Array(),
                    };
                    if (traces[t].Beds.Length != v.Length || traces[t].Widths.Length != v.Length
                        || traces[t].Bank.Length != v.Length || traces[t].BarNum.Length != bars.Length)
                        throw new ArgumentException("trace arrays differ in length");
                }
                Vector2I first = flat["first_cell"].AsVector2I();
                int side = flat["side"].AsInt32();
                int[] cellStart = flat["cell_start"].AsInt32Array();
                int[] seg = flat["seg"].AsInt32Array();
                if (cellStart.Length != side * side + 1 || cellStart[side * side] * 2 != seg.Length)
                    throw new ArgumentException("bad segment index");
                var segTrace = new Trace[seg.Length / 2];
                var segIndex = new int[seg.Length / 2];
                for (int k = 0; k < segTrace.Length; k++)
                {
                    segTrace[k] = traces[seg[2 * k]];
                    segIndex[k] = seg[2 * k + 1];
                    if (segIndex[k] < 0 || segIndex[k] + 1 >= segTrace[k].Points.Length)
                        throw new ArgumentException("segment out of range");
                }
                _region = new Region
                {
                    Ponds = ponds, FirstX = first.X, FirstZ = first.Y, Side = side,
                    CellStart = cellStart, SegTrace = segTrace, SegIndex = segIndex,
                };
                return "";
            }
            catch (Exception e)
            {
                _region = null;
                return e.Message;
            }
        }

        // ------------------------------------------------------------ batches

        /// _carve_region of this region at (xs[k], zs[k]) on ground grounds[k]
        /// (WaterPlan.noise_h of the point), spawn disk included.
        public double[] CarveBatch(double[] xs, double[] zs, double[] grounds)
        {
            Consts c = _consts ?? throw new InvalidOperationException("NativeCarve: Configure first");
            Region r = _region ?? throw new InvalidOperationException("NativeCarve: not a built region");
            var outC = new double[xs.Length];
            for (int k = 0; k < xs.Length; k++)
            {
                V2 p = V2.D(xs[k], zs[k]);
                if (p.Length() < c.SPAWN_WATER_RADIUS) continue;
                outC[k] = Carve(c, r, p, Floori(xs[k] / c.TILE + 0.5), Floori(zs[k] / c.TILE + 0.5), grounds[k]);
            }
            return outC;
        }

        /// HeightfieldPlan._sample for the lattice points lo + (index % width,
        /// index / width): [h - carve, carve, h] per index, flattened. regions
        /// holds the built carve regions, keys their super-cells (x, z pairs);
        /// every owner a point needs must be present.
        public double[] SampleBatch(long seed, int loX, int loZ, int width, int[] indices,
            Godot.Collections.Array regions, int[] keys, double point, double heightAmp, double waterAmp,
            double spawnLevel, double refAmplitude)
        {
            Consts c = _consts ?? throw new InvalidOperationException("NativeCarve: Configure first");
            var byCell = new Dictionary<(long, long), Region>();
            for (int k = 0; k < regions.Count; k++)
            {
                var obj = regions[k].AsGodotObject() as NativeCarve;
                Region r = obj?._region ?? throw new ArgumentException("region " + k + " is not built");
                byCell[(keys[2 * k], keys[2 * k + 1])] = r;
            }
            SeedField f = NativeTerrainHeight.FieldFor(seed);
            long cellsPerSuper = (long)(c.SUPER / c.TILE);
            var outS = new double[indices.Length * 3];
            for (int k = 0; k < indices.Length; k++)
            {
                int idx = indices[k];
                double x = (double)(loX + idx % width) * point;
                double z = (double)(loZ + idx / width) * point;
                V2 p = V2.D(x, z);
                // HeightfieldPlan.height01 round the native field (LOWPASS_M == 0).
                double h = f.HeightM(p, true);
                double falloff = Smootherstep(Clamp(((double)p.Length() - 60.0) / 180.0, 0.0, 1.0));
                if (falloff < 1.0) h = Lerp(spawnLevel, h, falloff);
                double n01 = Clamp(h / refAmplitude, 0.0, 1.0);
                double height = n01 * heightAmp;
                double carve = 0.0;
                if (!(p.Length() < c.SPAWN_WATER_RADIUS))
                {
                    long cx = Floori(x / c.TILE + 0.5);
                    long cz = Floori(z / c.TILE + 0.5);
                    long rcx = Floori((double)cx / (double)cellsPerSuper);
                    long rcz = Floori((double)cz / (double)cellsPerSuper);
                    if (!byCell.TryGetValue((rcx, rcz), out Region? r))
                        throw new ArgumentException($"no carve region ({rcx}, {rcz})");
                    carve = Carve(c, r, p, cx, cz, n01 * waterAmp);
                }
                outS[3 * k] = height - carve;
                outS[3 * k + 1] = carve;
                outS[3 * k + 2] = height;
            }
            return outS;
        }

        // ------------------------------------------------------------ the port

        /// Godot's MAX (maxf): a < b ? b : a (differs from Max on signed zeros).
        static double Maxf(double a, double b) => a < b ? b : a;

        /// WaterPlan._carve_region after the spawn disk: ground is known.
        static double Carve(Consts c, Region r, V2 p, long cx, long cz, double ground)
        {
            double best = 0.0;
            foreach (GdPond pond in r.Ponds)
            {
                double bound = pond.Bound;
                V2 dp = p - pond.Center;
                if ((double)dp.LengthSquared() > bound * bound) continue;
                best = Maxf(best, PondCarve(c, pond, p, ground));
            }
            long lx = cx - r.FirstX, lz = cz - r.FirstZ;
            if (lx < 0 || lz < 0 || lx >= r.Side || lz >= r.Side) return best;
            int cell = (int)(lz * r.Side + lx);
            for (int n = r.CellStart[cell]; n < r.CellStart[cell + 1]; n++)
            {
                Trace t = r.SegTrace[n];
                int si = r.SegIndex[n];
                V2 a = t.Points[si];
                V2 b = t.Points[si + 1];
                V2 ab = b - a;
                double len2 = ab.LengthSquared();
                double along = len2 > 0.000001 ? Clamp((double)(p - a).Dot(ab) / len2, 0.0, 1.0) : 0.0;
                V2 nearest = a + ab * along;
                double halfWidth = Lerp(t.Widths[si], t.Widths[si + 1], along);
                double d = p.DistanceTo(nearest);
                double infl = halfWidth + c.BANK_FEATHER;
                if (d >= infl) continue;
                double grade = Math.Abs((double)t.Beds[si + 1] - (double)t.Beds[si]) / Maxf(Math.Sqrt(len2), 0.001);
                double extra = grade < c.CARVE_EXTRA_MAX_GRADE ? c.CARVE_BED_EXTRA : 0.0;
                double bed = Lerp(t.Beds[si], t.Beds[si + 1], along);
                double carveBed = Maxf(bed - extra, c.BED_MIN);
                double target = carveBed;
                if (d > halfWidth)
                {
                    double shore = bed + c.SURFACE_RIDE + 0.5;
                    target = Lerp(shore, ground, (d - halfWidth) / c.BANK_FEATHER);
                }
                double strength = Lerp(t.Bank[si], t.Bank[si + 1], along);
                double originalWeight = Smootherstep(Clamp((halfWidth + c.CARVE_FEATHER - d) / c.CARVE_FEATHER, 0.0, 1.0));
                double originalCarve = Maxf(0.0, ground - carveBed) * originalWeight;
                double carve = Lerp(originalCarve, Maxf(0.0, ground - target), strength);
                double crest = Math.Ceiling((bed + c.SURFACE_RIDE + .75) / c.STOREY) * c.STOREY;
                double barCarve = Maxf(0.0, ground - crest);
                if (carve <= best) continue;
                if (barCarve >= carve)
                {
                    best = carve;
                    continue;
                }
                best = Maxf(best, Lerp(carve, barCarve, RetainedGroundWeight(c, t, p)));
            }
            return best;
        }

        static double FootprintT(Consts c, GdPond pond, V2 p) => pond.FootprintT(p, c.WOBBLE);

        static double SurfaceY(Consts c, GdPond pond) => pond.SurfaceY(c.POND_STOREY, c.SURFACE_DROP);

        static double BedY(Consts c, GdPond pond) => SurfaceY(c, pond) + c.SURFACE_DROP - pond.Depth;

        static double IslandExcavationWeight(GdPond pond, V2 p)
        {
            if (pond.IslandRadius <= 0.0) return 1.0;
            V2 local = p - pond.Center - pond.IslandOffset;
            if (pond.Peninsula)
            {
                V2 direction = pond.IslandOffset.Normalized();
                double along = Clamp((double)local.Dot(direction), 0.0, pond.Radius);
                local = local - direction * along;
            }
            return Smoothstep(pond.IslandRadius * 0.75, pond.IslandRadius * 1.25, local.Length());
        }

        static double PondCarve(Consts c, GdPond pond, V2 p, double groundY)
        {
            double t = FootprintT(c, pond, p);
            if (t >= 1.0) return 0.0;
            double w = Smootherstep(Clamp((1.0 - t) / c.RIM_FEATHER, 0.0, 1.0));
            w *= IslandExcavationWeight(pond, p);
            w *= 1.0 - Smoothstep(c.POND_STOREY, 3.0 * c.POND_STOREY, groundY - (double)pond.Level * c.POND_STOREY);
            return Maxf(0.0, (groundY - BedY(c, pond)) * w);
        }

        static double RetainedGroundWeight(Consts c, Trace t, V2 point)
        {
            double retained = 0.0;
            if (t.Pond != null && FootprintT(c, t.Pond, point) < 1.0)
                retained = 1.0 - IslandExcavationWeight(t.Pond, point);
            for (int k = 0; k < t.BarNum.Length / 2; k++)
            {
                V2 relative = point - t.BarVec[2 * k];
                V2 axis = t.BarVec[2 * k + 1];
                double radius = V2.D((double)relative.Dot(axis) / t.BarNum[2 * k],
                    (double)relative.Dot(new V2(-axis.Y, axis.X)) / t.BarNum[2 * k + 1]).Length();
                retained = Maxf(retained, 1.0 - Smoothstep(.65, 1.0, radius));
            }
            return retained;
        }
    }
}
