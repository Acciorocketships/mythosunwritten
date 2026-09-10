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
	cache.prepare([&"sfv.building.interior.blue.001"] as Array[StringName])
	var player := (load("res://characters/character.tscn") as PackedScene).instantiate() as CharacterBody3D
	var controller := InputController.new()
	player.controller=controller
	root.add_child(player)
	player.set_physics_process(false)
	var results: Array = []
	for yaw in [0.0,PI/2,PI,3*PI/2]:
		var stage := Node3D.new()
		root.add_child(stage)
		var pose := Transform3D(Basis(Vector3.UP,yaw).scaled(Vector3.ONE*2),Vector3.ZERO)
		var payload := EnvironmentInstancePayload.new()
		payload.add(&"sfv.building.interior.blue.001",pose,Color.WHITE,&"house")
		EnvironmentCollisionBuilder.commit(stage,payload,cache,&"House")
		var body := StaticBody3D.new()
		stage.add_child(body)
		var node := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size=Vector3(8,.1,4)
		node.shape=shape
		node.transform=pose*Transform3D(Basis.IDENTITY,Vector3(0,.472,7))
		body.add_child(node)
		for reverse in [false,true]:
			var from_z := 4.5 if reverse else 8.0
			var to_z := 8.0 if reverse else 4.5
			var sign_z := signf(to_z-from_z)
			player.global_position=pose*Vector3(.222,.57,from_z)
			player.velocity=Vector3.ZERO
			controller.direction=Vector2.ZERO
			for tick in 20:
				await physics_frame
				player._physics_process(1.0/60)
			var forward := (pose.basis*Vector3(0,0,sign_z)).normalized()
			controller.direction=Vector2(forward.x,forward.z)
			for tick in 240:
				await physics_frame
				player._physics_process(1.0/60)
				if ((pose.affine_inverse()*player.global_position).z-to_z)*sign_z>=0:break
			var end := pose.affine_inverse()*player.global_position
			var row := {"yaw":yaw,"reverse":reverse,"end":str(end),"passed":(end.z-to_z)*sign_z>=0 and player.is_on_floor()}
			results.append(row)
			print("DOOR_WALK ",JSON.stringify(row))
		stage.queue_free()
		await process_frame
	FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
	player.queue_free()
	await process_frame
	quit()
