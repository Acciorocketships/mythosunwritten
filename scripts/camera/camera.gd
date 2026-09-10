extends Node
## Elevated tactical orbit. Yaw is independent of travel and cursor-facing.
const LEGACY_VIEW := preload("res://scripts/camera/legacy_camera_view.gd")

@export var camera: Camera3D
@export var target: Node3D
@export var distance := 26.0
@export var height := 16.0
@export var look_height := 1.0
@export var tactical_view := true
@export var orbit_speed_rad := 2.0
@export var act_orbit_left := "camera_left"
@export var act_orbit_right := "camera_right"
## Centre fraction reserved for pointing/clicking. Motion, not dwell, rotates.
@export_range(0.0, 0.95) var mouse_dead_zone := 0.55
@export var mouse_sensitivity := 0.006
@export var visibility_bubble_enabled := true
@export var visibility_radius := 3.8
@export_range(0.0, 1.0) var obstruction_opacity := 0.12

var _yaw := 0.0
var _mouse_orbit := 0.0
var _visibility: CameraVisibilityBubble
var _legacy: Node

func _ready() -> void:
	if camera == null:
		camera = get_node(".") as Camera3D
	if camera != null and target != null:
		reset_orbit()
		camera.fov = 50.0
	_visibility = CameraVisibilityBubble.new()
	add_child(_visibility)
	_legacy = LEGACY_VIEW.new()
	_legacy.camera = camera
	_legacy.target = target
	add_child(_legacy)
	_apply_view()

func _unhandled_input(event: InputEvent) -> void:
	if camera == null or not camera.is_current(): return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F7:
		toggle_view()
		get_viewport().set_input_as_handled()
	elif tactical_view and event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		var width := get_viewport().get_visible_rect().size.x
		_mouse_orbit += edge_drag(motion.position.x - motion.relative.x,
			motion.position.x, width, mouse_dead_zone) * mouse_sensitivity

## Integrate outward motion beyond either edge of the centre. Returning to the
## click area must not unwind the orbit; another outward gesture can continue it.
## A boundary-crossing event behaves exactly like smaller events along that drag.
static func edge_drag(from_x: float, to_x: float, width: float, dead_zone: float) -> float:
	var left := width * (1.0 - dead_zone) * 0.5
	var right := width - left
	if to_x > from_x:
		return maxf(to_x - right, 0.0) - maxf(from_x - right, 0.0)
	return minf(to_x - left, 0.0) - minf(from_x - left, 0.0)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(camera) or not is_instance_valid(target):
		if _visibility != null: _visibility.clear()
		return
	if not tactical_view:
		_visibility.clear()
		_legacy.camera = camera
		_legacy.target = target
		_legacy.update_view(delta)
		return
	_yaw += _mouse_orbit + Input.get_axis(act_orbit_left, act_orbit_right) * orbit_speed_rad * delta
	_mouse_orbit = 0.0
	var pos := target.global_position
	if target.has_method("camera_follow_position"):
		pos = target.camera_follow_position()
	camera.global_position = pos + Vector3(sin(_yaw) * distance, height, cos(_yaw) * distance)
	camera.look_at(pos + Vector3.UP * look_height, Vector3.UP)
	if visibility_bubble_enabled and camera.is_current():
		_visibility.update_bubble(camera, target, pos, visibility_radius, obstruction_opacity, delta)
	else:
		_visibility.clear()

func toggle_view() -> void:
	tactical_view = not tactical_view
	_apply_view()

func _apply_view() -> void:
	if not is_instance_valid(camera) or not is_instance_valid(target): return
	reset_orbit()
	if tactical_view:
		camera.fov = 50.0
	else:
		_visibility.clear()
		camera.fov = 75.0
		var pos := target.global_position
		if target.has_method("camera_follow_position"): pos = target.camera_follow_position()
		camera.global_position = pos + Vector3(sin(_yaw) * _legacy.distance,
			_legacy.height, cos(_yaw) * _legacy.distance)
	_physics_process(0.0)

func reset_orbit() -> void:
	if camera == null or target == null: return
	var offset := camera.global_position - target.global_position
	_yaw = atan2(offset.x, offset.z)
	_mouse_orbit = 0.0
	if _legacy != null: _legacy.reset_follow()
