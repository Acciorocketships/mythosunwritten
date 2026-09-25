extends GutTest

const SOURCE := "res://docs/qa/2026-09-13-manual/04-path/source.txt"
const FROZEN := preload("res://tests/fixtures/frozen_maze_source.gd")

func test_photographed_ramp_reserves_real_air_and_clears_native_house_collision() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	var spatial := FROZEN.spatial(FROZEN.read(SOURCE),program)
	var plan := spatial.compiled_fabric_cache()
	var feet := Vector3(-222.4,17.7,-958.4)
	var town := Transform3D(Basis.from_scale(Vector3(-2,2,-2)),Vector3(-214.5,8.08,-944.5))
	var inverse := town.affine_inverse()
	# The actual photographed ramp rises 0.25 m per metre toward +Z.
	var invaded := []
	for z: float in [-955.0,-954.7,-954.4,-954.0,-953.5]:
		var floor_y := 17.72999+(z+958.4)*.25
		var local := inverse*Vector3(feet.x,floor_y+.10,z)
		var cell := Vector3i(roundi(local.x/FabricRecipe.CELL_SIZE),floori(local.y/FabricRecipe.CELL_SIZE),roundi(local.z/FabricRecipe.CELL_SIZE))
		if spatial.grid.use_at(cell) != WarrenSpatialGrid.Use.PUBLIC_AIR: invaded.append(cell)
	assert_true(invaded.is_empty(),"Continuous ramp air cannot become a private wall below the rounded route datum: %s" % str(invaded))
	var payload := SettlementFabricAssembler.payload(plan)
	payload.append_from(SettlementFabricAssembler.structural_support_payload(plan))
	payload.append_from(SettlementFabricAssembler.production_surface_bundle(plan.surface_plan,
		SettlementFabricAssembler.maze_module_footprints(plan),
		SettlementFabricAssembler.maze_skin_panel_boxes_for(plan),plan.planned_plaza_cells))
	var cache := EnvironmentRenderCache.new(catalog)
	cache.prepare(payload.asset_ids())
	var stage := Node3D.new()
	add_child_autofree(stage)
	stage.transform = town
	EnvironmentCollisionBuilder.commit(stage,payload,cache,&"NativeTown")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var capsule := CapsuleShape3D.new()
	capsule.radius = .39746094
	capsule.height = 2.244
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.margin = .02
	var blocked := []
	for offset: float in [-.7,0,.7]:
		for i in 33:
			var z := -957.0+float(i)*.125
			var y := 17.72999+(z+958.4)*.25
			query.transform = Transform3D(Basis.IDENTITY,Vector3(feet.x+offset,y+capsule.height*.5+.06,z))
			if not stage.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): blocked.append(query.transform.origin)
	assert_true(blocked.is_empty(),"Actual native wall collision must clear the photographed ramp at three lateral lines: %s"%str(blocked))

func test_native_flights_reserve_the_air_above_every_actual_tread_in_both_directions() -> void:
	var missed := []
	var samples := 0
	for direction: Vector3i in [Vector3i.LEFT,Vector3i.RIGHT,Vector3i.FORWARD,Vector3i.BACK]:
		for rise: int in [-1,1]:
			for run: int in [2,3]:
				var transition := WarrenVolumeTransition.new(&"flight",Vector3i(0,3,0),
					Vector3i(0,3+rise,0)+direction*run,
					WarrenVolumeTransition.Kind.STAIR if run == 2 else WarrenVolumeTransition.Kind.RAMP,[])
				assert_true(transition.seal())
				var route := transition.surface_cells()
				var air := transition.clearance_air_cells()
				var columns := {}
				for cell: Vector3i in route: columns[Vector2i(cell.x,cell.z)] = true
				var geometry := WarrenTransitionSurfaceBuilder.build(&"flight",transition,route,[],true)
				var points: PackedVector3Array = geometry.vertices
				var normals: PackedVector3Array = geometry.normals
				var indices: PackedInt32Array = geometry.indices
				for i in range(0,indices.size(),3):
					if normals[indices[i]].y < .7: continue
					var point := (points[indices[i]]+points[indices[i+1]]+points[indices[i+2]])/3.0
					var column := Vector2i(roundi(point.x/FabricRecipe.CELL_SIZE),roundi(point.z/FabricRecipe.CELL_SIZE))
					if not columns.has(column): continue
					for height: float in [.02,.4,1.2,TraversalEnvelope.MIN_HEADROOM-.02]:
						var cell := Vector3i(column.x,floori((point.y+height)/FabricRecipe.CELL_SIZE),column.y)
						samples += 1
						if not air.has(cell): missed.append([direction,rise,run,cell])
				assert_eq(route,transition.surface_cells(),"Clearance does not change the canonical route addresses")
	assert_gt(samples,100,"Inspect actual native ramp and stair top triangles")
	assert_true(missed.is_empty(),"Every sampled body interval must be reserved before room allocation: %s"%str(missed))

func test_ramp_clearance_keeps_only_final_grounded_stone_after_jamb_withdrawals() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var spatial := WarrenVolumetricSolver.solve(9, {}, program,
		WarrenVillageScaleProfile.for_id(&"standard"))
	assert_not_null(spatial)
	if spatial == null: return
	var fabric := spatial.compiled_fabric_cache()
	var stone := SettlementFabricAssembler.maze_stone_cells(fabric.retained_terrace_cells)
	var plinth := fabric.retained_terrace_cells.duplicate()
	for cell: Vector3i in stone: plinth.erase(cell)
	var support := WarrenSpatialFabricCompiler._supported_retained_maze_cells(
		spatial, fabric, plinth, stone, fabric.transformed_cells(&"solid"))
	assert_true((support.unsupported as Dictionary).is_empty(),
		"A withdrawn ramp-side jamb cannot continue to support an already visited crown: %s" % str(support.unsupported))
