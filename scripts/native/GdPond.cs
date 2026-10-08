// A PondStamp record (scripts/terrain/water/PondStamp.gd) read from the flat
// arrays NativeCarve.gd.flatten_ponds builds, with the shape functions the
// native carve and water fill share: radius_at, footprint_t, bound_radius and
// surface_y, line for line (GdMath.cs rules). Immutable once read.
using System;
using Godot;
using static Story.Native.GdMath;

namespace Story.Native
{
    internal sealed class GdPond
    {
        public V2 Center, IslandOffset;
        public double Radius, SurfaceCeiling, Depth, IslandRadius, Aspect, Bound, A, B;
        public long Level;
        public bool Peninsula;

        /// pond_vec: center, island_offset per pond; pond_num: radius,
        /// surface_ceiling, depth, island_radius, aspect_ratio; pond_int:
        /// shape_seed, level, peninsula.
        public static GdPond[] ReadAll(Vector2[] pondVec, double[] pondNum, long[] pondInt, double wobble)
        {
            int n = pondInt.Length / 3;
            if (pondVec.Length != 2 * n || pondNum.Length != 5 * n)
                throw new ArgumentException("pond arrays differ in length");
            var ponds = new GdPond[n];
            for (int k = 0; k < n; k++)
            {
                var p = new GdPond
                {
                    Center = new V2(pondVec[2 * k].X, pondVec[2 * k].Y),
                    IslandOffset = new V2(pondVec[2 * k + 1].X, pondVec[2 * k + 1].Y),
                    Radius = pondNum[5 * k], SurfaceCeiling = pondNum[5 * k + 1], Depth = pondNum[5 * k + 2],
                    IslandRadius = pondNum[5 * k + 3], Aspect = pondNum[5 * k + 4],
                    Level = pondInt[3 * k + 1], Peninsula = pondInt[3 * k + 2] != 0,
                };
                long seed = pondInt[3 * k];
                // radius_at's two phases and bound_radius(): pure functions of the record.
                p.A = Hash01(Mix64(seed)) * TAU;
                p.B = Hash01(Mix64(unchecked(seed + 1))) * TAU;
                p.Bound = p.Radius * (1.0 + wobble);
                ponds[k] = p;
            }
            return ponds;
        }

        static double Hash01(long h) => (double)(h & 0x7FFFFFFF) / (double)0x80000000L;

        public double RadiusAt(double ang, double wobble)
        {
            double minor = Clamp(Aspect, 0.5, 1.0);
            double across = Math.Sin(ang - A);
            double ellipse = minor / Math.Sqrt(minor * minor * (1.0 - across * across) + across * across);
            return Radius * ellipse
                * (1.0 + wobble * (0.6 * Math.Sin(2.0 * ang + A) + 0.4 * Math.Sin(3.0 * ang + B)));
        }

        public double FootprintT(V2 p, double wobble)
        {
            V2 d = p - Center;
            if ((double)d.LengthSquared() < 0.000001) return 0.0;
            return (double)d.Length() / RadiusAt(Math.Atan2((double)d.Y, (double)d.X), wobble);
        }

        public double SurfaceY(double storey, double surfaceDrop)
            => Min((double)Level * storey - surfaceDrop, SurfaceCeiling);
    }
}
