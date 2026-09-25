class_name CameraMovementFollow
extends RefCounted
## The original 8 m follow camera's planar motion, used only for its heading.
## Keeping that reference radius makes tactical rotation independent of zoom.
var _previous := Vector3.ZERO
var _position := Vector3.ZERO
var _velocity := Vector3.ZERO
var _back := Vector3.ZERO
var _initialized := false

func reset() -> void:
	_initialized = false
	_velocity = Vector3.ZERO
	_back = Vector3.ZERO

func update_heading(pos: Vector3, yaw: float, delta: float) -> float:
	if not _initialized or delta <= 0.0:
		_previous = pos
		_position = pos + Vector3(sin(yaw)*8.0,0,cos(yaw)*8.0)
		_initialized = true
		return yaw
	# Carry manual orbit into the reference camera without losing its radius.
	var old_offset := _position-_previous
	old_offset.y = 0.0
	_position = _previous+Vector3(sin(yaw),0,cos(yaw))*old_offset.length()
	var velocity := (pos-_previous)/delta
	velocity.y = 0.0
	_velocity = .9*_velocity+.1*velocity
	_previous = pos
	var previous_direction := _position-pos
	previous_direction.y = 0.0
	previous_direction = previous_direction.normalized() if previous_direction.length_squared() > 1e-9 else Vector3.BACK
	var speed := maxf(_velocity.length(),velocity.length())
	if _back.length_squared() == 0.0: _back = previous_direction
	if speed > .0001: _back = -_velocity/speed
	var behind := _back if speed > .0001 else _back.normalized()
	var desired := pos+(.8*previous_direction+.2*behind).normalized()*8.0
	var alpha := 1.0-exp(-speed*delta)
	var step := (_position.lerp(desired,alpha)-_position).limit_length(15.0*delta)
	var radial := _position+step-pos
	radial.y = 0.0
	if radial.length_squared() > 1e-9:
		radial = radial.lerp(radial.normalized()*8.0,alpha)
	_position = pos+radial
	return atan2(radial.x,radial.z)
