extends RefCounted
func run(review: Node) -> void:
	var plan: HeightfieldPlan = review._streamer._plan
	var water = plan._water_plan
	var rows := []
	for z in range(1500,1585,12):
		for x in range(648,745,12):
			var p := Vector2(x,z)
			var field: WaterFieldContext = review._streamer._fields.water(FieldTerrainStreamer.chunk_of(Vector3(x,0,z)))
			rows.append({"p":p,"natural":water.noise_h(p),"carve":water.carve_at(x,z),"raw":plan.raw_height(x/12,z/12),"final":TerrainTileField.surface_y(field._region,x,z),"water":field.level_at(p)})
	FileAccess.open(review._output_dir+"/ground-probe.json",FileAccess.WRITE).store_string(JSON.stringify(rows))
	# Measure actual retirement detachment separately from later destruction.
	var chunk: Vector2i = review._streamer._built.keys()[0]
	var node: Node = review._streamer._built[chunk]
	var count := node.find_children("*","",true,false).size()
	var started := Time.get_ticks_usec()
	review._streamer._retire_terrain(node)
	var elapsed := Time.get_ticks_usec()-started
	review._streamer._built.erase(chunk)
	print("RETIRE_DETACH nodes=",count," us=",elapsed)
	print("EVENING_GROUND_PROBE_DONE")
