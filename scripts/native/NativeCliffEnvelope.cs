// C# mirror of CliffSlopeEnvelope.build's numeric pipeline (everything after
// the ground grid, the keep-out mask, the water levels and the wall-line
// ground samples, which the GDScript presamples): _walls, _close_walls,
// _channel_scale, _lips, _ridges, the closings/erosions, _distance, the blend,
// fillet and caps, _bedrock with _bench/_bench_profile, _level_outward and
// _moss_grade. Same double arithmetic in the same order as the GDScript
// (Vector2 maths in float32 through V2), so results are bit-identical;
// NativeCliffEnvelope.gd checks that before switching over. Stateless and
// thread-safe (envelopes are built in chunk tails on pool threads).
using System;
using System.Collections.Generic;
using Godot;

namespace Story.Native
{
    public partial class NativeCliffEnvelope : RefCounted
    {
        /// NativeFault: arm a one-shot test failure; this thread's last failure.
        public void ArmFault() => NativeFault.Arm("NativeCliffEnvelope");
        public string TakeError() => NativeFault.Take();

        // CliffSlopeEnvelope constants (Vector2 constants are float32; the
        // parity gate compares this list with the GDScript's own).
        const double H = 0.5;
        static readonly double SHOULDER_X = (double)3.0f;
        static readonly double SHOULDER_Y = (double)6.4f;
        const double FOOT = 4.5;
        static readonly double TIGHT_X = (double)4.5f;
        static readonly double TIGHT_Y = (double)4.0f;
        static readonly double RELIEF_X = (double)4.0f;
        static readonly double RELIEF_Y = (double)10.0f;
        const double RELIEF_SPREAD = 25.0;
        const double CELL = 12.0;
        const double LOW = 3.0;
        const double WIDEN = 20.0;
        const double JUMP = 2.0;
        const double CLIFF_DROP = 3.2;
        static readonly double VARIED_X = (double)4.5f;
        static readonly double VARIED_Y = (double)8.0f;
        const double PLAIN = 0.0;
        const double CUT_SLOPE = 1.4;
        const double CUT_MARGIN = 0.5;
        const double CHANNEL_CORE = 8.0;
        const double WATER_SINK = 0.4;
        const double BEDROCK_RECESS = 0.25;
        const double BLOCK = 5.5;
        const double PATCH = 14.0;
        const double STRETCH = 2.2;
        const double TREAD = 1.75;
        const double RISER = 1.0;
        const double CORNER = 0.25;
        const double BLOCK_BLEND = 3.0;
        const double FILTER = 1.5;
        const double NEG_INF = double.NegativeInfinity;
        const double INF = double.PositiveInfinity;

        /// The constants above, in the order NativeCliffEnvelope.gd lists the GDScript's.
        public double[] Constants() => new double[] {
            H, SHOULDER_X, SHOULDER_Y, FOOT, TIGHT_X, TIGHT_Y, RELIEF_X, RELIEF_Y, RELIEF_SPREAD,
            CELL, LOW, WIDEN, JUMP, CLIFF_DROP, VARIED_X, VARIED_Y, PLAIN, CUT_SLOPE, CUT_MARGIN,
            CHANNEL_CORE, WATER_SINK, BEDROCK_RECESS, BLOCK, PATCH, STRETCH, TREAD, RISER, CORNER,
            BLOCK_BLEND, FILTER };

        static double Max(double a, double b) => a > b ? a : b;
        static double Min(double a, double b) => a < b ? a : b;
        static double Clamp(double v, double lo, double hi) => GdMath.Clamp(v, lo, hi);
        static double Lerp(double a, double b, double t) => GdMath.Lerp(a, b, t);
        static double Smooth(double a, double b, double s) => GdMath.Smoothstep(a, b, s);
        static bool Finite(double v) => !double.IsNaN(v) && !double.IsInfinity(v);
        static long Ceili(double v) => (long)Math.Ceiling(v);

        static double[] EnvAxis(double[] f, int w, int h, double a, bool columns, byte[]? only = null)
            => NativeGridKernels.EnvelopeAxisS(f, w, h, a, columns, only ?? Array.Empty<byte>());
        static double[] Blur(double[] f, int w, int h, int r) => NativeGridKernels.BlurS(f, w, h, r);

        static double[] Envelope2(double[] f, int w, int h, double a)
            => EnvAxis(EnvAxis(f, w, h, a, false), w, h, a, true);

        static double[] Dilate(double[] g, int w, int h, double radius)
        {
            var neg = new double[g.Length];
            for (int i = 0; i < g.Length; i++) neg[i] = -g[i];
            var output = Envelope2(neg, w, h, H * H / (2.0 * radius));
            for (int i = 0; i < output.Length; i++) output[i] = -output[i];
            return output;
        }

        static double[] Erode(double[] g, int w, int h, double radius)
            => Envelope2(g, w, h, H * H / (2.0 * radius));

        static double[] Distance(byte[] mask, int w, int h)
        {
            var f = new double[mask.Length];
            for (int i = 0; i < mask.Length; i++) f[i] = mask[i] != 0 ? 0.0 : INF;
            var output = Envelope2(f, w, h, 1.0);
            for (int i = 0; i < output.Length; i++) output[i] = Math.Sqrt(output[i]) * H;
            return output;
        }

        static bool Wet(double[] wet, double[] ground, int idx) => Finite(wet[idx]) && wet[idx] > ground[idx];
        static bool Deep(double[] wet, double[] ground, int idx) => Finite(wet[idx]) && wet[idx] > ground[idx] + WATER_SINK;

        sealed class Wall
        {
            public double[] Crest = null!, Drop = null!, Run = null!, Lead = null!, Depth = null!;
            public int[] Toward = null!;
            public int[] Crests = null!;
        }

