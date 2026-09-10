extends SceneTree

func _init() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://tools/environment_bake/manifests/fantasy_village_fabric.json"))
	var stock := {}
	for entry: Dictionary in source.assets: stock[StringName(entry.id)] = entry
	var unique := {}
	for pool: Array[StringName] in [SettlementFabricProgram.WOOD_CELL_FACADE_BLUE,
			SettlementFabricProgram.WOOD_CELL_FACADE_ORANGE,SettlementFabricProgram.WOOD_CELL_FACADE_AMBER]:
		for asset: StringName in pool: unique[asset] = true
	var assets: Array = []
	var ids := unique.keys()
	ids.sort()
	for asset: StringName in ids:
		for mask in range(1,4):
			var entry: Dictionary = stock[asset].duplicate(true)
			entry.id = "%s.retaining_miter%d" % [asset,mask]
			entry["facade_miter_ends"] = mask
			entry["facade_join_half_width"] = FabricRecipe.CELL_SIZE * 0.5
			entry["facade_join_front"] = SettlementFabricProgram.WOOD_CELL_FACADE_FRONT_DEPTH
			entry["facade_miter_cap_source"] = "res://assets/FantasyVillageFBX/FBX/Pillars and Floor/Pillars/SFV_Wall_Pillar_001.fbx"
			assets.append(entry)
			var open := entry.duplicate(true)
			open.id = entry.id + ".course_open"
			open["omit_coplanar_y"] = 3.0
			open["omit_coplanar_tolerance"] = 0.001
			assets.append(open)
	var manifest := {"pack":"fantasy_village_retained_facades","license":source.license,
		"default_scale":source.default_scale,"assets":assets,
		"generated_by":"res://tools/environment_bake/export_retained_facade_manifest.gd"}
	FileAccess.open("res://tools/environment_bake/manifests/fantasy_village_retained_facades.json",FileAccess.WRITE).store_string(JSON.stringify(manifest," ")+"\n")
	print("Retained facade variants: ",assets.size())
	quit()
