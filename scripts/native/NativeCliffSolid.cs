// C# mirror of CliffSlopeField's bedrock surface net (production sheet style):
// _columns with _window_max, then solid's column evaluation (_solid_top with
// _mesh_height over presampled 2 m quad corners), the surface-nets meshing,
// _drop_fragments and the gradient normals / rock exposure / moss grade of
// every vertex. Same arithmetic in the same order as the GDScript (Vector2 /
// Vector3 / AABB maths in float32, scalars in double, Vector3.snapped in
// double like the engine's Math::snapped), so the payload is bit-identical;
// NativeCliffSolid.gd checks that before switching over. Stateless and
// thread-safe (solids are built in chunk tails on pool threads).
using System;
using System.Collections.Generic;
using Godot;

namespace Story.Native
{
    public partial class NativeCliffSolid : RefCounted
    {
        // CliffSlopeField / CliffSlopeEnvelope constants (the gate compares
        // this list with the GDScript's own).
        const double GRID = 0.5;            // CliffSlopeField.GRID = CliffSlopeEnvelope.H
        const double SINK = 0.02;
        const double RAISED = 0.15;
        const int MARGIN = 8;
        const double EMERGE = 0.5;
        const double COVER = 0.01;
        const double STEP = 2.0;            // TerrainChunkMesher.STEP
        const int MIN_PIECE = 60;
        const double NEG_INF = double.NegativeInfinity;

        public double[] Constants() => new double[] { GRID, SINK, RAISED, MARGIN, EMERGE, COVER, STEP, MIN_PIECE };

        readonly struct V3 : IEquatable<V3>
        {
            public readonly float X, Y, Z;
            public V3(float x, float y, float z) { X = x; Y = y; Z = z; }
            public static V3 operator +(V3 a, V3 b) => new V3(a.X + b.X, a.Y + b.Y, a.Z + b.Z);
            public static V3 operator -(V3 a, V3 b) => new V3(a.X - b.X, a.Y - b.Y, a.Z - b.Z);
            public static V3 operator -(V3 a) => new V3(-a.X, -a.Y, -a.Z);
            /// Vector3 * float: the GDScript double becomes real_t first.
            public static V3 operator *(V3 a, double s) { float f = (float)s; return new V3(a.X * f, a.Y * f, a.Z * f); }
            public static V3 operator /(V3 a, double s) { float f = (float)s; return new V3(a.X / f, a.Y / f, a.Z / f); }
            public V3 Cross(V3 b) => new V3(Y * b.Z - Z * b.Y, Z * b.X - X * b.Z, X * b.Y - Y * b.X);
            public float LengthSquared() => X * X + Y * Y + Z * Z;
            public float Length() => MathF.Sqrt(LengthSquared());
            public V3 Normalized()
            {
                float l2 = LengthSquared();
                if (l2 == 0f) return new V3(0f, 0f, 0f);
                float l = MathF.Sqrt(l2);
                return new V3(X / l, Y / l, Z / l);
            }
            // Variant key semantics: float ==, so 0.0 and -0.0 are one key
            // (float.GetHashCode normalizes them too).
            public bool Equals(V3 o) => X == o.X && Y == o.Y && Z == o.Z;
            public override bool Equals(object? o) => o is V3 v && Equals(v);
            public override int GetHashCode() => HashCode.Combine(X, Y, Z);
            public Vector3 G => new Vector3(X, Y, Z);
        }

        /// Math::snapped (double), stored back to real_t.
        static float Snap(float v, float step)
        {
            double s = step;
            return (float)(Math.Floor((double)v / s + 0.5) * s);
        }

        // ---------------------------------------------------------------- envelope reads

        sealed class Env
        {
            public V2 Origin;
            public int W, H;
            public double[] Surface = Array.Empty<double>();
            public double[] Ground = Array.Empty<double>();
            public byte[] Excluded = Array.Empty<byte>();
            public double[] Rock = Array.Empty<double>();
            public double[] Moss = Array.Empty<double>();

