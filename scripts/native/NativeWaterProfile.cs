// C# mirror of WaterField.profile's terrain-shaped branch (_descend_segment,
// _find_descent_spans, _shape_descent_span, _dense_span_curve,
// _find_descent_knots, _eval_descent_knots, _descent_knot_tangents,
// _dense_span_points and the terminal pond reconcile) over lattice corner data
// handed in once, plus the trace's natural terrain corridor
// (HeightfieldPlan.compute_rect_region's certified values, computed only on
// the lattice points the profile reads). Same double / float32 arithmetic in
// the same order (GdMath.cs; PackedFloat32Array stores are (float) casts).
// Stateless; NativeWaterFill.gd gates it against the GDScript.
using System;
using System.Collections.Generic;
using Godot;
using static Story.Native.GdMath;

namespace Story.Native
{
    public partial class NativeWaterFill
    {
        // consts (NativeWaterFill.gd _profile_consts): SURFACE_RIDE, FILM,
        // _EASE_BAND, _DESCENT_STEP, DESCENT_CLAMP, EPS, DESCENT_POOL_GAP,
        // FALL_DROP_MIN, lattice spacing, TerrainTileField.cliff_end.
        sealed class ProfileConsts
        {
            public readonly double Ride, Film, Ease, Step, Clamp_, Eps, PoolGap, FallDrop, Spacing;
            public readonly int CliffEnd;
            public ProfileConsts(double[] c)
            {
                Ride = c[0]; Film = c[1]; Ease = c[2]; Step = c[3]; Clamp_ = c[4]; Eps = c[5];
                PoolGap = c[6]; FallDrop = c[7]; Spacing = c[8]; CliffEnd = (int)c[9];
            }
        }

        static long LatticeKey(long i, long j) => (i << 32) ^ (j & 0xFFFFFFFFL);

        static V2 LerpV(V2 a, V2 b, double weight)
        {
            float w = (float)weight;
            return new V2(a.X + (b.X - a.X) * w, a.Y + (b.Y - a.Y) * w);
        }

        static double Signf(double x) => x > 0.0 ? 1.0 : (x < 0.0 ? -1.0 : 0.0);

        // ------------------------------------------------------------ the trace

        sealed class ProfileTrace
        {
            public readonly V2[] P;
            public readonly float[] Beds, Widths;
            public readonly int N;
            public readonly float[] Raw;
            public readonly double[] RawD, ArcD;
            public readonly float[] Arclen;
            public readonly bool Varies;
            public readonly List<(int lo, int hi)> Spans = new();

            public ProfileTrace(Vector2[] points, float[] beds, float[] widths, double lvl0, ProfileConsts c)
            {
                N = points.Length;
                P = new V2[N];
                for (int k = 0; k < N; k++) P[k] = new V2(points[k].X, points[k].Y);
                Beds = beds;
                Widths = widths;
                Raw = new float[N];
                RawD = new double[N];
                Arclen = new float[N];
                ArcD = new double[N];
                if (N == 0) return;
                Raw[0] = (float)lvl0;
                for (int i = 1; i < N; i++)
                    Raw[i] = (float)Min(Raw[i - 1], (double)beds[i] + c.Ride);
                for (int i = 0; i < N; i++) RawD[i] = Raw[i];
                for (int i = 0; i < N; i++)
                    if (Raw[i] != Raw[0]) { Varies = true; break; }
                for (int i = 1; i < N; i++)
                    Arclen[i] = (float)(Arclen[i - 1] + (double)P[i - 1].DistanceTo(P[i]));
                for (int i = 0; i < N; i++) ArcD[i] = Arclen[i];
                if (Varies) FindSpans(c);
            }

            // _find_descent_spans
            void FindSpans(ProfileConsts c)
            {
                int i = 1;
                while (i < N)
                {
                    if (RawD[i - 1] - RawD[i] <= c.Eps) { i++; continue; }
                    int lo = i - 1, hi = i;
                    while (hi + 1 < N)
                    {
                        if (RawD[hi] - RawD[hi + 1] > c.Eps) { hi++; continue; }
                        int flatEnd = hi;
                        while (flatEnd + 1 < N && RawD[flatEnd] - RawD[flatEnd + 1] <= c.Eps) flatEnd++;
                        if (ArcD[flatEnd] - ArcD[hi] >= c.PoolGap || flatEnd + 1 >= N) break;
                        hi = flatEnd + 1;
                    }
                    Spans.Add((lo, hi));
                    i = hi + 1;
                }
            }

