// C# mirror of the seed and anchor stages of WaterField._build_sub_lattice_rescue
// with the coarse-field query they share: _rescue_coarse_level ->
// _fill_bilinear_coarse (_node_ground, _may_straddle_a_cliff, _wall_span,
// _shore_support_level; _fine_edge_support is the identity on the rescue's
// coarse context, which has no sub levels) and _fill_untapered_level.
// Terrain comes from a dense corner window (TerrainTileField.dense_window) and
// NativeTileKernel.Sample, which is TerrainTileField.surface_y / sample_baked on
// an ungraded region. The visited node sets depend on the coarse levels alone,
// so their ground is sampled in one batch before the stage runs (the seed
// stage samples every visited node; the anchor stage only nodes whose coarse
// level is finite, as _ground_at is called there). Same float32 / double
// arithmetic in the same order (GdMath.cs); the seed offers go through the
// PriorityQueue.gd port in the same order. Stateless; NativeWaterFill.gd gates
// it against the GDScript on random lattices with walls.
using System;
using System.Diagnostics;
using static Story.Native.GdMath;

namespace Story.Native
{
    public partial class NativeWaterFill
    {
        const double FILL_STEP = 6.0;          // WaterField.FILL_STEP
        const double FILL_SUB_STEP = 3.0;      // WaterField.FILL_SUB_STEP
        const double SHORE_DRY_DEPTH = 0.50;   // WaterField.SHORE_DRY_DEPTH
        const double FALL_DROP_MIN = 4.0;      // WaterField.FALL_DROP_MIN
        const double DESCENT_CLAMP = 0.10;     // WaterField.DESCENT_CLAMP
        const double WALL_GATE = 1.0;          // WaterField.WALL_GATE
        const float SHORE_EDGE_PROBE = 0.001f; // WaterField.SHORE_EDGE_PROBE (a Vector2 component)

        /// TerrainTileField.surface_y over a dense corner window (ungraded).
        sealed class TileWindow
        {
            readonly float[] _heights;
            readonly int[] _storeys;
            readonly int _w, _h, _i0, _j0, _mode;
            public readonly double Pitch;

            public TileWindow(float[] heights, int[] storeys, int w, int h, int i0, int j0, double pitch, int mode)
            {
                if (heights.Length != w * h || storeys.Length != w * h)
                    throw new ArgumentException("window arrays do not match its size");
                _heights = heights; _storeys = storeys; _w = w; _h = h; _i0 = i0; _j0 = j0;
                Pitch = pitch; _mode = mode;
            }

            /// TerrainTileField.point_of.
            public int PointOf(double v) => (int)Floori(v / Pitch + 0.5);

            public double SurfaceY(double x, double z)
            {
                int oi = PointOf(x), oj = PointOf(z);
                if (oi - 1 < _i0 || oi + 1 >= _i0 + _w || oj - 1 < _j0 || oj + 1 >= _j0 + _h)
                    throw new IndexOutOfRangeException($"surface_y ({x}, {z}) leaves the terrain window");
                return NativeTileKernel.Sample(_heights, _storeys, _w, _i0, _j0, Pitch, x, z, oi, oj, _mode);
            }
        }

        /// The rescue's coarse context: coarse levels, node ground memo and the
        /// 3 m sample memo (_rescue_coarse_level's surface_samples).
        sealed class CoarseQuery
        {
            readonly TileWindow _t;
            readonly float[] _levels;
            readonly int _m1, _rows, _subN;
            readonly V2 _base;
            public readonly double[] NodeGround;
            public readonly double[] Samples;

            public CoarseQuery(TileWindow t, float[] levels, int m1, V2 bas, int subLength)
            {
                _t = t; _levels = levels; _m1 = m1; _rows = levels.Length / m1; _base = bas;
                _subN = (m1 - 1) * 2 + 1;
                NodeGround = new double[levels.Length];
                Array.Fill(NodeGround, double.PositiveInfinity);
                Samples = new double[subLength];
                Array.Fill(Samples, double.PositiveInfinity);
            }

            /// _rescue_coarse_level.
            public double Rescue(V2 p)
            {
                V2 d = (p - _base) / FILL_SUB_STEP;
                int lx = (int)MathF.Round(d.X, MidpointRounding.AwayFromZero);
                int ly = (int)MathF.Round(d.Y, MidpointRounding.AwayFromZero);
                int index = ly * _subN + lx;
                if (Samples[index] == double.PositiveInfinity)
                    Samples[index] = Bilinear(p);
                return Samples[index];
            }

