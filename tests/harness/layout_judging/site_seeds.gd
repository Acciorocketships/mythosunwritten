extends SceneTree
## Lists the settlement site, city seed and scale profile for super cells.
func _init() -> void:
	var water := TerrainWorldTuning.make_water(2697992464)
	var plan := SettlementPlan.new(2697992464, water)
	for sx in range(-1, 2):
		for sz in range(0, 3):
			var site := plan.site_for(Vector2i(sx, sz))
			if site.is_empty():
				print("SITE ", Vector2i(sx, sz), " none")
				continue
			var cell: Vector2i = site.cell
			var city := VillagePlan.warren_seed_for_cell(2697992464, cell)
			var profile := WarrenVillageScaleProfile.select(city)
			print("SITE ", Vector2i(sx, sz), " cell=", cell, " world=", Vector2(cell) * 24.0, " city=", city, " profile=", profile.scale_id)
	quit()