            int Node(V2 q, out int k)
            {
                long i = GdMath.ClampI(GdMath.Roundi(((double)q.X - Origin.X) / GRID), 0, W - 1);
                k = (int)GdMath.ClampI(GdMath.Roundi(((double)q.Y - Origin.Y) / GRID), 0, H - 1);
                return (int)i;
            }
            public double At(V2 q) { int i = Node(q, out int k); return Surface[k * W + i]; }
            public double GroundNode(V2 q) { int i = Node(q, out int k); return Ground[k * W + i]; }
            public bool ExcludedNode(V2 q)
            {
                if (Excluded.Length == 0) return false;
                int i = Node(q, out int k); return Excluded[k * W + i] != 0;
            }
            double Bilinear(double[] a, V2 q)
            {
                V2 p = (q - Origin) / GRID;
                long i = GdMath.ClampI(GdMath.Floori(p.X), 0, W - 2);
                long k = GdMath.ClampI(GdMath.Floori(p.Y), 0, H - 2);
                double fx = GdMath.Clamp((double)p.X - i, 0.0, 1.0);
                double fz = GdMath.Clamp((double)p.Y - k, 0.0, 1.0);
                int b = (int)(k * W + i);
                return GdMath.Lerp(GdMath.Lerp(a[b], a[b + 1], fx), GdMath.Lerp(a[b + W], a[b + W + 1], fx), fz);
            }
            public double Sample(V2 q) => Bilinear(Surface, q);
            public double RockAt(V2 q) => Rock.Length == 0 ? 0.0 : Bilinear(Rock, q);
            public double MossAt(V2 q) => Moss.Length == 0 ? 0.0 : Bilinear(Moss, q);
        }

        /// Vector2(key) * GRID (float32).
        static V2 KeyPoint(int x, int z) => new V2((float)x, (float)z) * GRID;

        // ---------------------------------------------------------------- _columns

        /// CliffSlopeField._window_max, literally (van Herk / Gil-Werman).
        static double[] WindowMax(double[] f, int r)
        {
            int n = f.Length, size = 2 * r + 1;
            var pre = new double[n];
            var suf = new double[n];
            for (int i = 0; i < n; i++) pre[i] = i % size == 0 ? f[i] : GdMath.Max(pre[i - 1], f[i]);
            for (int i = n - 1; i >= 0; i--) suf[i] = (i % size == size - 1 || i == n - 1) ? f[i] : GdMath.Max(suf[i + 1], f[i]);
            var output = new double[n];
            for (int i = 0; i < n; i++)
            {
                int a = Math.Max(0, i - r), b = Math.Min(n - 1, i + r);
                if (a / size != b / size) output[i] = GdMath.Max(suf[a], pre[b]);
                else if (a % size == 0) output[i] = pre[b];
                else if (b % size == size - 1 || b == n - 1) output[i] = suf[a];
                else
                {
                    double m = NEG_INF;
                    for (int d = a; d <= b; d++) m = GdMath.Max(m, f[d]);
                    output[i] = m;
                }
            }
            return output;
        }

        /// CliffSlopeField._columns(owned) as a row-major mask over
        /// [lo, lo + size): [lo (Vector2i), size (Vector2i), mask, count].
        public Godot.Collections.Array Columns(Vector2 origin, int w, int h, double[] surface, double[] ground,
            Rect2 owned, bool bedrock)
        {
            var env = new Env { Origin = new V2(origin.X, origin.Y), W = w, H = h, Surface = surface, Ground = ground };
            ColumnsCore(env, owned, bedrock, out int lox, out int loz, out int mw, out int mh, out byte[] mask, out int count);
            return new Godot.Collections.Array { new Vector2I(lox, loz), new Vector2I(mw, mh), mask, count };
        }