            /// _node_ground.
            double Node(int i, int j)
            {
                int index = j * _m1 + i;
                if (NodeGround[index] == double.PositiveInfinity)
                {
                    V2 q = _base + new V2(i, j) * FILL_STEP;
                    NodeGround[index] = _t.SurfaceY(q.X, q.Y);
                }
                return NodeGround[index];
            }

            /// _fill_bilinear_coarse(c, p) with apply_shore_bound.
            double Bilinear(V2 p)
            {
                double lf = ((double)p.X - (double)_base.X) / FILL_STEP;
                double jf = ((double)p.Y - (double)_base.Y) / FILL_STEP;
                int i0 = (int)ClampI((long)Math.Floor(lf), 0, _m1 - 2);
                int j0 = (int)ClampI((long)Math.Floor(jf), 0, _rows - 2);
                double tx = Clamp(lf - i0, 0.0, 1.0);
                double tz = Clamp(jf - j0, 0.0, 1.0);
                Span<int> ci = stackalloc int[4] { i0, i0 + 1, i0, i0 + 1 };
                Span<int> cj = stackalloc int[4] { j0, j0, j0 + 1, j0 + 1 };
                Span<double> cw = stackalloc double[4]
                {
                    (1.0 - tx) * (1.0 - tz), tx * (1.0 - tz), (1.0 - tx) * tz, tx * tz,
                };
                double wetWeight = 0.0, wetAcc = 0.0;
                for (int k = 0; k < 4; k++)
                {
                    double lvl = _levels[cj[k] * _m1 + ci[k]];
                    if (lvl == double.NegativeInfinity) continue;
                    wetAcc += lvl * cw[k];
                    wetWeight += cw[k];
                }
                if (wetWeight <= 0.0) return double.NegativeInfinity;
                double wetRef = wetAcc / wetWeight;
                Span<float> values = stackalloc float[4];
                Span<bool> wet = stackalloc bool[4] { true, true, true, true };
                Span<float> dry = stackalloc float[4] { float.PositiveInfinity, float.PositiveInfinity, float.PositiveInfinity, float.PositiveInfinity };
                for (int k = 0; k < 4; k++)
                {
                    double lvl = _levels[cj[k] * _m1 + ci[k]];
                    if (lvl == double.NegativeInfinity)
                    {
                        double ground = Node(ci[k], cj[k]);
                        dry[k] = (float)ground;
                        wet[k] = false;
                        lvl = Min(wetRef, ground + EPS - SHORE_DRY_DEPTH);
                    }
                    values[k] = (float)lvl;
                }
                double x0 = (double)_base.X + (double)i0 * FILL_STEP;
                double z0 = (double)_base.Y + (double)j0 * FILL_STEP;
                double px = Clamp(p.X, x0, x0 + FILL_STEP);
                double pz = Clamp(p.Y, z0, z0 + FILL_STEP);
                double acc;
                if (Straddles(i0, j0))
                {
                    double row0 = WallSpan(values[0], values[1], wet[0], wet[1], x0, px, pz, 0);
                    double row1 = WallSpan(values[2], values[3], wet[2], wet[3], x0, px, pz, 0);
                    acc = WallSpan(row0, row1, wet[0] || wet[1], wet[2] || wet[3], z0, pz, px, 1);
                }
                else
                {
                    acc = Lerp(Lerp(values[0], values[1], tx), Lerp(values[2], values[3], tx), tz);
                }
                if (wetWeight >= 1.0 - 0.000001) return acc;
                return ShoreSupport(p, acc, wetRef, _base + new V2(i0, j0) * FILL_STEP, FILL_STEP, dry);
            }

            /// _may_straddle_a_cliff.
            bool Straddles(int i0, int j0)
            {
                double lo = double.PositiveInfinity, hi = double.NegativeInfinity;
                for (int k = 0; k < 4; k++)
                {
                    double g = Node(i0 + (k & 1), j0 + (k >> 1));
                    lo = Min(lo, g);
                    hi = Max(hi, g);
                }
                return hi - lo >= WALL_GATE;
            }

