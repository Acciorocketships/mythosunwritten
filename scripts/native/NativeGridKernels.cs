// C# mirrors of CliffSlopeEnvelope's pure grid kernels (_envelope_axis with
// its _envelope1 lower envelope, and _blur). Same double arithmetic in the same
// order as the GDScript, so results are bit-identical; NativeGridKernels.gd
// checks that on random grids before switching over. Stateless and
// thread-safe (chunk tails run in parallel).
using System;
using Godot;

namespace Story.Native
{
    public partial class NativeGridKernels : RefCounted
    {
        /// NativeFault: arm a one-shot test failure; this thread's last failure.
        public void ArmFault() => NativeFault.Arm("NativeGridKernels");
        public string TakeError() => NativeFault.Take();

        // _envelope1(f, n, a, out, v, z): min over p of f[p] + a*(q-p)^2.
        static void Envelope1(double[] f, int n, double a, double[] output, int[] v, double[] z)
        {
            int k = -1;
            for (int q = 0; q < n; q++)
            {
                double fq = f[q];
                if (fq == double.PositiveInfinity) continue;
                if (k < 0)
                {
                    k = 0; v[0] = q; z[0] = double.NegativeInfinity; z[1] = double.PositiveInfinity;
                    continue;
                }
                double s = ((fq + a * q * q) - (f[v[k]] + a * v[k] * v[k])) / (2.0 * a * (q - v[k]));
                while (s <= z[k])
                {
                    k -= 1;
                    if (k < 0) break;
                    s = ((fq + a * q * q) - (f[v[k]] + a * v[k] * v[k])) / (2.0 * a * (q - v[k]));
                }
                k += 1;
                v[k] = q; z[k] = k == 0 ? double.NegativeInfinity : s; z[k + 1] = double.PositiveInfinity;
            }
            if (k < 0)
            {
                for (int q = 0; q < n; q++) output[q] = double.PositiveInfinity;
                return;
            }
            int j = 0;
            for (int q = 0; q < n; q++)
            {
                while (z[j + 1] < q) j += 1;
                long d = q - v[j];
                output[q] = f[v[j]] + a * d * d;
            }
        }

        // _envelope_axis(f, w, h, a, columns, only)
        public double[] EnvelopeAxis(double[] f, int w, int h, double a, bool columns, byte[] only)
        {
            try { NativeFault.Check("NativeGridKernels"); return EnvelopeAxisS(f, w, h, a, columns, only); }
            catch (Exception e) { NativeFault.Record(e); return null!; }
        }

        internal static double[] EnvelopeAxisS(double[] f, int w, int h, double a, bool columns, byte[] only)
        {
            int n = Math.Max(w, h);
            var result = new double[n];
            var v = new int[n];
            var z = new double[n + 1];
            var output = (double[])f.Clone();
            bool all = only.Length == 0;
            if (columns)
            {
                var line = new double[h];
                for (int i = 0; i < w; i++)
                {
                    if (!all && only[i] == 0) continue;
                    for (int k = 0; k < h; k++) line[k] = f[k * w + i];
                    Envelope1(line, h, a, result, v, z);
                    for (int k = 0; k < h; k++) output[k * w + i] = result[k];
                }
                return output;
            }
            var row = new double[w];
            for (int k = 0; k < h; k++)
            {
                if (!all && only[k] == 0) continue;
                Array.Copy(f, k * w, row, 0, w);
                Envelope1(row, w, a, result, v, z);
                Array.Copy(result, 0, output, k * w, w);
            }
            return output;
        }

        // _slide(f, r, highest): van Herk / Gil-Werman sliding max (min).
        static double[] Slide(double[] f, int r, bool highest)
        {
            int n = f.Length; int size = 2 * r + 1;
            var pre = new double[n];
            var suf = new double[n];
            for (int i = 0; i < n; i++)
                pre[i] = i % size == 0 ? f[i] : (highest ? GdMax(pre[i - 1], f[i]) : GdMin(pre[i - 1], f[i]));
            for (int i = n - 1; i >= 0; i--)
                suf[i] = (i % size == size - 1 || i == n - 1) ? f[i] : (highest ? GdMax(suf[i + 1], f[i]) : GdMin(suf[i + 1], f[i]));
            var output = new double[n];
            for (int i = 0; i < n; i++)
            {
                double a = suf[Math.Max(0, i - r)]; double b = pre[Math.Min(n - 1, i + r)];
                output[i] = highest ? GdMax(a, b) : GdMin(a, b);
            }
            return output;
        }

        // Godot's maxf/minf are its MAX/MIN macros: a > b ? a : b; a < b ? a : b
        // (exact for signed zeros too).
        static double GdMax(double a, double b) => a > b ? a : b;
        static double GdMin(double a, double b) => a < b ? a : b;

        // _window(g, w, h, reach, highest) with r = ceili(reach / H).
        public double[] Window(double[] g, int w, int h, int r, bool highest)
        {
            try
            {
                NativeFault.Check("NativeGridKernels");
                var rows = (double[])g.Clone();
                var line = new double[w];
                for (int k = 0; k < h; k++)
                {
                    Array.Copy(g, k * w, line, 0, w);
                    var slid = Slide(line, r, highest);
                    Array.Copy(slid, 0, rows, k * w, w);
                }
                var output = (double[])rows.Clone();
                var column = new double[h];
                for (int i = 0; i < w; i++)
                {
                    for (int k = 0; k < h; k++) column[k] = rows[k * w + i];
                    var slid = Slide(column, r, highest);
                    for (int k = 0; k < h; k++) output[k * w + i] = slid[k];
                }
                return output;
            }
            catch (Exception e) { NativeFault.Record(e); return null!; }
        }

        // _blur(f, w, h, r): box blur of radius r nodes, rows then columns.
        public double[] Blur(double[] f, int w, int h, int r)
        {
            try { NativeFault.Check("NativeGridKernels"); return BlurS(f, w, h, r); }
            catch (Exception e) { NativeFault.Record(e); return null!; }
        }

        internal static double[] BlurS(double[] f, int w, int h, int r)
        {
            var tmp = (double[])f.Clone();
            for (int k = 0; k < h; k++)
            {
                double sum = 0.0; long count = 0;
                for (int i = 0; i < Math.Min(r, w); i++) { sum += f[k * w + i]; count += 1; }
                for (int i = 0; i < w; i++)
                {
                    if (i + r < w) { sum += f[k * w + i + r]; count += 1; }
                    if (i - r - 1 >= 0) { sum -= f[k * w + i - r - 1]; count -= 1; }
                    tmp[k * w + i] = sum / count;
                }
            }
            var output = (double[])tmp.Clone();
            for (int i = 0; i < w; i++)
            {
                double sum = 0.0; long count = 0;
                for (int k = 0; k < Math.Min(r, h); k++) { sum += tmp[k * w + i]; count += 1; }
                for (int k = 0; k < h; k++)
                {
                    if (k + r < h) { sum += tmp[(k + r) * w + i]; count += 1; }
                    if (k - r - 1 >= 0) { sum -= tmp[(k - r - 1) * w + i]; count -= 1; }
                    output[k * w + i] = sum / count;
                }
            }
            return output;
        }
    }
}
