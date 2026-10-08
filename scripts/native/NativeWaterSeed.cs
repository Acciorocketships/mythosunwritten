// C# mirror of WaterField's source seeding: _claim_rivers (with
// _claim_river_segment), _contain_rivers and _seed_ponds, over a complete
// ground lattice. Profiles and bank strengths come precomputed from GDScript
// (NativeWaterFill.gd.seed_sources flattens them per trace). Same double /
// float32 arithmetic in the same order (GdMath.cs), and the offers go through
// the PriorityQueue.gd port in the same order, so the heap handed back is the
// one the GDScript builds. Stateless; NativeWaterFill.gd gates it.
using System;
using System.Diagnostics;
using Godot;
using static Story.Native.GdMath;

namespace Story.Native
{
    public partial class NativeWaterFill
    {
        /// Godot's MAX (maxf): a < b ? b : a.
        static double Maxf(double a, double b) => a < b ? b : a;

        /// consts: FILL_STEP, BANK_FEATHER, PondStamp WOBBLE, STOREY,
        /// SURFACE_DROP. Ponds 0..seedPonds-1 are the context's ponds; later
        /// ones are terminal ponds referenced only by traces. riverLevels is
        /// updated on a copy. Returns [river_levels, margins, heap index,
        /// heap level, heap priority, claim usec, containment usec].
        public Godot.Collections.Array SeedSources(Godot.Collections.Dictionary flat, double[] consts,
            double baseX, double baseY, int m1, float[] levels, float[] gnd, float[] riverLevels)
        {
            try
            {
                NativeFault.Check("NativeWaterFill");
                double fillStep = consts[0], bankFeather = consts[1], wobble = consts[2],
                    storey = consts[3], surfaceDrop = consts[4];
                GdPond[] ponds = GdPond.ReadAll(flat["pond_vec"].AsVector2Array(),
                    flat["pond_num"].AsFloat64Array(), flat["pond_int"].AsInt64Array(), wobble);
                int seedPonds = flat["seed_ponds"].AsInt32();
                var points = flat["t_points"].AsGodotArray();
                var widths = flat["t_widths"].AsGodotArray();
                var profLevels = flat["t_levels"].AsGodotArray();
                var bank = flat["t_bank"].AsGodotArray();
                int[] terminal = flat["t_terminal"].AsInt32Array();
                int[] dStart = flat["d_start"].AsInt32Array();
                int[] dLo = flat["d_lo"].AsInt32Array();
                int[] dHi = flat["d_hi"].AsInt32Array();
                var dPos = flat["d_pos"].AsGodotArray();
                var dW = flat["d_w"].AsGodotArray();
                var dLvl = flat["d_lvl"].AsGodotArray();
                if (levels.Length != gnd.Length || levels.Length != riverLevels.Length || m1 <= 0)
                    throw new ArgumentException("lattice arrays differ in length");
                V2 bas = V2.D(baseX, baseY);
                var river = (float[])riverLevels.Clone();
                var margins = new float[river.Length];
                Array.Fill(margins, float.PositiveInfinity);
                var clock = Stopwatch.StartNew();

                // _claim_rivers
                for (int t = 0; t < terminal.Length; t++)
                {
                    Vector2[] pts = points[t].AsVector2Array();
                    float[] w = widths[t].AsFloat32Array();
                    float[] lv = profLevels[t].AsFloat32Array();
                    double[] bw = bank[t].AsFloat64Array();
                    var inSpan = new bool[Math.Max(0, pts.Length - 1)];
                    for (int d = dStart[t]; d < dStart[t + 1]; d++)
                    {
                        for (int si = dLo[d]; si < dHi[d]; si++) inSpan[si] = true;
                        Vector2[] dpos = dPos[d].AsVector2Array();
                        float[] dw = dW[d].AsFloat32Array();
                        float[] dl = dLvl[d].AsFloat32Array();
                        for (int k = 0; k < dpos.Length - 1; k++)
                            Claim(bas, m1, fillStep, bankFeather, wobble, storey, surfaceDrop, margins, river,
                                new V2(dpos[k].X, dpos[k].Y), new V2(dpos[k + 1].X, dpos[k + 1].Y),
                                dw[k], dw[k + 1], dl[k], dl[k + 1], 0.0, null);
                    }
                    GdPond? pond = terminal[t] >= 0 ? ponds[terminal[t]] : null;
                    for (int si = 0; si < pts.Length - 1; si++)
                    {
                        if (inSpan[si]) continue;
                        Claim(bas, m1, fillStep, bankFeather, wobble, storey, surfaceDrop, margins, river,
                            new V2(pts[si].X, pts[si].Y), new V2(pts[si + 1].X, pts[si + 1].Y),
                            w[si], w[si + 1], lv[si], lv[si + 1], bankFeather * Min(bw[si], bw[si + 1]), pond);
                    }
                    if (pts.Length == 1)
                    {
                        var p0 = new V2(pts[0].X, pts[0].Y);
                        Claim(bas, m1, fillStep, bankFeather, wobble, storey, surfaceDrop, margins, river,
                            p0, p0, w[0], w[0], lv[0], lv[0], bankFeather * bw[0], null);
                    }
                }
                long claimUsec = clock.ElapsedTicks * 1000000L / Stopwatch.Frequency;
                clock.Restart();

                // _contain_rivers
                var queue = new GdPriorityQueue<Offer>();
                int rows = levels.Length / m1;
                var boundsSquared = new double[seedPonds];
                for (int k = 0; k < seedPonds; k++) boundsSquared[k] = ponds[k].Bound * ponds[k].Bound;
                for (int j = 0; j < rows; j++)
                {
                    for (int i = 0; i < m1; i++)
                    {
                        int idx = j * m1 + i;
                        double lvl = river[idx];
                        if (lvl == double.NegativeInfinity) continue;
                        if ((double)margins[idx] > 0.0)
                        {
                            V2 point = bas + new V2(i, j) * fillStep;
                            for (int k = 0; k < seedPonds; k++)
                            {
                                GdPond pond = ponds[k];
                                if ((double)(point - pond.Center).LengthSquared() > boundsSquared[k]) continue;
                                if (pond.FootprintT(point, wobble) < 1.0)
                                {
                                    river[idx] = float.NegativeInfinity;
                                    break;
                                }
                            }
                            continue;
                        }
                        if ((double)gnd[idx] >= lvl - EPS)
                        {
                            river[idx] = float.NegativeInfinity;
                            continue;
                        }
                        if (levels[idx] == float.NegativeInfinity) queue.Push(new Offer(idx, lvl), lvl);
                    }
                }

                // _seed_ponds
                for (int k = 0; k < seedPonds; k++)
                {
                    GdPond pond = ponds[k];
                    double lvl = pond.SurfaceY(storey, surfaceDrop);
                    int loI = (int)Math.Max(0L, (long)Math.Floor(((double)pond.Center.X - pond.Bound - (double)bas.X) / fillStep));
                    int hiI = (int)Math.Min((long)(m1 - 1), (long)Math.Ceiling(((double)pond.Center.X + pond.Bound - (double)bas.X) / fillStep));
                    int loJ = (int)Math.Max(0L, (long)Math.Floor(((double)pond.Center.Y - pond.Bound - (double)bas.Y) / fillStep));
                    int hiJ = (int)Math.Min((long)(rows - 1), (long)Math.Ceiling(((double)pond.Center.Y + pond.Bound - (double)bas.Y) / fillStep));
                    for (int j = loJ; j <= hiJ; j++)
                    {
                        for (int i = loI; i <= hiI; i++)
                        {
                            V2 p = bas + new V2(i, j) * fillStep;
                            if (pond.FootprintT(p, wobble) >= 1.0) continue;
                            int idx = j * m1 + i;
                            if ((double)gnd[idx] >= lvl - EPS) continue;
                            if (levels[idx] == float.NegativeInfinity) queue.Push(new Offer(idx, lvl), lvl);
                        }
                    }
                }
                long containUsec = clock.ElapsedTicks * 1000000L / Stopwatch.Frequency;

                queue.ExportHeap(out Offer[] items, out double[] priorities);
                var heapIndex = new int[items.Length];
                var heapLevel = new double[items.Length];
                for (int k = 0; k < items.Length; k++)
                {
                    heapIndex[k] = items[k].Index;
                    heapLevel[k] = items[k].Level;
                }
                return new Godot.Collections.Array
                {
                    river, margins, heapIndex, heapLevel, priorities, claimUsec, containUsec,
                };
            }
            catch (Exception e) { NativeFault.Record(e); return null!; }
        }

