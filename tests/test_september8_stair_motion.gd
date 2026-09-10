extends "res://tests/test_september7_stair_walk.gd"

func test_stair_ascent_and_descent_have_no_body_reversals_or_visual_jumps() -> void:
	await _check_stair_motion(1.0)

func test_slow_stair_motion_keeps_the_same_access_and_smoothness() -> void:
	await _check_stair_motion(0.35)

func _check_stair_motion(speed:float) -> void:
	var stage := Node3D.new()
	add_child(stage)
	var body := StaticBody3D.new()
	stage.add_child(body)
	var payload := _stairs()
	var faces := PackedVector3Array()
	for point:Vector3 in payload.collision_faces: faces.append(point*2)
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision=true
	shape.set_faces(faces)
	var collision := CollisionShape3D.new()
	collision.shape=shape
	body.add_child(collision)
	_box(body,Vector3(1.5,-0.58,2),Vector3(6,1,5))
	_box(body,Vector3(1.5,2.5,12),Vector3(6,1,3))
	var player := load("res://characters/character.tscn").instantiate() as CharacterBody3D
	var controller := WalkController.new()
	player.controller=controller
	stage.add_child(player)
	player.set_physics_process(false)
	var camera := Camera3D.new()
	camera.set_script(load("res://scripts/camera/camera.gd"))
	camera.target=player
	camera.collision_enabled=false
	stage.add_child(camera)
	camera.set_physics_process(false)
	for descent:bool in [false,true]:
		player.position=Vector3(1.5,3.03,11.5) if descent else Vector3(1.5,-0.05,3.3)
		player.velocity=Vector3.ZERO
		controller.direction=Vector2.ZERO
		camera.position=player.position+Vector3(0,5,-8)
		camera._have_prev=false
		for tick in 60:
			await get_tree().physics_frame
			player._physics_process(1.0/60)
			camera._physics_process(1.0/60)
		var last:=Vector3(player.position.y,player.body_model_root.global_position.y,camera.global_position.y)
		var wrong_way:=0.0
		var worst_recovery:=0.0
		var visual_step:=0.0
		var camera_step:=0.0
		var reached:=false
		var airborne_animation_ticks:=0
		controller.direction=(Vector2.UP if descent else Vector2.DOWN)*speed
		for tick in 180:
			await get_tree().physics_frame
			player._physics_process(1.0/60)
			camera._physics_process(1.0/60)
			airborne_animation_ticks+=int(not player.was_on_ground)
			var current:=Vector3(player.position.y,player.body_model_root.global_position.y,camera.global_position.y)
			var change:=current-last
			wrong_way+=maxf(0,change.x if descent else -change.x)
			worst_recovery=maxf(worst_recovery,maxf(0,change.x if descent else -change.x))
			visual_step=maxf(visual_step,absf(change.y))
			camera_step=maxf(camera_step,absf(change.z))
			last=current
			if (descent and player.position.z<3.5) or (not descent and player.position.z>11.3):
				reached=true
				break
		assert_true(reached,"Both directions still reach the landing")
		assert_eq(airborne_animation_ticks,0,"Tread noses must not trigger jump/landing animation cycles")
		assert_lt(wrong_way,0.04,"Only millimetre collision recovery remains across the flight; descent=%s"%descent)
		assert_lt(worst_recovery,0.006,"No perceptible reverse step on a monotone flight")
		assert_lt(visual_step,0.15,"The model must absorb discrete riser handoffs; descent=%s"%descent)
		assert_lt(camera_step,0.15,"The camera follows the same continuous height; descent=%s"%descent)
		controller.direction=Vector2.ZERO
		for tick in 60:
			await get_tree().physics_frame
			player._physics_process(1.0/60)
		assert_almost_eq(player.body_model_root.position.y,0.0,0.001,"Visual offset settles at rest")
	stage.queue_free()
	await get_tree().process_frame

class JumpController extends CharacterController:
	var direction:=Vector2.ZERO
	var jump:=false
	func get_move_vector(_character:CharacterBody3D,_delta:float)->Vector2:
		return direction
	func wants_jump(_character:CharacterBody3D,_delta:float)->bool:
		return jump

func test_ground_snap_preserves_jumps_ledges_and_obstacle_limits() -> void:
	var stage:=Node3D.new()
	add_child(stage)
	var ground:=StaticBody3D.new()
	stage.add_child(ground)
	_box(ground,Vector3(0,-0.5,0),Vector3(20,1,20))
	var obstacle:=StaticBody3D.new()
	stage.add_child(obstacle)
	_box(obstacle,Vector3(0,0.4,2),Vector3(4,0.8,1))
	var player:=load("res://characters/character.tscn").instantiate() as CharacterBody3D
	var controller:=JumpController.new()
	player.controller=controller
	stage.add_child(player)
	player.set_physics_process(false)
	for tick in 30:
		await get_tree().physics_frame
		player._physics_process(1.0/60)
	controller.direction=Vector2.DOWN
	for tick in 60:
		await get_tree().physics_frame
		player._physics_process(1.0/60)
	assert_lt(player.position.z,1.5,"A wall taller than the step limit remains an obstacle")
	controller.direction=Vector2.ZERO
	controller.jump=true
	await get_tree().physics_frame
	player._physics_process(1.0/60)
	controller.jump=false
	for tick in 10:
		await get_tree().physics_frame
		player._physics_process(1.0/60)
	assert_gt(player.position.y,1.0,"The active floor witness cannot snap down a deliberate jump")
	assert_gt(player.velocity.y,0.0)
	assert_false(player.was_on_ground,"A deliberate jump still enters its airborne animation")
	# A real drop exceeds the same finite step limit and must become airborne.
	player.position=Vector3(8,0.01,0)
	player.velocity=Vector3.ZERO
	controller.direction=Vector2.ZERO
	for tick in 30:
		await get_tree().physics_frame
		player._physics_process(1.0/60)
	controller.direction=Vector2.RIGHT
	for tick in 35:
		await get_tree().physics_frame
		player._physics_process(1.0/60)
	assert_gt(player.position.x,10.5)
	assert_lt(player.position.y,-0.5,"A ledge remains a fall rather than an invisible step")
	# Test the swept rise under a low ceiling at an otherwise legal step.
	obstacle.queue_free()
	var low_step:=StaticBody3D.new()
	stage.add_child(low_step)
	_box(low_step,Vector3(0,0.2,2),Vector3(4,0.4,1))
	_box(low_step,Vector3(0,2.65,1),Vector3(4,0.3,4))
	player.position=Vector3(0,0.01,0)
	player.velocity=Vector3.ZERO
	controller.direction=Vector2.ZERO
	for tick in 30:
		await get_tree().physics_frame
		player._physics_process(1.0/60)
	controller.direction=Vector2.DOWN
	for tick in 45:
		await get_tree().physics_frame
		player._physics_process(1.0/60)
	assert_lt(player.position.z,1.5,"Step-up cannot move the capsule through a low ceiling")
	assert_lt(player.position.y,0.26)
	stage.queue_free()
	await get_tree().process_frame
