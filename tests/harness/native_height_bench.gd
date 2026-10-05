extends SceneTree

## Native (C#) vs GDScript terrain height timings. Run under the .NET editor
## (dotnet build Story.csproj first), once per mode, each in a fresh process so
## both start cold:
##   Godot_mono --headless --path . -s res://tests/harness/native_height_bench.gd -- gd 2697992464
##   Godot_mono --headless --path . -s res://tests/harness/native_height_bench.gd -- native 2697992464
## Prints plan setup (incl. the parity check), three cold compute_region(r16)
## calls and warm per-call HeightfieldPlan.height01 / batch costs.

const NativeHeightField := preload("res://scripts/native/NativeHeightField.gd")

func _init() -> void:
	var N = NativeHeightField
	var args := OS.get_cmdline_user_args()
	var mode: String = args[0]
	var seed := int(args[1])
	var t := Time.get_ticks_usec()
	var plan := TerrainWorldTuning.make_heightfield(seed)
	print(mode, " setup ms ", (Time.get_ticks_usec() - t) / 1000.0, " ready ", N.ready_for(seed))
	if mode == "gd":
		N.enabled = false
	# 1. cold compute_region for three chunk regions away from the parity probes
	for k in 3:
		var ci := 16 * (40 + 3 * k) + 8
		var a := Time.get_ticks_usec()
		var reg = plan.compute_region(ci, -ci, 16)
		print(mode, " cold compute_region(r16) #", k, " ms ", (Time.get_ticks_usec() - a) / 1000.0)
	# 2. warm local per-call: 64x64 lattice inside the last region, twice
	var pts := PackedVector2Array()
	var base := Vector2(12.0 * (16 * 46 + 8), -12.0 * (16 * 46 + 8))
	for j in 64:
		for i in 64:
			pts.append(base + Vector2(i * 6.0 - 192.0, j * 6.0 - 192.0))
	for d in [true, false]:
		for rep in 2:
			var a := Time.get_ticks_usec()
			for p in pts:
				HeightfieldPlan.height01(Vector3(p.x, 0.0, p.y), seed, d)
			print(mode, " height01 detail=", d, " rep ", rep, " us/call ", float(Time.get_ticks_usec() - a) / pts.size())
	if mode == "native":
		for d in [true, false]:
			var a := Time.get_ticks_usec()
			for p in pts:
				N.height_m(p, seed, d)
			var b := Time.get_ticks_usec()
			N.height_batch(pts, seed, d)
			var c := Time.get_ticks_usec()
			print("native height_m single us/call ", float(b - a) / pts.size(), " batch us/pt ", float(c - b) / pts.size(), " detail=", d)
	quit()
