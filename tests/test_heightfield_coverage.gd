extends GutTest

# ------------------------------------------------------------
# Ground coverage: every surface cell must get a placed tile.
# ------------------------------------------------------------
# A "hole through to the void" is a cell whose variant has no module in the
# library: spawn_placement drops it and nothing is placed. Scan the real plan and
# assert every surface-tile variant resolves to a module.

const _AMPLITUDE: float = 56.0
const _MAX_STOREYS: int = 12
const _SEED: int = 4242
const _RADIUS: int = 30


func _has_module(library: TerrainModuleLibrary, variant_tag: String) -> bool:
	var tag: String = HeightfieldInstantiator._lookup_tag(variant_tag)
	return not library.get_by_tags(TagList.new([tag])).is_empty()


func test_every_possible_variant_has_a_module() -> void:
	# Seed-independent: enumerate every variant_tag cell_descriptor can emit (each
	# bare tag, cliff and level family) and assert the library has a module for it.
	# A missing one is a hole anywhere that configuration occurs.
	var library: TerrainModuleLibrary = TerrainModuleLibrary.new()
	library.init()
	var missing: Array = []
	if not _has_module(library, "ground"):
		missing.append("ground")
	for bare in HeightfieldVariant.TAG_ORDER:
		var cliff_tag: String = "cliff-interior" if bare == "center" else "cliff-" + bare
		var level_tag: String = "level-center" if bare == "center" else "level-" + bare
		if not _has_module(library, cliff_tag):
			missing.append(cliff_tag)
		if not _has_module(library, level_tag):
			missing.append(level_tag)
	for m in missing:
		gut.p("  MISSING MODULE: " + m)
	assert_eq(missing.size(), 0, "every variant the heightfield can emit has a module")


func test_every_surface_cell_variant_has_a_module() -> void:
	var library: TerrainModuleLibrary = TerrainModuleLibrary.new()
	library.init()
	var plan: HeightfieldPlan = HeightfieldPlan.new(_SEED, _AMPLITUDE, _MAX_STOREYS, "mean")
	var region: HeightfieldRegion = plan.compute_region(0, 0, _RADIUS)

	var missing: Dictionary = {}
	var checked: int = 0
	for dz in range(-_RADIUS, _RADIUS + 1):
		for dx in range(-_RADIUS, _RADIUS + 1):
			var rec: Dictionary = HeightfieldInstantiator.placement_for_cell(region, dx, dz)
			checked += 1
			if not _has_module(library, String(rec["variant_tag"])):
				var key: String = String(rec["variant_tag"])
				missing[key] = int(missing.get(key, 0)) + 1
	gut.p("checked %d cells; variants with no module: %d" % [checked, missing.size()])
	for k in missing:
		gut.p("  MISSING MODULE: variant '%s' (%d cells)" % [k, missing[k]])
	assert_eq(missing.size(), 0, "every surface-tile variant resolves to a module (no holes)")
