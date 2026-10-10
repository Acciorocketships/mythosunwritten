extends GutTest
const Site = preload("res://scripts/terrain/features/villages/grammar/NativeTurretSite.gd")
const Recipe = preload("res://scripts/terrain/features/villages/grammar/NativeHouseRecipe.gd")
const Compiler = preload("res://scripts/terrain/features/villages/grammar/NativeGrammarCompiler.gd")


func test_ground_door_stair_and_bound_materials_survive_site_and_recipe() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var arrival := Vector3(40, 3, -28)
	for extra in [0, 1]:
		for scale_value in [1.0, 2.0]:
			for facing in 4:
				var outward := Basis(Vector3.UP, facing * PI / 2) * Vector3.BACK
				var site := Site.place(catalog, extra, scale_value, arrival, outward)
				assert_true(site.ok, site.reason)
				if not site.ok:
					continue
				assert_almost_eq(site.door.origin.y, arrival.y + 1.5 * scale_value, .001)
				assert_almost_eq(site.door.basis.z.normalized(), outward, Vector3.ONE * .001)
				assert_almost_eq((site.pose * Vector3.ZERO).y, arrival.y, .001)
				assert_eq(site.entry_route[0], arrival)
				assert_eq(site.entry_route.size(), 3, "Keep the stone landing turn")
				assert_gt(site.bearing_bounds.size(), 10, "Grade the real foundation contacts")
				for contact: AABB in site.bearing_bounds:
					assert_eq(contact.position.y, arrival.y)
					assert_eq(contact.size.y, 0.0)
				var compiled := Compiler.compile(
					site.parts, catalog, site.pose, &"turret.site", site.envelope.grow(.001)
				)
				assert_true(compiled.ok, compiled.reason)
				assert_eq(compiled.payload.instance_count, site.parts.size())
		var recipe := Recipe.turret(catalog, &"turret.recipe", extra)
		assert_not_null(recipe)
		if recipe == null:
			continue
		assert_true(recipe.is_sealed())
		assert_true(recipe.sockets.is_empty(), "Upper terrace is not a public bridge endpoint")
		assert_false(
			recipe.solid_cells.has(Vector3i.BACK), "Clear ground approach below the corner spire"
		)
		var plan := preload("res://tests/fixtures/native_house_plan.gd").build(
			recipe, catalog, extra
		)
		assert_true(plan.is_sealed(), "A real public landing must fit, not just an isolated recipe")
		var source := Site.place(catalog, extra, 2.0, Vector3.ZERO, Vector3.BACK, true)
		var to_world := Transform3D(Basis.from_scale(VillageWorldScale.frame_scale()), Vector3.ZERO)
		for index in source.parts.size():
			var part: Dictionary = source.parts[index]
			var placement: Dictionary = recipe.placements[index]
			assert_eq(placement.asset_id, part.asset_id)
			var expected: Transform3D = source.pose * part.transform
			expected.origin.y += VillageWorldScale.GROUND_DATUM_GUARD
			assert_almost_eq(
				(to_world * placement.transform).origin, expected.origin, Vector3.ONE * .001
			)


func test_invalid_sites_publish_no_partial_house() -> void:
	var catalog := EnvironmentCatalog.load_default()
	for site: Dictionary in [
		Site.place(catalog, 2, 2.0, Vector3.ZERO, Vector3.BACK),
		Site.place(catalog, 0, 3.0, Vector3.ZERO, Vector3.BACK),
		Site.place(catalog, 0, 2.0, Vector3.ZERO, Vector3.UP),
		Site.place(catalog, 0, 2.0, Vector3(INF, 0, 0), Vector3.BACK),
		Site.place(EnvironmentCatalog.new(), 0, 2.0, Vector3.ZERO, Vector3.BACK),
	]:
		assert_false(site.ok)
		assert_false(site.has("parts"))
