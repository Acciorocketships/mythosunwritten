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
	var spatial := frozen.spatial(frozen.read("res://tests/fixtures/september7-manual-source.txt"),program)
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
	var args := OS.get_cmdline_user_args()
	var speed := float(args[1]) if args.size()>1 else 1.0
	var lateral_offset := float(args[2]) if args.size()>2 else 0.0
	var results: Array = []
	for transition: WarrenVolumeTransition in spatial.source_volume.transitions:
		if transition.kind != WarrenVolumeTransition.Kind.STAIR: continue
		var ends := WarrenTransitionSurfaceBuilder._span_endpoints(transition)
		var low: Vector3 = ends.start if (ends.start as Vector3).y<(ends.end as Vector3).y else ends.end
		var high: Vector3 = ends.end if (ends.start as Vector3).y<(ends.end as Vector3).y else ends.start
		var forward := (high-low)*Vector3(1,0,1)
		forward = forward.normalized()
		var start := low*2-forward*1.2+Vector3.UP*0.03+forward.cross(Vector3.UP)*lateral_offset
		var target := high*2+forward*0.8
		player.global_position=start
		player.velocity=Vector3.ZERO
		controller.direction=Vector2.ZERO
		for tick in 30:
			await physics_frame
			player._physics_process(1.0/60)
		var trace: Array = []
		controller.direction=Vector2(forward.x,forward.z)*speed
		for tick in 360:
			await physics_frame
			player._physics_process(1.0/60)
			if tick%10==0: trace.append({"position":str(player.global_position),"velocity":str(player.velocity),"input":str(controller.get_move_vector(player,0)),"floor":player.is_on_floor(),"on_ground":player.on_ground})
			if (player.global_position-target).dot(forward)>=0: break
		var success := player.global_position.y>=high.y*2-0.1 and (player.global_position-target).dot(forward)>=-0.2
		var row := {"id":str(transition.stable_id),"low":str(low*2),"high":str(high*2),"end":str(player.global_position),"passed":success,"trace":trace}
		results.append(row)
		print("STAIR_WALK ",JSON.stringify(row))
	var output := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size()>0 else "/tmp/september7-stair-walk.json"
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
	player.queue_free()
	stage.queue_free()
	await process_frame
	quit()
