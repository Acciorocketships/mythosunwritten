class_name CameraMouseView
extends RefCounted
## Mouse-selected heading stays fixed during movement; collision only shortens
## the boom. The spring releases outwards without pulling through obstacles.
const PIVOT_HEIGHT := 3.2
const BOOM_LENGTH := 8.2 # original 8 m horizontal / 5 m high framing
const DEFAULT_PITCH := 0.22131444 # atan2(5 - pivot, 8)
var _obstruction := CameraObstructionSolver.new()
var _length := -1.0

func reset() -> void:
	_length = -1.0

func update_view(camera: Camera3D, target: Node3D, pos: Vector3,
		yaw: float, pitch: float, delta: float) -> void:
	var space := camera.get_world_3d().direct_space_state
	var excluded: Array[RID] = []
	if target is CollisionObject3D: excluded.append(target.get_rid())
	var pivot := _obstruction.resolve_ceiling(space,pos,1.0,PIVOT_HEIGHT,excluded)
	var direction := Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))
	var safe := _obstruction.resolve_boom(space,pivot,pivot+direction*BOOM_LENGTH,excluded)
	var length := safe.distance_to(pivot)
	if _length < 0.0 or length < _length: _length = length
	else: _length = move_toward(_length,length,6.0*delta)
	camera.global_position = pivot+direction*_length
	# A boom fully inside collision must still retain a finite chosen heading.
	camera.global_basis = Basis.looking_at(-direction,Vector3.UP)
