extends RefCounted

## Run through cliff_site_review's probe mailbox after its world has settled.
func run(review: Node) -> void:
	var sheets := review.find_children("WaterSheet", "MeshInstance3D", true, false)
	for sheet in sheets: sheet.visible = false
	RenderingServer.force_draw()
	review.get_viewport().get_texture().get_image().save_png(review._output_dir+"/without_water.png")
	for sheet in sheets: sheet.visible = true
	var script := load("res://scripts/terrain/grass/GrassField.gd") as GDScript
	script.source_code = FileAccess.get_file_as_string(script.resource_path)
	assert(script.reload(true) == OK)
	var streamer: FieldTerrainStreamer = review._streamer
	var settings := load("res://terrain/grass/settings.tres") as GrassSettings
	var program := GrassProgram.compile(settings, streamer._environment_catalog,
		streamer._environment_cache)
	var chunk := FieldTerrainStreamer.chunk_of(review._at)
	var inputs: Dictionary = review._inputs[chunk]
	var mesher := TerrainChunkMesher.new()
	mesher.set_seed(review._seed)
	mesher.prepare_resources()
	mesher.water_blocks = streamer._fields
	var box := [inputs, mesher, program, chunk, review._seed, review._output_dir]
	var task := WorkerThreadPool.add_task(_probe.bind(box))
	while not WorkerThreadPool.is_task_completed(task):
		await review.get_tree().create_timer(0.2).timeout
	WorkerThreadPool.wait_for_task_completion(task)
	print("[october8_probe] complete")

func _probe(box: Array) -> void:
	var inputs: Dictionary = box[0]
	var mesher: TerrainChunkMesher = box[1]
	var program: GrassProgram = box[2]
	var chunk: Vector2i = box[3]
	var seed_value: int = box[4]
	var directory: String = box[5]
	var payload := mesher.compute_chunk(chunk, inputs.region, inputs.water, inputs.features)
	var supports: Array = payload.cliff_terraces.grass_supports
	var context := GrassSamplingContext.detached(inputs.region, inputs.water, inputs.features, supports)
	var report := {"chunk": str(chunk), "grass": [], "buried_water": []}
	for tile: Vector2i in [chunk * 8 + Vector2i(3, 5), chunk * 8 + Vector2i(4, 5), chunk * 8 + Vector2i(3, 6)]:
		var began := Time.get_ticks_usec()
		var profile := {"enabled":true}
		var grass := GrassField.compute(program, seed_value, tile, context.region,
			context.water, context.features, context.supports, profile)
		report.grass.append({"tile": str(tile), "ms": (Time.get_ticks_usec()-began)/1000.0,
			"profile":profile,"instances": grass.instance_count, "hash": hash(grass.batches)})
		print("[october8_probe] grass ", report.grass[-1])
	var shore_begin := Time.get_ticks_usec()
	for i in 1000:
		context.water.shore_distance_at(Vector2(chunk)*192.0+Vector2(i%32,i/32)*6.0)
	print("[october8_probe] shore_1000_ms=", (Time.get_ticks_usec()-shore_begin)/1000.0)
	var support_index := GrassSupportSurfaces.spatial_index(supports)
	for z in range(chunk.y * 192, (chunk.y + 1) * 192):
		for x in range(chunk.x * 192, (chunk.x + 1) * 192):
			var p := Vector2(x,z)
			if not inputs.water.is_wet(p): continue
			var level: float = inputs.water.level_at(p)
			var ground: float = TerrainTileField.surface_y(inputs.region,x,z)
			var support := GrassSupportSurfaces.at_index(support_index,p)
			var shown: float = support.get("y",ground)
			if shown > level + 0.1:
				report.buried_water.append({"x":x,"z":z,"ground":ground,"sheet":shown,"water":level})
	FileAccess.open(directory+"/probe.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("[october8_probe] buried_water=",report.buried_water.size())
	box.clear()