        sealed class Ctx
        {
            public V2 Origin;
            public int W, H, N;
            public double[] Ground = null!;
            public double[] WetLevel = Array.Empty<double>();
            public long Seed;
        }

        // _walls, with the wall-line ground samples given.
        static Wall[] Walls(Ctx c, int[][] kbs, double[][] ats, double[][] samples, out double[] corners)
        {
            int w = c.W, h = c.H, n = c.N;
            var g = c.Ground; var wet = c.WetLevel; var ground = c.Ground;
            var output = new Wall[2];
            for (int axis = 0; axis < 2; axis++)
            {
                int step = axis == 0 ? w : 1;
                var crest = new double[n]; Array.Fill(crest, NEG_INF);
                var drop = new double[n];
                var toward = new int[n];
                var run = new double[n]; Array.Fill(run, INF);
                var lead = new double[n];
                var depth = new double[n];
                void Mark(int top, int low, double d)
                {
                    if (wet.Length > 0 && Wet(wet, ground, top) &&
                        (!Wet(wet, ground, low) || Min(wet[top], wet[low]) <= g[top] + WATER_SINK)) return;
                    if (g[low] > ground[low] + 1e-6) d = Min(d, g[top] - g[low]);
                    if (d < .02) return;
                    if (d > drop[top]) { crest[top] = g[top]; drop[top] = d; toward[top] = low - top; }
                }
                double o = axis == 0 ? c.Origin.Y : c.Origin.X;
                int length = axis == 0 ? w : h;
                int[] kb = kbs[axis]; double[] at = ats[axis]; double[] s = samples[axis];
                int lines = kb.Length;
                for (int li = 0; li < lines; li++)
                {
                    int k = kb[li];
                    for (int t = 0; t < length; t++)
                    {
                        double before, after;
                        if (axis == 0) { before = s[(2 * li) * w + t]; after = s[(2 * li + 1) * w + t]; }
                        else { before = s[t * 2 * lines + 2 * li]; after = s[t * 2 * lines + 2 * li + 1]; }
                        if (Math.Abs(before - after) < .02) continue;
                        int i0 = axis == 0 ? ((k - 1) * w + t) : (t * w + k - 1);
                        int i1 = i0 + step;
                        if (before > after)
                        {
                            Mark(i0, i1, before - after);
                            if (toward[i0] == i1 - i0) lead[i0] = Max(lead[i0], at[li] - o - (k - 1) * H);
                        }
                        else Mark(i1, i0, after - before);
                    }
                }
                for (int k = 0; k < h; k++)
                {
                    for (int i = 0; i < w; i++)
                    {
                        int idx = k * w + i;
                        if ((axis == 0 && k == h - 1) || (axis == 1 && i == w - 1)) continue;
                        double d = g[idx] - g[idx + step];
                        if (Math.Abs(d) < JUMP) continue;
                        if (d > 0.0) Mark(idx, idx + step, d);
                        else Mark(idx + step, idx, -d);
                    }
                }
                if (wet.Length > 0)
                {
                    for (int idx = 0; idx < n; idx++)
                    {
                        if (crest[idx] == NEG_INF) continue;
                        int q = idx + toward[idx]; double len = 0.0; bool found = false;
                        for (int j = 0; j < 160; j++)
                        {
                            if (q < 0 || q >= n || (axis == 1 && Math.Abs(q % w - idx % w) > j + 2)) break;
                            if (!Wet(wet, ground, q))
                            {
                                if (len == 0.0 && j < 2) { q += toward[idx]; continue; }
                                found = len > 0.0; break;
                            }
                            len += H; q += toward[idx];
                        }
                        if (found) run[idx] = len;
                        for (int ahead = 1; ahead <= 2; ahead++)
                        {
                            int foot = idx + toward[idx] * ahead;
                            if (foot >= 0 && foot < n && Wet(wet, ground, foot))
                            {
                                depth[idx] = wet[foot] - ground[foot]; break;
                            }
                        }
                    }
                }
                var crests = new List<int>();
                for (int idx = 0; idx < n; idx++) if (crest[idx] != NEG_INF) crests.Add(idx);
                output[axis] = new Wall { Crest = crest, Drop = drop, Toward = toward, Run = run, Lead = lead, Depth = depth, Crests = crests.ToArray() };
            }
            corners = new double[n];
            for (int idx = 0; idx < n; idx++) corners[idx] = Min(output[0].Crest[idx], output[1].Crest[idx]);
            return output;
        }

        // _channel_scale
        static double[] ChannelScale(Wall wall, int w, int n, int axis, double shoulder, double foot)
        {
            var crest = wall.Crest; var drop = wall.Drop; var toward = wall.Toward; var run = wall.Run;
            var root = new double[n]; Array.Fill(root, 1.0);
            bool any = false;
            for (int idx = 0; idx < n; idx++)
            {
                if (crest[idx] == NEG_INF || !Finite(run[idx])) continue;
                double weight = Smooth(1.25 * CHANNEL_CORE, 1.75 * CHANNEL_CORE, run[idx]);
                if (weight <= 0.0) continue;
                double rs = shoulder * Clamp(LOW / drop[idx], 1.0, WIDEN); double d = drop[idx];
                double extent = Math.Sqrt(2.0 * (rs + foot) * d);
                double above = Clamp(wall.Depth[idx], 0.0, d);
                double atWater = above <= d * foot / (rs + foot) ? extent - Math.Sqrt(2.0 * foot * above) : Math.Sqrt(2.0 * rs * (d - above));
                double shore = Max(run[idx] * .5 - CHANNEL_CORE * .25, run[idx] * .25);
                if (atWater <= shore) continue;
                root[idx] = Lerp(1.0, Max(.1, shore / atWater), weight); any = true;
            }
            if (!any) return Array.Empty<double>();
            int along = axis == 0 ? 1 : w;
            for (int sweep = 0; sweep < 2; sweep++)
            {
                int step = sweep == 0 ? -along : along;
                for (int it = 0; it < n; it++)
                {
                    int idx = sweep == 0 ? it : n - 1 - it;
                    int prev = idx + step;
                    if (crest[idx] == NEG_INF || prev < 0 || prev >= n || crest[prev] == NEG_INF || toward[prev] != toward[idx]) continue;
                    root[idx] = Min(root[idx], root[prev] + .08);
                }
            }
            for (int idx = 0; idx < n; idx++) root[idx] *= root[idx];
            return root;
        }

