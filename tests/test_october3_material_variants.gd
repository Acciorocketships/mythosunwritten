extends GutTest


func test_named_wood_finish_preserves_other_surfaces_and_source_resources() -> void:
	var source := EnvironmentVisual.new()
	var piece := EnvironmentVisualPiece.new()
	var mesh := ArrayMesh.new()
	for name in ["Wood_1", "Plaster", "RoofTiles", "Glass_Out"]:
		var primitive := BoxMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, primitive.get_mesh_arrays())
		var material := StandardMaterial3D.new()
		material.resource_name = name
		material.albedo_color = Color(.8, .7, .6)
		material.roughness = .7
		mesh.surface_set_material(mesh.get_surface_count() - 1, material)
	piece.mesh = mesh
	source.pieces.append(piece)
	var collision := EnvironmentCollisionPiece.new()
	collision.shape = BoxShape3D.new()
	source.collisions.append(collision)
	var tint := Color(.5, .4, .3)
	var result := EnvironmentRenderCache._tinted_visual(source, {"Wood_1": tint})
	assert_ne(result, source)
	assert_same(result.collisions[0], source.collisions[0])
	for surface in mesh.get_surface_count():
		var original := mesh.surface_get_material(surface) as StandardMaterial3D
		var material := result.pieces[0].mesh.surface_get_material(surface) as StandardMaterial3D
		assert_eq(original.albedo_color, Color(.8, .7, .6), "Source resource remains unchanged")
		assert_eq(
			material.albedo_color,
			original.albedo_color * tint if surface == 0 else original.albedo_color
		)
		assert_eq(material.roughness, original.roughness)
		assert_eq(
			result.pieces[0].mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX],
			mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		)


func test_frame_descriptors_reuse_native_visuals_and_collision_metadata() -> void:
	var palette := preload("res://scripts/terrain/features/villages/kit/TownFramePalette.gd")
	var catalog := EnvironmentCatalog.load_default()
	for id: StringName in palette.asset_ids():
		assert_true(catalog.has(id), String(id))
		if not catalog.has(id):
			continue
		var variant := catalog.descriptor(id)
		var source := catalog.descriptor(StringName(String(id).get_slice(".finish_", 0)))
		assert_eq(variant.visual_path, source.visual_path)
		assert_eq(variant.measured_aabb, source.measured_aabb)
		assert_eq(variant.collision_piece_count, source.collision_piece_count)
		assert_false(variant.material_tints.is_empty())


func test_mixed_wood_finishes_share_canonical_worker_geometry_even_after_first_load() -> void:
	var palette := preload("res://scripts/terrain/features/villages/kit/TownFramePalette.gd")
	var union := preload("res://scripts/terrain/features/villages/kit/KitRoofMeshUnion.gd")
	var data := {}
	var loaded := {}
	for finish: StringName in [&"native", &"walnut", &"oak"]:
		var kit := (
			preload("res://scripts/terrain/features/villages/kit/PureVillageBuildingKit.gd")
			. roof_study()
		)
		preload("res://scripts/terrain/features/villages/kit/TownRoofPalette.gd").apply(
			kit, &"sage"
		)
		palette.apply(kit, finish)
		union._load_geometry(kit, data, loaded)
		var id := kit.asset(&"roof.blue.eave")
		assert_true(data.has(id))
		assert_eq(data[id], data[&"pure_village.roof.eave.sage"])


func test_material_suffixes_do_not_bypass_measured_window_or_dormer_clearance() -> void:
	var contacts := preload("res://scripts/terrain/features/villages/kit/KitFacadeRoofContacts.gd")
	var window := &"pure_village.wall.plaster.window_arch"
	var context := {"openings": {window: AABB(Vector3(0, 1, 0), Vector3(1, 2, .1))}}
	for id: StringName in [
		window,
		&"pure_village.wall.plaster.window_arch.finish_walnut",
		&"pure_village.wall.plaster.window_arch.finish_oak"
	]:
		assert_eq(contacts.opening_asset(id), window)
		assert_false(contacts._clears_backing(id, Transform3D.IDENTITY, 1.5, context))
		assert_true(contacts._clears_backing(id, Transform3D.IDENTITY, .5, context))
	for suffix: String in ["", ".sage", ".wood_red", ".wood_blue"]:
		for finish: String in ["", ".finish_oak", ".finish_walnut"]:
			assert_eq(
				contacts.opening_asset(StringName("pure_village.roof.dormer" + suffix + finish)),
				&"pure_village.roof.dormer"
			)
	assert_eq(
		contacts.opening_asset(&"suntail.frame.frame_wall_1_w.finish_oak"),
		&"suntail.frame.frame_wall_1_w"
	)
