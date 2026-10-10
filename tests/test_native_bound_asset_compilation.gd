extends GutTest
const House = preload("res://scripts/terrain/features/villages/grammar/PureVillageTurretHouse.gd")
const Compiler = preload("res://scripts/terrain/features/villages/grammar/NativeGrammarCompiler.gd")


func test_authored_material_and_reflection_ids_survive_all_site_rotations() -> void:
	var catalog := EnvironmentCatalog.load_default()
	for extra in [0, 1]:
		var parts := House.derive(extra)
		for scale_value in [1.0, 2.0]:
			for turn in 4:
				var pose := Transform3D(
					Basis(Vector3.UP, turn * PI / 2).scaled(Vector3.ONE * scale_value),
					Vector3(12, 3, -4)
				)
				var result := Compiler.compile(
					parts,
					catalog,
					pose,
					&"fixture.turret",
					AABB(Vector3(-100, -100, -100), Vector3.ONE * 200)
				)
				assert_true(result.ok, result.reason)
				assert_eq(result.payload.instance_count, parts.size())
				var checked_bindings := 0
				for index in parts.size():
					var part: Dictionary = parts[index]
					assert_true(result.payload.batches.has(part.asset_id))
					var batch: Dictionary = result.payload.batches[part.asset_id]
					var at: int = batch.ids.find(StringName("fixture.turret/native.%04d" % index))
					assert_gte(at, 0)
					assert_eq(batch.transforms[at], pose * part.transform)
					if String(part.asset_id).contains(".binding."):
						checked_bindings += 1
				assert_gte(checked_bindings, 12)


func test_missing_authored_variant_cannot_silently_fall_back_to_stock() -> void:
	var parts := House.derive()
	parts[-1].asset_id = &"pure_village.native.missing.binding"
	var result := Compiler.compile(
		parts,
		EnvironmentCatalog.load_default(),
		Transform3D.IDENTITY,
		&"fixture",
		AABB(Vector3.ONE * -100, Vector3.ONE * 200)
	)
	assert_false(result.ok)
	assert_eq(result.reason, "missing_baked_module:pure_village.native.missing.binding")
	assert_eq(result.payload.instance_count, 0, "No partially published building")


func test_double_reflection_keeps_material_binding_identity() -> void:
	var transform := Transform3D(Basis.from_scale(Vector3(-1, 1, 1)), Vector3.ZERO)
	var result := Compiler.placement("Wall", transform, &"native.wall.binding.example.mirror_x")
	assert_eq(result.asset_id, &"native.wall.binding.example")
	assert_eq(result.transform, Transform3D.IDENTITY)