        // _close_walls
        static double[] CloseWalls(double[] g, Wall[] walls, double[] corners, int w, int h, double shoulder, double foot,
            byte[] channel, double[] along, Dictionary<double, double[]> groundRows)
        {
            var output = (double[])g.Clone();
            int n = g.Length;
            for (int axis = 0; axis < 2; axis++)
            {
                var wall = walls[axis];
                var crest = wall.Crest; var drop = wall.Drop; var toward = wall.Toward;
                var spread = (double[])g.Clone();
                double[] scale = ChannelScale(wall, w, n, axis, shoulder, foot);
                var fitted = (double[])g.Clone(); bool anyFitted = false;
                var lines = new byte[axis == 0 ? w : h];
                foreach (int idx in wall.Crests)
                {
                    lines[axis == 0 ? idx % w : idx / w] = 1;
                    double shoulderRadius = shoulder * Clamp(LOW / drop[idx], 1.0, WIDEN);
                    double radius = shoulderRadius + foot;
                    double lead = wall.Lead[idx];
                    double squeeze = scale.Length > 0 ? scale[idx] : 1.0;
                    int q = idx;
                    if (squeeze < .999)
                    {
                        anyFitted = true;
                        double rs = shoulderRadius * squeeze; double rf = foot * squeeze;
                        double extent = Math.Sqrt(2.0 * (rs + rf) * drop[idx]); double x1 = extent * rs / (rs + rf);
                        double baseLevel = crest[idx] - drop[idx];
                        long count = Ceili((extent + lead) / H) + 1;
                        for (long j = 0; j < count; j++)
                        {
                            if (q < 0 || q >= n) break;
                            double x = Max(0.0, j * H - lead);
                            double y = x <= x1 ? crest[idx] - x * x / (2.0 * rs) : baseLevel + (extent - x) * (extent - x) / (2.0 * rf);
                            fitted[q] = Max(fitted[q], y);
                            if (channel.Length > 0) channel[q] = 1;
                            if (axis == 1 && ((q % w == 0 && toward[idx] < 0) || (q % w == w - 1 && toward[idx] > 0))) break;
                            q += toward[idx];
                        }
                        continue;
                    }
                    double plain = shoulder + foot;
                    long reach = Ceili((Max(Math.Sqrt(2.0 * plain * (drop[idx] + 1.0)), Math.Sqrt(2.0 * radius * drop[idx])) + lead) / H) + 1;
                    for (long j = 0; j < reach + 1; j++)
                    {
                        if (q < 0 || q >= n) break;
                        double d = Max(0.0, j * H - lead);
                        double widened = Min(crest[idx], g[q] + drop[idx]) - d * d / (2.0 * radius);
                        spread[q] = Max(spread[q], Max(crest[idx] - d * d / (2.0 * plain), widened));
                        if (axis == 1 && ((q % w == 0 && toward[idx] < 0) || (q % w == w - 1 && toward[idx] > 0))) break;
                        q += toward[idx];
                    }
                }
                var closed = EnvAxis(spread, w, h, H * H / (2.0 * foot), axis == 0, lines);
                var lifted = new byte[axis == 0 ? h : w];
                double[] lift = Array.Empty<double>();
                bool withAlong = along.Length > 0;
                if (withAlong) { lift = new double[n]; Array.Fill(lift, -0.0); }
                int lineCount = axis == 0 ? w : h;
                int lineLength = axis == 0 ? h : w;
                int stride = axis == 0 ? w : 1;
                for (int line = 0; line < lineCount; line++)
                {
                    if (lines[line] == 0) continue;
                    int idx = axis == 0 ? line : line * w;
                    for (int t = 0; t < lineLength; t++)
                    {
                        output[idx] = Max(output[idx], anyFitted ? Max(closed[idx], fitted[idx]) : closed[idx]);
                        if (withAlong)
                        {
                            lift[idx] = -Max(closed[idx] - g[idx], 0.0);
                            if (lift[idx] < 0.0) lifted[t] = 1;
                        }
                        idx += stride;
                    }
                }
                if (withAlong)
                {
                    lift = EnvAxis(lift, w, h, H * H / (2.0 * foot), axis == 1, lifted);
                    for (int line = 0; line < lifted.Length; line++)
                    {
                        if (lifted[line] == 0) continue;
                        int idx = axis == 0 ? line * w : line;
                        int len = axis == 0 ? w : h;
                        for (int t = 0; t < len; t++)
                        {
                            along[idx] = Max(along[idx], -lift[idx]);
                            idx += axis == 0 ? 1 : w;
                        }
                    }
                }
            }
            bool anyCorner = false;
            for (int idx = 0; idx < n; idx++) if (corners[idx] != NEG_INF) { anyCorner = true; break; }
            if (!anyCorner) return output;
            var cornerRows = new byte[h];
            for (int k = 0; k < h; k++)
                for (int i = 0; i < w; i++)
                    if (corners[k * w + i] != NEG_INF) { cornerRows[k] = 1; break; }
            var neg = new double[n];
            for (int idx = 0; idx < n; idx++) neg[idx] = -corners[idx];
            double reachA = H * H / (2.0 * (shoulder + foot));
            neg = EnvAxis(EnvAxis(neg, w, h, reachA, false, cornerRows), w, h, reachA, true);
            var round = (double[])g.Clone();
            var liftRows = new byte[h];
            var liftCols = new byte[w];
            for (int idx = 0; idx < n; idx++)
            {
                double dilated = -neg[idx];
                if (dilated > g[idx]) { round[idx] = dilated; liftRows[idx / w] = 1; liftCols[idx % w] = 1; }
            }
            double a = H * H / (2.0 * foot);
            if (!groundRows.TryGetValue(foot, out var rows))
            {
                rows = EnvAxis(g, w, h, a, false);
                groundRows[foot] = rows;
            }
            var liftedRows = EnvAxis(round, w, h, a, false, liftRows);
            var rowPass = (double[])rows.Clone();
            for (int k = 0; k < h; k++)
            {
                if (liftRows[k] == 0) continue;
                for (int i = 0; i < w; i++) rowPass[k * w + i] = liftedRows[k * w + i];
            }
            round = EnvAxis(rowPass, w, h, a, true, liftCols);
            for (int i = 0; i < w; i++)
            {
                if (liftCols[i] == 0) continue;
                for (int k = 0; k < h; k++) output[k * w + i] = Max(output[k * w + i], round[k * w + i]);
            }
            return output;
        }

