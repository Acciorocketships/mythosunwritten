// GDScript-facing bridge of the C# terrain height field. Used only through
// scripts/native/NativeHeightField.gd, which hands over the live tables, checks
// bit-for-bit parity against TerrainField.height_m and falls back to GDScript
// otherwise. Thread-safe: the streamer worker, the grass worker and the main
// thread may all call HeightM concurrently.
using System;
using System.Collections.Concurrent;
using Godot;

namespace Story.Native
{
    public partial class NativeTerrainHeight : RefCounted
    {
        /// NativeFault: arm a one-shot test failure; this thread's last failure.
        public void ArmFault() => NativeFault.Arm("NativeTerrainHeight");
        public string TakeError() => NativeFault.Take();

        static volatile TerrainTables? _tables;
        static readonly ConcurrentDictionary<long, SeedField> _fields = new();

        /// Take the live tables (see NativeHeightField._tables). Returns an
        /// error message, or "" on success. Replacing the tables drops every
        /// per-seed field.
        public string Configure(Godot.Collections.Dictionary tables)
        {
            try
            {
                _tables = TerrainTables.From(tables);
                _fields.Clear();
                return "";
            }
            catch (Exception e)
            {
                _tables = null;
                return e.Message;
            }
        }

        /// The verified field of a seed, shared with the other native ports
        /// (NativeRiverWalk). Built on first use.
        internal static SeedField FieldFor(long seed) => Field(seed);

        static SeedField Field(long seed)
        {
            if (_fields.TryGetValue(seed, out var f)) return f;
            TerrainTables t = _tables ?? throw new InvalidOperationException("NativeTerrainHeight: Configure first");
            return _fields.GetOrAdd(seed, s => new SeedField(s, t));
        }

        /// Build (or keep) the field of a seed. Returns "" or an error message.
        public string Prepare(long seed)
        {
            try
            {
                Field(seed);
                return "";
            }
            catch (Exception e)
            {
                return e.Message;
            }
        }

        public double HeightM(Vector2 p, long seed, bool includeDetail)
        {
            try { NativeFault.Check("NativeTerrainHeight"); return Field(seed).HeightM(new V2(p.X, p.Y), includeDetail); }
            catch (Exception e) { NativeFault.Record(e); return double.NaN; }
        }

        public double[] HeightBatch(Vector2[] points, long seed, bool includeDetail)
        {
            try
            {
                NativeFault.Check("NativeTerrainHeight");
                SeedField f = Field(seed);
                var outH = new double[points.Length];
                for (int i = 0; i < points.Length; i++) outH[i] = f.HeightM(new V2(points[i].X, points[i].Y), includeDetail);
                return outH;
            }
            catch (Exception e) { NativeFault.Record(e); return null!; }
        }
    }
}
