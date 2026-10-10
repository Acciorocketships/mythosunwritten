extends SceneTree


## Feasibility diagnostic: prefer the turret without changing production weights.
func _init() -> void:
	for seed_value in [7, 13, 43, 83, 211]:
		var plan := WarrenMazeSitePlanner.plan(
			seed_value, {}, WarrenVillageScaleProfile.for_id(&"grand"), &"carve"
		)
		assert(plan != null)
		# Do not privilege other families already held by the normal preview.
		plan.audit.erase("preselected_landmarks")
		var columns: Array[Vector2i] = []
		columns.assign(plan.massif.columns.keys())
		columns.sort_custom(Callable(WarrenPlotPlanner, "column_less"))
		var used := {}
		for template: Dictionary in WarrenPlotReservations.ASSET_TEMPLATES:
			used[template.kind_id] = 0 if String(template.kind_id).contains(".turret.") else 1000
		var mirror := WarrenPlotReservations._new_mirror_tally()
		var blocked := WarrenPlotPlanner.blocked_columns(plan)
		for column in columns:
			if plan.massif.columns[column].has("house_site"):
				blocked[column] = true
		var site := WarrenPlotReservations._best_asset_site(
			plan,
			WarrenPlotPlanner.street_bands(plan),
			columns,
			blocked,
			{},
			mirror,
			used,
			WarrenPlotReservations.door_access_for(plan)
		)
		print(
			"TURRET_FIT ",
			seed_value,
			" ",
			(
				"none"
				if site.is_empty()
				else WarrenPlotReservations.ASSET_TEMPLATES[site.template].kind_id
			),
			" ",
			mirror
		)
	quit()