            /// _wall_span(region, pitch, a, b, wet_a, wet_b, s0, s, across, axis).
            double WallSpan(double a, double b, bool wetA, bool wetB, double s0, double s, double across, int axis)
            {
                double linear = Lerp(a, b, (s - s0) / FILL_STEP);
                if (Math.Abs(a - b) <= EPS) return linear;
                double pitch = _t.Pitch;
                double wall = s0 + FILL_STEP * 0.5;
                double phase = Fposmod(wall - pitch * 0.5, pitch);
                if (Min(phase, pitch - phase) > 0.001) return linear;
                V2 qa = axis == 0 ? V2.D(wall - 0.001, across) : V2.D(across, wall - 0.001);
                V2 qb = axis == 0 ? V2.D(wall + 0.001, across) : V2.D(across, wall + 0.001);
                double ga = _t.SurfaceY(qa.X, qa.Y);
                double gb = _t.SurfaceY(qb.X, qb.Y);
                double cliff = Smoothstep(FALL_DROP_MIN * 0.5, FALL_DROP_MIN, Math.Abs(ga - gb));
                if (cliff <= 0.0) return linear;
                if (!(wetA && wetB)) return Lerp(linear, s < wall ? a : b, cliff);
                double crown = Max(ga, gb);
                double upper = ga > gb ? a : b;
                double lower = ga > gb ? b : a;
                double weight = cliff * Smoothstep(crown, crown + DESCENT_CLAMP, upper)
                    * (1.0 - Smoothstep(crown - DESCENT_CLAMP, crown, lower));
                if (weight <= 0.0) return linear;
                double crest = Min(upper, crown + DESCENT_CLAMP);
                double spill = s < wall ? Lerp(a, crest, (s - s0) / (wall - s0))
                    : Lerp(crest, b, (s - wall) / (s0 + FILL_STEP - wall));
                return Lerp(linear, spill, weight);
            }

            /// _shore_support_level (with _fine_edge_support = dry_height: the
            /// rescue's coarse context has no sub levels).
            double ShoreSupport(V2 p, double interpolated, double head, V2 origin, double step, Span<float> dry)
            {
                float fs = (float)step;
                Span<V2> corners = stackalloc V2[4]
                {
                    origin, origin + new V2(fs, 0f), origin + new V2(0f, fs), origin + new V2(fs, fs),
                };
                double correction = 0.0;
                for (int e = 0; e < 4; e++)
                {
                    int ex = e == 0 ? 0 : e == 1 ? 1 : e == 2 ? 0 : 2;
                    int ey = e == 0 ? 2 : e == 1 ? 3 : e == 2 ? 1 : 3;
                    if (dry[ex] == float.PositiveInfinity || dry[ey] == float.PositiveInfinity) continue;
                    V2 a = corners[ex], b = corners[ey];
                    double t = Clamp((double)(p - a).Dot(b - a) / (step * step), 0.0, 1.0);
                    float tf = (float)t;
                    V2 q = new V2(a.X + (b.X - a.X) * tf, a.Y + (b.Y - a.Y) * tf);
                    double limitingHead = Lerp(Min(head, (double)dry[ex] + EPS - SHORE_DRY_DEPTH),
                        Min(head, (double)dry[ey] + EPS - SHORE_DRY_DEPTH), t);
                    double offX = ey - ex == 2 ? SHORE_EDGE_PROBE : 0f;
                    double offZ = ey - ex == 2 ? 0f : SHORE_EDGE_PROBE;
                    double edgeGround = _t.SurfaceY((double)q.X + offX, (double)q.Y + offZ);
                    double edgeSupport = edgeGround + EPS - SHORE_DRY_DEPTH;
                    double excess = Max(limitingHead - edgeSupport, 0.0);
                    double support = Clamp((double)p.DistanceTo(q) / step, 0.0, 1.0);
                    correction = Max(correction, excess * (1.0 - support));
                }
                return interpolated - correction;
            }

            /// _fill_untapered_level.
            public double Untapered(V2 p)
            {
                V2 local = (p - _base) / FILL_STEP;
                int i = (int)ClampI(Floori(local.X), 0, _m1 - 2);
                int j = (int)ClampI(Floori(local.Y), 0, _rows - 2);
                V2 r = local - new V2(i, j);
                float tx = r.X < 0f ? 0f : (r.X > 1f ? 1f : r.X);
                float ty = r.Y < 0f ? 0f : (r.Y > 1f ? 1f : r.Y);
                double total = 0.0, value = 0.0;
                for (int dz = 0; dz < 2; dz++)
                {
                    for (int dx = 0; dx < 2; dx++)
                    {
                        double level = _levels[(j + dz) * _m1 + i + dx];
                        if (level == double.NegativeInfinity) continue;
                        double weight = (dx != 0 ? (double)tx : 1.0 - tx) * (dz != 0 ? (double)ty : 1.0 - ty);
                        value += level * weight;
                        total += weight;
                    }
                }
                return total > 0.0 ? value / total : double.NegativeInfinity;
            }
        }

