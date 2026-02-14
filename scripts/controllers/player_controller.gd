class_name PlayerController
extends CharacterController

@export var left_action  := "left"
@export var right_action := "right"
@export var forward_action    := "forward"
@export var backward_action  := "backward"
@export var jump_action  := "jump"

var camera: Node3D = null
var player: Node3D = null

func get_move_vector(_c: CharacterBody3D, _dt: float) -> Vector2:
	var raw := Input.get_vector(left_action, right_action, forward_action, backward_action)
	if raw == Vector2.ZERO:
		return Vector2.ZERO
	if camera == null:
		_find_camera()

	var disp: Vector3 = player.position - camera.position
	var right: Vector3 =  disp.cross(Vector3.UP)
	var fwd: Vector3 = Vector3.UP.cross(right)
	fwd.y = 0.0; right.y = 0.0
	fwd = fwd.normalized()
	right = right.normalized()

	var world: Vector3 = right * raw.x - fwd * raw.y
	return Vector2(world.x, world.z)

func wants_jump(_c: CharacterBody3D, _dt: float) -> bool:
	return Input.is_action_just_pressed(jump_action)
	
func _find_camera():
	camera = Engine.get_main_loop().root.get_viewport().get_camera_3d()
	assert(camera, "Could not find camera")
	
func _set_player(plyr: Node3D):
	player = plyr