        // _lips (runs: a hash map beside an insertion-ordered key list, as the
        // GDScript Dictionary iterates).
        static double[] Lips(Wall[] walls, double[] g, int w, int n, bool shouldered)
        {
            var lips = new double[n]; Array.Fill(lips, NEG_INF);
            double shoulder = SHOULDER_Y;
            long past = Ceili(2.0 * FOOT / H);
            for (int axis = 0; axis < 2; axis++)
            {
                var wall = walls[axis];
                var drop = wall.Drop; var toward = wall.Toward; var leadArr = wall.Lead;
                int step = axis == 0 ? 1 : w;
                var index = new Dictionary<long, int>();
                var keyAt = new List<int>(); var keyToward = new List<int>();
                var runX = new List<float>(); var runY = new List<float>();
                foreach (int idx in wall.Crests)
                {
                    double radius = shoulder * Clamp(LOW / drop[idx], 1.0, WIDEN) + FOOT;
                    long reach = Ceili((Max(Math.Sqrt(2.0 * (shoulder + FOOT) * (drop[idx] + 1.0)), Math.Sqrt(2.0 * radius * drop[idx])) + leadArr[idx]) / H) + 1;
                    for (long k = -past; k < past + 1; k++)
                    {
                        long at = idx + k * step;
                        if (at < 0 || at >= n || (axis == 0 && at / w != idx / w)) continue;
                        int ia = (int)at;
                        long key = ((long)ia << 32) ^ (uint)toward[idx];
                        if (!index.TryGetValue(key, out int slot))
                        {
                            slot = keyAt.Count; index[key] = slot;
                            keyAt.Add(ia); keyToward.Add(toward[idx]); runX.Add(0f); runY.Add(0f);
                        }
                        // Vector2(maxf(run.x, reach), maxf(run.y, lead)): float32 components.
                        runX[slot] = (float)Max(runX[slot], (double)reach);
                        runY[slot] = (float)Max(runY[slot], leadArr[idx]);
                    }
                }
                for (int slot = 0; slot < keyAt.Count; slot++)
                {
                    int q = keyAt[slot]; double lip = g[q]; int dir = keyToward[slot];
                    double rx = runX[slot], ry = runY[slot];
                    long count = (long)rx + 1;
                    for (long j = 0; j < count; j++)
                    {
                        if (q < 0 || q >= n) break;
                        double d = shouldered ? Max(0.0, j * H - ry) : 0.0;
                        lips[q] = Max(lips[q], lip - d * d / (2.0 * (shoulder + FOOT)));
                        if (axis == 1 && ((q % w == 0 && dir < 0) || (q % w == w - 1 && dir > 0))) break;
                        q += dir;
                    }
                }
            }
            return lips;
        }

        // Vector2.snapped: Godot's Math::snapped runs in double (a float tie at
        // x/step + 0.5 rounds differently).
        static V2 Snapped(V2 v, double step)
            => V2.D(Math.Floor(v.X / step + 0.5) * step, Math.Floor(v.Y / step + 0.5) * step);

        // _ridges
        static double[] Ridges(Ctx c, double[] narrow, double[] wide, double[] dilated)
        {
            int w = c.W, h = c.H; long seed = c.Seed;
            var t = new double[w * h]; Array.Fill(t, .5);
            double reach = SHOULDER_Y + FOOT;
            for (int k = 1; k < h - 1; k++)
            {
                for (int i = 1; i < w - 1; i++)
                {
                    int idx = k * w + i;
                    if (wide[idx] - narrow[idx] < .005) continue;
                    V2 q = c.Origin + new V2(i, k) * H;
                    V2 grad = V2.D(dilated[idx + 1] - dilated[idx - 1], dilated[idx + w] - dilated[idx - w]) / (2.0 * H);
                    V2 src = Snapped(q + grad * reach, .25);
                    double warp = (GdMath.ValueNoise01(src, seed + 9131, 23.0) - .5) * 12.0;
                    V2 pw = new V2(src.X + (float)warp, src.Y + (float)(-warp));
                    double r = .6 * (GdMath.ValueNoise01(pw, seed + 9133, 7.0) * 2.0 - 1.0)
                        + .4 * (GdMath.ValueNoise01(pw, seed + 9137, 14.0) * 2.0 - 1.0);
                    double sign = r > 0.0 ? 1.0 : (r < 0.0 ? -1.0 : 0.0);
                    t[idx] = .5 + .5 * Clamp(sign * Math.Pow(Math.Abs(r) * 1.6, .7), -1.0, 1.0);
                }
            }
            t = Blur(Blur(t, w, h, 2), w, h, 2);
            for (int idx = 0; idx < t.Length; idx++) t[idx] = Smooth(.22, .78, t[idx]);
            for (int k = 0; k < h; k++)
            {
                for (int i = 0; i < w; i++)
                {
                    int idx = k * w + i;
                    if (wide[idx] - narrow[idx] < .005) continue;
                    V2 p = V2.D(c.Origin.X + i * H, c.Origin.Y + k * H);
                    double bump = (GdMath.ValueNoise01(p, seed + 9301, 4.5) - .5) * .15 + (GdMath.ValueNoise01(p, seed + 9307, 2.6) - .5) * .04;
                    t[idx] = Clamp(t[idx] + bump, 0.0, 1.0);
                }
            }
            return t;
        }

