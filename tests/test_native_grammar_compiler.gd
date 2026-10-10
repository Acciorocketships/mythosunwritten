extends GutTest
const Compiler = preload("res://scripts/terrain/features/villages/grammar/NativeGrammarCompiler.gd")
const House = preload("res://scripts/terrain/features/villages/grammar/PureVillageCrossHouse.gd")
const Foundation = preload(
	"res://scripts/terrain/features/villages/grammar/PureVillageCrossFoundation.gd"
)


func _parts() -> Array[Dictionary]:
	var parts := House.derive(2, 1, House.sample(31, 2, 1))
	parts.append_array(Foundation.derive(parts, 2, 1))
	return parts


func _envelope(parts: Array[Dictionary], catalog: EnvironmentCatalog, pose: Transform3D) -> AABB:
	var bounds := AABB()
	for index in parts.size():
		var box: AABB = (
			pose
			* parts[index].transform
			* catalog.descriptor(Compiler.asset_id(parts[index].module)).measured_aabb
		)
		bounds = box if index == 0 else bounds.merge(box)
	return bounds


func test_baked_vocabulary_has_collision_and_no_source_visual_paths() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var manifest: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(
			"res://tools/environment_bake/manifests/pure_village_native_grammar.json"
		)
	)
	for entry in manifest.assets:
		var descriptor := catalog.descriptor(StringName(entry.id))
		assert_not_null(descriptor, entry.id)
		if descriptor == null:
			continue
		assert_gt(descriptor.collision_piece_count, 0)
		assert_false(descriptor.visual_path.contains("assets/PureVillage"))
		assert_true(ResourceLoader.exists(descriptor.visual_path))


func test_compiles_complete_native_assembly_in_rotated_world_reservation() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var parts := _parts()
	var pose := Transform3D(Basis(Vector3.UP, PI * .5), Vector3(42, 9, -27))
	var envelope := _envelope(parts, catalog, pose)
	var result := Compiler.compile(parts, catalog, pose, &"house.test", envelope.grow(.01))
	assert_true(result.ok, result.reason)
	assert_true(result.payload.validate())
	assert_eq(result.payload.instance_count, parts.size())
	assert_eq(result.envelope, envelope)
	var seen: Dictionary = {}
	for id in result.payload.asset_ids():
		var batch: Dictionary = result.payload.batches[id]
		for index in batch.ids.size():
			assert_false(seen.has(batch.ids[index]), "Part identities remain unique")
			seen[batch.ids[index]] = true
			assert_true(batch.collision_enabled[index])
	var again := Compiler.compile(parts, catalog, pose, &"house.test", envelope.grow(.01))
	assert_eq(again.payload.batches, result.payload.batches)


func test_failure_never_emits_a_partial_house_or_clips_a_native_part() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var parts := _parts()
	var envelope := _envelope(parts, catalog, Transform3D.IDENTITY)
	var result := Compiler.compile(
		parts, catalog, Transform3D.IDENTITY, &"house.test", envelope.grow(-.5)
	)
	assert_false(result.ok)
	assert_true(String(result.reason).begins_with("outside_reservation"))
	assert_eq(result.payload.instance_count, 0)
	var last: Dictionary = parts.back()
	var bounds: AABB = (
		last.transform * catalog.descriptor(Compiler.asset_id(last.module)).measured_aabb
	)
	var air: Array[AABB] = [AABB(bounds.get_center() - Vector3.ONE * .1, Vector3.ONE * .2)]
	result = Compiler.compile(
		parts, catalog, Transform3D.IDENTITY, &"house.test", envelope.grow(.01), air
	)
	assert_false(result.ok)
	assert_true(String(result.reason).begins_with("public_clearance"))
	assert_eq(result.payload.instance_count, 0)
	parts.append({"module": "MissingFixtureModule", "transform": Transform3D.IDENTITY})
	result = Compiler.compile(
		parts, catalog, Transform3D.IDENTITY, &"house.test", envelope.grow(.01)
	)
	assert_false(result.ok)
	assert_true(String(result.reason).begins_with("missing_baked_module"))
	assert_eq(result.payload.instance_count, 0)


func test_baked_resource_dependency_graph_does_not_load_source_packs() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var visited: Dictionary = {}
	var pending: Array[String] = []
	var manifest: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(
			"res://tools/environment_bake/manifests/pure_village_native_grammar.json"
		)
	)
	for entry in manifest.assets:
		pending.append(catalog.descriptor(StringName(entry.id)).visual_path)
	while not pending.is_empty():
		var path: String = pending.pop_back()
		if visited.has(path):
			continue
		visited[path] = true
		assert_false(path.begins_with("res://assets/"), "Baked runtime dependency: %s" % path)
		for dependency in ResourceLoader.get_dependencies(path):
			var target: String = dependency.split("::")[-1]
			if target.begins_with("res://"):
				pending.append(target)
	assert_gt(
		visited.size(), manifest.assets.size(), "Traverse materials/textures as well as visuals"
	)
