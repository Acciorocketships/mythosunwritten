extends SceneTree

class WalkController extends CharacterController:
	var direction := Vector2.ZERO
	func get_move_vector(_character: CharacterBody3D,_delta: float) -> Vector2:
		return direction

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var args := OS.get_cmdline_user_args()
	var original := frozen.read("res://tests/fixtures/" + ("september8-night-center-source.txt" if args.has("--center") else "september7-manual-source.txt"))
	var source := WarrenMazeCarver.carve(original.world_seed,original.massif,original.scale_profile,false,false)
	WarrenPlotPlanner.reserve(source,source.scale_profile)
	WarrenPlotPlanner.partition(source,source.scale_profile)
	source.finish_construction(false)
	var spatial := frozen.spatial(source,program)
	var fabric := spatial.compiled_fabric_cache()
	var stage := Node3D.new()
	root.add_child(stage)
	var payload := SettlementFabricAssembler.production_surface_bundle(fabric.surface_plan,SettlementFabricAssembler.maze_module_footprints(fabric),SettlementFabricAssembler.maze_skin_panel_boxes_for(fabric),fabric.planned_plaza_cells)
	payload.append_from(SettlementFabricAssembler.payload(fabric))
	payload.append_from(SettlementFabricAssembler.structural_support_payload(fabric))
	payload.append_from(SettlementFabricAssembler.terrace_retaining_payload(fabric))
	var cache := EnvironmentRenderCache.new(EnvironmentCatalog.load_default())
	cache.prepare(payload.asset_ids())
	EnvironmentCollisionBuilder.commit(stage,payload,cache,&"StairTown")
	var surfaces := StaticBody3D.new()
	stage.add_child(surfaces)
	for mesh: Dictionary in payload.surface_meshes:
		if bool(mesh.get("visual_only",false)): continue
		var faces: PackedVector3Array = mesh.get("collision_faces",PackedVector3Array())
		if faces.is_empty(): continue
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision=true
		shape.set_faces(faces)
		var node := CollisionShape3D.new()
		node.shape=shape
		surfaces.add_child(node)
	for cell: Vector3i in fabric.surface_plan.cells_for_kind(PublicRealmSurfacePlan.SurfaceKind.TERRAIN_STREET):
		var shape := BoxShape3D.new()
		shape.size=Vector3(1.5,0.1,1.5)
		var node := CollisionShape3D.new()
		node.shape=shape
		node.position=Vector3(cell)*1.5-Vector3.UP*0.05
		surfaces.add_child(node)
	stage.scale = Vector3.ONE*2
	var player := (load("res://characters/character.tscn") as PackedScene).instantiate() as CharacterBody3D
	var controller := WalkController.new()
	player.controller = controller
	player.set_physics_process(false)
	root.add_child(player)
	player.set_physics_process(false)
	await physics_frame
	await physics_frame
	var results: Array = []
	var cells := spatial.source_volume.terminal_lookout_cells
	for a: Vector3i in cells:
		for b: Vector3i in cells:
			if absi(a.x-b.x)+absi(a.z-b.z)!=1: continue
			var start := Vector3(a.x*6+1.5,a.y*3+0.05,a.z*6+1.5)
			var target := Vector3(b.x*6+1.5,b.y*3+0.05,b.z*6+1.5)
			var forward := (target-start).normalized()
			player.global_position=start
			player.velocity=Vector3.ZERO
			controller.direction=Vector2.ZERO
			for tick in 20:
				await physics_frame
				player._physics_process(1.0/60)
			var minimum_y := player.global_position.y
			controller.direction=Vector2(forward.x,forward.z)
			for tick in 240:
				await physics_frame
				player._physics_process(1.0/60)
				minimum_y=minf(minimum_y,player.global_position.y)
				if (player.global_position-target).dot(forward)>=-0.1: break
			var success := minimum_y>=target.y-0.2 and (player.global_position-target).dot(forward)>=-0.2
			var row := {"from":str(a),"to":str(b),"end":str(player.global_position),"minimum_y":minimum_y,"passed":success}
			results.append(row)
			print("TERRACE_WALK ",JSON.stringify(row))
	# Walk the original stairs beneath the new terrace, in both directions.
	for transition: WarrenVolumeTransition in spatial.source_volume.transitions:
		if transition.kind != WarrenVolumeTransition.Kind.STAIR: continue
		if maxi(transition.from_cell.y,transition.to_cell.y) >= cells[0].y: continue
		var beneath := false
		for cell: Vector3i in cells:
			if cell.x >= mini(transition.from_cell.x,transition.to_cell.x) and cell.x <= maxi(transition.from_cell.x,transition.to_cell.x) and cell.z >= mini(transition.from_cell.z,transition.to_cell.z) and cell.z <= maxi(transition.from_cell.z,transition.to_cell.z): beneath=true
		if not beneath: continue
		var ends := WarrenTransitionSurfaceBuilder._span_endpoints(transition)
		for reverse in [false,true]:
			var a: Vector3 = ends.end if reverse else ends.start
			var b: Vector3 = ends.start if reverse else ends.end
			var forward := ((b-a)*Vector3(1,0,1)).normalized()
			var start := a*2-forward*0.8+Vector3.UP*0.05
			var target := b*2+forward*0.8
			player.global_position=start
			player.velocity=Vector3.ZERO
			controller.direction=Vector2.ZERO
			for tick in 20:
				await physics_frame
				player._physics_process(1.0/60)
			controller.direction=Vector2(forward.x,forward.z)
			for tick in 300:
				await physics_frame
				player._physics_process(1.0/60)
				if (player.global_position-target).dot(forward)>=-0.1: break
			var success := absf(player.global_position.y-target.y)<0.2 and (player.global_position-target).dot(forward)>=-0.2
			var row := {"lower_flight":str(transition.stable_id),"reverse":reverse,"end":str(player.global_position),"target":str(target),"passed":success}
			results.append(row)
			print("UNDER_TERRACE_WALK ",JSON.stringify(row))
	var output := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size()>0 else "/tmp/september7-stair-walk.json"
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
	player.queue_free()
	stage.queue_free()
	await process_frame
	quit()
