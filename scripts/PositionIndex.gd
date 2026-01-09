extends Node
class_name PositionIndex

# Keyed by quantized position, value is Array of [TerrainModuleInstance, Marker3D]
var store: Dictionary[Vector3, TerrainModuleSocket] = {}

# Tune this to your grid/socket spacing tolerance.
# If your sockets are on a 1-unit grid, set to 1.0; if they’re 0.5, use 0.5, etc.
const SNAP: float = 0.5

func _key(pos: Vector3) -> Vector3:
	# Quantize so floats don't break hashing/equality
	return Vector3(
		snappedf(pos.x, SNAP),
		snappedf(pos.y, SNAP),
		snappedf(pos.z, SNAP)
	)

func insert(piece_socket: TerrainModuleSocket) -> void:
	var k : Vector3 = _key(piece_socket.socket.global_position)
	store[k] = piece_socket

func query(pos: Vector3) -> TerrainModuleSocket:
	return store.get(_key(pos), null)
