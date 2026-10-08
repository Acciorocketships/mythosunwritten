// C# mirrors of WaterField's hydraulic fill kernels: _relax_fill,
// _reconcile_connected_surface, _smooth_fill_surface and
// _retain_source_connected_fill. Same arithmetic in the same order as the
// GDScript (GDScript float = double; PackedFloat32Array stores round to
// float32, reproduced with (float) casts at the same points), and the queue is
// an exact port of PriorityQueue.gd, so equal levels settle in the same order.
// NativeWaterFill.gd verifies bit-identity before switching over. Stateless and
// thread-safe (chunk tails run in parallel).
using System;
using Godot;

namespace Story.Native
{
    public partial class NativeWaterFill : RefCounted
    {
        /// NativeFault: arm a one-shot test failure; this thread's last failure.
        public void ArmFault() => NativeFault.Arm("NativeWaterFill");
        public string TakeError() => NativeFault.Take();

        const double EPS = 0.05;

        struct Offer
        {
            public int Index;
            public double Level;
            public Offer(int index, double level) { Index = index; Level = level; }
        }

        static double MaxF(double a, double b) => a > b ? a : b;
        static double MinF(double a, double b) => a < b ? a : b;

        // Test hook: replay pushes (priority >= 0, item = push count) and pops
        // (-1); returns the items the final drain pops, in order.
        public long[] QueueReplay(double[] pushes)
        {
            try
            {
                NativeFault.Check("NativeWaterFill");
                var queue = new GdPriorityQueue<long>();
                long item = 0;
                foreach (double p in pushes)
                {
                    if (p == -1.0) { if (!queue.IsEmpty) queue.Pop(); }
                    else queue.Push(item++, p);
                }
                var order = new long[queue.Count];
                int n = 0;
                while (!queue.IsEmpty) order[n++] = queue.Pop();
                return order;
            }
            catch (Exception e) { NativeFault.Record(e); return null!; }
        }

        // _relax_fill: `gnd` must be complete (no INF). The queue arrives as the
        // GDScript heap's entries in heap order.
        public float[] Relax(int m1, float[] levels, float[] gnd, float[] riverLevels,
            int[] heapIndex, double[] heapLevel, double[] heapPriority)
        {
            try
            {
                NativeFault.Check("NativeWaterFill");
                var output = (float[])levels.Clone();
                int rows = output.Length / m1;
                var items = new Offer[heapIndex.Length];
                for (int k = 0; k < items.Length; k++) items[k] = new Offer(heapIndex[k], heapLevel[k]);
                var pq = new GdPriorityQueue<Offer>();
                pq.LoadHeap(items, heapPriority);
                while (!pq.IsEmpty)
                {
                    Offer entry = pq.Pop();
                    int idx = entry.Index;
                    double lvl = entry.Level;
                    if (output[idx] != float.NegativeInfinity) continue;
                    if (riverLevels[idx] != float.NegativeInfinity)
                    {
                        lvl = riverLevels[idx];
                        if ((double)gnd[idx] >= lvl - EPS) continue;
                    }
                    output[idx] = (float)lvl;
                    int i = idx % m1;
                    int j = idx / m1;
                    for (int d = 0; d < 4; d++)
                    {
                        int ni = i, nj = j;
                        switch (d)
                        {
                            case 0: ni = i + 1; break;
                            case 1: ni = i - 1; break;
                            case 2: nj = j + 1; break;
                            default: nj = j - 1; break;
                        }
                        if (ni < 0 || ni >= m1 || nj < 0 || nj >= rows) continue;
                        int nidx = nj * m1 + ni;
                        if (output[nidx] != float.NegativeInfinity) continue;
                        if (riverLevels[nidx] != float.NegativeInfinity) continue;
                        if ((double)gnd[nidx] < lvl - EPS) pq.Push(new Offer(nidx, lvl), lvl);
                    }
                }
                return output;
            }
            catch (Exception e) { NativeFault.Record(e); return null!; }
        }

