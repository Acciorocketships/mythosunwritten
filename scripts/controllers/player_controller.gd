class_name PlayerController
extends CharacterController

@export var left_action := "left"
@export var right_action := "right"
@export var forward_action := "forward"
@export var backward_action := "backward"
@export var jump_action := "jump"

var camera: Node3D
var _last_facing := Vector2.ZERO

func get_move_vector(character: CharacterBody3D, _dt: float) -> Vector2:
	camera = character.get_viewport().get_camera_3d()
	var raw := Input.get_vector(left_action, right_action, forward_action, backward_action)
	if camera == null: return raw
	var movement := camera_relative(raw, camera.global_basis)
	var direction := Vector3(movement.x, 0.0, movement.y)
	var max_speed := float(character.get("MAX_SPEED"))
	var gait_speed := DirectionalLocomotion.RUN_CADENCE * DirectionalLocomotion.stride_length(direction, character.global_basis)
	return movement * minf(1.0, gait_speed / max_speed)

static func camera_relative(raw: Vector2, camera_basis: Basis) -> Vector2:
	var right := Vector3(camera_basis.x.x, 0.0, camera_basis.x.z).normalized()
	var forward := Vector3(-camera_basis.z.x, 0.0, -camera_basis.z.z).normalized()
	var world := right * raw.x - forward * raw.y
	return Vector2(world.x, world.z)

func get_facing_vector(character: CharacterBody3D, _dt: float) -> Vector2:
	var view := character.get_viewport()
	var active_camera := view.get_camera_3d()
	var cursor := view.get_mouse_position()
	if active_camera == null or not view.get_visible_rect().has_point(cursor):
		return _last_facing
	# A plane through the feet makes aim independent of foreground roofs and
	# walls (which may be transparent). It also behaves predictably on slopes.
	var aim := cursor_direction(active_camera, cursor, character.global_position)
	if aim.length_squared() > 0.0:
		_last_facing = aim
	return _last_facing

static func cursor_direction(view_camera: Camera3D, cursor: Vector2, origin: Vector3) -> Vector2:
	var ray_origin := view_camera.project_ray_origin(cursor)
	var ray_direction := view_camera.project_ray_normal(cursor)
	if absf(ray_direction.y) < 0.0001: return Vector2.ZERO
	var distance := (origin.y - ray_origin.y) / ray_direction.y
	if distance <= 0.0: return Vector2.ZERO
	var offset := ray_origin + ray_direction * distance - origin
	var flat := Vector2(offset.x, offset.z)
	return flat.normalized() if flat.length_squared() > 0.0625 else Vector2.ZERO

func wants_jump(_c: CharacterBody3D, _dt: float) -> bool:
	return Input.is_action_just_pressed(jump_action)

func jump_held(_c: CharacterBody3D, _dt: float) -> bool:
	return Input.is_action_pressed(jump_action)