            // _dense_span_points
            public void DensePoints(int lo, int hi, ProfileConsts c, out V2[] pos, out float[] w)
            {
                double spanLen = ArcD[hi] - ArcD[lo];
                int steps = Math.Max(1, (int)Math.Ceiling(spanLen / c.Step));
                pos = new V2[steps + 1];
                w = new float[steps + 1];
                int segI = lo;
                for (int k = 0; k <= steps; k++)
                {
                    double targetArc = ArcD[lo] + spanLen * (double)k / (double)steps;
                    while (segI < hi - 1 && ArcD[segI + 1] < targetArc) segI++;
                    double segStart = ArcD[segI], segEnd = ArcD[segI + 1];
                    double segT = segEnd - segStart < 0.001 ? 0.0
                        : Clamp((targetArc - segStart) / (segEnd - segStart), 0.0, 1.0);
                    pos[k] = LerpV(P[segI], P[segI + 1], segT);
                    w[k] = (float)Lerp(Widths[segI], Widths[segI + 1], segT);
                }
            }

            /// Every position the profile can read ground at: the trace points,
            /// every segment's _descend_segment substeps and every span's dense
            /// points (a superset: which of them are read depends on ground).
            public void Positions(ProfileConsts c, Action<V2> visit)
            {
                for (int i = 0; i < N; i++) visit(P[i]);
                for (int i = 1; i < N; i++)
                {
                    V2 a = P[i - 1], b = P[i];
                    int steps = SegmentSteps(a, b, c);
                    for (int k = 1; k <= steps; k++) visit(LerpV(a, b, (double)k / (double)steps));
                }
                foreach (var (lo, hi) in Spans)
                {
                    DensePoints(lo, hi, c, out V2[] pos, out _);
                    foreach (V2 p in pos) visit(p);
                }
            }
        }

        static int SegmentSteps(V2 a, V2 b, ProfileConsts c)
        {
            float segLen = a.DistanceTo(b);
            return Math.Max(1, (int)Math.Ceiling((double)segLen / c.Step));
        }

        static long PointOf(double v, double spacing) => (long)Math.Floor(v / spacing + 0.5);

        // ------------------------------------------------------------ ground

        /// Lattice corner data on a dense window over its bounding box;
        /// At == TerrainTileField.surface_y (ungraded) where every corner the
        /// sample reads was handed in.
        sealed class LatticeGround
        {
            readonly float[] _h;
            readonly int[] _s;
            readonly bool[] _has;
            readonly int _w, _rows, _i0, _j0;
            readonly double _spacing;
            readonly int _mode;

            public LatticeGround(int[] lattice, float[] heights, int[] storeys, double spacing, int mode)
            {
                _spacing = spacing;
                _mode = mode;
                int count = lattice.Length / 2;
                if (count == 0 || heights.Length != count || storeys.Length != count)
                    throw new ArgumentException("lattice data size");
                int i0 = int.MaxValue, j0 = int.MaxValue, i1 = int.MinValue, j1 = int.MinValue;
                for (int k = 0; k < count; k++)
                {
                    i0 = Math.Min(i0, lattice[2 * k]); i1 = Math.Max(i1, lattice[2 * k]);
                    j0 = Math.Min(j0, lattice[2 * k + 1]); j1 = Math.Max(j1, lattice[2 * k + 1]);
                }
                _i0 = i0; _j0 = j0; _w = i1 - i0 + 1; _rows = j1 - j0 + 1;
                _h = new float[_w * _rows];
                _s = new int[_w * _rows];
                _has = new bool[_w * _rows];
                for (int k = 0; k < count; k++)
                {
                    int a = (lattice[2 * k + 1] - j0) * _w + (lattice[2 * k] - i0);
                    _h[a] = heights[k];
                    _s[a] = storeys[k];
                    _has[a] = true;
                }
            }

