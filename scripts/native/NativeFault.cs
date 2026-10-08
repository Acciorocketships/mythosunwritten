// Exception guard shared by the native ports. Every public entry GDScript
// calls wraps its body in try { NativeFault.Check(); ... } catch (Exception e)
// { NativeFault.Record(e); return <sentinel>; }: an uncaught exception would
// reach GDScript as a null result, the typed assignment would raise a script
// error and abort the caller (a chunk tail stopped before it released its
// slot, and after three of them streaming stopped). The sentinel is null (an
// empty packed array, nil for Array/Dictionary), NaN or long.MinValue; the
// GDScript wrapper reads TakeError() on the same thread, turns its port off
// and runs the GDScript reference for that call (NativeGates.gd faulted()).
using System;

namespace Story.Native
{
    internal static class NativeFault
    {
        [ThreadStatic] static string? _error;
        static volatile string? _armed;

        /// Test hook: the next guarded entry of port `port` (its class name, on
        /// any thread) throws once.
        public static void Arm(string port) => _armed = port;

        public static void Check(string port)
        {
            if (_armed == null || _armed != port) return;
            _armed = null;
            throw new InvalidOperationException("forced test fault (NativeFault.Arm)");
        }

        public static void Record(Exception e) => _error = e.GetType().Name + ": " + e.Message;

        /// The calling thread's last recorded failure ("" when none), cleared.
        public static string Take()
        {
            string e = _error ?? "";
            _error = null;
            return e;
        }
    }
}
