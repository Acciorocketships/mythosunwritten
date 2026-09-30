extends GutTest
## Owner, September 27 (seed 2697992464, chunk (1,4)): rocks looked evenly
## sprinkled and too many on the mountaintop, some stacked on others, and they
## sat on the ground like separate objects. Rocks now gather in colonies with
## empty ground between them, never interpenetrate, sink by a share of their
## height below the whole base outline, and the ground rises in a skirt to
## meet them. Numeric site evidence: tests/harness/rock_distribution_metrics.gd.

const FIELD = preload("res://scripts/terrain/field/CliffSlopeField.gd")
const STYLE = preload("res://scripts/terrain/field/CliffRockStyle.gd")
const SEED := 2697992464
const CORE := Rect2(Vector2.ZERO, Vector2.ONE * 192.0)

func after_all() -> void:
	STYLE.apply("current")

func _flat_region(height := 8.0) -> HeightfieldRegion:
	var plan := HeightfieldPlan.new(0, 64.0, 12, "mean", 4)
	plan.set_raw_height_override(func(_cx, _cz): return height)
	return plan.compute_region(4, 4, 12)

func _dry(region: HeightfieldRegion, program: DressingProgram) -> WaterFieldContext:
	var context := WaterFieldContext.new()
	context._ctx = {"ponds": [], "rivers": [], "buckets": {}, "region": region}
	context._region = region
	context._coverage = CORE.grow(program.query_margin + 2.0)
	context._shore_limit = program.shore_distance_limit
	return context

## The production small-rock colony set (its authored colony radius,
## membership, scale and embedding) on every biome, without its habitat mask.
func _colony_program() -> DressingProgram:
	var set := (load("res://terrain/dressing/sets/ambient_rock.tres") as DressingSet).duplicate(true)
	var fill := {}
	for id: StringName in BiomeRegistry.biome_ids():
		fill[id] = 0.8
	set.fill_per_cell = fill
	set.habitat_layers.clear()
	for choice: DressingChoice in set.choices:
		var all := {}
		for id: StringName in fill:
			all[id] = 1.0
		choice.biome_affinity = all
	var index := DressingCatalogIndex.new()
	index.sets.append(set)
	return DressingCompiler.compile(index, EnvironmentCatalog.load_default())

func _rocks(payload: EnvironmentInstancePayload) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for asset_id: StringName in payload.asset_ids():
		for t: Transform3D in payload.batches[asset_id].transforms:
			out.append({"asset": asset_id, "t": t, "p": Vector2(t.origin.x, t.origin.z)})
	return out

func test_ambient_rocks_gather_in_colonies_with_empty_ground_between() -> void:
	var program := _colony_program()
	var region := _flat_region()
	var rocks := _rocks(DressingField.compute(program, SEED, CORE, region, _dry(region, program)))
	assert_gt(rocks.size(), 6, "the colonies are populated")
	var nn_sum := 0.0
	var isolated := 0
	for a: Dictionary in rocks:
		var best := INF
		for b: Dictionary in rocks:
			if a != b:
				best = minf(best, (a.p as Vector2).distance_to(b.p))
		nn_sum += best
		if best > 8.0:
			isolated += 1
	var density := rocks.size() / CORE.get_area()
	var clark_evans := nn_sum / rocks.size() / (0.5 / sqrt(density))
	assert_lt(clark_evans, 0.5, "strongly clustered, not a uniform sprinkle (R=%.2f)" % clark_evans)
	assert_lt(float(isolated) / rocks.size(), 0.2, "few rocks stand alone (%d of %d)" % [isolated, rocks.size()])

func _base_radius(program: DressingProgram, rock: Dictionary) -> float:
	return float(program.ground_radius_by_asset[rock.asset]) * (rock.t as Transform3D).basis.x.length()

## Owner, September 27 judging (photo 6): rocks too spaced out. Bases now
## nestle into each other (slight overlap) but a rock never swallows another:
## the smaller centre stays outside the larger base (DressingCompiler.nestle_distance).
func test_ambient_rock_bases_nestle_but_never_swallow() -> void:
	var program := _colony_program()
	var region := _flat_region()
	var rocks := _rocks(DressingField.compute(program, SEED, CORE, region, _dry(region, program)))
	var touching := 0
	for i in rocks.size():
		var nearest_touch := false
		for j in rocks.size():
			if i == j:
				continue
			var a := _base_radius(program, rocks[i])
			var b := _base_radius(program, rocks[j])
			var d := (rocks[i].p as Vector2).distance_to(rocks[j].p)
			assert_gte(d, DressingCompiler.nestle_distance(a, b) - 0.0001, "no rock swallowed by another")
			assert_gt(d, maxf(a, b), "the smaller centre stays outside the larger base")
			nearest_touch = nearest_touch or d < a + b
		if nearest_touch:
			touching += 1
	assert_gt(float(touching) / rocks.size(), 0.5,
		"most colony rocks nestle into a neighbour (%d of %d)" % [touching, rocks.size()])