            public double At(V2 p) => At(p.X, p.Y);

            public double At(double x, double z)
            {
                long oi = PointOf(x, _spacing), oj = PointOf(z, _spacing);
                for (long j = oj - 1; j <= oj + 1; j++)
                    for (long i = oi - 1; i <= oi + 1; i++)
                    {
                        long a = (j - _j0) * _w + (i - _i0);
                        if (i < _i0 || j < _j0 || i - _i0 >= _w || j - _j0 >= _rows || !_has[a])
                            throw new InvalidOperationException($"lattice point ({i}, {j}) missing");
                    }
                return NativeTileKernel.Sample(_h, _s, _w, _i0, _j0, _spacing, x, z, (int)oi, (int)oj, _mode);
            }
        }

        /// The lattice points (interleaved i, j; sorted) whose corner data the
        /// profile of this trace can read: the 3 x 3 points round the owner of
        /// every position Positions() visits.
        public int[] ProfileLattice(Vector2[] points, float[] beds, double lvl0, double[] consts)
        {
            try
            {
                NativeFault.Check("NativeWaterFill");
                var c = new ProfileConsts(consts);
                var trace = new ProfileTrace(points, beds, beds, lvl0, c);
                var keys = new HashSet<long>();
                trace.Positions(c, p =>
                {
                    long oi = PointOf(p.X, c.Spacing), oj = PointOf(p.Y, c.Spacing);
                    for (long j = oj - 1; j <= oj + 1; j++)
                        for (long i = oi - 1; i <= oi + 1; i++)
                            keys.Add(LatticeKey(i, j));
                });
                return SortedPoints(keys);
            }
            catch (Exception e) { NativeFault.Record(e); return null!; }
        }

        static int[] SortedPoints(HashSet<long> keys)
        {
            var list = new List<(int j, int i)>(keys.Count);
            foreach (long key in keys) list.Add(((int)(key & 0xFFFFFFFFL), (int)(key >> 32)));
            list.Sort();
            var output = new int[list.Count * 2];
            for (int k = 0; k < list.Count; k++) { output[2 * k] = list[k].i; output[2 * k + 1] = list[k].j; }
            return output;
        }

        // ------------------------------------------------------------ profile

