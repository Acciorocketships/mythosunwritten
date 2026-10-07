// C# mirror of WaterPlan's source search (_jitter_pos, _ascend, the gates of
// _has_source_uncached) and raw contour walk (_walk, _contour_step,
// _contained_bed, _pond_level). Line for line, same double / float32 /
// int64 arithmetic in the same order (see GdMath.cs for the rules). The field
// reads go straight to NativeTerrainHeight's SeedField plus the GDScript
// wrapper of HeightfieldPlan.height01 (spawn clearing, /REF_AMPLITUDE clamp).
// NativeRiverWalk.gd verifies bit-identity per seed before WaterPlan switches
// over. Stateless apart from the immutable constants: thread-safe.
using System;
using System.Collections.Generic;
using Godot;
using static Story.Native.GdMath;

namespace Story.Native
{
    public partial class NativeRiverWalk : RefCounted
    {
        sealed class Consts
        {
            public double SUPER, TILE, STOREY, SOURCE_MIN_HEIGHT, ASCEND_STEP, SOURCE_PEAK_EPS,
                SOURCE_JITTER_MIN_HEIGHT, PROMINENCE_R, PROMINENCE_MIN, SOURCE_PROB, TRACE_STEP,
                CONTOUR_DESCENT, MEANDER_AMP, MEANDER_SCALE, STEEP_HI, SUMMIT_STEEP_X, SUMMIT_STEEP_Y,
                SELF_AVOID_R, SUMMIT_REACH, TRACE_REACH, GRAD_EPS, W_MIN, W_MAX, CHANNEL_DEPTH,
                CONTAIN_DROP, BED_MIN, FEATHER, SOURCE_POOL_R, FLAT_EPS, LOWLANDS_HEIGHT,
                SPAWN_WATER_RADIUS, WOBBLE, POINT;
            public long ASCEND_MAX_STEPS, MAX_STEPS, SELF_AVOID_SKIP, MIN_STEPS;
        }

        static volatile Consts? _consts;

        /// Take WaterPlan's live constants (plus PondStamp.WOBBLE, HeightfieldPlan.POINT).
        /// Returns "" or an error message.
        public string Configure(Godot.Collections.Dictionary consts)
        {
            try
            {
                double D(string k)
                {
                    if (!consts.ContainsKey(k)) throw new ArgumentException("missing constant " + k);
                    return consts[k].AsDouble();
                }
                long L(string k)
                {
                    if (!consts.ContainsKey(k)) throw new ArgumentException("missing constant " + k);
                    return consts[k].AsInt64();
                }
                _consts = new Consts
                {
                    SUPER = D("SUPER"), TILE = D("TILE"), STOREY = D("STOREY"),
                    SOURCE_MIN_HEIGHT = D("SOURCE_MIN_HEIGHT"), ASCEND_STEP = D("ASCEND_STEP"),
                    SOURCE_PEAK_EPS = D("SOURCE_PEAK_EPS"), SOURCE_JITTER_MIN_HEIGHT = D("SOURCE_JITTER_MIN_HEIGHT"),
                    PROMINENCE_R = D("PROMINENCE_R"), PROMINENCE_MIN = D("PROMINENCE_MIN"),
                    SOURCE_PROB = D("SOURCE_PROB"), TRACE_STEP = D("TRACE_STEP"),
                    CONTOUR_DESCENT = D("CONTOUR_DESCENT"), MEANDER_AMP = D("MEANDER_AMP"),
                    MEANDER_SCALE = D("MEANDER_SCALE"), STEEP_HI = D("STEEP_HI"),
                    SUMMIT_STEEP_X = D("SUMMIT_STEEP_X"), SUMMIT_STEEP_Y = D("SUMMIT_STEEP_Y"),
                    SELF_AVOID_R = D("SELF_AVOID_R"), SUMMIT_REACH = D("SUMMIT_REACH"),
                    TRACE_REACH = D("TRACE_REACH"), GRAD_EPS = D("GRAD_EPS"), W_MIN = D("W_MIN"),
                    W_MAX = D("W_MAX"), CHANNEL_DEPTH = D("CHANNEL_DEPTH"), CONTAIN_DROP = D("CONTAIN_DROP"),
                    BED_MIN = D("BED_MIN"), FEATHER = D("FEATHER"), SOURCE_POOL_R = D("SOURCE_POOL_R"),
                    FLAT_EPS = D("FLAT_EPS"), LOWLANDS_HEIGHT = D("LOWLANDS_HEIGHT"),
                    SPAWN_WATER_RADIUS = D("SPAWN_WATER_RADIUS"), WOBBLE = D("WOBBLE"), POINT = D("POINT"),
                    ASCEND_MAX_STEPS = L("ASCEND_MAX_STEPS"), MAX_STEPS = L("MAX_STEPS"),
                    SELF_AVOID_SKIP = L("SELF_AVOID_SKIP"), MIN_STEPS = L("MIN_STEPS"),
                };
                return "";
            }
            catch (Exception e)
            {
                _consts = null;
                return e.Message;
            }
        }

