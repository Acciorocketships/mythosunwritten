using Godot;
using System;

namespace Story.Native
{
    // Diagnostic only, instantiated by frame_feel_profile. Cumulative counters
    // let the harness correlate a frame with GC without forcing a collection.
    public partial class NativeRuntimeProbe : RefCounted
    {
        public long PauseUsec()
        {
            try { return GC.GetTotalPauseDuration().Ticks / 10; }
            catch (Exception) { return -1; }
        }
        public long HeapBytes()
        {
            try { return GC.GetTotalMemory(false); }
            catch (Exception) { return -1; }
        }
        public long FullCollections()
        {
            try { return GC.CollectionCount(2); }
            catch (Exception) { return -1; }
        }
    }
}