        /// WaterField.profile's terrain-shaped branch. Returns [levels,
        /// descent lo, descent hi, descent sizes, pos (all descents), w, lvl].
        public Godot.Collections.Array Profile(Vector2[] points, float[] beds, float[] widths, double lvl0,
            bool hasPond, double pondY, int[] lattice, float[] heights, int[] storeys, double[] consts)
        {
            try
            {
                NativeFault.Check("NativeWaterFill");
                var c = new ProfileConsts(consts);
                var t = new ProfileTrace(points, beds, widths, lvl0, c);
                var g = new LatticeGround(lattice, heights, storeys, c.Spacing, c.CliffEnd);
                int n = t.N;
                var levels = new float[n];
                var dLo = new List<int>();
                var dHi = new List<int>();
                var dPos = new List<V2[]>();
                var dW = new List<float[]>();
                var dLvl = new List<float[]>();
                levels[0] = (float)lvl0;
                if (!t.Varies)
                {
                    Array.Copy(t.Raw, levels, n);
                }
                else
                {
                    int i = 1, spanIdx = 0;
                    while (i < n)
                    {
                        if (spanIdx < t.Spans.Count && t.Spans[spanIdx].lo == i - 1)
                        {
                            var (lo, hi) = t.Spans[spanIdx];
                            ShapeSpan(t, g, c, lo, hi, levels[lo], t.Raw[hi], out float[] samples, out float[] dense);
                            for (int k = lo + 1; k <= hi; k++) levels[k] = samples[k - lo];
                            t.DensePoints(lo, hi, c, out V2[] pos, out float[] w);
                            dLo.Add(lo); dHi.Add(hi); dPos.Add(pos); dW.Add(w); dLvl.Add(dense);
                            i = hi + 1;
                            spanIdx++;
                        }
                        else
                        {
                            double target = Min(levels[i - 1], (double)beds[i] + c.Ride);
                            levels[i] = (float)Descend(g, c, t.P[i - 1], t.P[i], levels[i - 1], target);
                            i++;
                        }
                    }
                }
                if (hasPond)
                {
                    double ps = pondY;
                    if ((double)levels[n - 1] - ps <= c.FallDrop + 0.01)
                    {
                        int i = n - 1;
                        while (i >= 0 && levels[i] < ps)
                        {
                            levels[i] = (float)Maxf(levels[i], ps);
                            i--;
                        }
                        levels[n - 1] = (float)ps;
                        foreach (float[] dl in dLvl)
                            for (int k = 0; k < dl.Length; k++) dl[k] = (float)Maxf(dl[k], ps);
                    }
                    else if (n >= 2)
                    {
                        levels[n - 1] = (float)Descend(g, c, t.P[n - 2], t.P[n - 1], levels[n - 2], ps);
                        for (int d = 0; d < dHi.Count; d++)
                        {
                            float[] dl = dLvl[d];
                            if (dHi[d] == n - 1 && dl.Length > 0)
                                dl[dl.Length - 1] = (float)Min(dl[dl.Length - 1], levels[n - 1]);
                        }
                    }
                }
                var sizes = new int[dLo.Count];
                int total = 0;
                for (int d = 0; d < dLo.Count; d++) { sizes[d] = dPos[d].Length; total += sizes[d]; }
                var posOut = new Vector2[total];
                var wOut = new float[total];
                var lvlOut = new float[total];
                int o = 0;
                for (int d = 0; d < dLo.Count; d++)
                {
                    if (dLvl[d].Length != sizes[d]) throw new InvalidOperationException("dense size");
                    for (int k = 0; k < sizes[d]; k++, o++)
                    {
                        posOut[o] = new Vector2(dPos[d][k].X, dPos[d][k].Y);
                        wOut[o] = dW[d][k];
                        lvlOut[o] = dLvl[d][k];
                    }
                }
                return new Godot.Collections.Array
                {
                    levels, dLo.ToArray(), dHi.ToArray(), sizes, posOut, wOut, lvlOut
                };
            }
            catch (Exception e) { NativeFault.Record(e); return null!; }
        }

        // _descend_segment
        static double Descend(LatticeGround g, ProfileConsts c, V2 a, V2 b, double start, double end)
        {
            if (start == end) return start;
            int steps = SegmentSteps(a, b, c);
            double held = start;
            for (int k = 1; k <= steps; k++)
            {
                double tt = (double)k / (double)steps;
                V2 p = LerpV(a, b, tt);
                double ground = g.At(p);
                double smooth = Lerp(start, end, Smootherstep(tt));
                double hug = ground + c.Film;
                double w = Smootherstep(Clamp((hug - smooth) / c.Ease, 0.0, 1.0));
                held = Min(held, Lerp(smooth, hug, w));
            }
            return held;
        }

        // _shape_descent_span (with _dense_span_curve)
        static void ShapeSpan(ProfileTrace t, LatticeGround g, ProfileConsts c, int lo, int hi,
            double anchorStart, double anchorEnd, out float[] samples, out float[] dense)
        {
            double groundLo = g.At(t.P[lo]);
            double groundHi = g.At(t.P[hi]);
            anchorStart = Maxf(anchorStart, groundLo + c.Clamp_);
            anchorEnd = Maxf(anchorEnd, groundHi + c.Clamp_);
            double spanLen = t.ArcD[hi] - t.ArcD[lo];
            samples = new float[hi - lo + 1];
            if (spanLen < 0.001)
            {
                for (int k = 0; k < samples.Length; k++) samples[k] = (float)anchorStart;
                dense = new[] { (float)anchorStart, (float)anchorStart };
                return;
            }
            t.DensePoints(lo, hi, c, out V2[] pos, out _);
            int steps = pos.Length - 1;
            var ground = new float[steps + 1];
            for (int k = 0; k <= steps; k++) ground[k] = (float)g.At(pos[k]);
            var knotK = new List<int>();
            var knotV = new List<double>();
            FindKnots(ground, steps, anchorStart, anchorEnd, c, knotK, knotV);
            dense = EvalKnots(knotK, knotV, steps);
            dense[0] = (float)anchorStart;
            dense[steps] = (float)anchorEnd;
            samples[0] = (float)anchorStart;
            samples[hi - lo] = (float)anchorEnd;
            for (int idx = lo + 1; idx < hi; idx++)
            {
                double d2 = t.ArcD[idx] - t.ArcD[lo];
                double kf = Clamp(d2 / c.Step, 0.0, (double)steps);
                int k0 = (int)Math.Floor(kf);
                int k1 = Math.Min(k0 + 1, steps);
                double tt = kf - (double)k0;
                samples[idx - lo] = (float)Lerp(dense[k0], dense[k1], tt);
            }
        }

