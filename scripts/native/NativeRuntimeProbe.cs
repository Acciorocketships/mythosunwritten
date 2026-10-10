using Godot;
using System;
using System.Runtime.InteropServices;

namespace Story.Native
{
    // Diagnostic only, instantiated by frame_feel_profile. Cumulative counters
    // let the harness correlate a frame with GC without forcing a collection.
    public partial class NativeRuntimeProbe : RefCounted
    {
        // macOS SDK sys/resource.h rusage_info_v2: all fields after the UUID
        // are uint64_t. proc_pid_rusage samples kernel counters without walking
        // the managed heap or forcing a collection. Other platforms report none.
        [StructLayout(LayoutKind.Sequential)]
        private struct UsageV2
        {
            public ulong Uuid0, Uuid1;
            public ulong UserTime, SystemTime, PackageWakeups, InterruptWakeups;
            public ulong Pageins, Wired, Resident, Footprint, Start, Exit;
            public ulong ChildUser, ChildSystem, ChildPackage, ChildInterrupt;
            public ulong ChildPageins, ChildElapsed, DiskRead, DiskWritten;
        }
        [DllImport("/usr/lib/libproc.dylib", EntryPoint = "proc_pid_rusage")]
        private static extern int ReadUsage(int pid, int flavor, out UsageV2 usage);

        public Godot.Collections.Dictionary OsUsage()
        {
            var result = new Godot.Collections.Dictionary();
            if (!OperatingSystem.IsMacOS()) return result;
            try
            {
                if (ReadUsage(System.Environment.ProcessId, 2, out var usage) != 0)
                    return result;
                result["pageins"] = (long)usage.Pageins;
                result["physical_bytes"] = (long)usage.Footprint;
                result["resident_bytes"] = (long)usage.Resident;
                result["disk_read_bytes"] = (long)usage.DiskRead;
                result["disk_written_bytes"] = (long)usage.DiskWritten;
            }
            catch (Exception) { /* Optional diagnostics must never stop play. */ }
            return result;
        }

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