func test_ambient_rocks_are_embedded_and_met_by_a_ground_skirt() -> void:
	var program := _colony_program()
	var region := _flat_region()
	var payload := DressingField.compute(program, SEED, CORE, region, _dry(region, program))
	var rocks := _rocks(payload)
	assert_eq(payload.ground_skirts.size(), rocks.size(), "one skirt per embedded rock")
	for rock: Dictionary in rocks:
		var t: Transform3D = rock.t
		var height: float = EnvironmentCatalog.load_default().descriptor(rock.asset).measured_aabb.end.y
		for local: Vector2 in program.ground_stencil_by_asset[rock.asset]:
			var w := t * Vector3(local.x, 0.0, local.y)
			assert_lte(w.y - TerrainSurfaceField.surface_y(region, w.x, w.z),
				-0.22 * height * t.basis.y.length() + 0.0001,
				"the whole visible base outline is sunk below the ground")
	for skirt: Dictionary in payload.ground_skirts:
		var vertices: PackedVector3Array = skirt.vertices
		var faces: PackedVector3Array = skirt.collision_faces
		assert_eq(faces.size(), (skirt.indices as PackedInt32Array).size(), "collision is the visual surface")
		var rim_start := vertices.size() - RockSkirt.SIDES
		for i in range(rim_start, vertices.size()):
			assert_almost_eq(vertices[i].y, 8.0 - RockSkirt.RIM_SINK, 0.001, "the rim sinks under the ground")
		for i in vertices.size():
			assert_almost_eq((skirt.normals as PackedVector3Array)[i].dot(Vector3.UP), 1.0, 0.0001,
				"the skirt takes the flat terrain's normal")
		var tint: Callable = RockSkirt.terrain_surface(region, SEED).tint
		for i in vertices.size():
			assert_eq((skirt.colors as PackedColorArray)[i], tint.call(Vector2(vertices[i].x, vertices[i].z)),
				"the skirt takes the terrain's own tint")
		assert_gt(vertices[RockSkirt.SIDES].y, 8.0 + 0.08, "the ground rises to meet the rock")
		for i in range(0, faces.size(), 3):
			assert_gt((faces[i + 2] - faces[i]).cross(faces[i + 1] - faces[i]).y, 0.0, "skirt faces point up")

func test_production_boulders_need_a_break_of_slope() -> void:
	# The owner's snowy mountaintop: large boulders on an open flat plateau.
	var program := DressingCompiler.compile(load("res://terrain/dressing/index.tres"),
		EnvironmentCatalog.load_default())
	var region := _flat_region(40.0)
	var payload := DressingField.compute(program, SEED, CORE, region, _dry(region, program))
	for asset_id: StringName in payload.asset_ids():
		assert_false(String(asset_id) in ["meadow.rock.01", "meadow.rock.02", "meadow.rock.03",
			"meadow.rock.04", "meadow.rock.05"], "no boulder on open flat ground (%s)" % asset_id)