        // _find_descent_knots
        static void FindKnots(float[] ground, int steps, double anchorStart, double anchorEnd,
            ProfileConsts c, List<int> knotK, List<double> knotV)
        {
            knotK.Add(0); knotV.Add(anchorStart);
            knotK.Add(steps); knotV.Add(anchorEnd);
            int guard = steps + 2;
            var isKnot = new bool[steps + 1];
            while (guard > 0)
            {
                guard--;
                float[] curve = EvalKnots(knotK, knotV, steps);
                Array.Clear(isKnot);
                foreach (int kn in knotK) isKnot[kn] = true;
                bool added = false;
                int k = 1;
                while (k < steps)
                {
                    if (isKnot[k] || curve[k] >= (double)ground[k] + c.Clamp_ - 0.0001) { k++; continue; }
                    int runEnd = k;
                    while (runEnd + 1 < steps && !isKnot[runEnd + 1]
                        && curve[runEnd + 1] < (double)ground[runEnd + 1] + c.Clamp_ - 0.0001)
                        runEnd++;
                    int peakK = k;
                    double peakV = (double)ground[k] + c.Clamp_;
                    for (int kk = k; kk <= runEnd; kk++)
                    {
                        double fv = (double)ground[kk] + c.Clamp_;
                        if (fv >= peakV) { peakV = fv; peakK = kk; }
                    }
                    int insertAt = knotK.Count;
                    for (int i = 0; i < knotK.Count; i++)
                        if (knotK[i] > peakK) { insertAt = i; break; }
                    peakV = Clamp(peakV, knotV[insertAt], knotV[insertAt - 1]);
                    knotK.Insert(insertAt, peakK);
                    knotV.Insert(insertAt, peakV);
                    added = true;
                    k = runEnd + 1;
                }
                if (!added) break;
            }
        }

        // _eval_descent_knots
        static float[] EvalKnots(List<int> knotK, List<double> knotV, int steps)
        {
            float[] tangents = KnotTangents(knotK, knotV);
            var output = new float[steps + 1];
            for (int seg = 0; seg < knotK.Count - 1; seg++)
            {
                int k0 = knotK[seg], k1 = knotK[seg + 1];
                double y0 = knotV[seg], y1 = knotV[seg + 1];
                double m0 = tangents[seg], m1 = tangents[seg + 1];
                double h = (double)(k1 - k0);
                for (int k = k0; k <= k1; k++)
                {
                    double t = k1 == k0 ? 0.0 : (double)(k - k0) / h;
                    double t2 = t * t;
                    double t3 = t2 * t;
                    double hb00 = 2.0 * t3 - 3.0 * t2 + 1.0;
                    double hb10 = t3 - 2.0 * t2 + t;
                    double hb01 = -2.0 * t3 + 3.0 * t2;
                    double hb11 = t3 - t2;
                    output[k] = (float)(hb00 * y0 + hb10 * h * m0 + hb01 * y1 + hb11 * h * m1);
                }
            }
            return output;
        }

