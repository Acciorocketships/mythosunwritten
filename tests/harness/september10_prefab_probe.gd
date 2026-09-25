extends SceneTree
func _init() -> void:
	var catalog:=EnvironmentCatalog.load_default()
	var program:=SettlementFabricProgram.compile(catalog)
	var frozen:=preload("res://tests/fixtures/frozen_maze_source.gd")
	var spatial:=frozen.spatial(frozen.read("res://tests/fixtures/september10-stone-source.txt"),program)
	var fabric:=spatial.compiled_fabric_cache()
	var skin:=SettlementFabricAssembler.maze_ground_skin_transaction(fabric)
	for unit:FabricUnit in fabric.units:
		var recipe:=fabric.recipe(unit.recipe_id)
		if not recipe.has_tag(&"prefab_anchor"):continue
		print("PREFAB ",unit.stable_id," ",unit.recipe_id," origin ",unit.lattice_origin," yaw ",unit.yaw_quarters)
		print("BEARING ",recipe.terrain_bearing_cells)
		print("FLOORS ",fabric.floor_surface_bounds())
		print("PLACEMENTS ",recipe.placements)
		for z in range(-5,5):
			var line:=""
			for x in range(-5,5):
				var c:=FabricRecipe.transform_cell(Vector3i(x,-1,z),unit.lattice_origin,unit.yaw_quarters)
				line += "R" if skin.retained.has(c) else "s" if skin.solids.has(c) else "."
			print("BELOW ",z," ",line)
		for key in ["retained","garden","paved","walked","cap_owners","solids","footprints"]:
			var near:Dictionary={}
			for c in skin[key]:
				if c is Vector3i and Vector2(c.x-unit.lattice_origin.x,c.z-unit.lattice_origin.z).length()<6 and abs(c.y-unit.lattice_origin.y)<2:near[c]=skin[key][c]
			print(key," ",near)
	FileAccess.open("/tmp/september10-prefab-payload.txt",FileAccess.WRITE).store_string(var_to_str(SettlementFabricAssembler.payload(fabric).batches))
	quit()
