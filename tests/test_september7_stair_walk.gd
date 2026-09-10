extends GutTest

class WalkController extends CharacterController:
	var direction := Vector2.DOWN
	func get_move_vector(_character: CharacterBody3D,_delta: float) -> Vector2:
		return direction

func test_scaled_stair_risers_reserve_the_ground_approach_clearance() -> void:
	for quarter in 4:
		for descending in [false,true]:
			var payload := _stairs(quarter,descending)
			var heights: Array[float] = [0.0]
			var vertices := payload.vertices as PackedVector3Array
			var normals := payload.normals as PackedVector3Array
			for index in range(0,vertices.size(),4):
				if normals[index].dot(Vector3.UP)<0.999: continue
				var span := vertices[index+1].distance_to(vertices[index])
				if absf(span-WarrenTransitionSurfaceBuilder.MACRO_SIZE)>0.001: continue
				if not heights.has(vertices[index].y): heights.append(vertices[index].y)
			heights.sort()
			assert_gte(heights.size(),3,"measure real tread faces")
			assert_almost_eq(heights[-1],1.5,0.0001,"the upper landing remains fixed")
			var previous := -VillageWarrenFabricSolver.DATUM_GUARD
			for height: float in heights.slice(1):
				var world_height := height*VillageWorldScale.PRODUCTION_UNIFORM_SCALE
				assert_lte(world_height-previous,TraversalEnvelope.MAX_PLANNED_STEP+0.0001,"every real tread, including the ground handoff, fits the walking contract")
				previous=world_height

func test_real_player_walks_from_ground_to_upper_landing_without_jump() -> void:
	var stage := Node3D.new()
	add_child(stage)
	var body := StaticBody3D.new()
	stage.add_child(body)
	var payload := _stairs()
	var faces := PackedVector3Array()
	for point: Vector3 in payload.collision_faces: faces.append(point*2)
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision=true
	shape.set_faces(faces)
	var collision := CollisionShape3D.new()
	collision.shape=shape
	body.add_child(collision)
	_box(body,Vector3(1.5,-0.58,2),Vector3(6,1,5))
	_box(body,Vector3(1.5,2.5,12),Vector3(6,1,3))
	var player := (load("res://characters/character.tscn") as PackedScene).instantiate() as CharacterBody3D
	var controller := WalkController.new()
	controller.direction=Vector2.ZERO
	player.controller=controller
	stage.add_child(player)
	player.set_physics_process(false)
	player.position=Vector3(1.5,-0.05,3.3)
	for tick in 30:
		await get_tree().physics_frame
		player._physics_process(1.0/60)
	assert_almost_eq(player.position.y,-0.08,0.005,"start on the real ground datum")
	controller.direction=Vector2.DOWN
	for tick in 150:
		await get_tree().physics_frame
		player._physics_process(1.0/60)
		if player.position.z>11.3: break
	assert_gt(player.position.z,11.3,"ordinary forward input reaches the upper landing")
	assert_almost_eq(player.position.y,3.0,0.06,"the player climbs the whole 3 m flight")
	stage.queue_free()
	await get_tree().process_frame

func _stairs(quarter: int=0,descending: bool=false) -> Dictionary:
	var high := Vector3i(Vector3(0,0,2).rotated(Vector3.UP,quarter*PI*0.5).round())+Vector3i.UP
	var transition := WarrenVolumeTransition.new(&"reported-step",high if descending else Vector3i.ZERO,Vector3i.ZERO if descending else high,WarrenVolumeTransition.Kind.STAIR,[])
	assert_true(transition.seal())
	return WarrenTransitionSurfaceBuilder.build(&"reported-step",transition,[Vector3i.ZERO])

func _box(body: StaticBody3D, centre: Vector3, size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size=size
	var node := CollisionShape3D.new()
	node.shape=shape
	node.position=centre
	body.add_child(node)
