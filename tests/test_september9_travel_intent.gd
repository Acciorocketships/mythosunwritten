extends GutTest

class DirectionController extends CharacterController:
	var direction:=Vector2(0,-1)
	func get_move_vector(_character:CharacterBody3D,_delta:float)->Vector2:return direction

func test_streaming_can_see_acceleration_intent_before_the_first_movement_tick()->void:
	var character:CharacterBody3D=load("res://characters/character.gd").new()
	var controller:=DirectionController.new()
	character.controller=controller
	character.velocity=Vector3.ZERO
	assert_true(character.has_method("streaming_velocity"),"the character publishes intended travel independently of physics freeze")
	if character.has_method("streaming_velocity"):
		assert_eq(character.call("streaming_velocity"),Vector3(0,0,-10))
		assert_eq(character.velocity,Vector3.ZERO,"the query must not move the character")
		controller.direction=Vector2.ZERO
		character.velocity=Vector3(4,-8,0)
		assert_eq(character.call("streaming_velocity"),Vector3(4,0,0),"uncommanded motion keeps its physical lookahead")
		controller.direction=Vector2(0,-1)
		character.in_water=true
		assert_eq(character.call("streaming_velocity"),Vector3(0,0,-4.5),"swimming uses its own attainable speed")
	character.free()
