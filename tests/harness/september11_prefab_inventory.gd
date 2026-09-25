extends SceneTree

func _init() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var reference := preload("res://tests/test_warren_maze_plots.gd").new()
	var groups: Dictionary = {}
	var fields: Array[String] = ["width","depth","height_bands","reach_forward",
		"reach_left","reach_right","bearing_forward","bearing_left","bearing_right"]
	for recipe: FabricRecipe in program.recipes():
		if not recipe.has_tag(&"prefab_anchor"): continue
		var row: Dictionary = reference._derived_asset_template(recipe)
		var parts := PackedStringArray()
		for field: String in fields: parts.append(str(row[field]))
		var key := ":".join(parts)
		if not groups.has(key): groups[key] = {"profile":row,"recipes":[]}
		(groups[key].recipes as Array).append({"id":recipe.recipe_id,
			"assets":recipe.asset_ids(),"bounds":str(recipe.local_clearance_bounds),
			"entrances":recipe.entrances})
	FileAccess.open("res://docs/qa/2026-09-11-manual/09-prefabs/inventory.json",
		FileAccess.WRITE).store_string(JSON.stringify(groups,"  "))
	print("PREFAB_INVENTORY groups=",groups.size())
	reference.free()
	quit()
