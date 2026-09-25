extends SceneTree
func _init() -> void:
	var program:=FeatureProgram.compile(EnvironmentCatalog.load_default())
	var water:=TerrainWorldTuning.make_water(2697992464)
	var heightfield:=TerrainWorldTuning.make_heightfield(2697992464,water)
	var fields:=WorldFieldBlockCache.new(heightfield,water,program.query_margin,
		program.shore_distance_limit,program.field_cache_cap)
	var world:=WorldFeaturePlan.new(2697992464,water,fields,program,SettlementPlan.new(2697992464,water))
	var frame := world.frame_for(Vector2i(0,0))
	var plan := world.village_plan()
	var terrain := VillageTerrainView.from_fields(fields)
	var seed_value := VillagePlan.warren_seed_for_cell(2697992464, frame.cell)
	var vp := VillageProgram.compile({}, EnvironmentCatalog.load_default())
	var directory := "res://docs/qa/2026-09-13-manual/20-civic/"
	for variant: String in ["well", "campfire"]:
		for original: bool in [true, false]:
			var urban: VillageUrbanFabricPlan
			var civic_seed := seed_value if variant == "well" else 1
			if original:
				urban = preload("res://docs/qa/2026-09-13-manual/20-civic/baseline_hamlet.gd").solve(terrain, civic_seed,
					frame.settlement_id, frame.centre, plan._street_axis(frame), &"orange", vp, frame.path_ground, 2697992464)
			else:
				urban = VillageHamletConstruction.solve(terrain, civic_seed, frame.settlement_id,
					frame.centre, plan._street_axis(frame), &"orange", vp, frame.path_ground, 2697992464)
			assert(urban.accepted)
			var payload := EnvironmentInstancePayload.new()
			var surfaces: Array[FeatureGroundShape] = []
			var clearances: Array[FeatureGroundShape] = []
			VillagePlan._materialize_urban_fabric(urban, payload, surfaces, clearances, VillageOccupancy.new())
			var shape_values: Array = []
			for shape: FeatureGroundShape in surfaces:
				shape_values.append([shape.kind,shape._a,shape._b,shape._radius,shape._half_extents,shape._angle,shape.surface_id,shape.priority,shape.stable_id])
			var clearance_values: Array = []
			for shape: FeatureGroundShape in clearances:
				clearance_values.append([shape.kind,shape._a,shape._b,shape._radius,shape._half_extents,shape._angle,shape.surface_id,shape.priority,shape.stable_id])
			var path := directory+variant+"/"
			DirAccess.make_dir_recursive_absolute(path)
			FileAccess.open(path+("before" if original else "after")+"-payload.bin",FileAccess.WRITE).store_var({
				"batches":payload.batches,"collision_boxes":payload.collision_boxes,"surface_meshes":payload.surface_meshes,
				"transform":Transform3D.IDENTITY,"surfaces":shape_values,"audit":urban.fabric_audit,"seed":civic_seed,
				"clearances":clearance_values,"routes":urban.ground_settlement.street_paths,"grade_claims":urban.terrain_grade._claims})
			print("CIVIC_PAYLOAD ",variant," original=",original," audit=",urban.fabric_audit)
	quit()