        // _moss_grade
        static double[] MossGrade(int w, int hh, double[] F)
        {
            var grade = new double[w * hh];
            for (int k = 1; k < hh - 1; k++)
            {
                for (int i = 1; i < w - 1; i++)
                {
                    int idx = k * w + i;
                    double gx = (F[idx + 1] - F[idx - 1]) / (2.0 * H); double gz = (F[idx + w] - F[idx - w]) / (2.0 * H);
                    grade[idx] = 1.0 - 1.0 / Math.Sqrt(1.0 + gx * gx + gz * gz);
                }
            }
            return Blur(grade, w, hh, 2);
        }

        // Helper.position_hash01(Vector3(a, b, salt) * .5, seed).
        static double PositionHash01(long a, long b, long salt, long seed)
        {
            long kx = GdMath.Roundi((double)((float)a * 0.5f) * 2.0);
            long ky = GdMath.Roundi((double)((float)b * 0.5f) * 2.0);
            long kz = GdMath.Roundi((double)((float)salt * 0.5f) * 2.0);
            // Vector3i components are int32.
            kx = (int)kx; ky = (int)ky; kz = (int)kz;
            long hsh = GdMath.Mix64(seed ^ GdMath.Mix64(kx ^ GdMath.Mix64(ky ^ GdMath.Mix64(kz))));
            return (double)(hsh & 0x7FFFFFFF) / (double)0x80000000L;
        }

        // _bedrock's `noise` closure.
        static double LatticeNoise(V2 q, double scale, long salt, long seed)
        {
            V2 p = q / scale;
            long i = GdMath.Floori(p.X); long k = GdMath.Floori(p.Y);
            V2 f = p - new V2(i, k);
            f = f * f * (new V2(3f, 3f) - f * 2.0);
            long s = seed + 4431;
            double c00 = PositionHash01(i, k, salt, s), c10 = PositionHash01(i + 1, k, salt, s);
            double c01 = PositionHash01(i, k + 1, salt, s), c11 = PositionHash01(i + 1, k + 1, salt, s);
            return Lerp(Lerp(c00, c10, f.X), Lerp(c01, c11, f.X), f.Y);
        }

        sealed class Cell { public V2 Point; public double Phase, Step, Riser; }

        static Cell CellAt(Dictionary<long, Cell> cells, long cx, long cz, long seed)
        {
            long key = (cx << 32) ^ (cz & 0xFFFFFFFFL);
            if (cells.TryGetValue(key, out var cell)) return cell;
            long s = seed + 7727;
            double Hsh(long salt) => PositionHash01(cx, cz, salt, s);
            V2 pt = (new V2((int)cx, (int)cz) + V2.D(.15 + .7 * Hsh(1), .15 + .7 * Hsh(2))) * BLOCK;
            double step = Lerp(3.5, 6.5, Hsh(4)) * (Hsh(7) >= .33 ? 1.0 : 1.15);
            cell = new Cell { Point = pt, Phase = Hsh(3) * step, Step = step, Riser = Lerp(.60, .75, Hsh(5)) };
            cells[key] = cell;
            return cell;
        }

        // _bench
        static double Bench(double height, Cell cell, double grade)
        {
            double reach = grade * H * FILTER;
            double a = BenchProfile(height - .75 * reach, cell, grade) + BenchProfile(height + .75 * reach, cell, grade);
            return (a + 3.0 * (BenchProfile(height - .25 * reach, cell, grade) + BenchProfile(height + .25 * reach, cell, grade))) / 8.0;
        }

        // _bench_profile
        static double BenchProfile(double height, Cell cell, double grade)
        {
            double step = cell.Step;
            double lo = RISER * grade / step; double hi = 1.0 - TREAD * grade / step;
            double r = Clamp(cell.Riser, lo, Max(lo, hi));
            double nn = Math.Floor((height + cell.Phase) / step);
            double baseLevel = nn * step - cell.Phase;
            double x = Clamp((height - baseLevel) / (r * step), 0.0, 1.0);
            double m = 1.0 / (1.0 - CORNER);
            double y = x < CORNER ? m * x * x / (2.0 * CORNER) : (x > 1.0 - CORNER ? 1.0 - m * (1.0 - x) * (1.0 - x) / (2.0 * CORNER) : m * (x - CORNER * .5));
            return Lerp(height, baseLevel + step * y, Smooth(0.0, .15, hi - lo));
        }

