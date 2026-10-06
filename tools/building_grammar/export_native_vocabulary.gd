extends SceneTree
const Native = preload("res://scripts/terrain/features/villages/grammar/NativeHouseRecipe.gd")
const OUTPUT := "res://scripts/terrain/features/villages/grammar/NativeHouseVocabulary.gd"


func _init() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var configurations: Array[Dictionary] = []
	var templates: Array[Dictionary] = []
	var variants := {}
	var by_signature := {}
	for old: Dictionary in WarrenPlotReservations.LEGACY_ASSET_TEMPLATES:
		by_signature[signature(old)] = old.kind_id
	for dims: Vector2i in [Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 1)]:
		for sample_seed in 8:
			var id := StringName(
				"anchor.z_native.cross.%02dx%02d.%02d" % [dims.x, dims.y, sample_seed]
			)
			var recipe := Native.cross(catalog, id, dims.x, dims.y, sample_seed)
			assert(recipe != null)
			# The existing frontage contract supports no body behind the street-facing
			# arrival. Such a derivation needs a different site contract, not rounding.
			var fronts_street := false
			for cell in recipe.solid_cells:
				fronts_street = fronts_street or cell.z > 0
			if fronts_street:
				print("Unsupported frontage ", id)
				continue
			configurations.append(
				{"id": id, "x_bays": dims.x, "z_bays": dims.y, "seed": sample_seed}
			)
			var row := derive_template(recipe)
			var key := signature(row)
			if not by_signature.has(key):
				by_signature[key] = id
				templates.append(row)
			var group: StringName = by_signature[key]
			if not variants.has(group):
				variants[group] = []
			variants[group].append(id)
	# Longer unsupported roof runs recreate the rejected narrow-block skyline.
	# Keep them as derivable studies until they gain secondary roof features.
	for bays in [2, 3]:
		for sample_seed in 8:
			var id := StringName("anchor.z_native.street.%02d.%02d" % [bays, sample_seed])
			var recipe := Native.street(catalog, id, bays, sample_seed)
			assert(recipe != null)
			var fronts_street := false
			for cell in recipe.solid_cells:
				fronts_street = fronts_street or cell.z > 0
			if fronts_street:
				print("Unsupported frontage ", id)
				continue
			configurations.append({"id": id, "family": "street", "bays": bays, "seed": sample_seed})
			var row := derive_template(recipe)
			var key := signature(row)
			if not by_signature.has(key):
				by_signature[key] = id
				templates.append(row)
			var group: StringName = by_signature[key]
			if not variants.has(group):
				variants[group] = []
			variants[group].append(id)
	# This larger reservation currently reduces covered streets in comparison towns.
	# Keep the measured family available for explicit studies until room/route
	# composition preserves enclosure; normal exports retain the accepted vocabulary.
	if OS.get_cmdline_user_args().has("--include-rear-jetty-study"):
		# A second complete projecting room changes the rear envelope. Give it
		# measured profiles of its own, never substitute into a smaller reservation.
		for bays in [2, 3]:
			for sample_seed in 4:
				var id := StringName("anchor.z_native.street_jetties.%02d.%02d" % [bays, sample_seed])
				var recipe := Native.street(catalog, id, bays, sample_seed, true)
				assert(recipe != null)
				for cell in recipe.solid_cells:
					assert(cell.z <= 0)
				configurations.append({"id": id, "family": "street", "bays": bays, "seed": sample_seed, "rear_jetty": true})
				var row := derive_template(recipe)
				var key := signature(row)
				if not by_signature.has(key):
					by_signature[key] = id
					templates.append(row)
				var group: StringName = by_signature[key]
				if not variants.has(group):
					variants[group] = []
				variants[group].append(id)
	for extra in [0, 1]:
		var id := StringName("anchor.z_native.turret.%02d" % extra)
		var recipe := Native.turret(catalog, id, extra)
		assert(recipe != null)
		for cell in recipe.solid_cells:
			assert(cell.z <= 0, "Turret reservation must include the complete forward reach")
		configurations.append({"id": id, "family": "turret", "extra_upper_storeys": extra})
		var row := derive_template(recipe)
		row["corner_turret"] = true
		templates.append(row)
		variants[id] = [id]
	for spec: Array in [[1, "Window_1_2"], [2, ""], [2, "Window_1_2"], [2, "Window_5_2"]]:
		var suffix := "source" if String(spec[1]).is_empty() else String(spec[1]).to_lower()
		var id := StringName("anchor.z_native.arcade.%02d.%s" % [spec[0], suffix])
		var recipe := Native.arcade(catalog, id, spec[0], spec[1])
		assert(recipe != null)
		for cell in recipe.solid_cells:
			assert(cell.z <= 0, "Arcade reservation must keep the complete roof behind its address")
		configurations.append(
			{"id": id, "family": "arcade", "upper_storeys": spec[0], "upper_side_window": spec[1]}
		)
		var row := derive_template(recipe)
		var key := signature(row)
		if not by_signature.has(key):
			by_signature[key] = id
			templates.append(row)
		var group: StringName = by_signature[key]
		if not variants.has(group):
			variants[group] = []
		variants[group].append(id)

	var output := "extends RefCounted\n## Generated by tools/building_grammar/export_native_vocabulary.gd.\n"
	output += (
		"const CONFIGURATIONS: Array[Dictionary] = "
		+ var_to_str(configurations).trim_prefix("Array[Dictionary](").trim_suffix(")")
		+ "\n"
	)
	output += (
		"const TEMPLATES: Array[Dictionary] = "
		+ var_to_str(templates).trim_prefix("Array[Dictionary](").trim_suffix(")")
		+ "\n"
	)
	output += "const VARIANTS: Dictionary = " + var_to_str(variants) + "\n"
	FileAccess.open(OUTPUT, FileAccess.WRITE).store_string(output)
	print("Exported ", configurations.size(), " derivations, ", templates.size(), " new profiles")
	quit()


