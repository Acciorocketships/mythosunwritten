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
## Outward drag gain relative to the horizontal field of view.
@export var mouse_sensitivity := 1.6
@export var visibility_bubble_enabled := true
@export var visibility_radius := 3.8
@export_range(0.0, 1.0) var obstruction_opacity := 0.12

var _yaw := 0.0
var _mouse_orbit := 0.0
var _visibility: CameraVisibilityBubble
var _legacy: Node
var _pointer := Vector2.ZERO
var _have_pointer := false
var _edge_pixels := 0.0
var _edge_captured := false
var _edge_enabled := true
var _previous_mouse_mode := Input.MOUSE_MODE_VISIBLE
var _edge_cursor: Control
var _forwarding_pointer := false

class EdgeCursor extends Control:
	func _draw() -> void:
		var outline := PackedVector2Array([Vector2.ZERO, Vector2(0,18), Vector2(4,14),
			Vector2(8,22), Vector2(11,20), Vector2(7,12), Vector2(14,12), Vector2.ZERO])
		draw_colored_polygon(outline, Color.WHITE)
		draw_polyline(outline, Color.BLACK, 1.5, true)

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
	var cursor_layer := CanvasLayer.new()
	cursor_layer.layer = 100
	add_child(cursor_layer)
	_edge_cursor = EdgeCursor.new()
	_edge_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_edge_cursor.hide()
	cursor_layer.add_child(_edge_cursor)
	_apply_view()

func _input(event: InputEvent) -> void:
	if _forwarding_pointer: return
	if not tactical_view or camera == null or not camera.is_current(): return
	if event is InputEventMouseMotion:
		var was_captured := _edge_captured
		var size := get_viewport().get_visible_rect().size
		var pixel := _pointer_pixel_size()
		var limit := (size - pixel).max(Vector2.ZERO)
		var start: Vector2 = _pointer if _have_pointer else event.position - event.relative
		if _edge_captured:
			_pointer = (_pointer + event.relative).clamp(Vector2.ZERO, limit)
			# GUI clicks and aim retain the visible edge cursor, not the OS capture centre.
			event.position = _pointer
			event.global_position = _pointer
			_edge_cursor.position = _pointer
		else:
			_pointer = event.position.clamp(Vector2.ZERO, limit)
		_edge_pixels = edge_drag(start.x, event.relative.x, size.x, pixel.x) if was_captured else 0.0
		_have_pointer = true
		if not _edge_captured and _edge_enabled and event.button_mask == 0:
			if Rect2(Vector2.ZERO, size).has_point(event.position):
				_begin_edge_capture()
		if was_captured: _forward_pointer_event(event)
	elif event is InputEventMouseButton:
		if _edge_captured:
			event.position = _pointer
			event.global_position = _pointer
			# Restore ordinary GUI/3D picking before dispatching a click at the edge.
			_release_edge(true, false)
			_forward_pointer_event(event)
		elif event.pressed:
			_edge_enabled = true
			_have_pointer = false

func _forward_pointer_event(event: InputEvent) -> void:
	# Godot computes GUI hover before _input. Redispatch the corrected position
	# once, so the visible cursor, hover, button focus and aim agree.
	_forwarding_pointer = true
	get_viewport().push_input(event.duplicate(), true)
	_forwarding_pointer = false
	get_viewport().set_input_as_handled()

func pointing_position() -> Vector2:
	return _pointer if _have_pointer or _edge_captured else get_viewport().get_mouse_position()

func _unhandled_input(event: InputEvent) -> void:
	if camera == null or not camera.is_current(): return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F7:
		toggle_view()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and _edge_captured:
		_release_edge(true)
		_edge_enabled = false
		get_viewport().set_input_as_handled()
	elif tactical_view and event is InputEventMouseMotion:
		if not _edge_enabled: return
		var size := get_viewport().get_visible_rect().size
		# Positive boom yaw looks left; outward right drag must turn the view right.
		_mouse_orbit -= _edge_pixels * drag_radians_per_pixel(size, camera.fov,
			camera.keep_aspect == Camera3D.KEEP_WIDTH) * mouse_sensitivity

func _begin_edge_capture() -> void:
	if _edge_captured: return
	if DisplayServer.get_name() != "headless" and not get_window().has_focus(): return
	if Input.mouse_mode not in [Input.MOUSE_MODE_VISIBLE, Input.MOUSE_MODE_CONFINED]: return
	# Keep raw input for the entire focused interaction. Waiting until the OS
	# pointer exits loses unpressed events and keyboard focus in embedded games.
	# The virtual pointer moves freely; only its outward overflow turns the view.
	_previous_mouse_mode = Input.mouse_mode
	_edge_captured = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_edge_cursor.position = _pointer
	_edge_cursor.scale.x = 1.0
	_edge_cursor.show()

## Only the part of this motion beyond the actual last viewport pixel rotates.
## Start at the clamped pointer, so moving inward never repays previous overflow.
static func edge_drag(from_x: float, motion_x: float, width: float, pixel_width := 1.0) -> float:
	var right := maxf(width - pixel_width, 0.0)
	var end := clampf(from_x, 0.0, right) + motion_x
	return end - clampf(end, 0.0, right)

func _pointer_pixel_size() -> Vector2:
	if DisplayServer.get_name() == "headless": return Vector2.ONE
	# macOS cursor coordinates are points scaled into backing pixels. In a
	# 1920-pixel Retina game window the last point is 1918, never 1919.
	var native_point := DisplayServer.screen_get_max_scale() if OS.get_name() == "macOS" else 1.0
	var inverse := get_viewport().get_screen_transform().affine_inverse()
	return Vector2(inverse.basis_xform(Vector2(native_point,0)).length(),
		inverse.basis_xform(Vector2(0,native_point)).length())

static func drag_radians_per_pixel(size: Vector2, fov: float, keep_width := false) -> float:
	if size.x <= 0.0 or size.y <= 0.0: return 0.0
	var horizontal_fov := deg_to_rad(fov)
	if not keep_width: horizontal_fov = 2.0 * atan(tan(horizontal_fov * 0.5) * size.x / size.y)
	return horizontal_fov / size.x

func _release_edge(warp_back := false, discard_motion := true) -> void:
	if _edge_captured:
		_edge_captured = false
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = _previous_mouse_mode
			if warp_back: get_viewport().warp_mouse(_pointer)
	if _edge_cursor != null: _edge_cursor.hide()
	_have_pointer = false
	_edge_pixels = 0.0
	if discard_motion: _mouse_orbit = 0.0

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_PAUSED:
		_release_edge()

func _exit_tree() -> void:
	_release_edge()

func _physics_process(delta: float) -> void:
	if _edge_captured and (not tactical_view or not is_instance_valid(target)
			or not is_instance_valid(camera) or not camera.is_current()
			or (DisplayServer.get_name() != "headless"
				and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED)):
		_release_edge()
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
	_release_edge(true)
	_edge_enabled = true
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
