// Mirror of TerrainRegimeField.gd, the region parts of TerrainRegimeCatalog.gd
// (draw, choose) and Helper.biome_weights5, for one world seed.
using System;
using System.Collections.Concurrent;
using static Story.Native.GdMath;

namespace Story.Native
{
    internal sealed class Region
    {
        public int Arch;          // archetype index (TerrainTables.ArchetypeNames)
        public Arch Kind;
        public double[] Q = Array.Empty<double>();
        public V2 Site;
        public double BaseM;
        public double Rot;
        public long Salt;
    }

    /// A small bounded cache: values are pure functions of their key, so a
    /// racing double compute or a wholesale clear never changes a result.
    internal sealed class Memo<T> where T : class
    {
        readonly ConcurrentDictionary<long, T> _map = new();
        readonly int _limit;
        int _count;
        public Memo(int limit) { _limit = limit; }

        public static long Key(long x, long z) => (x << 32) ^ (z & 0xFFFFFFFFL);

        public bool TryGet(long key, out T value) => _map.TryGetValue(key, out value!);

        public T Store(long key, T value)
        {
            if (System.Threading.Interlocked.Increment(ref _count) > _limit)
            {
                _map.Clear();
                System.Threading.Interlocked.Exchange(ref _count, 0);
            }
            return _map.GetOrAdd(key, value);
        }
    }

    internal sealed partial class SeedField
    {
        public readonly long Seed;
        readonly TerrainTables T;

        readonly Memo<Region> _regions = new(1 << 16);
        readonly Memo<V2[]> _hoods = new(1 << 15);
        readonly Memo<double[]> _nodes = new(1 << 16);

        public SeedField(long seed, TerrainTables tables)
        {
            Seed = seed;
            T = tables;
            _elevationOffset = ComputeElevationOffset();
        }

        // ---------------- ReliefPrimitives ----------------
        static double VNoise01(V2 p, long seed, double wl) => ValueNoise01(p, seed, wl);
        static double VNoise(V2 p, long seed, double wl) => VNoise01(p, seed, wl) * 2.0 - 1.0;

        static V2 Warp(V2 p, long seed, double amplitude, double wavelength)
        {
            if (amplitude <= 0.0) return p;
            return p + V2.D(VNoise(p, seed + 11, wavelength), VNoise(p, seed + 13, wavelength)) * amplitude;
        }

        double Hummock(V2 p, long seed, double wavelength, int octaves)
        {
            double total = 0.0, norm = 0.0, amp = 1.0, lam = wavelength;
            for (int o = 0; o < octaves; o++)
            {
                total += Math.Abs(VNoise(p.Rotated(T.OCTAVE_TURN * o), seed + 17 * o, lam)) * amp;
                norm += amp;
                amp *= 0.5;
                lam *= 0.5;
            }
            return total / norm;
        }

        double Ridged(V2 p, long seed, double wavelength, int octaves, double sharpness)
        {
            double total = 0.0, norm = 0.0, amp = 1.0, weight = 1.0, lam = wavelength;
            for (int o = 0; o < octaves; o++)
            {
                double r = Math.Pow(1.0 - Math.Abs(VNoise(p.Rotated(T.OCTAVE_TURN * o), seed + 17 * o, lam)), sharpness);
                r *= weight;
                weight = Clamp(r * 1.6, 0.0, 1.0);
                total += r * amp;
                norm += amp;
                amp *= 0.5;
                lam *= 0.5;
            }
            return total / norm;
        }

        V2 RidgedGradient(V2 p, long seed, double wavelength, double sharpness)
        {
            double e = wavelength * 0.02;
            double dx = Ridged(p + V2.D(e, 0.0), seed, wavelength, 2, sharpness)
                - Ridged(p - V2.D(e, 0.0), seed, wavelength, 2, sharpness);
            double dz = Ridged(p + V2.D(0.0, e), seed, wavelength, 2, sharpness)
                - Ridged(p - V2.D(0.0, e), seed, wavelength, 2, sharpness);
            return V2.D(dx, dz) / (2.0 * e);
        }

