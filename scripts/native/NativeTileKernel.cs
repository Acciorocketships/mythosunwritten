// C# mirror of TerrainTileField's tile evaluation (eval_params and helpers)
// over a dense window of corner heights. Same double arithmetic in the same
// order; heights are float32 as tile_params stores them. NativeTileKernel.gd
// checks bit-identity before switching over. Stateless and thread-safe.
using Godot;
using static Story.Native.GdMath;

namespace Story.Native
{
    public partial class NativeTileKernel : RefCounted
    {
        const double CLIFF_END_CLEAR = 0.2;   // TerrainTileField.CLIFF_END_CLEAR
        const int E1 = 0, E3 = 2;             // TerrainTileField.CliffEnd

        public double[] SampleOwned(float[] heights, int[] storeys, int w, int h, int i0, int j0,
            double spacing, double[] xs, double[] zs, int[] ownerI, int[] ownerJ, int cliffEnd)
        {
            var output = new double[xs.Length];
            double s = spacing;
            for (int k = 0; k < xs.Length; k++)
            {
                double cx = ownerI[k] * s, cz = ownerJ[k] * s;
                double lx = Clamp(xs[k], cx - s * 0.5, cx + s * 0.5);
                double lz = Clamp(zs[k], cz - s * 0.5, cz + s * 0.5);
                int ti = lx >= cx ? ownerI[k] : ownerI[k] - 1;
                int tj = lz >= cz ? ownerJ[k] : ownerJ[k] - 1;
                int sx = ti == ownerI[k] ? -1 : 1, sy = tj == ownerJ[k] ? -1 : 1;
                int a = (tj - j0) * w + (ti - i0);
                double h0 = heights[a], h1 = heights[a + 1], h2 = heights[a + w + 1], h3 = heights[a + w];
                int sa = storeys[a], sb = storeys[a + 1], sc = storeys[a + w + 1], sd = storeys[a + w];
                double cb = System.Math.Abs(sa - sb) >= 2 ? 1.0 : 0.0;
                double cr = System.Math.Abs(sb - sc) >= 2 ? 1.0 : 0.0;
                double ct = System.Math.Abs(sd - sc) >= 2 ? 1.0 : 0.0;
                double cl = System.Math.Abs(sa - sd) >= 2 ? 1.0 : 0.0;
                output[k] = Eval(h0, h1, h2, h3, cb, cr, ct, cl, (lx - ti * s) / s, (lz - tj * s) / s, sx, sy, cliffEnd);
            }
            return output;
        }

        static double Eval(double h0, double h1, double h2, double h3, double cb, double cr, double ct, double cl,
            double u, double v, int sx, int sy, int mode)
        {
            double lo = Min(Min(h0, h1), Min(h2, h3));
            double hi = Max(Max(h0, h1), Max(h2, h3));
            if (hi - lo <= 0.0) return lo;
            if (cb + cr + ct + cl == 0.0)
            {
                double su = Smootherstep(u), sv = Smootherstep(v);
                return Lerp(Lerp(h0, h1, su), Lerp(h3, h2, su), sv);
            }
            double result = lo, prev = lo;
            while (true)
            {
                double t = double.PositiveInfinity;
                if (h0 > prev && h0 < t) t = h0;
                if (h1 > prev && h1 < t) t = h1;
                if (h2 > prev && h2 < t) t = h2;
                if (h3 > prev && h3 < t) t = h3;
                if (t == double.PositiveInfinity) break;
                result += (t - prev) * Layer(h0 >= t, h1 >= t, h2 >= t, h3 >= t, cb, cr, ct, cl, u, v, sx, sy, mode);
                prev = t;
            }
            return result;
        }

