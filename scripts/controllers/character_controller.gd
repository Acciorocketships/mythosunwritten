class_name CharacterController
extends Resource

func get_move_vector(_character: CharacterBody3D, _delta: float) -> Vector2:
	return Vector2.ZERO
	
func wants_jump(_character: CharacterBody3D, _delta: float) -> bool:
	return false