        static double PassMod(V2 p, long seed, double spacing, double depth)
            => 1.0 - depth * Smoothstep(0.55, 0.8, VNoise01(p, seed, spacing));

        static double Gully(V2 p, long seed, double spacing, V2 downhill)
        {
            if (downhill.LengthSquared() < 1e-12) return 0.0;
            V2 across = new V2(-downhill.Y, downhill.X).Normalized();
            V2 q = p / spacing;
            long cx = Floori(q.X), cz = Floori(q.Y);
            double total = 0.0, weights = 0.0;
            for (int dz = -1; dz < 2; dz++)
                for (int dx = -1; dx < 2; dx++)
                {
                    long x = (int)(cx + dx), z = (int)(cz + dz);
                    V2 centre = new V2((float)x, (float)z) + V2.D(
                        0.25 + 0.5 * CellHash01(seed, x, z),
                        0.25 + 0.5 * CellHash01(seed + 1, x, z));
                    V2 d = q - centre;
                    double w = Max(0.0, 1.0 - d.LengthSquared() / (1.25 * 1.25));
                    w *= w;
                    double phase = CellHash01(seed + 2, x, z) * TAU;
                    total += w * Math.Cos(TAU * d.Dot(across) + phase);
                    weights += w;
                }
            return Clamp(total / Max(weights, 1e-6), -1.0, 1.0);
        }

        /// Worley F1/F2 and id, returned as a float32 Vector3.
        static void Worley(V2 p, long seed, double spacing, out float f1o, out float f2o, out float ido)
        {
            V2 q = p / spacing;
            long cx = Floori(q.X), cz = Floori(q.Y);
            double f1 = INF, f2 = INF, id = 0.0;
            for (int dz = -2; dz < 3; dz++)
                for (int dx = -2; dx < 3; dx++)
                {
                    long x = (int)(cx + dx), z = (int)(cz + dz);
                    V2 site = new V2((float)x, (float)z) + V2.D(
                        0.25 + 0.5 * CellHash01(seed, x, z),
                        0.25 + 0.5 * CellHash01(seed + 1, x, z));
                    double d = q.DistanceTo(site);
                    if (d < f1)
                    {
                        f2 = f1;
                        f1 = d;
                        id = CellHash01(seed + 2, x, z);
                    }
                    else if (d < f2)
                    {
                        f2 = d;
                    }
                }
            f1o = (float)(f1 * spacing);
            f2o = (float)(f2 * spacing);
            ido = (float)id;
        }

        static double Terrace(double h, double step, double riserFrac)
        {
            double k = Math.Floor(h / step);
            double t = Smoothstep(1.0 - riserFrac, 1.0, h / step - k);
            return (k + t) * step;
        }

        // ---------------- Helper biome weights ----------------
        void BiomeWeights(V2 site, double[] canonical)
        {
            V2 p = site; // Vector3(site.x, 0, site.y): x/z are the same floats
            long s = Seed;
            double moisture = ValueNoise01(p, s + 41, T.BIOME_MOISTURE_SCALE);
            double marsh = Smoothstep(0.74, 0.96, ValueNoise01(p, s + 47, T.BIOME_MARSH_SCALE) + 0.15 * moisture);
            double blossom = Smoothstep(0.66, 0.88, ValueNoise01(p, s + 43, T.BIOME_BLOSSOM_SCALE)) * (1.0 - marsh);
            double remaining = 1.0 - marsh - blossom;
            double amber = Smoothstep(0.58, 0.86, ValueNoise01(p, s + 53, 720.0)) * remaining;
            double jade = Smoothstep(0.64, 0.88, moisture) * (remaining - amber);
            double rest = remaining - amber - jade;
            double f01 = Smoothstep(0.42, 0.64, ValueNoise01(p, s + 31, T.BIOME_FOREST_SCALE));
            double r01 = Smoothstep(0.5, 0.8, ValueNoise01(p, s + 37, T.BIOME_ROCKY_SCALE));
            double forest = f01 * rest;
            double highland = r01 * (1.0 - f01) * rest;
            double meadow = rest - forest - highland;
            double spawnBlend = Smoothstep(100.0, 280.0, p.Length());
            marsh *= spawnBlend;
            blossom *= spawnBlend;
            forest *= spawnBlend;
            highland *= spawnBlend;
            amber *= spawnBlend;
            jade *= spawnBlend;
            meadow = 1.0 - (1.0 - meadow) * spawnBlend;
            canonical[0] = meadow; canonical[1] = forest; canonical[2] = highland; canonical[3] = blossom;
            canonical[4] = marsh; canonical[5] = amber; canonical[6] = jade;
        }