        static void ColumnsCore(Env env, Rect2 owned, bool bedrock, out int lox, out int loz, out int mw, out int mh,
            out byte[] mask, out int count)
        {
            Vector2 end = owned.End;
            int lx = (int)GdMath.Floori((double)owned.Position.X / GRID) - 3;
            int lz = (int)GdMath.Floori((double)owned.Position.Y / GRID) - 3;
            int hx = (int)Math.Ceiling((double)end.X / GRID) + 3;
            int hz = (int)Math.Ceiling((double)end.Y / GRID) + 3;
            int w = hx - lx + 1 + 2 * MARGIN, h = hz - lz + 1 + 2 * MARGIN;
            lox = lx; loz = lz; mw = w - 2 * MARGIN; mh = h - 2 * MARGIN;
            mask = new byte[mw * mh];
            count = 0;
            var top = new double[w * h];
            Array.Fill(top, NEG_INF);
            var grounds = new double[w * h];
            var rowAny = new bool[h];
            for (int k = 0; k < h; k++)
                for (int i = 0; i < w; i++)
                {
                    V2 q = KeyPoint(lx - MARGIN + i, lz - MARGIN + k);
                    double s = env.At(q), g = env.GroundNode(q);
                    grounds[k * w + i] = g;
                    if (s - g > RAISED) { top[k * w + i] = s; rowAny[k] = true; }
                }
            if (bedrock)
            {
                int[] offsets = { -1, 1, -w, w };
                for (int k = 1; k < h - 1; k++)
                    for (int i = 1; i < w - 1; i++)
                    {
                        int idx = k * w + i; double g = grounds[idx];
                        foreach (int offset in offsets)
                            if (Math.Abs(g - grounds[idx + offset]) >= 2.0)
                            {
                                top[idx] = GdMath.Max(top[idx], g); rowAny[k] = true; break;
                            }
                    }
            }
            var rows = new double[w * h];
            Array.Fill(rows, NEG_INF);
            bool anyRow = false;
            var line = new double[w];
            for (int k = 0; k < h; k++)
            {
                if (!rowAny[k]) continue;
                anyRow = true;
                Array.Copy(top, k * w, line, 0, w);
                var m = WindowMax(line, MARGIN);
                Array.Copy(m, 0, rows, k * w, w);
            }
            if (!anyRow) return;
            var column = new double[h];
            var colMax = new double[w * h];
            Array.Fill(colMax, NEG_INF);
            for (int i = MARGIN; i < w - MARGIN; i++)
            {
                bool any = false;
                for (int k = 0; k < h; k++) { column[k] = rows[k * w + i]; any = any || column[k] != NEG_INF; }
                if (!any) continue;
                var m = WindowMax(column, MARGIN);
                for (int k = MARGIN; k < h - MARGIN; k++) colMax[k * w + i] = m[k];
            }
            for (int k = MARGIN; k < h - MARGIN; k++)
                for (int i = MARGIN; i < w - MARGIN; i++)
                {
                    double m = colMax[k * w + i];
                    bool keep = bedrock ? double.IsFinite(m) : m > grounds[k * w + i] - 0.5;
                    if (keep) { mask[(k - MARGIN) * mw + (i - MARGIN)] = 1; count++; }
                }
        }

        // ---------------------------------------------------------------- solid

        sealed class Col
        {
            public int Jlo;
            public float[] Values = Array.Empty<float>();
            public int Cmin, Cmax;
        }

        /// The 2 m quad corners (quad (a, b) -> grid rows 2b, 2b+1, columns 2a, 2a+1).
        sealed class Mesh
        {
            public bool Present;
            public long Qx0, Qz0;
            public int Nqx, Nqz;
            public double[] Corners = Array.Empty<double>();

            public double Height(V2 q)
            {
                double x0 = Math.Floor((double)q.X / STEP) * STEP, z0 = Math.Floor((double)q.Y / STEP) * STEP;
                int a = (int)((long)Math.Floor((double)q.X / STEP) - Qx0), b = (int)((long)Math.Floor((double)q.Y / STEP) - Qz0);
                int w2 = 2 * Nqx;
                int r0 = 2 * b * w2 + 2 * a;
                double y00 = Corners[r0], y10 = Corners[r0 + 1], y01 = Corners[r0 + w2], y11 = Corners[r0 + w2 + 1];
                double fx = ((double)q.X - x0) / STEP, fz = ((double)q.Y - z0) / STEP;
                if (fx >= fz) return y00 + fx * (y10 - y00) + fz * (y11 - y10);
                return y00 + fz * (y01 - y00) + fx * (y11 - y01);
            }
        }