        // _bedrock (surface, moss_grade and rock written into the arrays given).
        static void Bedrock(Ctx c, double[] surface, out double[] mossGrade, out double[] rock,
            double[] floorLevel, double[] top, double[] cliff, double[] cut, bool anyCut)
        {
            int n = c.N, w = c.W, hh = c.H; long seed = c.Seed;
            var ground = c.Ground;
            var F = (double[])surface.Clone();
            var moss = new double[n];
            var crown = new byte[n];
            for (int k = 1; k < hh - 1; k++)
            {
                for (int i = 1; i < w - 1; i++)
                {
                    int idx = k * w + i;
                    double gx = (F[idx + 1] - F[idx - 1]) / (2.0 * H); double gz = (F[idx + w] - F[idx - w]) / (2.0 * H);
                    moss[idx] = 1.0 - 1.0 / Math.Sqrt(1.0 + gx * gx + gz * gz);
                    if (Math.Abs(F[idx] - ground[idx]) < .05 && F[idx] - floorLevel[idx] > 1.0 && gx * gx + gz * gz < .04) crown[idx] = 1;
                }
            }
            var crownDistance = Distance(crown, w, hh);
            mossGrade = Blur(moss, w, hh, 2);
            var raw = new double[n];
            var patch = new double[n];
            for (int k = 1; k < hh - 1; k++)
            {
                for (int i = 1; i < w - 1; i++)
                {
                    int idx = k * w + i;
                    raw[idx] = Smooth(.3, 1.0, cut[idx]);
                    if (cliff[idx] <= 0.0) continue;
                    double gx = (F[idx + 1] - F[idx - 1]) / (2.0 * H); double gz = (F[idx + w] - F[idx - w]) / (2.0 * H);
                    double steep = Math.Sqrt(gx * gx + gz * gz);
                    if (steep < .45) continue;
                    double span = Max(top[idx] - floorLevel[idx], 1.0);
                    double frac = (F[idx] - floorLevel[idx]) / span;
                    V2 q = c.Origin + new V2(i, k) * H;
                    double mask = .65 * LatticeNoise(q, PATCH, 1, seed) + .35 * LatticeNoise(q, PATCH * .45, 2, seed);
                    double e = Smooth(.54, .7, mask + .3 * (Smooth(.6, 1.6, steep) - .5));
                    e *= Smooth(.45, .9, steep) * Smooth(.08, .28, frac) * cliff[idx];
                    raw[idx] = Max(raw[idx], e); patch[idx] = e;
                }
            }
            raw = Blur(Blur(raw, w, hh, 2), w, hh, 2);
            if (anyCut)
            {
                var cutZone = new double[n];
                for (int idx = 0; idx < n; idx++) cutZone[idx] = Smooth(.05, .3, cut[idx]);
                cutZone = Blur(Blur(cutZone, w, hh, 2), w, hh, 2);
                for (int idx = 0; idx < n; idx++) patch[idx] *= 1.0 - Smooth(0.0, .2, cutZone[idx]);
            }
            patch = Blur(Blur(patch, w, hh, 2), w, hh, 2);
            var cells = new Dictionary<long, Cell>();
            var carvedNodes = new byte[n];
            var nearD = new double[25];
            var nearC = new Cell[25];
            for (int k = 1; k < hh - 1; k++)
            {
                for (int i = 1; i < w - 1; i++)
                {
                    int idx = k * w + i;
                    double gx = (F[idx + 1] - F[idx - 1]) / (2.0 * H); double gz = (F[idx + w] - F[idx - w]) / (2.0 * H);
                    double grade = Math.Sqrt(gx * gx + gz * gz);
                    double fade = Smooth(.3, .65, grade) * Smooth(3.0, 7.0, crownDistance[idx]);
                    raw[idx] *= fade;
                    double e = patch[idx] * fade;
                    if (e < .01) continue;
                    V2 q = c.Origin + new V2(i, k) * H;
                    long bx = GdMath.Floori(q.X / BLOCK), bz = GdMath.Floori(q.Y / BLOCK);
                    V2 fall = V2.D(gx, gz) / grade;
                    double d1 = INF; int m = 0;
                    for (int dz = -2; dz < 3; dz++)
                    {
                        for (int dx = -2; dx < 3; dx++)
                        {
                            // Vector2i components are int32.
                            Cell cell = CellAt(cells, (int)(bx + dx), (int)(bz + dz), seed);
                            V2 delta = q - cell.Point; double across = delta.Dot(fall);
                            double d = Math.Sqrt(delta.LengthSquared() + (STRETCH * STRETCH - 1.0) * across * across);
                            nearD[m] = d; nearC[m] = cell; m++; d1 = Min(d1, d);
                        }
                    }
                    double height = F[idx] - .35 * LatticeNoise(q, 4.6, 3, seed);
                    double carved = 0.0, weight = 0.0;
                    for (int j = 0; j < m; j++)
                    {
                        double wt = 1.0 - Smooth(0.0, BLOCK_BLEND, nearD[j] - d1);
                        if (wt > 0.0) { carved += wt * Bench(height, nearC[j], grade); weight += wt; }
                    }
                    carved /= weight;
                    carved = Min(carved, Max(F[idx], top[idx] - .5));
                    double shaped = Max(Lerp(F[idx], carved, Smooth(.15, .55, e)), F[idx] - BEDROCK_RECESS);
                    surface[idx] = Max(ground[idx] + Min(F[idx] - ground[idx], .4), shaped);
                    carvedNodes[idx] = 1;
                }
            }
            LevelOutward(w, surface, F, carvedNodes);
            rock = raw;
        }

