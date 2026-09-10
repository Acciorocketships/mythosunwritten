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
	var source := frozen.read("res://tests/fixtures/september7-manual-source.txt")
	var destination_review := OS.get_cmdline_user_args().has("--destination")
	if destination_review:
		source = WarrenMazeCarver.carve(source.world_seed,source.massif,source.scale_profile,false,false)
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
	var camera := Camera3D.new()
	camera.set_script(load("res://scripts/camera/camera.gd"))
	camera.target=player
	stage.add_child(camera)
	camera.set_physics_process(false)
	await physics_frame
	await physics_frame
	var args := OS.get_cmdline_user_args()
	var speed := float(args[1]) if args.size()>1 else 1.0
	var lateral_offset := float(args[2]) if args.size()>2 else 0.0
	var results: Array = []
	for transition: WarrenVolumeTransition in spatial.source_volume.transitions:
		var destination_link := destination_review and transition.from_cell == Vector3i(0,5,1) and transition.to_cell == Vector3i(0,5,2)
		if transition.kind != WarrenVolumeTransition.Kind.STAIR and not destination_link: continue
		var ends := WarrenTransitionSurfaceBuilder._span_endpoints(transition)
		var low: Vector3 = ends.start if (ends.start as Vector3).y<(ends.end as Vector3).y else ends.end
		var high: Vector3 = ends.end if (ends.start as Vector3).y<(ends.end as Vector3).y else ends.start
		if destination_link:
			low = Vector3(transition.from_cell)*Vector3(3,1.5,3)+Vector3(0.75,0,0.75)
			high = Vector3(transition.to_cell)*Vector3(3,1.5,3)+Vector3(0.75,0,0.75)
		var forward := (high-low)*Vector3(1,0,1)
		forward = forward.normalized()
		for descent:bool in [false,true]:
			var direction := -forward if descent else forward
			var start := (high*2+forward*0.8 if descent else low*2-forward*1.2)+Vector3.UP*0.03+forward.cross(Vector3.UP)*lateral_offset
			var target := (low*2-forward*1.2 if descent else high*2+forward*0.8)+forward.cross(Vector3.UP)*lateral_offset
			player.global_position=start
			player.velocity=Vector3.ZERO
			controller.direction=Vector2.ZERO
			camera.global_position=start-direction*8+Vector3.UP*5
			camera._have_prev=false
			for tick in 30:
				await physics_frame
				player._physics_process(1.0/60)
				camera._physics_process(1.0/60)
			var trace: Array = []
			controller.direction=Vector2(direction.x,direction.z)*speed
			var success := false
			for tick in 360:
				await physics_frame
				player._physics_process(1.0/60)
				camera._physics_process(1.0/60)
				var probe:=KinematicCollision3D.new()
				var supported:=player.test_move(player.global_transform,Vector3.DOWN*0.51,probe)
				trace.append({"support_hit":supported,"support_normal":str(probe.get_normal()) if supported else "","support_travel":str(probe.get_travel()) if supported else "","tick":tick,"xyz":[player.global_position.x,player.global_position.y,player.global_position.z],
					"visual_y":player.body_model_root.global_position.y,"camera_y":camera.global_position.y,
					"velocity_y":player.velocity.y,"floor":player.is_on_floor(),"on_ground":player.on_ground})
				if (player.global_position-target).dot(direction)>=0:
					success=absf(player.global_position.y-target.y)<0.15
					break
			if not success:
				var diagnosis:=KinematicCollision3D.new()
				var raised:=player.global_transform.translated(Vector3.UP*0.55+direction*speed*10/60)
				var hit:=player.test_move(raised,Vector3.DOWN*0.65,diagnosis)
				print("STEP_DIAG ",hit," normal=",diagnosis.get_normal()," travel=",diagnosis.get_travel()," point=",diagnosis.get_position())
			controller.direction=Vector2.ZERO
			for tick in 60:
				await physics_frame
				player._physics_process(1.0/60)
				camera._physics_process(1.0/60)
			var row := {"id":str(transition.stable_id),"descent":descent,"passed":success,"trace":trace}
			results.append(row)
			print("STAIR_MOTION ",transition.stable_id," descent=",descent," passed=",success)
	var output := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size()>0 else "/tmp/september8-stair-motion.json"
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
	player.queue_free()
	stage.queue_free()
	await process_frame
	quit()