        // ------------------------------------------------------------ bridge

        public Godot.Collections.Dictionary SourceGate(long seed, int scx, int scy, double amplitude,
            double spawnLevel, double refAmplitude)
        {
            var w = new Walker(seed, amplitude, spawnLevel, refAmplitude, 0);
            bool passes = w.Gates(scx, scy, out V2 pos, out bool hasPos);
            var d = new Godot.Collections.Dictionary
            {
                ["passes_gates"] = passes,
                ["has_source_pos"] = hasPos,
                ["source_pos"] = new Vector2(pos.X, pos.Y),
            };
            return d;
        }

        public Vector2 SourcePos(long seed, int scx, int scy, double amplitude, double spawnLevel, double refAmplitude)
        {
            var w = new Walker(seed, amplitude, spawnLevel, refAmplitude, 0);
            V2 p = w.Ascend(w.JitterPos(scx, scy));
            return new Vector2(p.X, p.Y);
        }

        public long PondLevel(long seed, Vector2 center, double radius, double amplitude, double spawnLevel,
            double refAmplitude, long maxStoreys)
        {
            var w = new Walker(seed, amplitude, spawnLevel, refAmplitude, maxStoreys);
            return w.PondLevel(new V2(center.X, center.Y), radius);
        }

        public Godot.Collections.Dictionary Walk(long seed, int scx, int scy, double amplitude,
            double spawnLevel, double refAmplitude, long maxStoreys)
        {
            var w = new Walker(seed, amplitude, spawnLevel, refAmplitude, maxStoreys);
            return w.Walk(scx, scy);
        }

        // ------------------------------------------------------------ the port

        sealed class Walker
        {
            readonly Consts C;
            readonly SeedField F;
            readonly long Seed;
            readonly double Amp, Spawn, Ref;
            readonly long MaxStoreys;
            // Per-call memo of exact field samples (as WaterPlan's own memo:
            // same key, same double value; performance only).
            readonly Dictionary<V2Key, double> _smooth = new();
            readonly Dictionary<V2Key, double> _detail = new();

            readonly struct V2Key : IEquatable<V2Key>
            {
                readonly long _bits;
                public V2Key(V2 p) { _bits = ((long)BitConverter.SingleToInt32Bits(p.X) << 32) | (uint)BitConverter.SingleToInt32Bits(p.Y); }
                public bool Equals(V2Key o) => _bits == o._bits;
                public override bool Equals(object? o) => o is V2Key k && Equals(k);
                public override int GetHashCode() => _bits.GetHashCode();
            }

            public Walker(long seed, double amp, double spawn, double refAmp, long maxStoreys)
            {
                C = _consts ?? throw new InvalidOperationException("NativeRiverWalk: Configure first");
                F = NativeTerrainHeight.FieldFor(seed);
                Seed = seed;
                Amp = amp;
                Spawn = spawn;
                Ref = refAmp;
                MaxStoreys = maxStoreys;
            }

            /// HeightfieldPlan.height01 (the GDScript wrapper round the native height).
            double Height01(V2 p, bool detail)
            {
                double h = F.HeightM(p, detail);
                double falloff = Smootherstep(Clamp(((double)p.Length() - 60.0) / 180.0, 0.0, 1.0));
                if (falloff < 1.0) h = Lerp(Spawn, h, falloff);
                return Clamp(h / Ref, 0.0, 1.0);
            }

            double Smooth01(V2 p)
            {
                var k = new V2Key(p);
                if (_smooth.TryGetValue(k, out double v)) return v;
                v = Height01(p, false);
                _smooth[k] = v;
                return v;
            }