        // _level_outward
        static void LevelOutward(int w, double[] surface, double[] F, byte[] carved)
        {
            var order = new List<long>();
            for (int idx = 0; idx < carved.Length; idx++)
                if (carved[idx] != 0) order.Add((long)GdMath.Roundf((1e4 - F[idx]) * 1000.0) * 1000000 + idx);
            var keys = order.ToArray();
            Array.Sort(keys);
            foreach (long key in keys)
            {
                int idx = (int)(key % 1000000);
                double gx = F[idx + 1] - F[idx - 1]; double gz = F[idx + w] - F[idx - w];
                if (Max(Math.Abs(gx), Math.Abs(gz)) < 1e-6) continue;
                int a, b; double t;
                if (Math.Abs(gx) >= Math.Abs(gz))
                {
                    a = idx + (gx > 0.0 ? 1 : -1); t = Math.Abs(gz / gx); b = a + (gz > 0.0 ? w : -w);
                }
                else
                {
                    a = idx + (gz > 0.0 ? w : -w); t = Math.Abs(gx / gz); b = a + (gx > 0.0 ? 1 : -1);
                }
                surface[idx] = Min(surface[idx], Min(surface[a], Lerp(surface[a], surface[b], t)));
            }
        }

        /// CliffSlopeEnvelope.build after its inputs. `kb*`/`at*`/`samples*`: the
        /// wall lines per axis (node index kb, world coordinate at) and their ground
        /// samples at at -/+ 0.001 (axis 0: row 2l before, 2l+1 after, w wide;
        /// axis 1: per node row t, columns 2l before and 2l+1 after).
        /// Returns [surface, rock, moss_grade, stages].
        public Godot.Collections.Array BuildShared(Vector2 origin, int w, int h, double[] ground,
            byte[] excluded, double[] wetLevel, long seed, bool bedrock)
        {
            try
            {
                NativeFault.Check("NativeCliffEnvelope");
                int n = w * h;
                var c = new Ctx { Origin = new V2(origin.X, origin.Y), W = w, H = h, N = n,
                    Ground = ground, WetLevel = wetLevel, Seed = seed };
                var surface = (double[])ground.Clone();
                var rock = Array.Empty<double>(); var moss = Array.Empty<double>();
                if (bedrock)
                {
                    var mask = new double[n];
                    for (int k = 1; k < h - 1; k++) for (int i = 1; i < w - 1; i++)
                    {
                        int idx = k * w + i;
                        if (excluded.Length > 0 && excluded[idx] != 0) continue;
                        if (wetLevel.Length > 0 && double.IsFinite(wetLevel[idx])) continue;
                        double gx = (ground[idx + 1] - ground[idx - 1]) / (2.0 * H);
                        double gz = (ground[idx + w] - ground[idx - w]) / (2.0 * H);
                        mask[idx] = Smooth(1.0, 1.2, Math.Sqrt(gx * gx + gz * gz));
                        surface[idx] = ground[idx] + .3 * mask[idx];
                    }
                    var floor = Erode(ground, w, h, SHOULDER_Y + FOOT);
                    var top = Dilate(ground, w, h, SHOULDER_Y + FOOT);
                    Bedrock(c, surface, out moss, out rock, floor, top, mask, new double[n], false);
                    for (int idx = 0; idx < n; idx++)
                    {
                        surface[idx] = Clamp(surface[idx], ground[idx], ground[idx] + .3 * mask[idx]);
                        rock[idx] *= mask[idx];
                    }
                }
                return new Godot.Collections.Array { surface, rock, moss };
            }
            catch (Exception e) { NativeFault.Record(e); return null!; }
        }

