extends Node

## The first frame that shows newly streamed geometry was slow (a 130 ms frame
## on the first turn after loading, then 30-50 ms ones): its pipelines,
## specializations and GPU buffers are made when it is first drawn, not when it
## is committed. This tiny viewport shares the game's World3D and, once per
## committed chunk or feature block, draws that area from above for one frame,
## so the game camera later sees it already prepared. One small extra render
## (and its shadow pass) every few seconds while new terrain arrives.
## Between those, every ORBIT_INTERVAL_MSEC it draws from the game camera's
## own position turned 90, 180 or 270 degrees (cycling), so whatever is near
## the player is drawn from every side at the distances, LODs and visibility
## ranges the game camera will use, before the player turns to it. Three views
## finish a stationary pose; movement or new geometry invalidates that coverage.
## Main thread only. FieldTerrainStreamer owns it.

const SIZE := Vector2i(96, 54)
## Above the area, looking down steeply enough that a whole 192 m chunk and
## its neighbours' edges are in view.
const HEIGHT := 140.0
const BACK := 60.0
const FOV := 100.0

var _viewport: SubViewport
var _camera: Camera3D
const ORBIT_INTERVAL_MSEC := 500
const ORBIT_MOVE_DISTANCE := 8.0
var _queue: Array[Vector3] = []
var _orbit_step := 0
var _last_orbit_msec := 0
var _orbit_anchor := Vector3.INF
var _orbit_remaining := 3
var _rendering := false
var warmed := 0


func setup(world: World3D, msaa: Viewport.MSAA) -> void:
	_viewport = SubViewport.new()
	_viewport.name = &"FirstViewWarmer"
	_viewport.size = SIZE
	_viewport.world_3d = world
	_viewport.msaa_3d = msaa
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_viewport.audio_listener_enable_3d = false
	_camera = Camera3D.new()
	_camera.fov = FOV
	_camera.far = 1200.0
	_viewport.add_child(_camera)
	add_child(_viewport)


## Draw the area around `centre` once, soon (one area per frame).
func warm(centre: Vector3) -> void:
	_queue.append(centre)
	_orbit_remaining = 3


func pending() -> int:
	return _queue.size()


func _next_orbit_due(position: Vector3, now_msec: int) -> bool:
	if not _orbit_anchor.is_finite() or position.distance_to(_orbit_anchor) >= ORBIT_MOVE_DISTANCE:
		_orbit_anchor = position
		_orbit_remaining = 3
	if _orbit_remaining == 0 or now_msec - _last_orbit_msec < ORBIT_INTERVAL_MSEC:
		return false
	_last_orbit_msec = now_msec
	_orbit_remaining -= 1
	return true


func _process(_delta: float) -> void:
	if _viewport == null:
		return
	if _rendering:
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_rendering = false
	var main := get_viewport()
	var game_camera := main.get_camera_3d()
	if _queue.is_empty():
		if game_camera == null or not _next_orbit_due(game_camera.global_position,Time.get_ticks_msec()):
			return
		_orbit_step = _orbit_step % 3 + 1
		_camera.fov = game_camera.fov
		_camera.global_transform = Transform3D(game_camera.global_basis.rotated(Vector3.UP,
			_orbit_step * PI * 0.5), game_camera.global_position)
	else:
		var centre: Vector3 = _queue.pop_front()
		_camera.fov = FOV
		_camera.global_position = centre + Vector3(0.0, HEIGHT, BACK)
		_camera.look_at(centre, Vector3.UP)
	_viewport.msaa_3d = main.msaa_3d
	_camera.current = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_rendering = true
	warmed += 1
