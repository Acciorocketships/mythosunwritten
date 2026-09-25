extends SceneTree
class InputController extends CharacterController:
	var direction := Vector2.ZERO
	var jump := false
	func get_move_vector(_character: CharacterBody3D,_delta: float)->Vector2:return direction
	func wants_jump(_character: CharacterBody3D,_delta: float)->bool:
		var value := jump
		jump=false
		return value
func _init()->void:call_deferred("_run")
func _run()->void:
	var cache := EnvironmentRenderCache.new(EnvironmentCatalog.load_default())
	cache.prepare([&"sfv.bridge.001"] as Array[StringName])
	var player := (load("res://characters/character.tscn") as PackedScene).instantiate() as CharacterBody3D
	var controller := InputController.new()
	player.controller=controller
	root.add_child(player)
	player.set_physics_process(false)
	var results: Array = []
	for yaw in [0.0,PI/2,PI,3*PI/2]:
		var stage := Node3D.new()
		root.add_child(stage)
		var pose := Transform3D(Basis(Vector3.UP,yaw),Vector3.ZERO)
		var payload := EnvironmentInstancePayload.new()
		payload.add(&"sfv.bridge.001",pose,Color.WHITE,&"bridge")
		EnvironmentCollisionBuilder.commit(stage,payload,cache,&"Bridge")
		for z in [-33.0,33.0]:
			var body := StaticBody3D.new()
			stage.add_child(body)
			var node := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size=Vector3(6,.2,6)
			node.shape=shape
			node.transform=pose*Transform3D(Basis.IDENTITY,Vector3(0,.08,z))
			body.add_child(node)
		await physics_frame
		await physics_frame
		player.global_position=pose*Vector3(0,.25,-32)
		player.velocity=Vector3.ZERO
		controller.direction=Vector2.ZERO
		for tick in 20:
			await physics_frame
			player._physics_process(1.0/60)
		var forward := pose.basis*Vector3.BACK
		controller.direction=Vector2(forward.x,forward.z)
		var jumped := false
		var landing_count := 0
		var minimum_y := 100.0
		for tick in 450:
			var local := pose.affine_inverse()*player.global_position
			if not jumped and local.z > -31.5:
				controller.jump=true
				jumped=true
			await physics_frame
			player._physics_process(1.0/60)
			local=pose.affine_inverse()*player.global_position
			if absf(local.z)<28:
				minimum_y=minf(minimum_y,local.y)
				if player.is_on_floor():landing_count+=1
			if local.z>=32:break
		var end := pose.affine_inverse()*player.global_position
		var row := {"yaw":yaw,"jumped":jumped,"landing_frames":landing_count,"minimum_deck_y":minimum_y,"end":str(end),"passed":end.z>=32 and minimum_y>0.2 and landing_count>0}
		results.append(row)
		print("BRIDGE_JUMP ",JSON.stringify(row))
		stage.queue_free()
		await process_frame
	FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
	player.queue_free()
	await process_frame
	quit()