        /// CliffSlopeField._solid_top_over.
        static double SolidTop(Env env, Mesh mesh, V2 q)
        {
            double e = env.At(q), g = env.GroundNode(q);
            double raised = GdMath.Smoothstep(RAISED, EMERGE, e - g);
            if (raised >= 1.0 || !mesh.Present) return e - SINK;
            double m = mesh.Height(q);
            if (env.ExcludedNode(q)) return GdMath.Min(e, m) - SINK - 0.12;
            raised = GdMath.Max(raised, GdMath.Smoothstep(RAISED, EMERGE, g - m));
            return e + (m - g) * (1.0 - raised) + COVER * (1.0 - raised) - SINK * raised;
        }

        /// The 2 m quads (index ranges from `qlo`, size `qsize`) whose corner
        /// heights _solid_top reads for the columns of `mask`: quads of columns
        /// whose envelope does not fully raise the solid.
        public byte[] NeededQuads(Vector2 origin, int w, int h, double[] surface, double[] ground,
            Vector2I lo, Vector2I size, byte[] mask, Vector2I qlo, Vector2I qsize)
        {
            var env = new Env { Origin = new V2(origin.X, origin.Y), W = w, H = h, Surface = surface, Ground = ground };
            var output = new byte[qsize.X * qsize.Y];
            for (int k = 0; k < size.Y; k++)
                for (int i = 0; i < size.X; i++)
                {
                    if (mask[k * size.X + i] == 0) continue;
                    V2 q = KeyPoint(lo.X + i, lo.Y + k);
                    if (GdMath.Smoothstep(RAISED, EMERGE, env.At(q) - env.GroundNode(q)) >= 1.0) continue;
                    long a = (long)Math.Floor((double)q.X / STEP) - qlo.X, b = (long)Math.Floor((double)q.Y / STEP) - qlo.Y;
                    output[b * qsize.X + a] = 1;
                }
            return output;
        }

        /// CliffSlopeField.solid's bedrock branch over the columns `mask`
        /// ([lo, lo + size), row-major) and the owned rectangle. `corners`: the
        /// mesh heights of quads [qlo, qlo + qsize) (empty without a region).
        /// Returns [faces, root points, root normals, exposure, grade,
        /// bounds position, bounds size]; faces empty when nothing survives.
        public Godot.Collections.Array Solid(Vector2 origin, int w, int h, double[] surface, double[] ground,
            byte[] excluded, double[] rock, double[] moss, Rect2 owned, Vector2I lo, Vector2I size, byte[] mask,
            bool hasRegion, Vector2I qlo, Vector2I qsize, double[] corners)
        {
            var env = new Env
            {
                Origin = new V2(origin.X, origin.Y), W = w, H = h, Surface = surface, Ground = ground,
                Excluded = excluded, Rock = rock, Moss = moss,
            };
            var mesh = new Mesh { Present = hasRegion, Qx0 = qlo.X, Qz0 = qlo.Y, Nqx = qsize.X, Nqz = qsize.Y, Corners = corners };
            var faces = Mesh_(env, mesh, owned, lo.X, lo.Y, size.X, size.Y, mask);
            faces = DropFragments(faces);
            var result = new Godot.Collections.Array();
            var gfaces = new Vector3[faces.Count];
            for (int n = 0; n < faces.Count; n++) gfaces[n] = faces[n].G;
            result.Add(gfaces);
            if (faces.Count == 0)
            {
                result.Add(Array.Empty<Vector3>()); result.Add(Array.Empty<Vector3>());
                result.Add(Array.Empty<double>()); result.Add(Array.Empty<double>());
                result.Add(Vector3.Zero); result.Add(Vector3.Zero);
                return result;
            }
            Roots(env, faces, out var points, out var normals, out var exposure, out var grade, out V3 bpos, out V3 bsize);
            result.Add(points); result.Add(normals); result.Add(exposure); result.Add(grade);
            result.Add(bpos.G); result.Add(bsize.G);
            return result;
        }

        static readonly int[,] EDGES = { { 0, 1 }, { 2, 3 }, { 4, 5 }, { 6, 7 }, { 0, 2 }, { 1, 3 }, { 4, 6 }, { 5, 7 }, { 0, 4 }, { 1, 5 }, { 2, 6 }, { 3, 7 } };

