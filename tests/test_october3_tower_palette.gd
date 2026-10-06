extends GutTest
const PALETTE := preload("res://scripts/terrain/features/villages/kit/KitTowerPalette.gd")

func test_native_cap_inherits_adjoining_roof_family_without_changing_geometry() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var cache := EnvironmentRenderCache.new(catalog)
	for kit: BuildingKit in [SuntailBuildingKit.create(), preload("res://scripts/terrain/features/villages/kit/PureVillageBuildingKit.gd").roof_study()]:
		for colour: StringName in [&"red", &"blue"]:
			var mass := BuildingMass.new()
			mass.add_roof(Rect2i(0,0,4,3),0,6,colour)
			for prefix: String in ["pure_village.tower.roof", "pure_village.roof_turret.roof"]:
				var candidate := {"host":mass,"kit":kit,"host_plan":{"wings":{0:""}},"parts":[{"role":&"tower.roof","asset_id":StringName(prefix)}]}
				PALETTE.apply(candidate)
				var id: StringName = candidate.parts[0].asset_id
				var expected := prefix if String(kit.asset(StringName("roof.%s.eave"%colour))).begins_with("pure_village.") else prefix+".wood_"+String(colour)
				assert_eq(String(id),expected)
				PALETTE.apply(candidate)
				assert_eq(candidate.parts[0].asset_id,id,"Applying the same house palette twice is harmless")
				assert_eq(catalog.descriptor(id).measured_aabb,catalog.descriptor(StringName(prefix)).measured_aabb)
				var original := cache.visual(StringName(prefix))
				var variant := cache.visual(id)
				assert_eq(variant.collisions.size(),original.collisions.size())
				for index in original.pieces.size():
					var a: Mesh = original.pieces[index].mesh
					var b: Mesh = variant.pieces[index].mesh
					assert_eq(a.get_surface_count(),b.get_surface_count())
					for surface in a.get_surface_count():
						assert_eq(a.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX],b.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX])
						var mat := b.surface_get_material(surface) as StandardMaterial3D
						if id == StringName(prefix) or mat.resource_name != "RoofTiles": continue
						assert_eq(mat.albedo_color,Color(.58,.4,.26,1) if colour==&"red" else Color(.4,.34,.27,1))
						assert_not_null(mat.albedo_texture)
						assert_not_null(mat.normal_texture)
