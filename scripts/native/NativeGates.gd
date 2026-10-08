extends RefCounted

## Shared plumbing of the native ports (scripts/native/*.gd). No class_name:
## preload it.
##
## DEFERRED PARITY GATES. Each port proves itself bit-identical to its
## GDScript reference before it serves anything. Tests and harnesses gate
## synchronously in setup(). The game must not: those gates (the height
## field's ~2.2 s, the river walk's ~1.8 s, the tile kernel's 60 cases) ran on
## the main thread inside FieldTerrainStreamer._ready and froze the loading
## screen. FieldTerrainStreamer._ready sets `deferred` before it builds any
## plan; from then on setup() only loads C# and registers the seed, and the
## gate runs on the first call from a non-main thread (a worker or chunk
## tail) that wins the port's try_lock. Every other thread, the main thread
## always, keeps the GDScript reference meanwhile: the results are identical,
## only slower.
##
## FAULTS. Every C# entry catches its own exceptions (NativeFault.cs) and
## returns a sentinel; faulted() reads the calling thread's error. A port
## whose C# threw turns itself off (push_warning names the error) and its
## caller runs the GDScript for that call.

##
## THREADS. A port's gate state is read on every height sample and river walk
## from many pool threads. Never publish it in a static Dictionary/Array that
## readers access unlocked, even one that is "replaced, never mutated":
## reading a container static copies its Variant (load the private pointer,
## then reference it) while assignment unreferences, frees and nulls the old
## pointer before storing the new one, so a reader in that window
## dereferences null or freed memory (the intermittent startup SIGSEGV in
## NativeRiverWalk.ready_for, October 8). Containers are touched only under
## the port's state mutex; the lock-free fast path compares plain ints and
## bools (copied by value).

static var deferred := false

## "No seed" for a port's lock-free fast-path seed (seeds are 32-bit hashes).
const NO_SEED := -9223372036854775807 - 1


## Whether a deferred gate may run on this thread (never the main thread).
static func may_gate_here() -> bool:
	return OS.get_thread_caller_id() != OS.get_main_thread_id()


## The C# error behind `result` ("" when the call succeeded). A failed call
## returns null or an empty container; only then is the thread's error read.
static func faulted(native: Object, result) -> String:
	if result != null:
		var t := typeof(result)
		var container := t == TYPE_ARRAY or t == TYPE_DICTIONARY \
			or (t >= TYPE_PACKED_BYTE_ARRAY and t < TYPE_MAX)
		if not container or not result.is_empty():
			if t == TYPE_FLOAT and is_nan(result):
				pass   # double sentinel
			elif t == TYPE_INT and result == -9223372036854775807 - 1:
				pass   # long sentinel
			elif t == TYPE_VECTOR2 and is_nan(result.x):
				pass   # Vector2 sentinel
			else:
				return ""
	if native == null:
		return "no C# instance"
	return String(native.TakeError())