        static List<V3> Mesh_(Env env, Mesh mesh, Rect2 owned, int lox, int loz, int mw, int mh, byte[] mask)
        {
            // field over [lox, lox + mw) x [loz, loz + mh); a column outside it is absent.
            var field = new Col?[mw * mh];
            var order = new List<int>();
            for (int k = 0; k < mh; k++)
                for (int i = 0; i < mw; i++)
                {
                    if (mask[k * mw + i] == 0) continue;
                    int kx = lox + i, kz = loz + k;
                    V2 q = KeyPoint(kx, kz);
                    double g = env.GroundNode(q);
                    double surf = SolidTop(env, mesh, q);
                    int jlo = (int)GdMath.Floori((GdMath.Min(surf, g) - 2.4) / GRID);
                    int jhi = (int)Math.Ceiling(surf / GRID) + 1;
                    int count = Math.Max(0, jhi - jlo + 1);
                    var values = new float[count];
                    for (int j = jlo; j <= jhi; j++) values[j - jlo] = (float)(surf - j * GRID);
                    int cmin = 1000000, cmax = -1000000;
                    for (int idx = 0; idx < count; idx++)
                    {
                        double next = idx + 1 < count ? values[idx + 1] : -1.0;
                        if (((double)values[idx] > 0.0) != (next > 0.0)) { cmin = Math.Min(cmin, jlo + idx); cmax = Math.Max(cmax, jlo + idx); }
                    }
                    field[k * mw + i] = new Col { Jlo = jlo, Values = values, Cmin = cmin, Cmax = cmax };
                    order.Add(k * mw + i);
                }
            Col? Get(int x, int z)
            {
                int i = x - lox, k = z - loz;
                if (i < 0 || k < 0 || i >= mw || k >= mh) return null;
                return field[k * mw + i];
            }
            double At(int i, int j, int k)
            {
                var col = Get(i, k);
                if (col == null) return -1.0;
                int idx = j - col.Jlo;
                if (idx < 0) return 1.0;
                return idx < col.Values.Length ? col.Values[idx] : -1.0;
            }
            var vertices = new Dictionary<(int, int, int), V3?>();
            V3? Vertex(int i, int j, int k)
            {
                var key = (i, j, k);
                if (vertices.TryGetValue(key, out var cached)) return cached;
                var sum = new V3(0f, 0f, 0f); int n = 0;
                for (int e = 0; e < 12; e++)
                {
                    int ca = EDGES[e, 0], cb = EDGES[e, 1];
                    int ax = i + (ca & 1), ay = j + ((ca >> 1) & 1), az = k + ((ca >> 2) & 1);
                    int bx = i + (cb & 1), by = j + ((cb >> 1) & 1), bz = k + ((cb >> 2) & 1);
                    double fa = At(ax, ay, az), fb = At(bx, by, bz);
                    if ((fa > 0.0) == (fb > 0.0)) continue;
                    double t = fa / (fa - fb);
                    sum = sum + (new V3(ax, ay, az) * (1.0 - t) + new V3(bx, by, bz) * t); n++;
                }
                V3? result = null;
                if (n > 0)
                {
                    V3 v = sum / (double)n * GRID;
                    float s = 0.0001f;
                    result = new V3(Snap(v.X, s), Snap(v.Y, s), Snap(v.Z, s));
                }
                vertices[key] = result;
                return result;
            }
            var faces = new List<V3>();
            Vector2 end = owned.End;
            int olx = (int)Math.Ceiling((double)owned.Position.X / GRID), olz = (int)Math.Ceiling((double)owned.Position.Y / GRID);
            int ohx = (int)Math.Ceiling((double)end.X / GRID) - 1, ohz = (int)Math.Ceiling((double)end.Y / GRID) - 1;
            // points: insertion-ordered set of key, key - x, key - z (over [lox - 1, lox + mw) x [loz - 1, loz + mh)).
            int pw = mw + 1, ph = mh + 1;
            var seen = new bool[pw * ph];
            var points = new List<(int, int)>();
            void Add(int x, int z)
            {
                int s = (z - loz + 1) * pw + (x - lox + 1);
                if (seen[s]) return;
                seen[s] = true; points.Add((x, z));
            }
            foreach (int f in order)
            {
                int x = lox + f % mw, z = loz + f / mw;
                Add(x, z); Add(x - 1, z); Add(x, z - 1);
            }
            var quad = new V3[4];
            int[] cx = new int[4], cy = new int[4], cz = new int[4];
            foreach (var (kx, kz) in points)
            {
                if (kx < olx || kx > ohx || kz < olz || kz > ohz) continue;
                int rx, ry;
                {
                    var c0 = Get(kx, kz);
                    rx = c0 == null ? 1000000 : c0.Jlo; ry = c0 == null ? -1000000 : c0.Jlo + c0.Values.Length;
                    var c1 = Get(kx + 1, kz);
                    int ox = c1 == null ? 1000000 : c1.Jlo, oy = c1 == null ? -1000000 : c1.Jlo + c1.Values.Length;
                    rx = Math.Min(rx, ox); ry = Math.Max(ry, oy);
                    var c2 = Get(kx, kz + 1);
                    ox = c2 == null ? 1000000 : c2.Jlo; oy = c2 == null ? -1000000 : c2.Jlo + c2.Values.Length;
                    rx = Math.Min(rx, ox); ry = Math.Max(ry, oy);
                }
                if (rx > ry) continue;
                int j0 = rx - 1, j1 = ry + 1;
                int bx = 1000000, by = -1000000;
                for (int d = 0; d < 3; d++)
                {
                    var col = d == 0 ? Get(kx, kz) : (d == 1 ? Get(kx + 1, kz) : Get(kx, kz + 1));
                    if (col == null) { bx = j0; by = j1 - 1; break; }
                    bx = Math.Min(bx, col.Cmin); by = Math.Max(by, col.Cmax);
                }
                j0 = Math.Max(j0, bx); j1 = Math.Min(j1, by + 1);
                for (int j = j0; j < j1; j++)
                {
                    double f0 = At(kx, j, kz);
                    for (int axis = 0; axis < 3; axis++)
                    {
                        int ox = axis == 0 ? 1 : 0, oy = axis == 1 ? 1 : 0, oz = axis == 2 ? 1 : 0;
                        double f1 = At(kx + ox, j + oy, kz + oz);
                        if ((f0 > 0.0) == (f1 > 0.0)) continue;
                        if (axis == 0)
                        {
                            cx[0] = kx; cy[0] = j; cz[0] = kz; cx[1] = kx; cy[1] = j - 1; cz[1] = kz;
                            cx[2] = kx; cy[2] = j - 1; cz[2] = kz - 1; cx[3] = kx; cy[3] = j; cz[3] = kz - 1;
                        }
                        else if (axis == 1)
                        {
                            cx[0] = kx; cy[0] = j; cz[0] = kz; cx[1] = kx - 1; cy[1] = j; cz[1] = kz;
                            cx[2] = kx - 1; cy[2] = j; cz[2] = kz - 1; cx[3] = kx; cy[3] = j; cz[3] = kz - 1;
                        }
                        else
                        {
                            cx[0] = kx; cy[0] = j; cz[0] = kz; cx[1] = kx - 1; cy[1] = j; cz[1] = kz;
                            cx[2] = kx - 1; cy[2] = j - 1; cz[2] = kz; cx[3] = kx; cy[3] = j - 1; cz[3] = kz;
                        }
                        int got = 0;
                        for (int c = 0; c < 4; c++)
                        {
                            var v = Vertex(cx[c], cy[c], cz[c]);
                            if (v == null) break;
                            quad[got++] = v.Value;
                        }
                        if (got < 4) continue;
                        bool forward = (f0 > 0.0) == (axis == 1);
                        for (int tri = 0; tri < 2; tri++)
                        {
                            V3 a = quad[0], b = tri == 0 ? quad[1] : quad[2], c = tri == 0 ? quad[2] : quad[3];
                            if ((double)(b - a).Cross(c - a).LengthSquared() < 1e-10) continue;
                            faces.Add(a);
                            if (forward) { faces.Add(b); faces.Add(c); }
                            else { faces.Add(c); faces.Add(b); }
                        }
                    }
                }
            }
            return faces;
        }

