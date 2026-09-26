extends SceneTree
func _init() -> void:
	var rows: Array[Dictionary] = []
	var field_script := preload("res://scripts/terrain/features/villages/fabric/WarrenTownField.gd")
	for seed_value in range(1, 129):
		var profile := WarrenVillageScaleProfile.for_id(&"grand")
		var field := field_script.sample(seed_value, profile)
		var bounds := BuildingDesigner._bounds(field.solid)
		var fill := float(field.solid.size()) / bounds.get_area()
		rows.append({"seed": seed_value, "fill": fill, "spread": field.spread, "density": field.density, "open": field.openness, "columns": field.solid.size()})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.fill < b.fill)
	for row: Dictionary in rows.slice(0, 10): print("FIELD ", row)
	quit()
