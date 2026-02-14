extends Node
class_name PositionIndex

# Keyed by snapped position, value is all sockets at that position.
# Note: GDScript doesn't reliably support nested generic types like Dictionary[Vector3, Array[Foo]].
var store: Dictionary[Vector3, Array] = {}

func insert(piece_socket: TerrainModuleSocket) -> void:
	# Use world position computed from the piece transform and local socket transform.
	# This avoids relying on Node3D.global_position, which requires the node to be inside the scene tree.
	var k: Vector3 = Helper.snap_vec3(piece_socket.get_socket_position())
	var arr: Array = store.get(k, [])
	arr.append(piece_socket)
	store[k] = arr

func query(pos: Vector3) -> TerrainModuleSocket:
	var arr: Array = store.get(Helper.snap_vec3(pos), [])
	if arr.is_empty():
		return null
	return arr[0] as TerrainModuleSocket

func query_other(pos: Vector3, piece: TerrainModuleInstance) -> TerrainModuleSocket:
	var arr: Array = store.get(Helper.snap_vec3(pos), [])
	for ps in arr:
		if ps != null and ps.piece != piece:
			return ps as TerrainModuleSocket
	return null
