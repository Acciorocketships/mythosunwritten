extends GutTest

func test_projecting_bay_inherits_its_storeys_finish() -> void:
	for kit: BuildingKit in [SuntailBuildingKit.create(),preload("res://scripts/terrain/features/villages/kit/PureVillageBuildingKit.gd").roof_study()]:
		var mass := BuildingMass.new()
		var storey := mass.add_storey(0,BuildingMass.rect_cells(Rect2i(0,0,2,2)),BuildingMass.MATERIAL_TIMBER)
		storey.tint = Color(.93,.87,.78)
		storey.openings[Vector3i(0,0,3)] = BuildingMass.OPENING_BAY
		var bays := 0
		for part: Dictionary in BuildingKitAssembler.new(kit).assemble(mass):
			if not String(part.role).begins_with("bay."): continue
			bays += 1
			assert_eq(part.color,storey.tint,"Outcroppings receive the same house finish as their surrounding walls")
		assert_eq(bays,1)

func test_pure_bay_uses_host_plaster_without_changing_native_geometry() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var cache := EnvironmentRenderCache.new(catalog)
	var host := cache.visual(&"pure_village.wall.plaster.plain")
	var plaster := host.pieces[0].mesh.surface_get_material(0) as StandardMaterial3D
	for colour: String in ["red","blue"]:
		var source_id := StringName("suntail.frame.frame_extension_"+colour)
		var source := cache.visual(source_id)
		for finish: StringName in [&"native",&"oak",&"walnut"]:
			var kit := preload("res://scripts/terrain/features/villages/kit/PureVillageBuildingKit.gd").roof_study()
			preload("res://scripts/terrain/features/villages/kit/TownFramePalette.gd").apply(kit,finish)
			var id := kit.asset(StringName("bay."+colour))
			var variant := cache.visual(id)
			assert_not_null(variant)
			assert_eq(catalog.descriptor(id).measured_aabb,catalog.descriptor(source_id).measured_aabb)
			assert_eq(variant.collisions.size(),source.collisions.size())
			for index in source.collisions.size():
				assert_eq(variant.collisions[index].local_transform,source.collisions[index].local_transform)
				assert_eq((variant.collisions[index].shape as ConcavePolygonShape3D).get_faces(),
					(source.collisions[index].shape as ConcavePolygonShape3D).get_faces())
			var seen := 0
			for index in source.pieces.size():
				var a := source.pieces[index].mesh
				var b := variant.pieces[index].mesh
				assert_eq(b.get_surface_count(),a.get_surface_count())
				for surface in a.get_surface_count():
					assert_eq(b.surface_get_arrays(surface),a.surface_get_arrays(surface),"Keep every native vertex, UV and normal")
					var old := a.surface_get_material(surface) as StandardMaterial3D
					var material := b.surface_get_material(surface) as StandardMaterial3D
					if old.resource_name == "Wall":
						seen += 1
						assert_eq(material.albedo_texture,plaster.albedo_texture)
						assert_eq(material.albedo_color,plaster.albedo_color)
						assert_eq(material.normal_texture,plaster.normal_texture)
					elif finish == &"native": assert_eq(material,old,"Other materials stay authored")
			assert_eq(seen,1)
