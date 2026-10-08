extends GutTest
## The native cliff envelope (NativeCliffEnvelope.cs) is bit-identical to
## CliffSlopeEnvelope's GDScript build, or stays off: on the reported P03
## mountain inputs, and on synthetic dual-grid regions (terraces, 2-4 storey
## walls, wet channels, roads). A mismatch names the first differing stage.

const N := preload("res://scripts/native/NativeCliffEnvelope.gd")
const E := preload("res://scripts/terrain/field/CliffSlopeEnvelope.gd")
const POINTS := preload("res://tests/fixtures/tile_point_region.gd")

func after_each() -> void:
	N.force_off = false

func test_native_matches_gdscript_or_stays_off() -> void:
	N.setup()
	if not ClassDB.class_exists(&"CSharpScript"):
		assert_false(N.enabled, "the standard editor has no native envelope")
		return
	assert_true(N.enabled, "parity gate passed")

func test_p03_fixture_matches_exactly() -> void:
	N.setup()
	if not N.enabled:
		pass_test("native envelope unavailable")
		return
	var d: Dictionary = bytes_to_var(FileAccess.get_file_as_bytes("res://tests/fixtures/september26-cliffs/p03-constrained-inputs.var.gz").decompress_dynamic(4000000, FileAccess.COMPRESSION_GZIP))
	var index := func(q: Vector2) -> int:
		var p := Vector2i(((q - d.origin) / .5).round()).clamp(Vector2i.ZERO, Vector2i(d.w - 1, d.h - 1))
		return p.y * d.w + p.x
	var ground := func(q: Vector2) -> float: return d.ground[index.call(q)]
	var c := {"rect": Rect2(476, 924, 92, 96), "ground": ground,
		"excluded": func(q: Vector2) -> bool: return d.excluded[index.call(q)] != 0,
		"water": func(q: Vector2) -> float: return d.wet[index.call(q)],
		"seed": 2697992464, "bedrock": true}
	assert_eq(N.compare(c, true), "", "P03 (bedrock)")
	c.bedrock = false
	assert_eq(N.compare(c, true), "", "P03 (plain sheet)")

## Twelve random point regions through the real tile kernel, with the batched
## ground grid / wall-line samples the cliff field passes.
func test_synthetic_regions_match_exactly() -> void:
	N.setup()
	if not N.enabled:
		pass_test("native envelope unavailable")
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261007
	for case_index in 12:
		var heights := {}
		var kind := case_index % 4
		for j in range(-6, 7):
			for i in range(-6, 7):
				var h := 0.0
				match kind:
					0: # random terraces: 0-4 storeys with levels
						h = float(rng.randi_range(0, 4)) * 4.0 + float(rng.randi_range(0, 3))
					1: # a stepped massif: 2-4 storey walls
						h = 4.0 * float(clampi(4 - maxi(absi(i), absi(j)), 0, 4)) * float(rng.randi_range(2, 4)) * 0.5
					2: # a slope with a wall ending in it
						h = 4.0 * float(clampi(j + 2, 0, 3)) + (8.0 if i > 1 and j < 0 else 0.0)
					3: # walls beside a low channel
						h = 0.0 if absi(i + 1) <= 1 else 4.0 * float(rng.randi_range(2, 4))
				heights[Vector2i(i, j)] = h
		var region = POINTS.new(heights, 0.0)
		var ground := func(q: Vector2) -> float: return TerrainTileField.surface_y(region, q.x, q.y)
		var grid := func(origin: Vector2, w: int, h: int) -> PackedFloat64Array:
			var xs := PackedFloat64Array(); xs.resize(w)
			for i in w: xs[i] = (origin + Vector2(i, 0) * E.H).x
			var zs := PackedFloat64Array(); zs.resize(h)
			for k in h: zs[k] = (origin + Vector2(0, k) * E.H).y
			return TerrainTileField.sample_grid(region, xs, zs)
		var points := func(xs: PackedFloat64Array, zs: PackedFloat64Array) -> PackedFloat64Array:
			return TerrainTileField.sample_grid(region, xs, zs)
		var water := Callable()
		if kind == 3 or case_index % 5 == 1:
			var level := rng.randf_range(1.0, 3.0)
			water = func(q: Vector2) -> float: return level if absf(q.x + 12.0) < 20.0 else NAN
		var excluded := Callable()
		if case_index % 3 == 0:
			var lo := rng.randf_range(-20.0, 10.0)
			excluded = func(q: Vector2) -> bool: return q.y > lo and q.y < lo + 5.0 and q.x > -10.0
		var c := {"rect": Rect2(-18, -18, 36, 36), "ground": ground, "excluded": excluded, "water": water,
			"seed": rng.randi(), "bedrock": case_index % 6 != 5}
		if case_index % 2 == 0:
			c.ground_grid = grid
			c.ground_points = points
		assert_eq(N.compare(c, true), "", "synthetic case %d (kind %d)" % [case_index, kind])

## The dispatch itself (build with native on vs forced off).
func test_build_dispatch_matches_the_reference() -> void:
	N.setup()
	if not N.enabled:
		pass_test("native envelope unavailable")
		return
	var c: Dictionary = N.parity_cases()[1]
	var run := func(native: bool):
		N.force_off = not native
		var env = E.build(c.rect, c.ground, c.excluded, c.seed, c.water)
		N.force_off = false
		return [env.surface, env.rock, env.moss_grade, env.excluded]
	assert_eq(run.call(true), run.call(false))


## A C# build that throws turns the port off for good and the envelope is
## built in GDScript: the same arrays, no script error.
func test_a_throwing_call_falls_back_to_gdscript_and_disables() -> void:
	N.setup()
	if not N.enabled:
		pass_test("native envelope unavailable")
		return
	var c: Dictionary = N.parity_cases()[1]
	var run := func():
		var env = E.build(c.rect, c.ground, c.excluded, c.seed, c.water)
		return [env.surface, env.rock, env.moss_grade, env.excluded]
	N.force_off = true
	var expected = run.call()
	N.force_off = false
	N.arm_fault()
	assert_eq(run.call(), expected, "the faulted build returns the GDScript envelope")
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