        public Godot.Collections.Array Build(Vector2 origin, int w, int h, double[] ground, byte[] excluded,
            double[] wetLevel, int[] kb0, double[] at0, double[] samples0, int[] kb1, double[] at1,
            double[] samples1, long seed, bool bedrock, bool withStages)
        {
            try
            {
                NativeFault.Check("NativeCliffEnvelope");
                int n = w * h;
                var c = new Ctx { Origin = new V2(origin.X, origin.Y), W = w, H = h, N = n, Ground = ground, WetLevel = wetLevel, Seed = seed };
                var stages = new Godot.Collections.Dictionary();
                bool anyExcluded = excluded.Length > 0;
                bool anyWet = wetLevel.Length > 0;
                var g = ground;
                var walls = Walls(c, new[] { kb0, kb1 }, new[] { at0, at1 }, new[] { samples0, samples1 }, out var corners);
                if (withStages)
                {
                    stages["crest0"] = walls[0].Crest; stages["drop0"] = walls[0].Drop; stages["lead0"] = walls[0].Lead;
                    stages["crest1"] = walls[1].Crest; stages["drop1"] = walls[1].Drop; stages["lead1"] = walls[1].Lead;
                }
                double[] surface, rock = Array.Empty<double>(), mossGrade = Array.Empty<double>();
                if (walls[0].Crests.Length == 0 && walls[1].Crests.Length == 0)
                {
                    surface = (double[])g.Clone();
                    if (bedrock) { mossGrade = MossGrade(w, h, surface); rock = new double[n]; }
                    return new Godot.Collections.Array { surface, rock, mossGrade, stages };
                }
                double shX = SHOULDER_X, shY = SHOULDER_Y, foot = FOOT;
                var channel = new byte[n];
                var alongNarrow = new double[n]; var alongWide = new double[n];
                var alongTight = new double[n]; var alongTightWide = new double[n];
                var groundRows = new Dictionary<double, double[]>();
                var narrow = CloseWalls(g, walls, corners, w, h, shX, foot, channel, alongNarrow, groundRows);
                var wideDilated = Dilate(g, w, h, shY + foot);
                var wide = CloseWalls(g, walls, corners, w, h, shY, foot, channel, alongWide, groundRows);
                var tight = CloseWalls(g, walls, corners, w, h, TIGHT_X, TIGHT_Y, channel, alongTight, groundRows);
                var tightWide = CloseWalls(g, walls, corners, w, h, 6.4, TIGHT_Y, channel, alongTightWide, groundRows);
                if (withStages)
                {
                    stages["narrow"] = narrow; stages["wide"] = wide; stages["tight"] = tight; stages["tight_wide"] = tightWide;
                    stages["along_narrow"] = alongNarrow; stages["channel"] = channel;
                }
                var floorLevel = Erode(g, w, h, SHOULDER_Y + FOOT);
                var relief = new double[n];
                for (int idx = 0; idx < n; idx++) relief[idx] = wideDilated[idx] - floorLevel[idx];
                relief = Dilate(relief, w, h, RELIEF_SPREAD);
                var drop = relief;
                if (anyWet)
                {
                    var floorDry = (double[])g.Clone();
                    for (int idx = 0; idx < n; idx++)
                        if (Finite(wetLevel[idx]) && wetLevel[idx] > floorDry[idx]) floorDry[idx] = wetLevel[idx];
                    floorDry = Erode(floorDry, w, h, SHOULDER_Y + FOOT);
                    drop = new double[n];
                    for (int idx = 0; idx < n; idx++) drop[idx] = wideDilated[idx] - floorDry[idx];
                    drop = Dilate(drop, w, h, RELIEF_SPREAD);
                }
                var t = Ridges(c, narrow, wide, wideDilated);
                if (withStages) { stages["relief"] = relief; stages["drop"] = drop; stages["ridges"] = t; }
                surface = new double[n];
                var along = new double[n];
                for (int idx = 0; idx < n; idx++)
                {
                    double tall = Smooth(RELIEF_X, RELIEF_Y, relief[idx]);
                    double ridge = Lerp(PLAIN, t[idx], Smooth(VARIED_X, VARIED_Y, drop[idx]));
                    surface[idx] = Lerp(Lerp(narrow[idx], wide[idx], ridge), Lerp(tight[idx], tightWide[idx], ridge), tall);
                    along[idx] = Lerp(Lerp(alongNarrow[idx], alongWide[idx], ridge), Lerp(alongTight[idx], alongTightWide[idx], ridge), tall);
                }
                if (withStages) stages["blend"] = (double[])surface.Clone();
                var filleted = Erode(Dilate(surface, w, h, FOOT), w, h, FOOT);
                var lips = Lips(walls, g, w, n, true);
                if (withStages) stages["lips"] = lips;
                for (int idx = 0; idx < n; idx++)
                {
                    double fill = filleted[idx];
                    if (lips[idx] > NEG_INF) fill = Min(fill, Max(lips[idx], surface[idx]));
                    if (channel[idx] != 0 && Deep(wetLevel, ground, idx)) fill = Min(fill, wetLevel[idx] - .3);
                    surface[idx] = Lerp(surface[idx], Max(surface[idx], fill), Smooth(0.0, .5, Max(surface[idx] - g[idx], along[idx])));
                }
                var uncut = (double[])surface.Clone();
                if (withStages) stages["fillet"] = uncut;
                var shaped = (double[])surface.Clone();
                var caps = new double[n]; Array.Fill(caps, INF);
                if (anyExcluded)
                {
                    var dist = Distance(excluded, w, h);
                    for (int idx = 0; idx < n; idx++) caps[idx] = ground[idx] + CUT_SLOPE * Max(0.0, dist[idx] - CUT_MARGIN);
                }
                var rockCaps = (double[])caps.Clone();
                var rockLips = Lips(walls, g, w, n, false);
                for (int idx = 0; idx < n; idx++)
                    if (rockLips[idx] > NEG_INF)
                        rockCaps[idx] = Min(rockCaps[idx], Max(rockLips[idx], uncut[idx]) + 7.5 * Smooth(0.0, 1.0, uncut[idx] - rockLips[idx]));
                for (int idx = 0; idx < n; idx++) surface[idx] = Min(surface[idx], Max(ground[idx], caps[idx]));
                if (withStages) { stages["caps"] = (double[])surface.Clone(); stages["rock_caps"] = rockCaps; }
                if (bedrock)
                {
                    if (anyWet)
                    {
                        for (int idx = 0; idx < n; idx++)
                        {
                            if (!Deep(wetLevel, ground, idx)) continue;
                            double room = 7.5 * Smooth(.75, 3.0, surface[idx] - wetLevel[idx]);
                            rockCaps[idx] = Min(rockCaps[idx], surface[idx] + room);
                        }
                    }
                    var cut = new double[n];
                    for (int idx = 0; idx < n; idx++) cut[idx] = shaped[idx] - surface[idx];
                    var cliff = new double[n];
                    for (int idx = 0; idx < n; idx++)
                        cliff[idx] = Smooth(VARIED_X, VARIED_Y, relief[idx]) * Smooth(CLIFF_DROP, VARIED_X, drop[idx]) * Smooth(.15, 1.0, uncut[idx] - g[idx]);
                    if (anyWet)
                    {
                        for (int idx = 0; idx < n; idx++)
                            if (Deep(wetLevel, ground, idx)) cliff[idx] *= 1.0 - Smooth(-.5, 0.0, wetLevel[idx] - surface[idx]);
                    }
                    Bedrock(c, surface, out mossGrade, out rock, floorLevel, wideDilated, cliff, cut, anyExcluded);
                    if (withStages) { stages["cliff"] = cliff; stages["bedrock"] = (double[])surface.Clone(); }
                    for (int idx = 0; idx < n; idx++) surface[idx] = Min(surface[idx], Max(ground[idx], rockCaps[idx]));
                }
                return new Godot.Collections.Array { surface, rock, mossGrade, stages };
            }
            catch (Exception e) { NativeFault.Record(e); return null!; }
        }
    }
}
