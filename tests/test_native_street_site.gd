extends GutTest
const Site = preload("res://scripts/terrain/features/villages/grammar/NativeHouseSite.gd")
const Recipe = preload("res://scripts/terrain/features/villages/grammar/NativeHouseRecipe.gd")
const Compiler = preload("res://scripts/terrain/features/villages/grammar/NativeGrammarCompiler.gd")


func test_street_derivations_preserve_complete_supported_projection_and_entry() -> void:
	var catalog := EnvironmentCatalog.load_default()
	for bays in [2, 3, 4]:
		for seed_value in [7, 31]:
			for scale_value in [1.0, 2.0]:
				var site := Site.street(
					catalog, bays, seed_value, scale_value, Vector3(12, 6, -40), Vector3.LEFT
				)
				assert_true(site.ok, site.reason)
				if not site.ok:
					continue
				var entries := 0
				var supports := 0
				for part in site.parts:
					if part.has("entry_for"):
						entries += 1
					if String(part.module).begins_with("Support_"):
						supports += 1
				assert_eq(entries, 1)
				assert_gt(supports, 0, "Native projecting floor retains its authored brackets")
				var compiled := Compiler.compile(
					site.parts, catalog, site.pose, &"street", site.envelope.grow(.001)
				)
				assert_true(compiled.ok, compiled.reason)
				assert_eq(compiled.payload.instance_count, site.parts.size())
				for id in compiled.payload.asset_ids():
					for transform in compiled.payload.batches[id].transforms:
						assert_gt(transform.basis.determinant(), 0.0)
			var recipe := Recipe.street(catalog, &"street", bays, seed_value)
			assert_not_null(recipe)
			if recipe != null:
				assert_true(recipe.is_sealed())
				assert_true(recipe.sockets.is_empty())


func test_street_site_rejects_invalid_dimensions_scale_and_frame() -> void:
	var catalog := EnvironmentCatalog.load_default()
	assert_false(Site.street(catalog, 1, 7, 2.0, Vector3.ZERO, Vector3.BACK).ok)
	assert_false(Site.street(catalog, 2, 7, 3.0, Vector3.ZERO, Vector3.BACK).ok)
	assert_false(Site.street(catalog, 2, 7, 2.0, Vector3.ZERO, Vector3.UP).ok)


func test_double_projection_reserves_its_new_rear_reach_without_moving_the_entrance() -> void:
	var catalog := EnvironmentCatalog.load_default()
	for bays in [2, 3]:
		for yaw in 4:
			var outward := Basis(Vector3.UP, yaw * PI * .5) * Vector3.BACK
			var original := Site.street(catalog, bays, 7, 2.0, Vector3.ZERO, outward)
			var extended := Site.street(catalog, bays, 7, 2.0, Vector3.ZERO, outward, true)
			assert_true(extended.ok, extended.reason)
			if not extended.ok:
				continue
			assert_eq(extended.entry_route, original.entry_route)
			assert_eq(extended.pose, original.pose)
			assert_gt(
				extended.envelope.size.dot(outward.abs()), original.envelope.size.dot(outward.abs())
			)
			var old_bounds := Compiler.compile(
				extended.parts, catalog, extended.pose, &"street", original.envelope.grow(.001)
			)
			assert_false(old_bounds.ok, "The new room cannot use a single-projection reservation")
			var full := Compiler.compile(
				extended.parts, catalog, extended.pose, &"street", extended.envelope.grow(.001)
			)
			assert_true(full.ok, full.reason)
			assert_eq(full.payload.instance_count, extended.parts.size())
		var recipe := Recipe.street(catalog, &"double.street", bays, 7, true)
		assert_not_null(recipe)
		if recipe != null:
			assert_true(recipe.is_sealed())