        /// _claim_river_segment (no `eligible` mask).
        static void Claim(V2 bas, int m1, double fillStep, double bankFeather, double wobble, double storey,
            double surfaceDrop, float[] margins, float[] river, V2 a, V2 b, double wa, double wb,
            double la, double lb, double bankWidth, GdPond? terminal)
        {
            double reach = Maxf(wa, wb) + bankWidth;
            long loI = Math.Max(0L, (long)Math.Floor((Min(a.X, b.X) - reach - (double)bas.X) / fillStep));
            long hiI = Math.Min((long)(m1 - 1), (long)Math.Ceiling((Maxf(a.X, b.X) + reach - (double)bas.X) / fillStep));
            long loJ = Math.Max(0L, (long)Math.Floor((Min(a.Y, b.Y) - reach - (double)bas.Y) / fillStep));
            long hiJ = Math.Min((long)(river.Length / m1 - 1), (long)Math.Ceiling((Maxf(a.Y, b.Y) + reach - (double)bas.Y) / fillStep));
            V2 ab = b - a;
            double len2 = ab.LengthSquared();
            double terminalLevel = terminal != null ? terminal.SurfaceY(storey, surfaceDrop) : 0.0;
            for (long j = loJ; j <= hiJ; j++)
            {
                for (long i = loI; i <= hiI; i++)
                {
                    int idx = (int)(j * m1 + i);
                    V2 q = bas + new V2(i, j) * fillStep;
                    double t = len2 > 0.000001 ? Clamp((double)(q - a).Dot(ab) / len2, 0.0, 1.0) : 0.0;
                    V2 nearest = a + ab * t;
                    double width = Lerp(wa, wb, t);
                    double margin = (double)q.DistanceTo(nearest) - width;
                    if (margin > bankWidth) continue;
                    double lvl = Lerp(la, lb, t);
                    // A terminal lake owns its approach when its level reaches this
                    // river datum. Its finite bank collar must remain flood-connected.
                    if (margin > 0.0 && terminal != null && terminalLevel >= lvl - EPS
                        && (double)q.DistanceTo(terminal.Center) <= terminal.Bound + bankFeather)
                        continue;
                    double current = margins[idx];
                    if (margin < current - 0.0001
                        || (Math.Abs(margin - current) <= 0.0001 && lvl < (double)river[idx]))
                    {
                        margins[idx] = (float)margin;
                        river[idx] = (float)lvl;
                    }
                }
            }
        }
    }
}