        // ---------------- TerrainRegimeCatalog ----------------
        double[] Draw(long cx, long cz, long salt, ParamSpec[] spec, double scale)
        {
            var q = new double[T.ParamCount];
            Array.Fill(q, double.NaN);
            foreach (var ps in spec)
            {
                double u = CellHash01(Seed + salt + ps.GroupHash, cx, cz);
                double v = Lerp(ps.Lo, ps.Hi, u);
                if (ps.IsM) v *= scale;
                q[ps.Id] = v;
            }
            return q;
        }

        int Choose(double[] canonical, double u, double altitude01)
        {
            int na = T.Archetypes.Length;
            Span<double> scores = stackalloc double[na];
            double total = 0.0;
            for (int a = 0; a < na; a++)
            {
                double s = 0.0;
                double[] aff = T.Affinity[a];
                for (int b = 0; b < T.BiomeOrder.Length; b++)
                    s += canonical[T.BiomeOrder[b]] * Max(T.AFFINITY_FLOOR, aff[b]);
                s *= Max(0.15, 1.0 + T.AltitudeBias[a] * (2.0 * altitude01 - 1.0));
                scores[a] = s;
                total += s;
            }
            double t = u * total;
            for (int i = 0; i < na; i++)
            {
                t -= scores[i];
                if (t < 0.0) return i;
            }
            return na - 1;
        }

        // ---------------- TerrainRegimeField ----------------
        V2 SiteOf(long cx, long cz)
            => (new V2((float)cx, (float)cz) + V2.D(
                0.2 + 0.6 * CellHash01(Seed + 1401, cx, cz),
                0.2 + 0.6 * CellHash01(Seed + 1402, cx, cz))) * T.REGION_CELL;

        Region OwnRegion(long cx, long cz)
        {
            V2 site = SiteOf(cx, cz);
            bool calm = site.Length() < T.SPAWN_CALM_M;
            int arch;
            if (calm)
            {
                arch = T.RollingDownsIndex;
            }
            else
            {
                var w = new double[7];
                BiomeWeights(site, w);
                arch = Choose(w, CellHash01(Seed + 1403, cx, cz), Elevation01(site));
            }
            double scale = Lerp(0.6, 1.7, CellHash01(Seed + 1404, cx, cz));
            double[] q = Draw(cx, cz, 1410, T.ArchParams[arch], scale);
            if (calm)
            {
                q[P.base_level_st] = Min(q[P.base_level_st], 2.0);
                q[P.relief_st] = Min(q[P.relief_st], 1.0);
            }
            return new Region
            {
                Arch = arch,
                Kind = T.Archetypes[arch],
                Q = q,
                Site = site,
                BaseM = q[P.base_level_st] * T.STOREY,
                Rot = CellHash01(Seed + 1405, cx, cz) * TAU,
                Salt = (long)(CellHash01(Seed + 1406, cx, cz) * 1000000.0),
            };
        }

