extends SceneTree
## Exercises the production world record, road projection, graded terrain and
## grass compiler at reserved greens. No synthetic terrain or feature context.

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var seed_value := 2697992464
	var site := Vector2i(0,1)
	var output := "/tmp/town-world-ground.json"
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--seed": seed_value = int(args[i+1])
		if args[i] == "--site":
			var pair := args[i+1].split(",")
			site = Vector2i(int(pair[0]),int(pair[1]))
		if args[i] == "--output": output = args[i+1]
	var water := TerrainWorldTuning.make_water(seed_value)
	var heights := TerrainWorldTuning.make_heightfield(seed_value,water)
	var catalog := EnvironmentCatalog.load_default()
	var program := FeatureProgram.compile(catalog)
	var grass := GrassProgram.compile(load("res://terrain/grass/settings.tres"),catalog,EnvironmentRenderCache.new(catalog))
	var fields := WorldFieldBlockCache.new(heights,water,maxf(program.query_margin,grass.query_margin),
		maxf(program.shore_distance_limit,grass.shore_distance_limit),program.field_cache_cap)
	var world := WorldFeaturePlan.new(seed_value,water,fields,program,SettlementPlan.new(seed_value,water))
	print("GROUND_FRAME ",site)
	var frame := world.frame_for(site)
	assert(frame != null)
	var record := world.village_plan().record_for(frame)
	var town := record.urban_fabric
	assert(town.accepted)
	var source: WarrenMazeSourcePlan = town.volumetric_spatial.source_volume.mass_context[&"maze_source_plan"]
	var field := preload("res://scripts/terrain/features/villages/fabric/WarrenTownField.gd").sample(source.world_seed,source.scale_profile)
	var green_world: Vector3 = town.world_transform*Vector3(field.green_centre.x*3.0,0,field.green_centre.y*3.0)
	print("GROUND_TOWN ",{"seed":source.world_seed,"central_green":field.central_green,"green_world":green_world})
	var samples: Array[Dictionary] = []
	var tiles := {}
	var inverse := town.world_transform.affine_inverse()
	var reserved := {}
	var planting_spaces := TownGroundDressing._planting_spaces(source.massif) if args.has("--planting-spaces") else source.massif.open_spaces
	for space: Dictionary in planting_spaces:
		for column: Vector2i in space.cells: reserved[column] = true
	for column: Vector2i in reserved:
		var p := town.world_transform * Vector3(column.x*3.0,0,column.y*3.0)
		var point := Vector2(p.x,p.z)
		print("GROUND_CONTEXT ",point)
		var context := world.context_for(WorldFieldBlockCache.key_of(point))
		var local_field := FeatureGroundField.new(town.surfaces,town.clearances,8)
		var region := context.graded_region(fields.region_at(point))
		var tile_fields := GrassField._bake_tile_fields(grass,Vector2(GrassField.tile_of(point))*GrassField.TILE_WORLD,seed_value)
		var ecology := GrassField._sample_tile_fields(tile_fields,point-Vector2(GrassField.tile_of(point))*GrassField.TILE_WORLD)
		samples.append({"column":str(column),"point":str(point),
			"town_surface":local_field.surface_at(point),"world_surface":context.surface_at(point),
			"clearance":context.clearance_at(point,false),"ecology":ecology,
			"shore":fields.water_at(point).shore_distance_at(point),
			"gradient":str(GrassField._surface_gradient(region,point,{})),
			"qualified":not GrassField._qualified_surface(grass,point,region,fields.water_at(point),context,1.0).is_empty()})
		tiles[GrassField.tile_of(point)] = true
	var grass_in_greens := 0
	var grass_on_paths := 0
	var total_grass := 0
	var natural_grass := 0
	for tile: Vector2i in tiles:
		var block := GrassField.parent_chunk(tile)
		var context := world.context_for(block)
		var region := context.graded_region(fields.region(block))
		var payload := GrassField.compute(grass,seed_value,tile,region,fields.water(block),context)
		natural_grass += GrassField.compute(grass,seed_value,tile,region,fields.water(block)).instance_count
		total_grass += payload.instance_count
		for batch: Dictionary in payload.batches.values():
			var buffer: PackedFloat32Array = batch.buffer
			for i in int(batch.count):
				var offset := i*GrassPayload.FLOATS_PER_INSTANCE
				var p := Vector3(buffer[offset+3],buffer[offset+7],buffer[offset+11])
				var local := inverse*p
				var column := Vector2i(floori((local.x+.75)/3),floori((local.z+.75)/3))
				if reserved.has(column): grass_in_greens += 1
				if context.surface_at(Vector2(p.x,p.z)) != FeatureGroundField.NATURAL: grass_on_paths += 1
		print("GROUND_GRASS ",tile," ",payload.instance_count)
	var result := {"town_seed":source.world_seed,"central_green":field.central_green,"green_world":str(green_world),"seed":seed_value,"site":str(site),"centre":str(record.centre),
		"dressing":town.ground_dressing_audit,"samples":samples,
		"tiles":tiles.size(),"grass":total_grass,"natural_grass":natural_grass,"grass_in_greens":grass_in_greens,"grass_on_paths":grass_on_paths}
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("WORLD_GROUND ",JSON.stringify(result))
	quit(0 if grass_on_paths == 0 and grass_in_greens > 0 else 1)
