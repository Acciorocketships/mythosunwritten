extends Node

@export var camera: Camera3D
@export var target: Node3D

# Framing
@export var distance: float = 8.0
@export var height: float = 5.0

# Orbit (Q/E)
@export var orbit_speed_rad: float = 2          # radians per second
@export var act_orbit_left := "camera_left"       # bind to Q
@export var act_orbit_right := "camera_right"     # bind to E

# Follow behavior
@export var ema_alpha: float = 0.1 # when strafe ratio is close to 0, increasing this makes it "snappier"
@export var strafe_ratio: float = 1.3 	# if 0, camera moves behind direction of motion. if 1, camera moves to keep same angle
@export var follow_gain: float = 1.0 # how much to follow the player. if 0, it stays in the same place
@export var max_speed: float = 15.0 

var _prev_pos: Vector3
var _have_prev := false
var _v_ema := Vector3.ZERO
var _last_back_dir := Vector3.ZERO

func _process(delta: float) -> void:
	if camera == null or target == null:
		return

	# --- sample and smooth target velocity ---
	var pos := target.global_position
	var v: Vector3 = Vector3.ZERO
	if _have_prev:
		v = (pos - _prev_pos) / max(delta, 1e-6)
		_v_ema = (1-ema_alpha) * _v_ema + ema_alpha * v
	else:
		_have_prev = true
	var prev_dir : Vector3 = (camera.global_position -_prev_pos).normalized()
	_prev_pos = pos
	var speed : float = max(_v_ema.length(), v.length())

	# --- determine "behind" direction based on smoothed velocity ---
	var back_dir: Vector3
	if _last_back_dir.length() == 0:
		_last_back_dir = camera.position - target.position
		_last_back_dir.y = 0
		_last_back_dir = _last_back_dir.normalized()
	if speed > 1e-4:
		back_dir = (-_v_ema / speed)
		_last_back_dir = back_dir
	else:
		back_dir = _last_back_dir.normalized()

	# --- base desired position directly behind the target ---
	var center := pos + Vector3.UP * height
	var disp = (strafe_ratio * prev_dir + (1-strafe_ratio) * back_dir).normalized() * distance
	var desired : Vector3 = center + disp

	# --- smooth movement (only when moving) ---
	var new_pos := camera.global_position
	var gain := follow_gain * speed
	var alpha := 1.0 - exp(-gain * delta)
	var lerped := camera.global_position.lerp(desired, alpha)
	var step := lerped - camera.global_position
	var max_step := max_speed * delta
	new_pos = camera.global_position + step.limit_length(max_step) if step.length() > max_step else lerped

	# --- snap to circle (radius & height) ---
	var radial := new_pos - center
	radial.y = 0.0
	if radial.length_squared() > 1e-9:
		radial = radial.lerp(radial.normalized() * distance, alpha)
		
	# --- apply manual orbit (Q/E) *after* smoothing ---
	var yaw_dir := Input.get_axis(act_orbit_left, act_orbit_right)
	if absf(yaw_dir) > 1e-6:
		var rot_amount := orbit_speed_rad * yaw_dir * delta
		radial = radial.rotated(Vector3.UP, rot_amount)

	camera.global_position = center + radial

	# --- always look at the target ---
	camera.look_at(pos, Vector3.UP)
