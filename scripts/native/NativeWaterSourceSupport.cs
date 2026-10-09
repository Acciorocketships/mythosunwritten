using System;
using Godot;

namespace Story.Native
{
    public partial class NativeWaterFill
    {
        // WaterSourceSupport.constrain: the highest source-supported head
        // bounded by each offered surface and bed. All propagated heads are
        // existing float32 values; heap tie order cannot change the maximum.
        public Godot.Collections.Array SourceSupport(float[] levels, float[] ground,
            int columns, int[] roots, double epsilon)
        {
            try
            {
                NativeFault.Check("NativeWaterFill");
                if (columns <= 0 || levels.Length != ground.Length || levels.Length % columns != 0)
                    throw new ArgumentException("invalid source-support grid");
                int rows = levels.Length / columns;
                var result = new float[levels.Length];
                Array.Fill(result, float.NegativeInfinity);
                var settled = new bool[levels.Length];
                var queue = new System.Collections.Generic.PriorityQueue<int, float>();
                foreach (int index in roots)
                {
                    if (index < 0 || index >= levels.Length)
                        throw new ArgumentException("source root outside grid");
                    if (float.IsFinite(levels[index]) && levels[index] > ground[index] + epsilon
                        && float.IsNegativeInfinity(result[index]))
                    {
                        result[index] = levels[index];
                        queue.Enqueue(index, -levels[index]);
                    }
                }
                while (queue.Count != 0)
                {
                    int index = queue.Dequeue();
                    if (settled[index]) continue;
                    settled[index] = true;
                    int x = index % columns, z = index / columns;
                    if (x > 0) Offer(index - 1, result[index]);
                    if (x + 1 < columns) Offer(index + 1, result[index]);
                    if (z > 0) Offer(index - columns, result[index]);
                    if (z + 1 < rows) Offer(index + columns, result[index]);
                }
                return new Godot.Collections.Array { result };

                void Offer(int next, float incoming)
                {
                    if (settled[next] || !float.IsFinite(levels[next])) return;
                    float head = Math.Min(incoming, levels[next]);
                    if (head <= ground[next] + epsilon || head <= result[next]) return;
                    result[next] = head;
                    queue.Enqueue(next, -head);
                }
            }
            catch (Exception e) { NativeFault.Record(e); return null!; }
        }
    }
}
