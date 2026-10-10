extends GutTest
## October 8 owner review (31/large, docs/qa/2026-10-07-town-odds/taste/final/
## after/31_large_overview.png): a roof "way too tall and too short
## lengthwise" whose gable side "looks like an apartment building". It was
## the enclosed bridge-house `kit.skywalk.2.6.-3.0.1`: one module wide and
## eight modules long, its transverse (gatehouse) roof spanned all eight, so
## the roof stood 12 m over a 2 m ridge and its windowed gable infill rose four
## storeys above the bridge.
##
## Guardrail (a pure geometric invariant on every built pitched roof): the
## gable triangle exposes at most two storeys, and the roof is at most three
## times as tall as its ridge is long. Independent oracle here; the designer
## owns the same limits in BuildingDesigner.roof_proportion_ok.

const MAX_GABLE_STOREYS := 2
const MAX_SLENDERNESS := 3.0


func _violations(masses: Array, kits: Dictionary, kit: BuildingKit) -> Array[String]:
	var out: Array[String] = []
	for mass: BuildingMass in masses:
		var own := StringName(String(mass.stable_id).trim_prefix("kit."))
		var roof_kit: BuildingKit = kits.get(own, kit)
		for roof: Dictionary in mass.roofs:
			var axis := int(roof.axis)
			var rect: Rect2i = roof.rect
			var height := float(roof_kit.roof_profile(rect.size[1 - axis]).height)
			var ridge := float(rect.size[axis]) * roof_kit.module_width
			if height > MAX_GABLE_STOREYS * roof_kit.storey_height + 0.001 \
					or height > MAX_SLENDERNESS * ridge + 0.001:
				out.append("%s %s axis %d: %.2f m tall over a %.2f m ridge" % [
					mass.stable_id, rect, axis, height, ridge])
	return out


func test_a_long_narrow_bridge_house_keeps_a_proportioned_roof() -> void:
	var kit := SuntailBuildingKit.create()
	for gap in [2, 3, 4, 5, 6, 7, 8]:
		for step in [Vector3i.RIGHT, Vector3i.BACK]:
			var span := {"cell": Vector3i(1, 6, -3), "step": step, "gap": gap,
				"width": 1, "cross": Vector3i(step.z, 0, step.x), "enclosed": true}
			var mass := KitVillageBuildings._skywalk_mass(span, 43)
			assert_false(mass.roofs.is_empty(), "gap %d keeps a roof" % gap)
			assert_eq(_violations([mass], {}, kit), [] as Array[String], "gap %d" % gap)
			# One roof covers the whole bridge (never a row of gables).
			assert_eq(mass.roofs.size(), 1, "one roof (gap %d)" % gap)
			var covered := {}
			for roof: Dictionary in mass.roofs:
				for cell: Vector2i in BuildingMass.rect_cells(roof.rect):
					covered[cell] = true
			assert_eq(covered.size(), gap, "every bay roofed (gap %d)" % gap)


func test_a_long_narrow_bridge_house_takes_one_long_gable_along_its_span() -> void:
	# October 8 owner ruling: a one-module bridge too long for its transverse
	# gatehouse roof takes ONE long gable whose ridge runs along the span (not
	# a sawtooth row of transverse gables), dressed with ridge details.
	for gap in [5, 6, 7, 8]:
		for step in [Vector3i.RIGHT, Vector3i.BACK]:
			var span := {"cell": Vector3i(1, 6, -3), "step": step, "gap": gap,
				"width": 1, "cross": Vector3i(step.z, 0, step.x), "enclosed": true}
			var mass := KitVillageBuildings._skywalk_mass(span, 43)
			assert_eq(mass.roofs.size(), 1, "one gable (gap %d)" % gap)
			if mass.roofs.size() != 1: continue
			var roof: Dictionary = mass.roofs[0]
			var along := 0 if step.x != 0 else 1
			assert_eq(int(roof.axis), along, "ridge along the span (gap %d)" % gap)
			assert_eq((roof.rect as Rect2i).size[along], gap, "ridge spans the bridge (gap %d)" % gap)
			assert_true(bool(roof.get("chimney", false)), "a chimney on the ridge (gap %d)" % gap)
			assert_true(bool(roof.get("ridge_peaks", false)), "ridge finials (gap %d)" % gap)


func test_short_bridge_houses_keep_their_gatehouse_roof() -> void:
	# The reviewed gatehouse (owner's "tiny roof" ruling) is unchanged where it
	# is in proportion: one transverse roof over the whole span.
	for gap in [2, 3, 4]:
		var span := {"cell": Vector3i(1, 6, -3), "step": Vector3i.RIGHT, "gap": gap,
			"width": 1, "cross": Vector3i(0, 0, 1), "enclosed": true}
		var mass := KitVillageBuildings._skywalk_mass(span, 43)
		assert_eq(mass.roofs.size(), 1, "gap %d" % gap)
		assert_eq(int(mass.roofs[0].axis), 1, "ridge across the span (gap %d)" % gap)


func test_built_towns_have_no_out_of_proportion_roof() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var kit := SuntailBuildingKit.create()
	# 31/large with clearings is the owner's render; the rest are corpus towns
	# carrying one-wide bridge-houses and deep crowns.
	for town: Array in [[31, &"large", {&"clearing_count": 2.5}], [31, &"large", {}],
			[53, &"grand", {}], [13, &"standard", {}], [7, &"compact", {}]]:
		var program := SettlementFabricProgram.compile(catalog)
		if not (town[2] as Dictionary).is_empty():
			program.town_odds = program.town_odds.with_overrides(town[2])
		var spatial := WarrenVolumetricSolver.generate(int(town[0]), {}, program,
			WarrenVillageScaleProfile.for_id(town[1]))
		assert_not_null(spatial, "%s %s" % [town, WarrenVolumetricSolver.last_failure])
		if spatial == null: continue
		var built := KitVillageBuildings.build(spatial, spatial.compiled_fabric_cache(), kit)
		assert_eq(_violations(built.masses, built.house_kits, kit), [] as Array[String],
			"%d/%s %s" % [town[0], town[1], town[2]])
		# The owner's bridge (step +z): one long gable along its span, not a row.
		if not (town[2] as Dictionary).is_empty():
			var found := false
			for mass: BuildingMass in built.masses:
				if mass.stable_id == &"kit.skywalk.2.6.-3.0.1":
					found = true
					assert_eq(mass.roofs.size(), 1, "the 31/large bridge has one roof")
					if mass.roofs.size() == 1:
						assert_eq(int(mass.roofs[0].axis), 1, "its ridge runs along the span")
			assert_true(found, "the owner's bridge is built")