            double SmoothH(V2 p) => Smooth01(p) * Amp;

            /// natural01 with LOWPASS_M == 0 (the native path is off otherwise).
            double NoiseH(V2 p)
            {
                var k = new V2Key(p);
                if (!_detail.TryGetValue(k, out double v))
                {
                    v = Height01(p, true);
                    _detail[k] = v;
                }
                return v * Amp;
            }

            V2 Grad(V2 p)
            {
                return V2.D(
                    SmoothH(p + V2.D(C.GRAD_EPS, 0.0)) - SmoothH(p - V2.D(C.GRAD_EPS, 0.0)),
                    SmoothH(p + V2.D(0.0, C.GRAD_EPS)) - SmoothH(p - V2.D(0.0, C.GRAD_EPS))
                ) / (2.0 * C.GRAD_EPS);
            }

            long HashCell(long scx, long scy, long salt)
                => Mix64(Seed ^ Mix64(scx ^ Mix64(scy + salt)));

            static double Hash01(long h) => (double)(h & 0x7FFFFFFF) / (double)0x80000000L;

            public V2 Ascend(V2 start)
            {
                V2 p = start;
                double step = C.ASCEND_STEP;
                double h = SmoothH(p);
                for (long i = 0; i < C.ASCEND_MAX_STEPS; i++)
                {
                    V2 g = Grad(p);
                    V2 q = p;
                    double hq = h;
                    if (g.Length() >= C.SOURCE_PEAK_EPS * 0.5)
                    {
                        q = p + g.Normalized() * step;
                        hq = SmoothH(q);
                    }
                    if (hq <= h)
                    {
                        double reach = g.Length() >= C.SOURCE_PEAK_EPS * 0.5 ? step : 2.0 * C.ASCEND_STEP;
                        for (long k = 0; k < 8; k++)
                        {
                            V2 c = p + V2.FromAngle(k * TAU / 8.0) * reach;
                            double hc = SmoothH(c);
                            if (hc > hq)
                            {
                                q = c;
                                hq = hc;
                            }
                        }
                    }
                    if (hq <= h)
                    {
                        if (g.Length() < C.SOURCE_PEAK_EPS * 0.5) break;
                        step *= 0.5;
                        if (step < 0.25) break;
                        continue;
                    }
                    p = q;
                    h = hq;
                }
                return p;
            }

            double RingProminence(V2 p)
            {
                double acc = 0.0;
                for (long i = 0; i < 8; i++)
                    acc += Grad(p + V2.FromAngle(TAU * (double)i / 8.0) * C.PROMINENCE_R).Length();
                return acc / 8.0;
            }

            public V2 JitterPos(long scx, long scy)
            {
                V2 best = V2.Zero;
                double bestH = double.NegativeInfinity;
                for (long i = 0; i < 16; i++)
                {
                    double jx = ((double)(i % 4) + Hash01(HashCell(scx, scy, 101 + i * 17))) * 0.25;
                    double jz = ((double)(i / 4) + Hash01(HashCell(scx, scy, 102 + i * 17))) * 0.25;
                    V2 p = (new V2((float)scx, (float)scy) + V2.D(jx, jz)) * C.SUPER;
                    double h = Smooth01(p);
                    if (h > bestH)
                    {
                        best = p;
                        bestH = h;
                    }
                }
                return best;
            }

            /// Every gate of _has_source_uncached before the walk.
            public bool Gates(long scx, long scy, out V2 pos, out bool hasPos)
            {
                pos = V2.Zero;
                hasPos = false;
                if (Hash01(HashCell(scx, scy, 103)) >= C.SOURCE_PROB) return false;
                V2 j = JitterPos(scx, scy);
                if (j.Length() < C.SPAWN_WATER_RADIUS) return false;
                if (SmoothH(j) < C.SOURCE_JITTER_MIN_HEIGHT) return false;
                V2 p = Ascend(j);
                pos = p;
                hasPos = true;
                if (p.Length() < C.SPAWN_WATER_RADIUS) return false;
                if (SmoothH(p) < C.SOURCE_MIN_HEIGHT) return false;
                if (Grad(p).Length() >= C.SOURCE_PEAK_EPS) return false;
                if (RingProminence(p) < C.PROMINENCE_MIN) return false;
                return true;
            }

