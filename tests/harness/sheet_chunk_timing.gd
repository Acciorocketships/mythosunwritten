extends SceneTree
## Streams the world headless at a site and reports when the player's arrival
## chunks are ready (sheet-style chunk cost). Args: --at x,y,z --style name --radius n
var _streamer: FieldTerrainStreamer
var _started := 0
var _at := Vector3.ZERO

func _initialize() -> void:
	var at := Vector3(262, 30, 1045)
	var style := "sheet"
	var radius := 1
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		var next := args[i + 1] if i + 1 < args.size() else ""
		match args[i]:
			"--at":
				var p := next.split(",")
				at = Vector3(float(p[0]), float(p[1]), float(p[2]))
			"--style": style = next
			"--radius": radius = int(next)
	var world := (load("res://scenes/world.tscn") as PackedScene).instantiate()
	_streamer = world.find_child("FieldTerrain", true, false) as FieldTerrainStreamer
	var character := world.find_child("Character", true, false) as Node3D
	_streamer.CLIFF_STYLE = "sheet_bedrock" if style == "default" else style
	_streamer.CHUNK_RADIUS = radius
	_streamer.KEEP_RADIUS = radius + 1
	_streamer.GRASS_ENABLED = false
	character.position = at
	_at = at
	root.add_child(world)
	_started = Time.get_ticks_msec()

func _process(_delta: float) -> bool:
	if _streamer == null or not _streamer._built.has(FieldTerrainStreamer.chunk_of(_at)):
		return false
	print("[sheet_chunk_timing] chunk ready ms=%d built=%d" % [Time.get_ticks_msec() - _started, _streamer._built.size()])
	_streamer._exit_tree()   # the worker must be idle: its caches are not shared-safe
	_profile(FieldTerrainStreamer.chunk_of(_at))
	var STYLE = load("res://scripts/terrain/field/CliffRockStyle.gd")
	STYLE.apply(STYLE.PRODUCTION)
	print("[sheet_chunk_timing] -- production style")
	_profile_total(FieldTerrainStreamer.chunk_of(_at))
	return true


func _profile_total(chunk: Vector2i) -> void:
	var features: FeatureContext = _streamer._features.context_for(chunk, Callable())
	var region: HeightfieldRegion = features.graded_region(_streamer._fields.region(chunk))
	var t := Time.get_ticks_usec()
	preload("res://scripts/terrain/field/CliffRockDressing.gd").compute(region, chunk,
		_streamer._mesher._water_seed, features, _streamer._fields.water(chunk))
	print("[sheet_chunk_timing] TOTAL %8.1f ms" % ((Time.get_ticks_usec() - t) / 1000.0))


## Per-stage cost of the cliff rock dressing for one chunk (worker idle).
func _profile(chunk: Vector2i) -> void:
	const DRESS = preload("res://scripts/terrain/field/CliffRockDressing.gd")
	const SLOPE = preload("res://scripts/terrain/field/CliffSlopeField.gd")
	const CRAGS = preload("res://scripts/terrain/field/CliffRockCrags.gd")
	var features: FeatureContext = _streamer._features.context_for(chunk, Callable())
	var region: HeightfieldRegion = features.graded_region(_streamer._fields.region(chunk))
	var water: WaterFieldContext = _streamer._fields.water(chunk)
	var seed_value: int = _streamer._mesher._water_seed
	print("[sheet_chunk_timing] ground at site y=%.2f" % TerrainTileField.surface_y(region, _at.x, _at.z))
	var t := Time.get_ticks_usec()
	var mark := func(label: String) -> void:
		print("[sheet_chunk_timing] %-12s %8.1f ms" % [label, (Time.get_ticks_usec() - t) / 1000.0])
		t = Time.get_ticks_usec()
	var owned: Rect2 = DRESS.owned_rect(chunk)
	var walls := TerrainTileField.wall_segments(region, owned.grow(DRESS.WALL_HALO))
	mark.call("walls")
	var slope = SLOPE.new(walls, seed_value, region, owned, features, water)
	mark.call("slope_init")
	var solid: Array = slope.solid(owned)
	mark.call("solid")
	var rocks: Array = slope.rocks(owned)
	mark.call("rocks")
	for p: Dictionary in solid:
		CRAGS.mesh_arrays(p, region, seed_value)
		print("[sheet_chunk_timing] triangles=%d walls=%d rocks=%d" % [(p.faces as PackedVector3Array).size() / 3, walls.size(), rocks.size()])
	mark.call("mesh_arrays")
	t = Time.get_ticks_usec()
	DRESS.compute(region, chunk, seed_value, features, water)
	mark.call("TOTAL")