func test_slope_rocks_are_colonial_and_never_stacked() -> void:
	STYLE.apply("sheet_bedrock")
	var walls: Array = []
	# (Kept within the envelope's node budget.)
	for i in 4:
		walls.append({"replay_recipe": {"kind": "wall", "width": 150.0, "height": 8.0, "left_end": true,
			"right_end": true, "abut": Vector2i.ZERO}, "transform": Transform3D(Basis(), Vector3(0, 0, 40.0 * i))})
	var field = FIELD.new(walls, SEED)
	var bunches := {}
	for rock: Dictionary in field.rock_list:
		bunches[rock.bunch] = bunches.get(rock.bunch, []) + [rock]
	var slots := 4 * int(150.0 / FIELD.CLUSTER_SPACING)
	assert_gt(bunches.size(), 0, "the walls still carry rocks")
	assert_lt(bunches.size(), slots * 0.7, "not every slot carries a cluster (%d of %d)" % [bunches.size(), slots])
	# Genuinely bare stretches of foot between colonies.
	var bare := 0
	for i in 4:
		var along: Array[float] = [-75.0, 75.0]
		for bunch: Vector2 in bunches:
			if absf(bunch.y - 40.0 * i) < 15.0:
				along.append(bunch.x)
		along.sort()
		for k in range(1, along.size()):
			if along[k] - along[k - 1] > 30.0:
				bare += 1
	assert_gt(bare, 1, "colonies leave bare stretches of foot")
	# Owner, September 27 judging: fewer, fuller clusters whose rocks slightly
	# overlap; still never stacked (nestle distance) and never a singleton.
	var members := 0
	for bunch: Vector2 in bunches:
		assert_between((bunches[bunch] as Array).size(), 2, 4, "clusters of two to four")
		members += (bunches[bunch] as Array).size()
	assert_gt(float(members) / bunches.size(), 2.6, "fuller clusters than two or three (the first September 27 pass: 2.4)")
	var rocks: Array = field.rock_list
	for i in rocks.size():
		var touches := false
		for j in rocks.size():
			if i == j:
				continue
			var d: float = FIELD._base_centre(rocks[i]).distance_to(FIELD._base_centre(rocks[j]))
			var a: float = FIELD._base_radius(rocks[i])
			var b: float = FIELD._base_radius(rocks[j])
			assert_gte(d, DressingCompiler.nestle_distance(a, b) - 0.0001, "no rock stacked on another")
			touches = touches or (rocks[i].bunch == rocks[j].bunch and d < a + b)
		assert_true(touches, "every cluster rock nestles into another of its cluster")

## Coordinator review (September 27 judging): a basal rock's material
## measures its contact band from its support plane, so that plane must be
## the surface where the rock finally stands (after the fall-line shift or
## nestle station), not the steeper point it was sought from; otherwise a
## low rock lies wholly "below" its plane and draws as one lawn hump.
func test_basal_rock_support_plane_is_the_surface_it_stands_on() -> void:
	STYLE.apply("sheet_bedrock")
	var walls: Array = []
	for i in 4:
		walls.append({"replay_recipe": {"kind": "wall", "width": 150.0, "height": 8.0, "left_end": true,
			"right_end": true, "abut": Vector2i.ZERO}, "transform": Transform3D(Basis(), Vector3(0, 0, 40.0 * i))})
	var field = FIELD.new(walls, SEED)
	var env = field.envelope()
	assert_gt(field.rock_list.size(), 0)
	for rock: Dictionary in field.rock_list:
		if rock.kind != "basal":
			continue
		var q := Vector2((rock.point as Vector3).x, (rock.point as Vector3).z)
		var grad := Vector2(env.sample(q + Vector2(.3, 0)) - env.sample(q - Vector2(.3, 0)),
			env.sample(q + Vector2(0, .3)) - env.sample(q - Vector2(0, .3))) / .6
		var surface := Vector3(-grad.x, 1, -grad.y).normalized()
		assert_almost_eq((rock.normal as Vector3).dot(surface), 1.0, 0.0005, "the plane of the surface under the rock")
		assert_almost_eq(float((rock.point as Vector3).y), float(env.sample(q)), 0.0001, "the point on that surface")

func test_basal_slope_rocks_get_a_ground_skirt() -> void:
	STYLE.apply("sheet_bedrock")
	var wall := {"replay_recipe": {"kind": "wall", "width": 200.0, "height": 8.0, "left_end": true,
		"right_end": true, "abut": Vector2i.ZERO}, "transform": Transform3D(Basis(), Vector3(0, 0, 0))}
	var field = FIELD.new([wall], SEED)
	assert_gt(field.rock_list.size(), 0)
	for rock: Dictionary in field.rock_list:
		var skirt: Dictionary = field.skirt(rock)
		var vertices: PackedVector3Array = skirt.vertices
		var t: Transform3D = rock.transform
		# At the contact the mound rises by RockSkirt.RISE of the rock's
		# visible height there, so it stays below the rock's top; where the
		# slope buries the rock (its uphill side) no mound rises at all.
		var top: float = t.origin.y + 0.5 * FIELD.ROCKS.PIECES[rock.piece][1].y * t.basis.y.length()
		for k in RockSkirt.SIDES:
			var inner := vertices[RockSkirt.SIDES + k]
			var q := Vector2(inner.x, inner.z)
			var surface: float = maxf(field.envelope().sample(q), field.ground(q))
			var shown := maxf(0.0, top - surface)
			assert_lte(inner.y - surface, RockSkirt.rise_for(shown) + 0.001, "the mound rises only where the rock shows")
			if shown > 0.0:
				assert_lt(inner.y, top, "the mound stays below the rock's top")
		assert_eq((skirt.collision_faces as PackedVector3Array).size(),
			(skirt.indices as PackedInt32Array).size() + (skirt.sheet_indices as PackedInt32Array).size())
		# Every vertex takes the covered surface's exact normal: no pad, no seam.
		var normals: PackedVector3Array = skirt.normals
		for i in vertices.size():
			var q := Vector2(vertices[i].x, vertices[i].z)
			var covered: Vector3 = field.sheet_normal(q) if field.envelope().sample(q) - FIELD.SINK > field.ground(q) else Vector3.UP
			assert_almost_eq(normals[i].dot(covered), 1.0, 0.0001, "the covered surface's normal")