        /// CliffSlopeField._drop_fragments: triangles of connected pieces
        /// (sharing a vertex) of at least MIN_PIECE triangles, in order.
        static List<V3> DropFragments(List<V3> faces)
        {
            int nt = faces.Count / 3;
            var parent = new int[nt];
            for (int i = 0; i < nt; i++) parent[i] = i;
            int Find(int i)
            {
                while (parent[i] != i) { parent[i] = parent[parent[i]]; i = parent[i]; }
                return i;
            }
            var owner = new Dictionary<V3, int>(faces.Count);
            for (int t = 0; t < nt; t++)
                for (int k = 0; k < 3; k++)
                {
                    var v = faces[t * 3 + k];
                    if (owner.TryGetValue(v, out int o))
                    {
                        int a = Find(t), b = Find(o);
                        if (a != b) parent[a] = b;
                    }
                    else owner[v] = t;
                }
            var size = new int[nt];
            for (int t = 0; t < nt; t++) size[Find(t)]++;
            var kept = new List<V3>(faces.Count);
            for (int t = 0; t < nt; t++)
                if (size[Find(t)] >= MIN_PIECE) { kept.Add(faces[t * 3]); kept.Add(faces[t * 3 + 1]); kept.Add(faces[t * 3 + 2]); }
            return kept;
        }