        // _reconcile_connected_surface: returns [levels, initial_offers].
        public Godot.Collections.Array Reconcile(float[] levels, float[] ground, int columns, double step)
        {
            try
            {
                NativeFault.Check("NativeWaterFill");
                const double MAX_GRADE = 0.30;
                const double MIN_DEPTH = 0.10;
                var output = (float[])levels.Clone();
                int rows = output.Length / columns;
                var queue = new GdPriorityQueue<Offer>();
                float stored;
                for (int index = 0; index < output.Length; index++)
                {
                    if (!double.IsFinite(output[index]) || (double)output[index] <= ground[index] + EPS) continue;
                    int x = index % columns;
                    int z = index / columns;
                    for (int d = 0; d < 4; d++)
                    {
                        Step(d, x, z, out int nx, out int nz);
                        if (nx < 0 || nz < 0 || nx >= columns || nz >= rows) continue;
                        int next = nz * columns + nx;
                        if (!double.IsFinite(output[next]) || (double)output[next] <= ground[next] + EPS) continue;
                        stored = (float)MaxF(ground[next] + MIN_DEPTH, output[index] + MAX_GRADE * step);
                        if (stored < output[next])
                        {
                            queue.Push(new Offer(index, output[index]), output[index]);
                            break;
                        }
                    }
                }
                int initialOffers = queue.Count;
                while (!queue.IsEmpty)
                {
                    Offer entry = queue.Pop();
                    int index = entry.Index;
                    if (entry.Level != (double)output[index]) continue;
                    int x = index % columns;
                    int z = index / columns;
                    for (int d = 0; d < 4; d++)
                    {
                        Step(d, x, z, out int nx, out int nz);
                        if (nx < 0 || nz < 0 || nx >= columns || nz >= rows) continue;
                        int next = nz * columns + nx;
                        if (!double.IsFinite(output[next]) || (double)output[next] <= ground[next] + EPS) continue;
                        stored = (float)MaxF(ground[next] + MIN_DEPTH, output[index] + MAX_GRADE * step);
                        if (stored >= output[next]) continue;
                        output[next] = stored;
                        queue.Push(new Offer(next, output[next]), output[next]);
                    }
                }
                return new Godot.Collections.Array { output, initialOffers };
            }
            catch (Exception e) { NativeFault.Record(e); return null!; }
        }

        // Vector2i.LEFT, RIGHT, UP, DOWN.
        static void Step(int d, int x, int z, out int nx, out int nz)
        {
            nx = x; nz = z;
            switch (d)
            {
                case 0: nx = x - 1; break;
                case 1: nx = x + 1; break;
                case 2: nz = z - 1; break;
                default: nz = z + 1; break;
            }
        }

        // _smooth_fill_surface: `gnd` must be complete; empty `ceilings` = the
        // incoming levels.
        public float[] Smooth(int m1, float[] levels, float[] gnd, float[] riverLevels,
            float[] physicalCeilings, int passes)
        {
            try
            {
                NativeFault.Check("NativeWaterFill");
                var output = (float[])levels.Clone();
                int rows = output.Length / m1;
                float[] ceilings = physicalCeilings.Length == 0 ? (float[])levels.Clone() : physicalCeilings;
                var previous = new float[output.Length];
                for (int pass = 0; pass < passes; pass++)
                {
                    Array.Copy(output, previous, output.Length);
                    for (int j = 0; j < rows; j++)
                    {
                        for (int i = 0; i < m1; i++)
                        {
                            int idx = j * m1 + i;
                            if (previous[idx] == float.NegativeInfinity || riverLevels[idx] != float.NegativeInfinity)
                                continue;
                            double acc = previous[idx];
                            double weight = 1.0;
                            for (int d = 0; d < 4; d++)
                            {
                                int ni = i, nj = j;
                                switch (d)
                                {
                                    case 0: ni = i + 1; break;
                                    case 1: ni = i - 1; break;
                                    case 2: nj = j + 1; break;
                                    default: nj = j - 1; break;
                                }
                                if (ni < 0 || ni >= m1 || nj < 0 || nj >= rows) continue;
                                double neighbour = previous[nj * m1 + ni];
                                if (neighbour == double.NegativeInfinity) continue;
                                acc += neighbour;
                                weight += 1.0;
                            }
                            double ground = gnd[idx];
                            output[idx] = (float)MinF(ceilings[idx], MaxF(acc / weight, ground + EPS + 0.01));
                        }
                    }
                }
                return output;
            }
            catch (Exception e) { NativeFault.Record(e); return null!; }
        }

        // _retain_source_connected_fill: returns [levels, removed].
        public Godot.Collections.Array Retain(float[] levels, int side, int[] sourceIndices)
        {
            try
            {
                NativeFault.Check("NativeWaterFill");
                var output = (float[])levels.Clone();
                int rows = output.Length / side;
                var retained = new byte[output.Length];
                var queue = new int[output.Length];
                int tail = 0;
                foreach (int index in sourceIndices)
                {
                    if (retained[index] == 0 && double.IsFinite(output[index]))
                    {
                        retained[index] = 1;
                        queue[tail++] = index;
                    }
                }
                int cursor = 0;
                while (cursor < tail)
                {
                    int index = queue[cursor++];
                    int x = index % side;
                    int z = index / side;
                    for (int d = 0; d < 4; d++)
                    {
                        Step(d, x, z, out int nx, out int nz);
                        if (nx < 0 || nz < 0 || nx >= side || nz >= rows) continue;
                        int ni = nz * side + nx;
                        if (retained[ni] == 1 || !double.IsFinite(output[ni])) continue;
                        retained[ni] = 1;
                        queue[tail++] = ni;
                    }
                }
                int removed = 0;
                for (int index = 0; index < output.Length; index++)
                {
                    if (retained[index] == 0 && double.IsFinite(output[index]))
                    {
                        output[index] = float.NegativeInfinity;
                        removed++;
                    }
                }
                return new Godot.Collections.Array { output, removed };
            }
            catch (Exception e) { NativeFault.Record(e); return null!; }
        }

