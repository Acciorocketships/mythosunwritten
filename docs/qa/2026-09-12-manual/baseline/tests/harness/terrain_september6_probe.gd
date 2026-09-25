extends SceneTree
func _init() -> void:
	var water := TerrainWorldTuning.make_water(2697992464)
	var plan := TerrainWorldTuning.make_heightfield(2697992464, water)
	for centre: Vector2i in [Vector2i(24,-32), Vector2i(32,-62), Vector2i(39,-115)]:
		var region := plan.compute_region(centre.x, centre.y, 5)
		for z in range(centre.y-1, centre.y+2):
			for x in range(centre.x-1, centre.x+2):
				print("CELL ", Vector2i(x,z), " height=",region.surface_height(x,z)," flat=",TerrainSurfaceField.is_flat_cell(region,x,z)," corners=",CliffDressing.corner_flags(region,x,z)," clip=",TerrainChunkMesher._cell_clip_info(region,{},x,z))
	quit()
