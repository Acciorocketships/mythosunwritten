// Exact port of scripts/core/PriorityQueue.gd: a binary min-heap of
// (item, double priority) with hole sifts and the same comparisons, so equal
// priorities pop in the identical order (the water fill's ties depend on it).
// Not System.Collections.Generic.PriorityQueue, whose tie order differs.
using System;

namespace Story.Native
{
    public sealed class GdPriorityQueue<T>
    {
        T[] _items = new T[64];
        double[] _priorities = new double[64];
        int _count;

        public int Count => _count;
        public bool IsEmpty => _count == 0;

        // Rebuild a GDScript heap verbatim (entries in its heap order).
        public void LoadHeap(T[] items, double[] priorities)
        {
            Grow(items.Length);
            Array.Copy(items, _items, items.Length);
            Array.Copy(priorities, _priorities, priorities.Length);
            _count = items.Length;
        }

        public void Push(T item, double priority)
        {
            Grow(_count + 1);
            _items[_count] = item;
            _priorities[_count] = priority;
            _count++;
            BubbleUp(_count - 1);
        }

        // Caller checks IsEmpty first (the GDScript returns null when empty).
        public T Pop()
        {
            T root = _items[0];
            _count--;
            T lastItem = _items[_count];
            double lastPriority = _priorities[_count];
            _items[_count] = default!;
            if (_count > 0)
            {
                _items[0] = lastItem;
                _priorities[0] = lastPriority;
                BubbleDown(0);
            }
            return root;
        }

        void Grow(int need)
        {
            if (need <= _items.Length) return;
            int size = Math.Max(need, _items.Length * 2);
            Array.Resize(ref _items, size);
            Array.Resize(ref _priorities, size);
        }

        void BubbleUp(int i)
        {
            T item = _items[i];
            double priority = _priorities[i];
            while (i > 0)
            {
                int p = (i - 1) / 2;
                if (priority >= _priorities[p]) break;
                _items[i] = _items[p];
                _priorities[i] = _priorities[p];
                i = p;
            }
            _items[i] = item;
            _priorities[i] = priority;
        }

        void BubbleDown(int i)
        {
            int n = _count;
            T item = _items[i];
            double priority = _priorities[i];
            while (true)
            {
                int l = i * 2 + 1;
                if (l >= n) break;
                int smallest = i;
                double smallestPriority = priority;
                double leftPriority = _priorities[l];
                if (leftPriority < smallestPriority)
                {
                    smallest = l;
                    smallestPriority = leftPriority;
                }
                int r = l + 1;
                if (r < n)
                {
                    double rightPriority = _priorities[r];
                    if (rightPriority < smallestPriority) smallest = r;
                }
                if (smallest == i) break;
                _items[i] = _items[smallest];
                _priorities[i] = _priorities[smallest];
                i = smallest;
            }
            _items[i] = item;
            _priorities[i] = priority;
        }
    }
}
