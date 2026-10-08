extends GutTest
## The native bedrock surface net (NativeCliffSolid.cs) is bit-identical to
## CliffSlopeField.solid's GDScript or stays off: faces in emission order,
## native_roots keys in insertion order with their normal / exposure / grade,
## every other placement field, the solid's columns and the replacement
## columns, on the reported P03 mountain (no region: the solid lies on the
## envelope) and on windows of three real cliffy chunks (the 2 m mesh chords
## through the tile kernel), one with a terrain grade list.

const N := preload("res://scripts/native/NativeCliffSolid.gd")
const FIELD := preload("res://scripts/terrain/field/CliffSlopeField.gd")
const STYLE := preload("res://scripts/terrain/field/CliffRockStyle.gd")
const DRESSING := preload("res://scripts/terrain/field/CliffRockDressing.gd")

func before_each() -> void:
	STYLE.apply("sheet_bedrock")

func after_each() -> void:
	N.force_off = false

func test_native_matches_gdscript_or_stays_off() -> void:
	N.setup()
	if not ClassDB.class_exists(&"CSharpScript"):
		assert_false(N.enabled, "the standard editor has no native solid")
		return
	assert_true(N.enabled, "parity gate passed")

func test_parity_cases_mesh_something() -> void:
	N.setup()
	if not N.enabled:
		pass_test("native solid unavailable")
		return
	for c: Dictionary in N.parity_cases():
		assert_eq(N.compare(c), "")

func test_p03_fixture_matches_exactly() -> void:
	N.setup()
	if not N.enabled:
		pass_test("native solid unavailable")
		return
	var d: Dictionary = bytes_to_var(FileAccess.get_file_as_bytes("res://tests/fixtures/september26-cliffs/p03-constrained-inputs.var.gz").decompress_dynamic(4000000, FileAccess.COMPRESSION_GZIP))
	var index := func(q: Vector2) -> int:
		var p := Vector2i(((q - d.origin) / .5).round()).clamp(Vector2i.ZERO, Vector2i(d.w - 1, d.h - 1))
		return p.y * d.w + p.x
	var ground := func(q: Vector2) -> float: return d.ground[index.call(q)]
	var env = FIELD.ENVELOPE.build(Rect2(476, 924, 92, 96), ground,
		func(q: Vector2) -> bool: return d.excluded[index.call(q)] != 0, 2697992464,
		func(q: Vector2) -> float: return d.wet[index.call(q)])
	var field = FIELD.new([], 2697992464)
	field._env = env
	field.ground_at = ground
	var owned := Rect2(480, 930, 36, 44)
	assert_gt(field.solid(owned, 1)[0].faces.size(), 1000, "the P03 solid meshes the mountain")
	assert_eq(N.compare_field(field, owned), "", "P03")

## The 96 m quarter of a real chunk holding the most wall segments.
static func _window(region: HeightfieldRegion, chunk: Vector2i) -> Rect2:
	var owned := DRESSING.owned_rect(chunk)
	var walls := TerrainTileField.wall_segments(region, owned)
	var best := Rect2()
	var most := -1
	for q in 4:
		var r := Rect2(owned.position + Vector2(q & 1, q >> 1) * 96.0, Vector2.ONE * 96.0)
		var n := 0
		for wall: Dictionary in walls:
			if r.has_point(((wall.a as Vector2) + (wall.b as Vector2)) * 0.5):
				n += 1
		if n > most:
			most = n
			best = r
	return best

func test_real_chunks_match_exactly() -> void:
	N.setup()
	if not N.enabled:
		pass_test("native solid unavailable")
		return
	var seed_value := 2697992464
	var water := TerrainWorldTuning.make_water(seed_value)
	var plan := TerrainWorldTuning.make_heightfield(seed_value, water)
	var chunks := [Vector2i(2, 4), Vector2i(1, 4), Vector2i(1, 3)]
	for n in chunks.size():
		var chunk: Vector2i = chunks[n]
		var region := plan.compute_region(chunk.x * 16 + 8, chunk.y * 16 + 8, 18)
		var owned := _window(region, chunk)
		if n == 2:
			# A region still carrying its grade list (the _apply_grade path of
			# the mesh chords).
			var listed := HeightfieldRegion.new(region._storeys, region._levels, region._carved, region.plan)
			var c := owned.get_center()
			listed.terrain_grades.append(TerrainGradePatch.new(&"t", {Vector2i(0, 0): 40.0, Vector2i(1, 0): 40.0}, c, 3.0))
			region = listed
			assert_true(TerrainTileField.grades(region))
		var field = FIELD.new([], seed_value, region, owned)
		var placements: Array = field.solid(owned, 1)
		assert_false(placements.is_empty(), "chunk %s meshes a solid" % chunk)
		if not placements.is_empty():
			assert_gt(placements[0].faces.size(), 3000, "chunk %s has cliffs in its window" % chunk)
		assert_eq(N.compare_field(field, owned), "", "chunk %s window %s" % [chunk, owned])

## The dispatch: solid() with native on is the GDScript solid, and grass
## support reads the same columns.
func test_dispatch_and_grass_support_match() -> void:
	N.setup()
	if not N.enabled:
		pass_test("native solid unavailable")
		return
	var c: Dictionary = N.parity_cases()[1]
	var region := N.region_of(c.storeys)
	var owned: Rect2 = c.owned
	var walls := TerrainTileField.wall_segments(region, owned.grow(24.0))
	var results := []
	for native in [true, false]:
		N.force_off = not native
		var field = FIELD.new(walls, c.seed, region, owned)
		var placements: Array = field.solid(owned)
		var support: Dictionary = field.grass_support(owned.grow(-2.0))
		support.erase("mesh_cells")  # rebuilt from mesh_faces
		results.append([placements, support])
		N.force_off = false
	assert_eq(results[0][0].size(), results[1][0].size())
	assert_eq(results[0][0][0].faces, results[1][0][0].faces)
	assert_eq(results[0][0][0].native_roots.keys(), results[1][0][0].native_roots.keys())
	assert_eq(results[0][1], results[1][1], "grass support")


## A C# call that throws turns the port off for good and solid() meshes in
## GDScript: the same faces, no script error.
func test_a_throwing_call_falls_back_to_gdscript_and_disables() -> void:
	N.setup()
	if not N.enabled:
		pass_test("native solid unavailable")
		return
	var c: Dictionary = N.parity_cases()[1]
	var region := N.region_of(c.storeys)
	var owned: Rect2 = c.owned
	var walls := TerrainTileField.wall_segments(region, owned.grow(24.0))
	var faces := []
	for native in [false, true]:
		N.force_off = not native
		var field = FIELD.new(walls, c.seed, region, owned)
		field.envelope()   # the envelope's own C# calls are not the ones faulted
		if native:
			N.arm_fault()
		var placements: Array = field.solid(owned)
		faces.append(placements[0].faces)
		N.force_off = false
	assert_eq(faces[1], faces[0], "the faulted solid returns the GDScript faces")
	assert_false(N.on(), "the port turned itself off")
	N._faulted = false
	N.enabled = true
	_expect_fault_warning()


## The fault's warning is the expected outcome, not a test failure.
func _expect_fault_warning() -> void:
	var warned := 0
	for e in get_errors():
		if e.contains_text("forced test fault"):
			e.handled = true
			warned += 1
	assert_gt(warned, 0, "a warning names the C# failure")
