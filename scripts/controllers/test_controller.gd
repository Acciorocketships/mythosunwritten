class_name TestController
extends CharacterController

@export var target: NodePath
@export var deadzone := 0.05

func get_move_vector(character: CharacterBody3D, _dt) -> Vector2:
	var t := character.get_node_or_null(target) as Node3D
	if t == null: return Vector2.ZERO
	var to := (t.global_transform.origin - character.global_transform.origin)
	var flat := Vector2(to.x, to.z)
	return flat.normalized() if flat.length() > deadzone else Vector2.ZERO

func wants_jump(_c, _dt) -> bool:
	return false
