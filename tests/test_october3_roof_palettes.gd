extends GutTest

const PURE := preload("res://scripts/terrain/features/villages/kit/PureVillageBuildingKit.gd")
const PALETTE := preload("res://scripts/terrain/features/villages/kit/TownRoofPalette.gd")
const TOWER := preload("res://scripts/terrain/features/villages/kit/KitTowerPalette.gd")


func test_seeded_families_are_stable_and_varied() -> void:
	var seen := {}
	for seed_value in 100:
		var family := PALETTE.choose(seed_value, &"compound.house")
		assert_eq(family, PALETTE.choose(seed_value, &"compound.house"))
		seen[family] = true
	assert_eq(seen.size(), PALETTE.FAMILIES.size())


func test_complete_native_roof_and_corner_cap_share_family_and_geometry() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var cache := EnvironmentRenderCache.new(catalog)
	var worker: Dictionary = (
		FileAccess
		. open("res://terrain/environment/geometry/pure_village_roofs.bin", FileAccess.READ)
		. get_var()
	)
	var original := PURE.roof_study()
	for family: StringName in PALETTE.FAMILIES:
		var kit := PURE.roof_study()
		PALETTE.apply(kit, family)
		for role: StringName in original.roles:
			for index in original.roles[role].size():
				var base: StringName = original.roles[role][index]
				var variant: StringName = kit.roles[role][index]
				if not String(base).begins_with("pure_village.roof."):
					assert_eq(variant, base)
					continue
				assert_eq(
					variant, base if family == &"blue" else StringName("%s.%s" % [base, family])
				)
				assert_true(worker.has(variant), "Worker clipping geometry exists for %s" % variant)
				assert_eq(
					catalog.descriptor(variant).measured_aabb,
					catalog.descriptor(base).measured_aabb
				)
				if original.asset_anchors.has(base):
					assert_eq(kit.asset_anchors[variant], original.asset_anchors[base])
				if original.roof_cap_x_bounds.has(base):
					assert_eq(kit.roof_cap_x_bounds[variant], original.roof_cap_x_bounds[base])
				var a := cache.visual(base)
				var b := cache.visual(variant)
				assert_eq(a.collisions.size(), b.collisions.size())
				for piece in a.pieces.size():
					for surface in a.pieces[piece].mesh.get_surface_count():
						var material := (
							b.pieces[piece].mesh.surface_get_material(surface) as StandardMaterial3D
						)
						if (
							family != &"blue"
							and material.resource_name in ["RoofTiles", "RoofTopTiles"]
						):
							assert_ne(
								material.albedo_color,
								Color.WHITE,
								"Every roof surface receives the family, including ridge tiles"
							)
						assert_eq(
							a.pieces[piece].mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX],
							b.pieces[piece].mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
						)
		var mass := BuildingMass.new()
		mass.add_roof(Rect2i(0, 0, 4, 3), 0, 6, &"red")
		for prefix: String in ["pure_village.tower.roof", "pure_village.roof_turret.roof"]:
			var candidate := {
				"host": mass,
				"kit": kit,
				"host_plan": {"wings": {0: ""}},
				"parts": [{"role": &"tower.roof", "asset_id": StringName(prefix)}]
			}
			TOWER.apply(candidate)
			var expected := StringName(prefix if family == &"blue" else "%s.%s" % [prefix, family])
			assert_eq(candidate.parts[0].asset_id, expected)
			TOWER.apply(candidate)
			assert_eq(candidate.parts[0].asset_id, expected)
			assert_eq(
				catalog.descriptor(expected).measured_aabb,
				catalog.descriptor(StringName(prefix)).measured_aabb
			)