            public long PondLevel(V2 center, double radius)
            {
                double pitch = C.POINT;
                double bound = radius * (1.0 + C.WOBBLE) + C.TILE;
                long rPoints = (long)Math.Ceiling(bound / pitch);
                long ccx = Roundi(center.X / pitch), ccy = Roundi(center.Y / pitch);
                double minH = double.PositiveInfinity;
                for (long dz = -rPoints; dz < rPoints + 1; dz++)
                {
                    for (long dx = -rPoints; dx < rPoints + 1; dx++)
                    {
                        V2 p = V2.D((double)(ccx + dx) * pitch, (double)(ccy + dz) * pitch);
                        if (p.DistanceTo(center) <= bound) minH = Min(minH, NoiseH(p));
                    }
                }
                return ClampI((long)Math.Floor(minH / C.STOREY), 1, MaxStoreys);
            }

            double ContainedBed(double prevBed, V2 p, V2 dir, double halfW)
            {
                V2 n = new V2(-dir.Y, dir.X);
                double pitch = C.POINT;
                double d0 = halfW + C.FEATHER + pitch * 0.5;
                double bank = double.PositiveInfinity;
                V2 o0 = n * d0, o1 = -n * d0, o2 = n * (d0 + pitch), o3 = -n * (d0 + pitch);
                bank = Min(bank, Roundf(NoiseH(p + o0) / C.STOREY) * C.STOREY);
                bank = Min(bank, Roundf(NoiseH(p + o1) / C.STOREY) * C.STOREY);
                bank = Min(bank, Roundf(NoiseH(p + o2) / C.STOREY) * C.STOREY);
                bank = Min(bank, Roundf(NoiseH(p + o3) / C.STOREY) * C.STOREY);
                return Max(Min(Min(prevBed, SmoothH(p) - C.CHANNEL_DEPTH), bank - C.CONTAIN_DROP), C.BED_MIN);
            }

            static V2 LerpV(V2 a, V2 b, double weight)
            {
                float w = (float)weight;
                return new V2(a.X + (b.X - a.X) * w, a.Y + (b.Y - a.Y) * w);
            }

            /// Vector2((v).floor()) -> Vector2i.
            static (int, int) FloorI(V2 v) => ((int)MathF.Floor(v.X), (int)MathF.Floor(v.Y));

            bool ContourStep(List<V2> points, Dictionary<(int, int), List<int>> visited, V2 p, V2 dir, V2 g,
                V2 source, double arc, double phase, double hand, List<V2> nearby, out V2 best)
            {
                V2 down = g.LengthSquared() > 0.000001 ? -g.Normalized() : dir;
                V2 contour = p.DistanceTo(source) < C.SUMMIT_REACH ? down : down.Rotated(hand * Math.Acos(C.CONTOUR_DESCENT));
                double strength = Clamp(g.Length() / C.STEEP_HI, 0.0, 1.0);
                V2 outward = p.DistanceTo(source) > C.TILE ? (p - source).Normalized() : dir;
                V2 preferred = LerpV(outward, contour, strength * 0.75).Normalized();
                double wobble = ValueNoise01(V2.D(arc + phase, 0.0), Seed + 71, C.MEANDER_SCALE) * 2.0 - 1.0;
                preferred = preferred.Rotated(wobble * C.MEANDER_AMP);
                double height = SmoothH(p);
                best = default;
                bool found = false;
                double bestScore = double.PositiveInfinity;
                nearby.Clear();
                V2 reachV = new V2(1f, 1f) * (C.SELF_AVOID_R + C.TRACE_STEP);
                var lo = FloorI((p - reachV) / C.SELF_AVOID_R);
                var hi = FloorI((p + reachV) / C.SELF_AVOID_R);
                long limit = points.Count - C.SELF_AVOID_SKIP;
                for (int z = lo.Item2; z < hi.Item2 + 1; z++)
                    for (int x = lo.Item1; x < hi.Item1 + 1; x++)
                        if (visited.TryGetValue((x, z), out var ks))
                            foreach (int k in ks)
                                if (k < limit) nearby.Add(points[k]);
                double distSource = p.DistanceTo(source);
                for (long turn = -6; turn < 7; turn++)
                {
                    V2 heading = dir.Rotated((double)turn * PI / 12.0);
                    V2 q = p + heading * C.TRACE_STEP;
                    if (q.Length() < C.SPAWN_WATER_RADIUS + C.SOURCE_POOL_R || q.DistanceTo(source) > C.TRACE_REACH)
                        continue;
                    if (distSource > C.SUMMIT_REACH && heading.Dot(outward) < 0.15) continue;
                    double clearance = C.SELF_AVOID_R;
                    foreach (V2 old in nearby) clearance = Min(clearance, q.DistanceTo(old));
                    if (clearance < C.W_MAX * 2.0 + C.FEATHER) continue;
                    double change = SmoothH(q) - height;
                    double gl = g.Length();
                    double desiredDrop = gl * C.TRACE_STEP * (distSource < C.SUMMIT_REACH
                        ? Lerp(C.CONTOUR_DESCENT, 1.0, Smoothstep(C.SUMMIT_STEEP_X, C.SUMMIT_STEEP_Y, gl))
                        : C.CONTOUR_DESCENT);
                    double score = Math.Abs(change + desiredDrop) * 2.0
                        + Max(change, 0.0) * 3.0 + (1.0 - heading.Dot(preferred)) * 3.0
                        + (1.0 - clearance / C.SELF_AVOID_R) * 3.0;
                    if (score < bestScore)
                    {
                        bestScore = score;
                        best = q;
                        found = true;
                    }
                }
                return found;
            }

