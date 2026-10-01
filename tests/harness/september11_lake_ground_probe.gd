extends SceneTree
func _init() -> void:
	var water:=TerrainWorldTuning.make_water(2697992464)
	var trace:=water.river_for(Vector2i(-3,-1))
	var pond:=trace.pond
	var center:=pond.center+pond.island_offset
	print("LAKE_GROUND center=",center," source=",water.noise_h(center)," surface=",pond.surface_y()," radius=",pond.island_radius," direction=",pond.island_offset)
	var plan:=TerrainWorldTuning.make_heightfield(2697992464,water)
	var cell:=Vector2i((center/24).round())
	print("LAKE_GROUND coarse=",cell," raw=",plan.raw_height(cell.x,cell.y)," carve=",water.carve_at(cell.x*24.0,cell.y*24.0))
	var region:=plan.compute_region(cell.x,cell.y,26)
	print("LAKE_GROUND actual=",TerrainTileField.surface_y(region,center.x,center.y))
	quit()