        static double Layer(bool ba, bool bb, bool bc, bool bd, double cb, double cr, double ct, double cl,
            double u, double v, int sx, int sy, int mode)
        {
            int highs = (ba ? 1 : 0) + (bb ? 1 : 0) + (bc ? 1 : 0) + (bd ? 1 : 0);
            bool ends = mode == E3 && (cb >= 1.0 ? 1 : 0) + (cr >= 1.0 ? 1 : 0) + (ct >= 1.0 ? 1 : 0) + (cl >= 1.0 ? 1 : 0) == 1;
            if (highs != 2 || ba == bc)
            {
                bool mixed = (ba != bb && cb < 1.0) || (bd != bc && ct < 1.0) || (ba != bd && cl < 1.0) || (bb != bc && cr < 1.0);
                double c0 = (1.0 - CornerProfile(u, cb, v, 0.0, mixed, sx, sy, ends, mode)) * (1.0 - CornerProfile(v, cl, u, 0.0, mixed, sy, sx, ends, mode));
                double c1 = CornerProfile(u, cb, v, 1.0, mixed, sx, sy, ends, mode) * (1.0 - CornerProfile(v, cr, 1.0 - u, 0.0, mixed, sy, -sx, ends, mode));
                double c2 = CornerProfile(u, ct, 1.0 - v, 1.0, mixed, sx, -sy, ends, mode) * CornerProfile(v, cr, 1.0 - u, 1.0, mixed, sy, -sx, ends, mode);
                double c3 = (1.0 - CornerProfile(u, ct, 1.0 - v, 0.0, mixed, sx, -sy, ends, mode)) * CornerProfile(v, cl, u, 1.0, mixed, sy, sx, ends, mode);
                if (highs == 1) return ba ? c0 : bb ? c1 : bc ? c2 : c3;
                double plateau = 1.0;
                if (!ba) plateau *= 1.0 - c0;
                if (!bb) plateau *= 1.0 - c1;
                if (!bc) plateau *= 1.0 - c2;
                if (!bd) plateau *= 1.0 - c3;
                return plateau;
            }
            bool xb = ba != bb, xt = bd != bc, xl = ba != bd, xr = bb != bc;
            bool anySlope = (xb && cb < 1.0) || (xt && ct < 1.0) || (xl && cl < 1.0) || (xr && cr < 1.0);
            double idle = anySlope ? 0.0 : 1.0;
            double kb = xb ? cb : idle, kt = xt ? ct : idle, kl = xl ? cl : idle, kr = xr ? cr : idle;
            double pu = Profile(u, kb, kt, v, sx, sy, ends, mode);
            double pv = Profile(v, kl, kr, u, sy, sx, ends, mode);
            double a = ba ? 1.0 : 0.0, b = bb ? 1.0 : 0.0, c = bc ? 1.0 : 0.0, d = bd ? 1.0 : 0.0;
            return Lerp(Lerp(a, b, pu), Lerp(d, c, pu), pv);
        }

        static double CornerProfile(double t, double k, double s, double cornerT, bool mixed, int side, int sideS, bool ends, int mode)
        {
            if (k <= 0.0) return Smootherstep(t);
            if (!mixed) return Step(t, side);
            if (ends) return Step(s, sideS) == 0.0 ? Step(t, side) : Smootherstep(t);
            double wall = mode == E1 ? 1.0 - s
                : Smootherstep(Clamp((1.0 - CLIFF_END_CLEAR - s) / (0.5 - CLIFF_END_CLEAR), 0.0, 1.0));
            double ramp = Smoothstep(0.0, 1.0, Clamp((t - 0.5 * cornerT) * 2.0, 0.0, 1.0));
            return Lerp(ramp, Step(t, side), wall);
        }

        static double Profile(double t, double k0, double k1, double s, int side, int sideS, bool ends, int mode)
        {
            double k;
            if (mode == E1 || k0 == k1) k = Lerp(k0, k1, s);
            else if (ends) k = Step(s, sideS) == 0.0 ? k0 : k1;
            else if (k0 > k1) k = Smootherstep(Clamp((1.0 - CLIFF_END_CLEAR - s) / (0.5 - CLIFF_END_CLEAR), 0.0, 1.0));
            else k = Smootherstep(Clamp((s - CLIFF_END_CLEAR) / (0.5 - CLIFF_END_CLEAR), 0.0, 1.0));
            if (k >= 1.0) return Step(t, side);
            if (k <= 0.0) return Smootherstep(t);
            return Lerp(Smootherstep(t), Step(t, side), k);
        }

        static double Step(double t, int side) => t > 0.5 ? 1.0 : t < 0.5 ? 0.0 : (side < 0 ? 0.0 : 1.0);
    }
}
