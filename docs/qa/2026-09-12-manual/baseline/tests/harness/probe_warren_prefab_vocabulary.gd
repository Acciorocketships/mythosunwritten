extends SceneTree

## Reports the measured construction envelopes used by the warren prefab
## broad phase. This keeps source-pack scale decisions reviewable without
## instantiating meshes or guessing from one screenshot.


func _init() -> void:
	var program := SettlementFabricProgram.compile(
		EnvironmentCatalog.load_default())
	assert(program != null)
	var rows: Array[Dictionary] = []
	for recipe_value: FabricRecipe in program.recipes():
		if not recipe_value.has_tag(&"prefab_anchor"):
			continue
		var bounds := recipe_value.local_clearance_bounds
		rows.append({
			"recipe": String(recipe_value.recipe_id),
			"asset": String(recipe_value.asset_ids()[0]),
			"size_m": [bounds.size.x, bounds.size.y, bounds.size.z],
			"footprint_area_m2": bounds.size.x * bounds.size.z,
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.footprint_area_m2) < float(b.footprint_area_m2))
	print(JSON.stringify(rows, "  "))
	quit()