        // _descent_knot_tangents
        static float[] KnotTangents(List<int> knotK, List<double> knotV)
        {
            int m = knotK.Count - 1;
            var delta = new float[m];
            for (int i = 0; i < m; i++)
            {
                double h = (double)(knotK[i + 1] - knotK[i]);
                delta[i] = (float)((knotV[i + 1] - knotV[i]) / h);
            }
            var tangents = new float[knotK.Count];
            for (int i = 1; i < knotK.Count - 1; i++)
            {
                double d0 = delta[i - 1], d1 = delta[i];
                if (d0 == 0.0 || d1 == 0.0 || (d0 > 0.0) != (d1 > 0.0)) { tangents[i] = 0f; continue; }
                double mi = (d0 + d1) * 0.5;
                double minD = Min(Math.Abs(d0), Math.Abs(d1));
                if (Math.Abs(mi) > 3.0 * minD) mi = Signf(mi) * 3.0 * minD;
                tangents[i] = (float)mi;
            }
            return tangents;
        }

        // ------------------------------------------------------------ corridor terrain
        // HeightfieldPlan.compute_rect_region's certified values on a sparse
        // set of lattice points. A certified point's clamped storey is the
        // minimum over q of target(q) + max_step * |p - q|_1 (targets >= 0, so
        // only q closer than ceil(target(p) / max_step) can lower it); its level
        // depends on storeys within (LEVELS - 1) relaxation steps plus
        // (CLIFF - 1) cliff-distance steps plus one neighbour ring.

        /// terrain: STOREY_HEIGHT, LEVEL_HEIGHT, LEVELS_PER_STOREY,
        /// _CLIFF_SEARCH_MAX, RENDER_LEVELS (0/1), _NO_CLIFF.
        static int CorridorRing(double[] terrain) => ((int)terrain[2] - 1) + ((int)terrain[3] - 1) + 1;

        /// The points within Manhattan distance CorridorRing of `n` (sorted):
        /// every point whose storey the levels of `n` read.
        public int[] CorridorPoints(int[] n, double[] terrain)
        {
            try
            {
                NativeFault.Check("NativeWaterFill");
                int ring = CorridorRing(terrain);
                var keys = new HashSet<long>();
                for (int k = 0; k < n.Length / 2; k++)
                    for (int dj = -ring; dj <= ring; dj++)
                    {
                        int rem = ring - Math.Abs(dj);
                        for (int di = -rem; di <= rem; di++)
                            keys.Add(LatticeKey(n[2 * k] + di, n[2 * k + 1] + dj));
                    }
                return SortedPoints(keys);
            }
            catch (Exception e) { NativeFault.Record(e); return null!; }
        }

        static long RoundWith(double q, int aggregation) => aggregation switch
        {
            0 => (long)Math.Floor(q),
            2 => (long)Math.Ceiling(q),
            _ => Roundi(q),
        };

        static int Quantize(double h, int aggregation, int maxStoreys, double storeyHeight) =>
            (int)ClampI(RoundWith(h / storeyHeight, aggregation), 0, maxStoreys);

        /// Only q with max_step * |p - q|_1 < target(p) can lower p's storey.
        static int ClampRadius(int target, int maxStep) => Math.Max(0, (target + maxStep - 1) / maxStep - 1);

        /// The points (sorted) outside `s` that the clamped storeys of `s` read:
        /// within ClampRadius of each point of `s`. One row-interval sweep over
        /// the bounding box.
        public int[] CorridorDisks(int[] s, double[] hs, int aggregation, int maxStoreys, int maxStep, double[] terrain)
        {
            try
            {
                NativeFault.Check("NativeWaterFill");
                int count = s.Length / 2;
                var radius = new int[count];
                int reach = 0, i0 = int.MaxValue, j0 = int.MaxValue, i1 = int.MinValue, j1 = int.MinValue;
                for (int k = 0; k < count; k++)
                {
                    radius[k] = ClampRadius(Quantize(hs[k], aggregation, maxStoreys, terrain[0]), maxStep);
                    reach = Math.Max(reach, radius[k]);
                    i0 = Math.Min(i0, s[2 * k]); i1 = Math.Max(i1, s[2 * k]);
                    j0 = Math.Min(j0, s[2 * k + 1]); j1 = Math.Max(j1, s[2 * k + 1]);
                }
                if (count == 0) return Array.Empty<int>();
                i0 -= reach; j0 -= reach; i1 += reach; j1 += reach;
                int w = i1 - i0 + 1, rows = j1 - j0 + 1;
                var cover = new int[(w + 1) * rows];   // per-row interval difference array
                for (int k = 0; k < count; k++)
                {
                    int pi = s[2 * k] - i0, pj = s[2 * k + 1] - j0, r = radius[k];
                    for (int dj = -r; dj <= r; dj++)
                    {
                        int rem = r - Math.Abs(dj), row = (pj + dj) * (w + 1);
                        cover[row + pi - rem]++;
                        cover[row + pi + rem + 1]--;
                    }
                }
                var inner = new bool[w * rows];
                for (int k = 0; k < count; k++) inner[(s[2 * k + 1] - j0) * w + (s[2 * k] - i0)] = true;
                var output = new List<int>();
                for (int j = 0; j < rows; j++)
                {
                    int run = 0;
                    for (int i = 0; i < w; i++)
                    {
                        run += cover[j * (w + 1) + i];
                        if (run > 0 && !inner[j * w + i]) { output.Add(i + i0); output.Add(j + j0); }
                    }
                }
                return output.ToArray();
            }
            catch (Exception e) { NativeFault.Record(e); return null!; }
        }