            public Godot.Collections.Dictionary Walk(long scx, long scy)
            {
                long priority = HashCell(scx, scy, 0x51ED);
                V2 p = Ascend(JitterPos(scx, scy));
                V2 sourceP = p;
                long poolLevel = PondLevel(p, C.SOURCE_POOL_R);
                long absPriority = priority < 0 ? unchecked(-priority) : priority;
                double meanderOffset = (double)(absPriority % 4096) * 37.0;
                V2 dir = V2.FromAngle(Hash01(HashCell(scx, scy, 104)) * TAU);
                V2 g0 = Grad(p);
                if (g0.Length() > 0.000001) dir = (-g0).Normalized();
                double bed = ContainedBed(INF, p, dir, C.W_MIN);
                double arc = 0.0;
                var visited = new Dictionary<(int, int), List<int>>();
                var points = new List<V2>();
                var beds = new List<float>();
                var widths = new List<float>();
                var nearby = new List<V2>();
                V2 source = p;
                double handedness = HashCell(scx, scy, 107) < 0 ? -1.0 : 1.0;
                double span = (double)C.MAX_STEPS * C.TRACE_STEP;
                for (long i = 0; i < C.MAX_STEPS; i++)
                {
                    var bucket = FloorI(p / C.SELF_AVOID_R);
                    if (!visited.TryGetValue(bucket, out var list))
                    {
                        list = new List<int>();
                        visited[bucket] = list;
                    }
                    list.Add(points.Count);
                    points.Add(p);
                    beds.Add((float)bed);
                    widths.Add((float)Lerp(C.W_MIN, C.W_MAX, arc / span));
                    V2 g = Grad(p);
                    if (i >= C.MIN_STEPS && g.Length() < C.FLAT_EPS) break;
                    if (i >= C.MIN_STEPS && SmoothH(p) < C.LOWLANDS_HEIGHT) break;
                    if (!ContourStep(points, visited, p, dir, g, source, arc, meanderOffset, handedness, nearby, out V2 next))
                        break;
                    dir = (next - p).Normalized();
                    p = next;
                    arc += C.TRACE_STEP;
                    bed = ContainedBed(bed, p, dir, Lerp(C.W_MIN, C.W_MAX, arc / span));
                }
                var outPoints = new Vector2[points.Count];
                for (int k = 0; k < points.Count; k++) outPoints[k] = new Vector2(points[k].X, points[k].Y);
                return new Godot.Collections.Dictionary
                {
                    ["points"] = outPoints,
                    ["beds"] = beds.ToArray(),
                    ["widths"] = widths.ToArray(),
                    ["end"] = new Vector2(p.X, p.Y),
                    ["arc"] = arc,
                    ["source"] = new Vector2(sourceP.X, sourceP.Y),
                    ["pool_level"] = poolLevel,
                    ["priority"] = priority,
                };
            }
        }
    }
}