        public Region RegionOf(long cx, long cz)
        {
            long key = Memo<Region>.Key(cx, cz);
            if (_regions.TryGet(key, out var cached)) return cached;
            long dx = cx, dz = cz;
            if (SiteOf(cx, cz).Length() >= T.SPAWN_CALM_M && CellHash01(Seed + 1407, cx, cz) < T.MERGE_CHANCE)
            {
                if (CellHash01(Seed + 1408, cx, cz) < 0.5) dx = (int)(cx - 1);
                else dz = (int)(cz - 1);
            }
            return _regions.Store(key, OwnRegion(dx, dz));
        }

        V2[] Neighbourhood(long cx, long cz)
        {
            long key = Memo<V2[]>.Key(cx, cz);
            if (_hoods.TryGet(key, out var cached)) return cached;
            var sites = new V2[25];
            int i = 0;
            for (int dz = -2; dz < 3; dz++)
                for (int dx = -2; dx < 3; dx++)
                    sites[i++] = SiteOf((int)(cx + dx), (int)(cz + dz));
            return _hoods.Store(key, sites);
        }

        public Region RegionAt(V2 p)
        {
            long cx = (int)Floori(p.X / T.REGION_CELL), cz = (int)Floori(p.Y / T.REGION_CELL);
            V2[] sites = Neighbourhood(cx, cz);
            double d1 = INF;
            int i1 = 0;
            for (int i = 0; i < 25; i++)
            {
                double d = p.DistanceTo(sites[i]);
                if (d < d1)
                {
                    d1 = d;
                    i1 = i;
                }
            }
            return RegionOf((int)(cx + (i1 % 5 - 2)), (int)(cz + (i1 / 5 - 2)));
        }

        /// TerrainRegimeField.sample: fills regions/weights, returns the count.
        public int Sample(V2 p, Region[] regions, double[] weights)
        {
            V2 q = Warp(p, Seed + 1409, T.BORDER_WARP_M, T.BORDER_WARP_WL);
            long cx = (int)Floori(q.X / T.REGION_CELL), cz = (int)Floori(q.Y / T.REGION_CELL);
            V2[] sites = Neighbourhood(cx, cz);
            Span<double> dists = stackalloc double[25];
            double d1 = INF;
            int nearest = 0;
            for (int i = 0; i < 25; i++)
            {
                double d = q.DistanceTo(sites[i]);
                dists[i] = d;
                if (d < d1)
                {
                    d1 = d;
                    nearest = i;
                }
            }
            int n = 0;
            regions[n] = RegionOf((int)(cx + (nearest % 5 - 2)), (int)(cz + (nearest / 5 - 2)));
            weights[n++] = 1.0;
            double total = 1.0;
            for (int i = 0; i < 25; i++)
            {
                if (i == nearest || dists[i] - d1 >= T.BAND_M) continue;
                double w = 1.0 - Smootherstep((dists[i] - d1) / T.BAND_M);
                if (w > 0.0)
                {
                    regions[n] = RegionOf((int)(cx + (i % 5 - 2)), (int)(cz + (i / 5 - 2)));
                    weights[n++] = w;
                    total += w;
                }
            }
            if (total > 1.0)
                for (int i = 0; i < n; i++) weights[i] = weights[i] / total;
            return n;
        }

        double NodeBase(long nx, long nz)
        {
            long key = Memo<double[]>.Key(nx, nz);
            if (_nodes.TryGet(key, out var cached)) return cached[0];
            double v = RegionAt(new V2((float)nx, (float)nz) * T.BASE_NODE).BaseM;
            return _nodes.Store(key, new[] { v })[0];
        }

        public double BaseM(V2 p)
        {
            V2 q = p / T.BASE_NODE;
            long cx = (int)Floori(q.X), cz = (int)Floori(q.Y);
            double fx = Smootherstep(q.X - (double)cx);
            double fz = Smootherstep(q.Y - (double)cz);
            double a = Lerp(NodeBase(cx, cz), NodeBase((int)(cx + 1), cz), fx);
            double b = Lerp(NodeBase(cx, (int)(cz + 1)), NodeBase((int)(cx + 1), (int)(cz + 1)), fx);
            return Lerp(a, b, fz);
        }
    }
}
