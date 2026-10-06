extends GutTest
const LOGGIAS := preload("res://scripts/terrain/features/villages/kit/KitLoggias.gd")

func test_loggias_preserve_complete_lower_roofed_wings() -> void:
	var damage := []
	var loggias := 0
	for width in [2, 3]:
		for seed_value in 24:
			var mass := BuildingMass.new()
			mass.seed = seed_value
			var full := BuildingMass.rect_cells(Rect2i(0, 0, 6, 2))
			mass.add_storey(0, full, BuildingMass.MATERIAL_TIMBER)
			var lower := mass.add_storey(2, full.duplicate(), BuildingMass.MATERIAL_TIMBER)
			var wing := BuildingMass.rect_cells(Rect2i(0, 0, width, 2))
			lower.roofed = wing
			lower.crown_parts = [wing]
			mass.add_storey(4, BuildingMass.rect_cells(Rect2i(width, 0, 6-width, 2)), BuildingMass.MATERIAL_TIMBER)
			LOGGIAS.recess(mass, Callable(), Callable())
			var remaining := {}
			for cell: Vector2i in wing:
				if lower.cells.has(cell): remaining[cell] = true
			if remaining.is_empty(): damage.append([width, seed_value, "removed"])
			for rect: Rect2i in BuildingDesigner.decompose(remaining):
				if mini(rect.size.x, rect.size.y)<2: damage.append([width, seed_value, rect])
			if bool(lower.get("loggia", false)): loggias += 1
	assert_eq(damage, [], "Recesses must not leave a one-module roof strip: %s" % [damage])
	assert_gt(loggias, 0, "Keep balcony recesses in the rest of the building")

func test_broad_roofed_wing_can_still_receive_a_recess() -> void:
	var wing := BuildingMass.rect_cells(Rect2i(0, 0, 4, 4))
	var retained := wing.duplicate()
	retained.erase(Vector2i(0, 0))
	retained.erase(Vector2i(0, 1))
	retained.erase(Vector2i(1, 0))
	retained.erase(Vector2i(1, 1))
	assert_true(LOGGIAS._preserves_roofed_wings({"cells":wing, "crown_parts":[wing]}, retained),
		"An L crown with two complete two-module arms remains roofable")