static func signature(row: Dictionary) -> String:
	var values := PackedStringArray()
	for field in [
		"width",
		"depth",
		"height_bands",
		"reach_forward",
		"reach_left",
		"reach_right",
		"bearing_forward",
		"bearing_left",
		"bearing_right"
	]:
		values.append(str(row[field]))
	return ":".join(values)


static func derive_template(recipe_value: FabricRecipe) -> Dictionary:
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
	for cells: Array[Vector3i] in [
		recipe_value.solid_cells, recipe_value.headroom_cells, recipe_value.walk_cells
	]:
		for local_cell: Vector3i in cells:
			var offset := local_cell - door
			reach = Vector3i(
				maxi(reach.x, -(offset.x * facing.x + offset.z * facing.z)),
				maxi(reach.y, offset.x * lateral.x + offset.z * lateral.z),
				maxi(reach.z, -(offset.x * lateral.x + offset.z * lateral.z))
			)
			rise = maxi(rise, offset.y)
	for local_cell: Vector3i in recipe_value.terrain_bearing_cells:
		var offset := local_cell - door
		bearing = Vector3i(
			maxi(bearing.x, -(offset.x * facing.x + offset.z * facing.z)),
			maxi(bearing.y, offset.x * lateral.x + offset.z * lateral.z),
			maxi(bearing.z, -(offset.x * lateral.x + offset.z * lateral.z))
		)
	# The measured visual clearance, expanded exactly as
	# WarrenVolumetricSolver._skywalk_visual_clearance_cells expands it, then
	# folded into the same reach: everything the plot must own.
	var cell_size := FabricRecipe.CELL_SIZE
	var half := cell_size * 0.5
	var bounds := recipe_value.local_clearance_bounds
	for y in range(floori(bounds.position.y / cell_size) - 1, ceili(bounds.end.y / cell_size) + 2):
		for z in range(
			floori((bounds.position.z - half) / cell_size) - 1,
			ceili((bounds.end.z + half) / cell_size) + 2
		):
			for x in range(
				floori((bounds.position.x - half) / cell_size) - 1,
				ceili((bounds.end.x + half) / cell_size) + 2
			):
				var cell := Vector3i(x, y, z)
				if not SettlementFabricPlan._aabb_overlaps_volume(
					bounds,
					AABB(
						Vector3(cell) * cell_size + Vector3(-half, 0.0, -half),
						Vector3.ONE * cell_size
					)
				):
					continue
				var offset := cell - door
				reach = Vector3i(
					maxi(reach.x, -(offset.x * facing.x + offset.z * facing.z)),
					maxi(reach.y, offset.x * lateral.x + offset.z * lateral.z),
					maxi(reach.z, -(offset.x * lateral.x + offset.z * lateral.z))
				)
	return {
		"kind_id": recipe_value.recipe_id,
		"width": ceili(float(reach.y + reach.z + 1) / 2.0) + 1,
		"depth": ceili(float(reach.x + 1) / 2.0),
		"height_bands": rise + 1,
		"reach_forward": reach.x,
		"reach_left": reach.y,
		"reach_right": reach.z,
		"bearing_forward": bearing.x,
		"bearing_left": bearing.y,
		"bearing_right": bearing.z
	}
