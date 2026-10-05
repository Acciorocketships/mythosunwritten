// Bit-exact mirrors of the Godot 4.5 (single-precision build) math the GDScript
// terrain height field uses. Rules (verified against the engine, see
// NativeHeightField.gd):
// - GDScript float is double, int is int64 (wrapping multiply, arithmetic >>).
// - Vector2 is two float32s; its arithmetic, length, dot, distance_to,
//   normalized and rotated run in float32 inside the engine, which is NOT
//   compiled with FMA contraction (so neither is this; RyuJIT never contracts).
// - The engine computes a paired float sin/cos (Vector2.rotated, from_angle)
//   through Apple's __sincosf_stret, which differs in the last bit from sinf.
// - Scalar GDScript math (sin, cos, pow, exp, tanh, sqrt, floor, round) is
//   libm double; lerpf / smoothstep / clampf / maxf / minf follow math_funcs.h.
using System;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;

namespace Story.Native
{
    internal readonly struct V2
    {
        public readonly float X;
        public readonly float Y;

        [MethodImpl(MethodImplOptions.AggressiveInlining)]
        public V2(float x, float y) { X = x; Y = y; }

        /// Vector2(a, b) built from GDScript floats (doubles): each rounds to float32.
        [MethodImpl(MethodImplOptions.AggressiveInlining)]
        public static V2 D(double x, double y) => new V2((float)x, (float)y);

        public static readonly V2 Zero = new V2(0f, 0f);

        public static V2 operator +(V2 a, V2 b) => new V2(a.X + b.X, a.Y + b.Y);
        public static V2 operator -(V2 a, V2 b) => new V2(a.X - b.X, a.Y - b.Y);
        public static V2 operator -(V2 a) => new V2(-a.X, -a.Y);
        public static V2 operator *(V2 a, V2 b) => new V2(a.X * b.X, a.Y * b.Y);
        public static V2 operator /(V2 a, V2 b) => new V2(a.X / b.X, a.Y / b.Y);
        /// Vector2 * float: the GDScript double is converted to real_t first.
        public static V2 operator *(V2 a, double s) { float f = (float)s; return new V2(a.X * f, a.Y * f); }
        public static V2 operator /(V2 a, double s) { float f = (float)s; return new V2(a.X / f, a.Y / f); }

        public float LengthSquared() => X * X + Y * Y;
        public float Length() => MathF.Sqrt(X * X + Y * Y);
        public float Dot(V2 o) => X * o.X + Y * o.Y;
        public float DistanceTo(V2 o)
        {
            float dx = X - o.X, dy = Y - o.Y;
            return MathF.Sqrt(dx * dx + dy * dy);
        }
        public V2 Normalized()
        {
            float l = X * X + Y * Y;
            if (l != 0f)
            {
                l = MathF.Sqrt(l);
                return new V2(X / l, Y / l);
            }
            return this;
        }
        public V2 Orthogonal() => new V2(Y, -X);
        public float Angle() => GdMath.Atan2f(Y, X);

        /// Vector2.rotated(angle): the GDScript double angle becomes a float.
        public V2 Rotated(double by)
        {
            GdMath.SinCosF((float)by, out float sine, out float cosi);
            return new V2(X * cosi - Y * sine, X * sine + Y * cosi);
        }

        public static V2 FromAngle(double angle)
        {
            GdMath.SinCosF((float)angle, out float s, out float c);
            return new V2(c, s);
        }
    }

    internal static class GdMath
    {
        public const double TAU = 6.283185307179586;
        public const double PI = 3.141592653589793;
        public const double INF = double.PositiveInfinity;
        const double CMP_EPSILON = 0.00001;

        [StructLayout(LayoutKind.Sequential)]
        struct SinCos { public float S; public float C; }

        [DllImport("libSystem.dylib", EntryPoint = "__sincosf_stret")]
        [SuppressGCTransition]
        static extern SinCos AppleSinCosF(float x);

        [DllImport("libSystem.dylib", EntryPoint = "atan2f")]
        [SuppressGCTransition]
        static extern float AppleAtan2f(float y, float x);

        static readonly bool Apple = OperatingSystem.IsMacOS();

