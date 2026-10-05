// Mirror of TerrainField.gd (height_m and its layers) and RegimeRelief.gd.
using System;
using static Story.Native.GdMath;

namespace Story.Native
{
    internal sealed partial class SeedField
    {
        readonly V2 _elevationOffset;

        [ThreadStatic] static Region[]? _pairRegions;
        [ThreadStatic] static double[]? _pairWeights;

        // ---------------- TerrainField ----------------
        double Elevation01Of(double n)
            => T.FLOOR * (1.0 - Smoothstep(0.46, 0.28, n)) + T.UPLAND * Smoothstep(T.FRONT_LO, T.FRONT_HI, n)
                + T.SWELL * Smoothstep(0.53, 0.72, n);

        double ElevationNoise(V2 q)
        {
            V2 w = Warp(q.Rotated(0.45), Seed + 1715, 1500.0, 5000.0);
            return 0.65 * VNoise01(w, Seed + 1711, 9000.0)
                + 0.35 * VNoise01(w.Rotated(1.3), Seed + 1712, 4500.0);
        }

        V2 ComputeElevationOffset()
        {
            V2 best = V2.Zero;
            double bestE = INF;
            V2[] probes = { V2.Zero, new V2(1500f, 0f), new V2(-1500f, 0f), new V2(0f, 1500f), new V2(0f, -1500f) };
            for (int k = 0; k < 64; k++)
            {
                V2 off = V2.D(CellHash01(Seed + 1713, k, 0) - 0.5, CellHash01(Seed + 1714, k, 0) - 0.5) * 40000.0;
                double e = 0.0;
                foreach (V2 d in probes)
                    e = Max(e, Math.Abs(Elevation01Of(ElevationNoise(off + d)) - T.FLOOR));
                if (e < bestE)
                {
                    bestE = e;
                    best = off;
                }
                if (e < 0.03) break;
            }
            return best;
        }

        public double Elevation01(V2 p) => Elevation01Of(ElevationNoise(p + _elevationOffset));

        double ElevationM(V2 p) => T.ELEVATION_M * Elevation01(p);

        double ContinentalM(V2 p)
        {
            double n = 0.65 * VNoise01(p, Seed + 1701, 2600.0)
                + 0.35 * VNoise01(p.Rotated(0.9), Seed + 1702, 1300.0);
            return T.CONTINENTAL_M * Smoothstep(0.2, 0.8, n);
        }

        public double HeightM(V2 p, bool detail)
        {
            V2 sp = SetpieceSample(p);
            V2 f = FeatureSample(p, detail);
            double h = BaseM(p) + ElevationM(p) + ContinentalM(p) + sp.X + Net(f);
            double keep = 1.0 - T.SETPIECE_RELIEF_SUPPRESSION * sp.Y;
            var regions = _pairRegions ??= new Region[25];
            var weights = _pairWeights ??= new double[25];
            int n = Sample(p, regions, weights);
            double outH = 0.0;
            for (int i = 0; i < n; i++)
            {
                Region region = regions[i];
                double hr = h + ReliefM(region, p, detail) * keep;
                outH += weights[i] * (detail ? Terraced(hr, region) : hr);
            }
            return SoftCeiling(outH);
        }

        double SoftCeiling(double h)
        {
            if (h <= T.SOFT_CEILING) return h;
            double room = T.REF_AMPLITUDE - T.SOFT_CEILING;
            return T.SOFT_CEILING + room * Math.Tanh((h - T.SOFT_CEILING) / room);
        }

        /// _terraced(h, RegimeRelief.terrace_of(region)): terrace_of is a float32 Vector2.
        double Terraced(double h, Region region)
        {
            if (region.Kind != Arch.TerracedValleys) return h; // Vector2.ZERO: t.x <= 0
            float tx = (float)T.STOREY;
            float ty = (float)region.Q[P.riser_frac];
            return tx <= 0f ? h : Terrace(h, tx, ty);
        }

        // ---------------- RegimeRelief ----------------
        double ReliefM(Region region, V2 p, bool detail)
        {
            double[] q = region.Q;
            long s = region.Salt;
            V2 pr = p.Rotated(region.Rot);
            double ST = T.STOREY;
            switch (region.Kind)
            {
                case Arch.RollingDowns:
                case Arch.KarstHollows:
                case Arch.LowFlats:
                    if (!detail) return Hummock(pr, s, q[P.hummock_wl_m], 1) * q[P.relief_st] * ST;
                    return Hummock(pr, s, q[P.hummock_wl_m], 2) * q[P.relief_st] * ST;
                case Arch.RidgeAndPass:
                case Arch.HighlandMassif:
                    if (!detail) return 0.0;
                    return Ridges(q, s, pr, 2, detail);
                case Arch.EscarpmentCountry:
                {
                    double td = q[P.tread_depth_m];
                    V2 pw = Warp(pr, s + 1, td * 0.5, td * 2.0);
                    double period = 2.0 * q[P.steps] * td;
                    double u = pw.X + VNoise(pw, s + 3, td * 4.0) * td;
                    double stair = Math.Abs(Fposmod(u / period, 1.0) - 0.5) * 2.0 * q[P.steps] * q[P.tread_rise_st] * ST;
                    if (!detail)
                        return (0.5 + 0.5 * Math.Cos(TAU * u / period)) * q[P.steps] * q[P.tread_rise_st] * ST;
                    return Terrace(stair, Roundf(q[P.tread_rise_st]) * ST, q[P.riser_frac])
                        + Hummock(pr, s, q[P.hummock_wl_m], 2) * q[P.relief_st] * ST;
                }
                case Arch.TerracedValleys:
                {
                    V2 axis = V2.FromAngle(region.Rot).Orthogonal();
                    V2 rel = Warp(p - region.Site, s + 1, 40.0, 300.0);
                    double side = Max(0.0, Math.Abs((double)rel.Dot(axis)) - q[P.valley_half_width_m]);
                    if (!detail) return Min(side / q[P.tread_depth_m], q[P.treads]) * ST;
                    return Min(side / q[P.tread_depth_m], q[P.treads]) * ST
                        + Hummock(pr, s, q[P.hummock_wl_m], 2) * q[P.relief_st] * ST;
                }
                case Arch.Tableland:
                {
                    Worley(Warp(pr, s + 1, q[P.channel_m], q[P.cell_m]), s + 7, q[P.cell_m], out float wx, out float wy, out float wz);
                    double interior = Smoothstep(q[P.channel_m] * 0.5, q[P.channel_m], (double)wy - (double)wx);
                    return interior * Lerp(0.55, 1.0, wz) * q[P.rim_st] * ST;
                }
            }
            return 0.0;
        }

        double Ridges(double[] q, long s, V2 pr, int octaves, bool detail)
        {
            double ST = T.STOREY;
            double wl = q[P.ridge_spacing_m] * 2.0;
            V2 pw = Warp(pr, s + 1, q[P.ridge_spacing_m] * 0.35, q[P.ridge_spacing_m] * 1.5);
            double height = q[P.ridge_st] * ST;
            double r = Ridged(pw, s + 2, wl, detail ? octaves : 2, 2.0)
                * PassMod(pr, s + 3, q[P.pass_spacing_m], q[P.pass_depth]);
            if (!detail) return r * height;
            V2 grad = RidgedGradient(pw, s + 2, wl, 2.0) * height;
            double gate = Smoothstep(0.05, 0.25, grad.Length());
            return r * height + Gully(pr, s + 4, q[P.gully_spacing_m], -grad) * q[P.gully_st] * ST * gate;
        }
    }
}
