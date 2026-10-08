extends GutTest
## A chunk integrated step by step (the streamer runs one or more steps a
## frame, FieldTerrainStreamer._integration_steps) builds exactly the node
## tree commit_chunk builds in one call, and the biome effects' steps build
## exactly build_field's tree: same nodes, classes, child order and contents.

const SIGNATURE := preload("res://tests/fixtures/node_tree_signature.gd")
const REFERENCE := preload("res://tests/fixtures/commit_reference.gd")
const SEED := 2697992464
## A cliffy chunk: sheet tiles, slope rocks with collision, rock skirts.
const CHUNK := Vector2i(1, -1)

var _data: Dictionary = {}
var _fx: Dictionary = {}


func before_all() -> void:
	var water := TerrainWorldTuning.make_water(SEED)
	var plan := TerrainWorldTuning.make_heightfield(SEED, water)
	var fields := WorldFieldBlockCache.new(plan, water, 0.0, 0.0, 16)
	var region := fields.region(CHUNK)
	var water_ctx := fields.water(CHUNK)
	var mesher := TerrainChunkMesher.new()
	mesher.set_seed(SEED)
	mesher.prepare_resources()
	mesher.water_blocks = fields
	_data = mesher.compute_chunk(CHUNK, region, water_ctx, null)
	assert(not _data.is_empty())
	_fx = BiomeAtmosphereField.compute(CHUNK, region, SEED, water_ctx)


func test_terrain_steps_build_the_commit_chunk_tree() -> void:
	var mesher := TerrainChunkMesher.new()
	mesher.set_seed(SEED)
	mesher.prepare_resources()
	var whole := mesher.commit_chunk(_data)
	var timed := mesher.commit_steps(_data)
	assert_eq((timed.labels as PackedStringArray).size(), (timed.steps as Array).size(), "one label per step")
	for step: Callable in timed.steps:
		step.call()
	var stepped: Node3D = timed.root
	assert_gt(SIGNATURE.of(whole).count("\n"), 20, "a cliffy chunk with many nodes")
	assert_eq(SIGNATURE.of(stepped), SIGNATURE.of(whole))
	gut.p("terrain tree md5 %s" % SIGNATURE.of(whole).md5_text())
	whole.free()
	stepped.free()


func test_fx_steps_build_the_build_field_tree() -> void:
	if _fx.is_empty():
		pass_test("no effects in this chunk")
		return
	var whole := BiomeChunkFx.build_field(_fx)
	var built := BiomeChunkFx.build_field_steps(_fx)
	assert_eq((built.labels as PackedStringArray).size(), (built.steps as Array).size(), "one label per step")
	for step: Callable in built.steps:
		step.call()
	assert_eq(SIGNATURE.of(built.root), SIGNATURE.of(whole))
	gut.p("fx tree md5 %s" % SIGNATURE.of(whole).md5_text())
	whole.free()
	(built.root as Node).free()


## The rock skirts' steps (gather, mesh, collision) build what the single
## pre-split commit built: the same nodes and the same collision triangles.
func test_rock_skirt_steps_match_the_single_commit() -> void:
	var chunk_skirts: Array = (_data.get("cliff_terraces", {}) as Dictionary).get("rock_skirts", [])
	assert_gt(chunk_skirts.size(), 0, "the chunk has rock skirts")
	# Repeated past two gather steps (a step boundary inside the list).
	var skirts: Array = []
	while skirts.size() <= 2 * RockSkirt.SKIRTS_PER_STEP:
		skirts.append_array(chunk_skirts)
	var reference := Node3D.new()
	REFERENCE.commit(reference, skirts)
	var stepped := Node3D.new()
	var steps := RockSkirt.commit_steps(stepped, skirts)
	assert_gt(steps.size(), 4, "three gathers, mesh, collision")
	for step: Callable in steps:
		step.call()
	assert_eq(SIGNATURE.of(stepped), SIGNATURE.of(reference))
	var faces := func(root: Node3D) -> PackedVector3Array:
		return ((root.get_node("RockSkirtCollision/RockSkirts") as CollisionShape3D).shape as ConcavePolygonShape3D).get_faces()
	assert_eq(faces.call(stepped), faces.call(reference))
	reference.free()
	stepped.free()


## Point emitters configured before their process material is assigned (one
## shader per configuration) end with the same material as before.
func test_point_emitters_keep_their_material() -> void:
	var data := {"lo": 3.0, "hi": 21.0}
	var points := PackedVector3Array([Vector3(4, 6, 9), Vector3(80, 12, 150), Vector3(120, 8, 30)])
	for recipe: StringName in BiomeChunkFx.RECIPES:
		if recipe == &"fireflies":
			continue
		var before: GPUParticles3D = REFERENCE.point_effect(recipe, points, data)
		var after: GPUParticles3D = BiomeChunkFx._point_effect(recipe, points, data)
		assert_eq(SIGNATURE.of(after), SIGNATURE.of(before), String(recipe))
		var a := before.process_material as ParticleProcessMaterial
		var b := after.process_material as ParticleProcessMaterial
		for prop: Dictionary in a.get_property_list():
			if not (prop.usage & PROPERTY_USAGE_STORAGE):
				continue
			var name: String = prop.name
			if name == "emission_point_texture":
				assert_eq((b.get(name) as ImageTexture).get_image().get_data(),
					(a.get(name) as ImageTexture).get_image().get_data(), "%s points" % recipe)
			elif not (a.get(name) is Resource):
				assert_eq(b.get(name), a.get(name), "%s %s" % [recipe, name])
		for prop in ["amount", "lifetime", "preprocess", "fixed_fps", "local_coords", "visibility_aabb", "draw_pass_1"]:
			assert_eq(after.get(prop), before.get(prop), "%s %s" % [recipe, prop])
		before.free()
		after.free()