        [MethodImpl(MethodImplOptions.AggressiveInlining)]
        public static void SinCosF(float x, out float s, out float c)
        {
            if (Apple)
            {
                SinCos r = AppleSinCosF(x);
                s = r.S;
                c = r.C;
            }
            else
            {
                s = MathF.Sin(x);
                c = MathF.Cos(x);
            }
        }

        public static float Atan2f(float y, float x) => Apple ? AppleAtan2f(y, x) : MathF.Atan2(y, x);

        // --- math_funcs.h ---
        [MethodImpl(MethodImplOptions.AggressiveInlining)]
        public static double Lerp(double from, double to, double w) => from + (to - from) * w;
        [MethodImpl(MethodImplOptions.AggressiveInlining)]
        public static double Max(double a, double b) => a > b ? a : b;
        [MethodImpl(MethodImplOptions.AggressiveInlining)]
        public static double Min(double a, double b) => a < b ? a : b;
        [MethodImpl(MethodImplOptions.AggressiveInlining)]
        public static double Clamp(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);
        [MethodImpl(MethodImplOptions.AggressiveInlining)]
        public static long ClampI(long v, long lo, long hi) => v < lo ? lo : (v > hi ? hi : v);

        static bool IsEqualApprox(double a, double b)
        {
            if (a == b) return true;
            double tolerance = CMP_EPSILON * Math.Abs(a);
            if (tolerance < CMP_EPSILON) tolerance = CMP_EPSILON;
            return Math.Abs(a - b) < tolerance;
        }

        public static double Smoothstep(double from, double to, double s)
        {
            if (IsEqualApprox(from, to))
            {
                if (from <= to) return s <= from ? 0.0 : 1.0;
                return s <= to ? 1.0 : 0.0;
            }
            double x = Clamp((s - from) / (to - from), 0.0, 1.0);
            return x * x * (3.0 - 2.0 * x);
        }

        /// Math::fposmod.
        public static double Fposmod(double x, double y)
        {
            double value = x % y; // C# % on doubles is C fmod
            if ((value < 0 && y > 0) || (value > 0 && y < 0)) value += y;
            value += 0.0;
            return value;
        }

        [MethodImpl(MethodImplOptions.AggressiveInlining)]
        public static long Floori(double x) => (long)Math.Floor(x);
        public static long Roundi(double x) => (long)Math.Round(x, MidpointRounding.AwayFromZero);
        public static double Roundf(double x) => Math.Round(x, MidpointRounding.AwayFromZero);

        /// SlopeProfile.smootherstep (GDScript arithmetic, evaluated left to right).
        public static double Smootherstep(double t)
        {
            t = Clamp(t, 0.0, 1.0);
            return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
        }

        // --- Helper.gd hashes and value noise ---
        [MethodImpl(MethodImplOptions.AggressiveInlining)]
        public static long Mix64(long value)
        {
            unchecked
            {
                long x = value + -7046029254386353131L;
                x = (x ^ (x >> 30)) * -4658895280553007687L;
                x = (x ^ (x >> 27)) * -7723592293110705685L;
                return x ^ (x >> 31);
            }
        }

        [MethodImpl(MethodImplOptions.AggressiveInlining)]
        public static double CellHash01(long seed, long cx, long cz)
        {
            long h = Mix64(seed ^ Mix64(cx ^ Mix64(cz)));
            return (double)(h & 0x7FFFFFFF) / (double)0x80000000L;
        }

        /// Helper._value_noise01(Vector3(p.x, 0, p.y), seed, scale).
        public static double ValueNoise01(V2 p, long seed, double scale)
        {
            double x = p.X / scale;
            double z = p.Y / scale;
            long cx = Floori(x);
            long cz = Floori(z);
            double fx = Smoothstep(0.0, 1.0, x - (double)cx);
            double fz = Smoothstep(0.0, 1.0, z - (double)cz);
            double c0 = CellHash01(seed, cx, cz);
            double c1 = CellHash01(seed, cx + 1, cz);
            double c2 = CellHash01(seed, cx, cz + 1);
            double c3 = CellHash01(seed, cx + 1, cz + 1);
            return Lerp(Lerp(c0, c1, fx), Lerp(c2, c3, fx), fz);
        }
    }
}
