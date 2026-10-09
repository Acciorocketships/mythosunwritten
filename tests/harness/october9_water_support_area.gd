extends SceneTree


## Headless version of the local supply study. Uses the same seed, block
## cache and dressing query margins as the rendered scene. No mesh or GPU
## work is needed to compare the actual analytic water and terrain fields.
class StreamerProxy:
	extends RefCounted
	var _fields: WorldFieldBlockCache


class ReviewProxy:
	extends Node
	var _streamer: StreamerProxy
	var _output_dir: String


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var output := "/tmp/oct9-water-support-area"
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		output = args[0]
	DirAccess.make_dir_recursive_absolute(output)
	TerrainTileField.cliff_end = TerrainTileField.CliffEnd.SHARED_PROFILE
	preload("res://scripts/native/NativeGridKernels.gd").setup()
	preload("res://scripts/native/NativeTileKernel.gd").setup()
	preload("res://scripts/native/NativeWaterFill.gd").setup()
	WaterField.SOURCE_SUPPORT = args.has("--source-support")
	if not WaterField.SOURCE_SUPPORT:
		preload("res://scripts/terrain/field/PlanningDiskCache.gd").configure(2697992464)
	var catalog := EnvironmentCatalog.load_default()
	var program := DressingCompiler.compile(load("res://terrain/dressing/index.tres"), catalog)
	var water := TerrainWorldTuning.make_water(2697992464)
	var plan := TerrainWorldTuning.make_heightfield(2697992464, water)
	var proxy := ReviewProxy.new()
	proxy._streamer = StreamerProxy.new()
	proxy._streamer._fields = WorldFieldBlockCache.new(
		plan, water, program.query_margin, program.shore_distance_limit, 16
	)
	proxy._output_dir = output
	root.add_child(proxy)
	for step: float in [.5, 1.0, 3.0]:
		var probe = load("res://tests/harness/october9_water_branch_supply.gd").new()
		probe.sample_step = step
		probe.sample_origin = Vector2(-81, 1098)
		probe.diagonals = true
		probe.support_trial = true
		probe.output_suffix = "-step-" + str(step)
		await probe.run(proxy)
	proxy.free()
	quit()