        // _cap_hydrostatic_fill with a dense `ground` (no INF) and, when
        // `hasNatural`, a dense uncarved `naturalGround`. Returns
        // [levels, ceilings] (both float32 lattices, like the GDScript's
        // levels and levels.duplicate()).
        public Godot.Collections.Array CapHydrostatic(int side, float[] levels, float[] ground,
            float[] anchors, bool hasNatural, float[] naturalGround, float[] flowCeilings)
        {
            try
            {
                NativeFault.Check("NativeWaterFill");
                var output = (float[])levels.Clone();
                var ceilings = (float[])levels.Clone();
                var search = new SpillSearch(side, levels, ground, anchors);
                bool useNatural = hasNatural && flowCeilings.Length != 0;
                for (int index = 0; index < output.Length; index++)
                {
                    if (!double.IsFinite(output[index]) || double.IsFinite(anchors[index])) continue;
                    double ceiling = search.HeightAt(index) - EPS;
                    if (useNatural && double.IsFinite(flowCeilings[index]))
                    {
                        double uncarved = naturalGround[index];
                        if (uncarved > ground[index] + EPS)
                            ceiling = MaxF(ceiling, MinF(uncarved - EPS, flowCeilings[index]));
                    }
                    ceilings[index] = (float)ceiling;
                    double level = MinF(output[index], ceiling);
                    output[index] = level > ground[index] + EPS ? (float)level : float.NegativeInfinity;
                }
                return new Godot.Collections.Array { output, ceilings };
            }
            catch (Exception e) { NativeFault.Record(e); return null!; }
        }

        // WaterField.SpillSearch over a dense ground lattice (all anchors
        // scanned, as with anchor_indices == null).
        sealed class SpillSearch
        {
            readonly int _side, _rows;
            readonly float[] _ground;
            readonly double[] _escape, _distance;
            readonly int[] _marks;
            int _generation;
            readonly GdPriorityQueue<int> _queue = new GdPriorityQueue<int>();
            readonly System.Collections.Generic.List<int> _reached = new System.Collections.Generic.List<int>();

            public SpillSearch(int side, float[] levels, float[] ground, float[] anchors)
            {
                _side = side;
                _ground = ground;
                _rows = levels.Length / side;
                _escape = new double[levels.Length];
                Array.Fill(_escape, double.PositiveInfinity);
                _marks = new int[levels.Length];
                _distance = new double[levels.Length];
                for (int index = 0; index < levels.Length; index++)
                    if (double.IsFinite(levels[index]) && double.IsFinite(anchors[index]))
                        _escape[index] = MaxF(anchors[index] + EPS, ground[index]);
                for (int x = 0; x < side; x++)
                {
                    SetBoundary(x);
                    SetBoundary((_rows - 1) * side + x);
                }
                for (int z = 1; z < _rows - 1; z++)
                {
                    SetBoundary(z * side);
                    SetBoundary(z * side + side - 1);
                }
            }

            void SetBoundary(int index)
            {
                if (!double.IsFinite(_escape[index])) _escape[index] = _ground[index];
            }

            public double HeightAt(int target)
            {
                if (!double.IsFinite(_escape[target]))
                {
                    _generation++;
                    _reached.Clear();
                    double start = _ground[target];
                    _marks[target] = _generation;
                    _distance[target] = start;
                    _queue.Push(target, start);
                    double outlet = double.PositiveInfinity;
                    while (!_queue.IsEmpty)
                    {
                        int index = _queue.Pop();
                        double height = _distance[index];
                        if (double.IsFinite(_escape[index]))
                        {
                            outlet = height;
                            break;
                        }
                        _reached.Add(index);
                        int x = index % _side;
                        int z = index / _side;
                        for (int d = 0; d < 4; d++)
                        {
                            Step(d, x, z, out int nx, out int nz);
                            if (nx < 0 || nz < 0 || nx >= _side || nz >= _rows) continue;
                            int next = nz * _side + nx;
                            if (_marks[next] == _generation) continue;
                            double cost = MaxF(height, _ground[next]);
                            if (double.IsFinite(_escape[next])) cost = MaxF(cost, _escape[next]);
                            _marks[next] = _generation;
                            _distance[next] = cost;
                            _queue.Push(next, cost);
                        }
                    }
                    _queue.Clear();
                    _escape[target] = outlet;
                    foreach (int index in _reached)
                        if (_distance[index] < outlet || _ground[index] >= outlet)
                            _escape[index] = outlet;
                }
                return _escape[target];
            }
        }
    }
}