        /// The seed and anchor stages of _build_sub_lattice_rescue. `subGround`
        /// is the rescue's ground (INF = unsampled; prefilled entries are kept).
        /// Returns [sub_ground, surface_samples, node_ground, queued, heap index,
        /// heap level, heap priority, fine_anchors, anchor indices,
        /// [seed usec, anchor usec, ground usec, seed visits, anchor visits]];
        /// the anchor arrays are empty when nothing was seeded (the GDScript
        /// returns before the anchor stage).
        public Godot.Collections.Array RescueSeedAnchors(float[] heights, int[] storeys, int w, int h,
            int i0, int j0, double pitch, int cliffEnd, double baseX, double baseY,
            float[] coarseLevels, int coarseN, float[] subGround)
        {
            try
            {
                NativeFault.Check("NativeWaterFill");
                var clock = Stopwatch.StartNew();
                var window = new TileWindow(heights, storeys, w, h, i0, j0, pitch, cliffEnd);
                int coarseRows = coarseLevels.Length / coarseN;
                int subRows = (coarseRows - 1) * 2 + 1;
                int subN = (coarseN - 1) * 2 + 1;
                if (coarseN < 2 || coarseRows < 2 || subGround.Length != subN * subRows)
                    throw new ArgumentException("rescue lattice sizes disagree");
                V2 bas = V2.D(baseX, baseY);
                var ground = (float[])subGround.Clone();
                var coarse = new CoarseQuery(window, coarseLevels, coarseN, bas, ground.Length);
                var queued = new byte[ground.Length];
                long groundTicks = 0;

                // Seed: every 3 m point of a mixed coarse cell is visited (its
                // first visit always is: `queued` marks pushed points only), and
                // _ground_at samples each visited point.
                var visit = new byte[ground.Length];
                var seedVisits = new int[64];
                int seedCount = 0;
                for (int cj = 0; cj < coarseRows - 1; cj++)
                {
                    for (int ci = 0; ci < coarseN - 1; ci++)
                    {
                        if (!MixedCell(coarseLevels, coarseN, ci, cj)) continue;
                        for (int sj = cj * 2; sj < cj * 2 + 3; sj++)
                            for (int si = ci * 2; si < ci * 2 + 3; si++)
                            {
                                int sidx = sj * subN + si;
                                if (visit[sidx] == 1) continue;
                                visit[sidx] = 1;
                                if (seedCount == seedVisits.Length) Array.Resize(ref seedVisits, seedCount * 2);
                                seedVisits[seedCount++] = sidx;
                            }
                    }
                }
                long t0 = clock.ElapsedTicks;
                SampleGround(window, bas, subN, ground, seedVisits, seedCount);
                groundTicks += clock.ElapsedTicks - t0;
                var pq = new GdPriorityQueue<Offer>();
                for (int cj = 0; cj < coarseRows - 1; cj++)
                {
                    for (int ci = 0; ci < coarseN - 1; ci++)
                    {
                        if (!MixedCell(coarseLevels, coarseN, ci, cj)) continue;
                        for (int sj = cj * 2; sj < cj * 2 + 3; sj++)
                            for (int si = ci * 2; si < ci * 2 + 3; si++)
                            {
                                int sidx = sj * subN + si;
                                if (queued[sidx] == 1) continue;
                                V2 p = bas + new V2(si, sj) * FILL_SUB_STEP;
                                double lvl = coarse.Rescue(p);
                                double g = ground[sidx];
                                if (lvl == double.NegativeInfinity || lvl <= g + EPS) continue;
                                double head = coarse.Untapered(p);
                                queued[sidx] = 1;
                                pq.Push(new Offer(sidx, head), head);
                            }
                    }
                }
                long seedTicks = clock.ElapsedTicks;
                pq.ExportHeap(out Offer[] heap, out double[] priorities);
                var heapIndex = new int[heap.Length];
                var heapLevel = new double[heap.Length];
                for (int k = 0; k < heap.Length; k++) { heapIndex[k] = heap[k].Index; heapLevel[k] = heap[k].Level; }

                var anchors = Array.Empty<float>();
                var anchorIndices = Array.Empty<int>();
                int anchorVisits = 0;
                if (heap.Length > 0)
                {
                    // Anchors: the 3 m ring round each wet coarse node, in the
                    // GDScript's visit order; ground only where the level is finite.
                    var seen = new byte[ground.Length];
                    var found = new int[64];
                    var foundLevel = new double[64];
                    int foundCount = 0;
                    for (int coarseIndex = 0; coarseIndex < coarseLevels.Length; coarseIndex++)
                    {
                        if (!float.IsFinite(coarseLevels[coarseIndex])) continue;
                        int cx = coarseIndex % coarseN;
                        int cz = coarseIndex / coarseN;
                        int sjEnd = Math.Min(subRows, cz * 2 + 2), siEnd = Math.Min(subN, cx * 2 + 2);
                        for (int sj = Math.Max(0, cz * 2 - 1); sj < sjEnd; sj++)
                            for (int si = Math.Max(0, cx * 2 - 1); si < siEnd; si++)
                            {
                                int idx = sj * subN + si;
                                if (seen[idx] == 1) continue;
                                seen[idx] = 1;
                                anchorVisits++;
                                V2 p = bas + new V2(si, sj) * FILL_SUB_STEP;
                                double level = coarse.Rescue(p);
                                if (!double.IsFinite(level)) continue;
                                if (foundCount == found.Length)
                                {
                                    Array.Resize(ref found, foundCount * 2);
                                    Array.Resize(ref foundLevel, foundCount * 2);
                                }
                                found[foundCount] = idx;
                                foundLevel[foundCount++] = level;
                            }
                    }
                    t0 = clock.ElapsedTicks;
                    SampleGround(window, bas, subN, ground, found, foundCount);
                    groundTicks += clock.ElapsedTicks - t0;
                    anchors = new float[ground.Length];
                    Array.Fill(anchors, float.NegativeInfinity);
                    var indices = new int[foundCount];
                    int n = 0;
                    for (int k = 0; k < foundCount; k++)
                    {
                        int idx = found[k];
                        if (foundLevel[k] <= (double)ground[idx] + EPS) continue;
                        V2 p = bas + new V2(idx % subN, idx / subN) * FILL_SUB_STEP;
                        anchors[idx] = (float)coarse.Untapered(p);
                        indices[n++] = idx;
                    }
                    anchorIndices = indices.AsSpan(0, n).ToArray();
                }
                long endTicks = clock.ElapsedTicks;
                double usec = 1e6 / Stopwatch.Frequency;
                var stats = new long[]
                {
                    (long)(seedTicks * usec), (long)((endTicks - seedTicks) * usec), (long)(groundTicks * usec),
                    seedCount, anchorVisits,
                };
                return new Godot.Collections.Array
                {
                    ground, coarse.Samples, coarse.NodeGround, queued, heapIndex, heapLevel, priorities,
                    anchors, anchorIndices, stats,
                };
            }
            catch (Exception e) { NativeFault.Record(e); return null!; }
        }

        static bool MixedCell(float[] levels, int n, int ci, int cj)
        {
            int corner = cj * n + ci;
            bool nw = levels[corner] != float.NegativeInfinity;
            bool ne = levels[corner + 1] != float.NegativeInfinity;
            bool sw = levels[corner + n] != float.NegativeInfinity;
            bool se = levels[corner + n + 1] != float.NegativeInfinity;
            return !((!nw && !ne && !sw && !se) || (nw && ne && sw && se));
        }

        /// _ground_at for each listed 3 m point still unsampled (INF): the
        /// point_of-owned surface at base + (i, j) * FILL_SUB_STEP, stored float32.
        static void SampleGround(TileWindow window, V2 bas, int subN, float[] ground, int[] list, int count)
        {
            for (int k = 0; k < count; k++)
            {
                int idx = list[k];
                if (ground[idx] != float.PositiveInfinity) continue;
                V2 p = bas + new V2(idx % subN, idx / subN) * FILL_SUB_STEP;
                ground[idx] = (float)window.SurfaceY(p.X, p.Y);
            }
        }
    }
}