        static void Roots(Env env, List<V3> faces, out Vector3[] points, out Vector3[] normals, out double[] exposure,
            out double[] grade, out V3 bpos, out V3 bsize)
        {
            var gradients = new Dictionary<(int, int), V3>();
            V3 Grad(int i, int k)
            {
                if (gradients.TryGetValue((i, k), out var cached)) return cached;
                V2 q = KeyPoint(i, k);
                V2 dx = new V2((float)GRID, 0f), dz = new V2(0f, (float)GRID);
                var g = new V3((float)(env.Sample(q + dx) - env.Sample(q - dx)), (float)(-2.0 * GRID),
                    (float)(env.Sample(q + dz) - env.Sample(q - dz)));
                gradients[(i, k)] = g;
                return g;
            }
            var seen = new HashSet<V3>();
            var pts = new List<Vector3>();
            var nrm = new List<Vector3>();
            var exp = new List<double>();
            var grd = new List<double>();
            V3 pos = faces[0], sz = new V3(0f, 0f, 0f);
            foreach (var p in faces)
            {
                // AABB.expand (float32).
                V3 begin = pos, end = pos + sz;
                float bx = begin.X, by = begin.Y, bz = begin.Z, ex = end.X, ey = end.Y, ez = end.Z;
                if (p.X < bx) bx = p.X;
                if (p.Y < by) by = p.Y;
                if (p.Z < bz) bz = p.Z;
                if (p.X > ex) ex = p.X;
                if (p.Y > ey) ey = p.Y;
                if (p.Z > ez) ez = p.Z;
                pos = new V3(bx, by, bz);
                sz = new V3(ex, ey, ez) - pos;
                if (!seen.Add(p)) continue;
                V3 g = p / GRID;
                int i = (int)Math.Floor((double)g.X), j = (int)Math.Floor((double)g.Y), k = (int)Math.Floor((double)g.Z);
                V3 t = g - new V3(i, j, k);
                var n = new V3(0f, 0f, 0f);
                for (int c = 0; c < 8; c++)
                {
                    int ox = c & 1, oy = (c >> 1) & 1, oz = (c >> 2) & 1;
                    double w = (ox == 1 ? (double)t.X : 1.0 - t.X) * (oy == 1 ? (double)t.Y : 1.0 - t.Y) * (oz == 1 ? (double)t.Z : 1.0 - t.Z);
                    // grad(i, j, k) is independent of the level for bedrock.
                    n = n + Grad(i + ox, k + oz) * w;
                }
                n = -n;
                V2 xz = new V2(p.X, p.Z);
                double e = env.RockAt(xz);
                pts.Add(p.G);
                nrm.Add((double)n.Length() > 1e-6 ? n.Normalized().G : Vector3.Up);
                exp.Add(e);
                grd.Add(env.Moss.Length != 0 ? env.MossAt(xz) * GdMath.Smoothstep(0.1, 0.5, e) : 0.0);
            }
            points = pts.ToArray(); normals = nrm.ToArray(); exposure = exp.ToArray(); grade = grd.ToArray();
            bpos = pos; bsize = sz;
        }
    }
}