func test_ambient_skirts_are_owned_once_across_chunk_windows() -> void:
	var program := _colony_program()
	var plan := HeightfieldPlan.new(991177, 32.0, 8, "mean")
	var region := plan.compute_region(8, 4, 20)
	var union := Rect2(Vector2.ZERO, Vector2(384.0, 192.0))
	var water := _dry(region, program)
	water._coverage = union.grow(program.query_margin + 2.0)
	var ids := func(payload: EnvironmentInstancePayload) -> Dictionary:
		var out := {}
		for skirt: Dictionary in payload.ground_skirts:
			out[skirt.id] = skirt.vertices
		return out
	var left: Dictionary = ids.call(DressingField.compute(program, SEED, Rect2(0, 0, 192, 192), region, water))
	var right: Dictionary = ids.call(DressingField.compute(program, SEED, Rect2(192, 0, 192, 192), region, water))
	var both: Dictionary = ids.call(DressingField.compute(program, SEED, union, region, water))
	assert_gt(both.size(), 0)
	assert_eq(left.size() + right.size(), both.size(), "every skirt has exactly one owner")
	for id: String in both:
		var mine: Dictionary = left if left.has(id) else right
		assert_true(mine.has(id), "skirt %s is owned by one chunk" % id)
		assert_eq(mine.get(id), both[id], "an owned skirt does not depend on the query window")

func test_slope_ground_rock_collision_matches_its_visual() -> void:
	var rocks := preload("res://scripts/terrain/field/CliffSlopeRocks.gd")
	rocks.prepare()
	for i in range(1, 6):
		var name := "angry_%02d" % i
		var visual := load("res://terrain/environment/visuals/meadow/rock_%02d.res" % i) as EnvironmentVisual
		var lift := Transform3D(Basis(), Vector3(0, -0.5 * (rocks.PIECES[name][1] as Vector3).y, 0))
		var collision: Transform3D = lift * visual.collisions[0].local_transform
		var render: Transform3D = rocks._pieces[name][1]
		assert_true(collision.is_equal_approx(render), "%s hull sits on its rendered mesh" % name)

## Nestled rocks overlap (September 27 judging), so their skirts overlap too:
## a point under either rock grows no grass, even where the other rock's
## mound is the higher surface there.
func test_overlapping_skirts_grow_no_grass_under_either_rock() -> void:
	var surface := {"height": func(_p: Vector2) -> float: return 0.0,
		"normal": func(_p: Vector2) -> Vector3: return Vector3.UP,
		"tint": func(_p: Vector2) -> Color: return Color.WHITE}
	# A low rock a, and a tall neighbour b whose mound rises over a's base.
	var a := RockSkirt.build("a", Vector2.ZERO, RockSkirt.ellipse_radii(Vector2(1.0, 1.0), Vector2.RIGHT), 0.2, surface)
	var b := RockSkirt.build("b", Vector2(2.6, 0.0), RockSkirt.ellipse_radii(Vector2(1.6, 1.6), Vector2.RIGHT), 3.0, surface)
	var cells := GrassSupportSurfaces.spatial_index([a.grass_support, b.grass_support])
	var inside_a := Vector2(0.4, 0.0)
	assert_gt(float(GrassSupportSurfaces.at_grid(b.grass_support, inside_a).y),
		float(GrassSupportSurfaces.at_grid(a.grass_support, inside_a).y), "b's mound is the higher surface there")
	var sample := GrassSupportSurfaces.at_index(cells, inside_a)
	assert_false(sample.is_empty(), "the overlap is supported")
	assert_eq(float(sample.get("edge_distance", -1.0)), 0.0, "no blade inside rock a under b's mound")
	var open := GrassSupportSurfaces.at_index(cells, Vector2(-1.5, 0.0))
	assert_gt(float(open.get("edge_distance", 0.0)), 0.0, "a's own open skirt still grows grass")