        /// Certified surface heights (float32) and storeys of the points `n`,
        /// from the samples (_sample()[0]) of CorridorPoints(n) = `s` and of
        /// CorridorDisks(s) = `d`. Returns [heights, storeys].
        public Godot.Collections.Array CorridorTerrain(int[] n, int[] s, double[] hs, int[] d, double[] hd,
            int aggregation, int maxStoreys, int maxStep, double[] terrain)
        {
            try
            {
                NativeFault.Check("NativeWaterFill");
                double storeyHeight = terrain[0], levelHeight = terrain[1];
                int levels = (int)terrain[2], cliffMax = (int)terrain[3], noCliff = (int)terrain[5];
                bool renderLevels = terrain[4] != 0.0;
                int i0 = int.MaxValue, j0 = int.MaxValue, i1 = int.MinValue, j1 = int.MinValue;
                void Bound(int[] pts)
                {
                    for (int k = 0; k < pts.Length / 2; k++)
                    {
                        i0 = Math.Min(i0, pts[2 * k]); i1 = Math.Max(i1, pts[2 * k]);
                        j0 = Math.Min(j0, pts[2 * k + 1]); j1 = Math.Max(j1, pts[2 * k + 1]);
                    }
                }
                Bound(s);
                Bound(d);
                int w = i1 - i0 + 1, rows = j1 - j0 + 1;
                var h = new double[w * rows];
                var target = new int[w * rows];
                var has = new bool[w * rows];
                void Fill(int[] pts, double[] values)
                {
                    for (int k = 0; k < pts.Length / 2; k++)
                    {
                        int a = (pts[2 * k + 1] - j0) * w + (pts[2 * k] - i0);
                        h[a] = values[k];
                        target[a] = Quantize(values[k], aggregation, maxStoreys, storeyHeight);
                        has[a] = true;
                    }
                }
                Fill(s, hs);
                Fill(d, hd);
                int Index(int i, int j)
                {
                    if (i < i0 || j < j0 || i > i1 || j > j1 || !has[(j - j0) * w + (i - i0)])
                        throw new InvalidOperationException($"corridor point ({i}, {j}) missing");
                    return (j - j0) * w + (i - i0);
                }
                // Clamped storeys: the separable L1 distance transform of the
                // targets (absent points never win), read on s only.
                const int Absent = 1 << 28;
                var clamp = new int[w * rows];
                for (int a = 0; a < clamp.Length; a++) clamp[a] = has[a] ? target[a] : Absent;
                for (int j = 0; j < rows; j++)
                {
                    int row = j * w;
                    for (int i = 1; i < w; i++) clamp[row + i] = Math.Min(clamp[row + i], clamp[row + i - 1] + maxStep);
                    for (int i = w - 2; i >= 0; i--) clamp[row + i] = Math.Min(clamp[row + i], clamp[row + i + 1] + maxStep);
                }
                for (int j = 1; j < rows; j++)
                    for (int i = 0; i < w; i++) clamp[j * w + i] = Math.Min(clamp[j * w + i], clamp[(j - 1) * w + i] + maxStep);
                for (int j = rows - 2; j >= 0; j--)
                    for (int i = 0; i < w; i++) clamp[j * w + i] = Math.Min(clamp[j * w + i], clamp[(j + 1) * w + i] + maxStep);
                var storey = new int[w * rows];
                Array.Fill(storey, int.MinValue);   // int.MinValue: not in s
                for (int k = 0; k < s.Length / 2; k++)
                {
                    int a = Index(s[2 * k], s[2 * k + 1]);
                    storey[a] = clamp[a];
                }
                int StoreyAt(int i, int j)
                {
                    int v = storey[Index(i, j)];
                    if (v == int.MinValue) throw new InvalidOperationException($"corridor storey ({i}, {j}) missing");
                    return v;
                }
                int[] dI = { 1, -1, 0, 0 }, dJ = { 0, 0, 1, -1 };
                bool Boundary(int i, int j)
                {
                    int here = StoreyAt(i, j);
                    for (int q = 0; q < 4; q++)
                        if (StoreyAt(i + dI[q], j + dJ[q]) != here) return true;
                    return false;
                }
                // Same-storey cardinal breadth-first walk from (i, j) to `depth`;
                // visit(i, j, steps) returns true to stop.
                void Walk(int si, int sj, int depth, Func<int, int, int, bool> visit)
                {
                    int here = StoreyAt(si, sj);
                    var seen = new HashSet<long> { LatticeKey(si, sj) };
                    var frontier = new List<(int, int)> { (si, sj) };
                    for (int step = 0; ; step++)
                    {
                        foreach (var (fi, fj) in frontier)
                            if (visit(fi, fj, step)) return;
                        if (step == depth) return;
                        var next = new List<(int, int)>();
                        foreach (var (fi, fj) in frontier)
                            for (int q = 0; q < 4; q++)
                            {
                                int ni = fi + dI[q], nj = fj + dJ[q];
                                if (StoreyAt(ni, nj) != here || !seen.Add(LatticeKey(ni, nj))) continue;
                                next.Add((ni, nj));
                            }
                        if (next.Count == 0) return;
                        frontier = next;
                    }
                }
                var initLevel = new Dictionary<long, int>();
                int Init(int i, int j)
                {
                    long key = LatticeKey(i, j);
                    if (initLevel.TryGetValue(key, out int cached)) return cached;
                    int here = StoreyAt(i, j);
                    double residual = h[Index(i, j)] - (double)here * storeyHeight;
                    int detail = (int)ClampI(RoundWith(residual / levelHeight, aggregation), 0, levels - 1);
                    int distance = noCliff;
                    Walk(i, j, cliffMax - 1, (wi, wj, steps) =>
                    {
                        if (!Boundary(wi, wj)) return false;
                        distance = steps + 1;
                        return true;
                    });
                    int cap = distance - 1;
                    if (StoreyAt(i - 1, j - 1) != here || StoreyAt(i + 1, j - 1) != here
                            || StoreyAt(i - 1, j + 1) != here || StoreyAt(i + 1, j + 1) != here)
                        cap = 0;
                    int level = (int)ClampI(Math.Min(detail, cap), 0, levels - 1);
                    initLevel[key] = level;
                    return level;
                }
                int count = n.Length / 2;
                var heightsOut = new float[count];
                var storeysOut = new int[count];
                for (int k = 0; k < count; k++)
                {
                    int pi = n[2 * k], pj = n[2 * k + 1];
                    int level = int.MaxValue;
                    Walk(pi, pj, levels - 1, (wi, wj, steps) =>
                    {
                        level = Math.Min(level, Init(wi, wj) + steps);
                        return false;
                    });
                    int st = StoreyAt(pi, pj);
                    double surface = (double)st * storeyHeight;
                    if (renderLevels) surface += (double)level * levelHeight;
                    heightsOut[k] = (float)surface;
                    storeysOut[k] = st;
                }
                return new Godot.Collections.Array { heightsOut, storeysOut };
            }
            catch (Exception e) { NativeFault.Record(e); return null!; }
        }
    }
}
