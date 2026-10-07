extends Node
## Movement-follow tactical orbit and mouse-look close view.
const MOVEMENT_FOLLOW := preload("res://scripts/camera/CameraMovementFollow.gd")
const MOUSE_VIEW := preload("res://scripts/camera/CameraMouseView.gd")

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
@export_range(0.1,0.9) var visibility_screen_diameter := 0.5
@export_range(0.0, 1.0) var obstruction_opacity := 0.0

var _yaw := 0.0
var _mouse_orbit := 0.0
var _visibility: CameraVisibilityBubble
var _follow := MOVEMENT_FOLLOW.new()
var _close := MOUSE_VIEW.new()
var _pitch := MOUSE_VIEW.DEFAULT_PITCH
var _look_captured := false
var _crosshair: Control
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

class Crosshair extends Control:
	func _draw() -> void:
		for endpoint: Vector2 in [Vector2(-7,0),Vector2(7,0),Vector2(0,-7),Vector2(0,7)]:
			var start := endpoint.normalized()*3.0
			draw_line(start,endpoint,Color(0,0,0,.8),3.0,true)
			draw_line(start,endpoint,Color(1,1,1,.9),1.0,true)

func _ready() -> void:
	if camera == null:
		camera = get_node(".") as Camera3D
	if camera != null and target != null:
		reset_orbit()
		camera.fov = 50.0
	_visibility = CameraVisibilityBubble.new()
	add_child(_visibility)
	var cursor_layer := CanvasLayer.new()
	cursor_layer.layer = 100
	add_child(cursor_layer)
	_edge_cursor = EdgeCursor.new()
	_edge_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_edge_cursor.hide()
	cursor_layer.add_child(_edge_cursor)
	_crosshair = Crosshair.new()
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cursor_layer.add_child(_crosshair)
	_apply_view()

func _input(event: InputEvent) -> void:
	if _forwarding_pointer: return
	if camera == null or not camera.is_current(): return
	if not tactical_view:
		if _look_captured and event is InputEventMouseMotion:
			_apply_look_motion(event.relative)
			get_viewport().set_input_as_handled()
		return
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

func _apply_look_motion(relative: Vector2) -> void:
	var gain := drag_radians_per_pixel(get_viewport().get_visible_rect().size,camera.fov,
		camera.keep_aspect == Camera3D.KEEP_WIDTH)*mouse_sensitivity
	_yaw -= relative.x*gain
	_pitch = clampf(_pitch+relative.y*gain,deg_to_rad(-60),deg_to_rad(75))

func facing_direction(origin: Vector3) -> Vector2:
	if tactical_view:
		return PlayerController.cursor_direction(camera,pointing_position(),origin)
	var forward := -camera.global_basis.z
	return Vector2(forward.x,forward.z).normalized()

func pointing_position() -> Vector2:
	if not tactical_view: return get_viewport().get_visible_rect().size/2
	return _pointer if _have_pointer or _edge_captured else get_viewport().get_mouse_position()

func _unhandled_input(event: InputEvent) -> void:
	if camera == null or not camera.is_current(): return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F7:
		toggle_view()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and (_edge_captured or _look_captured):
		_release_edge(true)
		_release_look()
		_edge_enabled = false
		get_viewport().set_input_as_handled()
	elif not tactical_view and event is InputEventMouseButton and event.pressed:
		_begin_look()
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

func _begin_look() -> void:
	if _look_captured: return
	if DisplayServer.get_name() != "headless" and not get_window().has_focus(): return
	_previous_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_look_captured = true

func _release_look() -> void:
	if not _look_captured: return
	_look_captured = false
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED: Input.mouse_mode = _previous_mouse_mode

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_PAUSED:
		_release_edge()
		_release_look()

func _exit_tree() -> void:
	_release_edge()
	_release_look()

## Every rendered frame, not every physics tick: the display runs faster
## than (and out of step with) 60 Hz physics, so a tick-driven camera moved
## in uneven steps and a mouse turn waited for the next tick. The target is
## drawn interpolated between ticks (camera_follow_position).
func _process(delta: float) -> void:
	if _look_captured and (tactical_view or not is_instance_valid(target)
			or not is_instance_valid(camera) or not camera.is_current()
			or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED):
		_release_look()
	if _crosshair != null:
		_crosshair.visible = not tactical_view and is_instance_valid(camera) and camera.is_current()
		_crosshair.position = get_viewport().get_visible_rect().size/2
	if _edge_captured and (not tactical_view or not is_instance_valid(target)
			or not is_instance_valid(camera) or not camera.is_current()
			or (DisplayServer.get_name() != "headless"
				and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED)):
		_release_edge()
	if not is_instance_valid(camera) or not is_instance_valid(target):
		if _visibility != null: _visibility.clear()
		return
	var pos := target.global_position
	if target.has_method("camera_follow_position"):
		pos = target.camera_follow_position()
	if not tactical_view:
		_visibility.clear()
		_yaw += Input.get_axis(act_orbit_left,act_orbit_right)*orbit_speed_rad*delta
		_close.update_view(camera,target,pos,_yaw,_pitch,delta)
		return
	_yaw = _follow.update_heading(pos,_yaw,delta)
	_yaw += _mouse_orbit + Input.get_axis(act_orbit_left, act_orbit_right) * orbit_speed_rad * delta
	_mouse_orbit = 0.0
	camera.global_position = pos + Vector3(sin(_yaw) * distance, height, cos(_yaw) * distance)
	camera.look_at(pos + Vector3.UP * look_height, Vector3.UP)
	if visibility_bubble_enabled and camera.is_current():
		_visibility.update_bubble(camera, target, pos,
			CameraVisibilityBubble.screen_radius(camera,pos,visibility_screen_diameter), obstruction_opacity, delta)
	else:
		_visibility.clear()

func toggle_view() -> void:
	tactical_view = not tactical_view
	_apply_view()

func _apply_view() -> void:
	if not is_instance_valid(camera) or not is_instance_valid(target): return
	_release_edge(true)
	_release_look()
	_edge_enabled = true
	_mouse_orbit = 0.0
	_follow.reset()
	_close.reset()
	camera.fov = 50.0 if tactical_view else 75.0
	if not tactical_view: _begin_look()
	_process(0.0)

func reset_orbit() -> void:
	if camera == null or target == null: return
	# Review/teleport callers place the eye before resetting its orbit.
	var offset := camera.global_position-target.global_position
	_yaw = atan2(offset.x,offset.z)
	_mouse_orbit = 0.0
	_follow.reset()
	_close.reset()
