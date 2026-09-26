extends SceneTree
## Compares the `sheet` slope built from full crag formations with the one
## built from outline formations, over a 3x3 chunk block at a site.
## Args: --at x,y,z
const STYLE = preload("res://scripts/terrain/field/CliffRockStyle.gd")
const DRESS = preload("res://scripts/terrain/field/CliffRockDressing.gd")
const CORNERS = preload("res://scripts/terrain/field/CliffCornerCrags.gd")
const JOINS = preload("res://scripts/terrain/field/CliffInnerConnections.gd")
const SLOPE = preload("res://scripts/terrain/field/CliffSlopeField.gd")
var _streamer: FieldTerrainStreamer
var _at := Vector3(262, 30, 1045)
var _done := false

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--at":
			var p := args[i + 1].split(",")
			_at = Vector3(float(p[0]), float(p[1]), float(p[2]))
	var world := (load("res://scenes/world.tscn") as PackedScene).instantiate()
	_streamer = world.find_child("FieldTerrain", true, false) as FieldTerrainStreamer
	_streamer.CHUNK_RADIUS = 1
	_streamer.KEEP_RADIUS = 2
	_streamer.GRASS_ENABLED = false
	(world.find_child("Character", true, false) as Node3D).position = _at
	root.add_child(world)

func _process(_delta: float) -> bool:
	if _done:
		return true
	var target := FieldTerrainStreamer.chunk_of(_at)
	var ready := _streamer._built.has(target) or _streamer._pending_terrain.any(
		func(r: Dictionary) -> bool: return r.chunk == target)
	if not ready:
		return false
	_done = true
	_streamer._exit_tree()   # the worker's caches are not shared-safe
	for dz in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			_compare(target + Vector2i(dx, dz))
	return true

func _build(chunk: Vector2i, full: bool) -> Dictionary:
	var features: FeatureContext = _streamer._features.context_for(chunk, Callable())
	var region: HeightfieldRegion = features.graded_region(_streamer._fields.region(chunk))
	var water: WaterFieldContext = _streamer._fields.water(chunk)
	var seed_value: int = _streamer._mesher._water_seed
	var cells := TerrainChunkMesher.CELLS_PER_CHUNK
	var lo := chunk * cells
	STYLE.apply("sheet")
	var t := Time.get_ticks_usec()
	STYLE.sheet_only = not full
	var cliffs := CliffDressing.compute(region, lo.x - 1, lo.y - 1, cells + 2)
	var forms: Array = DRESS.formations(cliffs.wall, seed_value, region, features, water)
	forms.append_array(CORNERS.formations(cliffs.outer_wall, seed_value, region, features, false, water))
	forms.append_array(CORNERS.formations(cliffs.inner_wall, seed_value, region, features, true, water))
	JOINS.apply(forms, region, features)
	STYLE.sheet_only = true
	var formations_ms := (Time.get_ticks_usec() - t) / 1000.0
	var owned := Rect2(Vector2(lo) * 24.0 - Vector2(12, 12), Vector2.ONE * cells * 24.0)
	var slope = SLOPE.new(forms, seed_value, region, owned)
	var solid: Array = slope.solid(owned)
	var prims: Array[String] = []
	for s: Dictionary in slope._primitives:
		prims.append(("arc %s %s" % [s.c, s.base]) if s.arc else ("seg %s %.2f %s %.2f %.2f %s%s" % [
			(s.a as Vector2).snapped(Vector2.ONE * .01), s.length, s.n, s.base, s.height, s.free_a, s.free_b]))
	prims.sort()
	var depth := 0.0
	for f: Dictionary in forms:
		if f.get("replay_recipe", {}).get("kind", "") == "wall":
			depth = maxf(depth, ((f.transform as Transform3D).affine_inverse() * (f.bounds as AABB)).end.z)
	return {"slope": slope, "owned": owned, "prims": prims, "ms": formations_ms,
		"total_ms": (Time.get_ticks_usec() - t) / 1000.0, "depth": depth,
		"hash": hash((solid[0].faces as PackedVector3Array)) if not solid.is_empty() else 0,
		"tris": (solid[0].faces as PackedVector3Array).size() / 3 if not solid.is_empty() else 0,
		"rocks": slope.rock_list.size(), "kinds": _kinds(forms)}

static func _kinds(forms: Array) -> Dictionary:
	var out := {}
	for f: Dictionary in forms:
		var k: String = f.get("replay_recipe", {}).get("kind", "?")
		out[k] = int(out.get(k, 0)) + 1
	return out

func _compare(chunk: Vector2i) -> void:
	var a := _build(chunk, true)
	var b := _build(chunk, false)
	var only_a: Array = (a.prims as Array).filter(func(p: String) -> bool: return not (b.prims as Array).has(p))
	var only_b: Array = (b.prims as Array).filter(func(p: String) -> bool: return not (a.prims as Array).has(p))
	var worst := 0.0; var moved := 0; var columns := 0
	var owned: Rect2 = a.owned
	var x := owned.position.x
	while x < owned.end.x:
		var z := owned.position.y
		while z < owned.end.y:
			var q := Vector2(x, z)
			var ha: float = a.slope.surface_height(a.slope._contributions(q), q)
			var hb: float = b.slope.surface_height(b.slope._contributions(q), q)
			columns += 1
			if absf(ha - hb) > .05: moved += 1
			worst = maxf(worst, absf(ha - hb))
			z += 1.0
		x += 1.0
	print("[outline_compare] chunk=%s full %.0f/%.0f ms outline %.0f/%.0f ms | prims %d vs %d (only_full %d only_outline %d) | solid same=%s tris %d/%d rocks %d/%d | surface moved>5cm %d/%d max %.2f m | wall depth %.2f | kinds full %s outline %s" % [
		chunk, a.ms, a.total_ms, b.ms, b.total_ms, a.prims.size(), b.prims.size(), only_a.size(), only_b.size(),
		str(a.hash == b.hash), a.tris, b.tris, a.rocks, b.rocks, moved, columns, worst, a.depth, a.kinds, b.kinds])
	for p in only_a: print("[outline_compare]   only_full ", p)
	for p in only_b: print("[outline_compare]   only_outline ", p)
