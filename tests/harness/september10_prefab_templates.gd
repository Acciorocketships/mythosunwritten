extends SceneTree
func _init() -> void:
	var program:=SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var seen:Dictionary={}
	var rows:Array=[]
	for recipe:FabricRecipe in program.recipes():
		if not recipe.has_tag(&"prefab_anchor"):continue
		var row:=_derived_asset_template(recipe)
		var key:=row.duplicate()
		key.erase("kind_id")
		var signature:=str(key)
		if seen.has(signature):continue
		seen[signature]=true
		rows.append(row)
	FileAccess.open("/tmp/september10-prefab-templates.txt",FileAccess.WRITE).store_string(var_to_str(rows))
	quit()

func _derived_asset_template(recipe_value: FabricRecipe) -> Dictionary:
	## TASK C5b RULING 3. The macro footprint must hold the prefab as the
	## LANDMARK BUILDER places it -- anchored by its own doorway -- not merely
	## somewhere inside the plot, so every extent is measured from the entrance
	## cell in the entrance's own frame, in fine cells.
	var entrance := recipe_value.entrances[0] as Dictionary
	var door := entrance.cell as Vector3i
	var facing := entrance.facing as Vector3i
	var lateral := Vector3i(facing.z, 0, -facing.x)
	var reach := Vector3i.ZERO
	var bearing := Vector3i.ZERO
	var rise := 0
	for cells: Array[Vector3i] in [recipe_value.solid_cells,
			recipe_value.headroom_cells, recipe_value.walk_cells]:
		for local_cell: Vector3i in cells:
			var offset := local_cell - door
			reach = Vector3i(
				maxi(reach.x, -(offset.x * facing.x + offset.z * facing.z)),
				maxi(reach.y, offset.x * lateral.x + offset.z * lateral.z),
				maxi(reach.z, -(offset.x * lateral.x + offset.z * lateral.z)))
			rise = maxi(rise, offset.y)
	for local_cell: Vector3i in recipe_value.terrain_bearing_cells:
		var offset := local_cell - door
		bearing = Vector3i(
			maxi(bearing.x, -(offset.x * facing.x + offset.z * facing.z)),
			maxi(bearing.y, offset.x * lateral.x + offset.z * lateral.z),
			maxi(bearing.z, -(offset.x * lateral.x + offset.z * lateral.z)))
	# The measured visual clearance, expanded exactly as
	# WarrenVolumetricSolver._skywalk_visual_clearance_cells expands it, then
	# folded into the same reach: everything the plot must own.
	var cell_size := FabricRecipe.CELL_SIZE
	var half := cell_size * 0.5
	var bounds := recipe_value.local_clearance_bounds
	for y in range(floori(bounds.position.y / cell_size) - 1,
			ceili(bounds.end.y / cell_size) + 2):
		for z in range(floori((bounds.position.z - half) / cell_size) - 1,
				ceili((bounds.end.z + half) / cell_size) + 2):
			for x in range(floori((bounds.position.x - half) / cell_size) - 1,
					ceili((bounds.end.x + half) / cell_size) + 2):
				var cell := Vector3i(x, y, z)
				if not SettlementFabricPlan._aabb_overlaps_volume(bounds,
						AABB(Vector3(cell) * cell_size
							+ Vector3(-half, 0.0, -half),
							Vector3.ONE * cell_size)):
					continue
				var offset := cell - door
				reach = Vector3i(
					maxi(reach.x,
						-(offset.x * facing.x + offset.z * facing.z)),
					maxi(reach.y, offset.x * lateral.x + offset.z * lateral.z),
					maxi(reach.z,
						-(offset.x * lateral.x + offset.z * lateral.z)))
	return {"kind_id": recipe_value.recipe_id,
		"width": ceili(float(reach.y + reach.z + 1) / 2.0) + 1,
		"depth": ceili(float(reach.x + 1) / 2.0),
		"height_bands": rise + 1,
		"reach_forward": reach.x, "reach_left": reach.y,
		"reach_right": reach.z, "bearing_forward": bearing.x,
		"bearing_left": bearing.y, "bearing_right": bearing.z}


