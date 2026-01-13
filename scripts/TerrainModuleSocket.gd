extends Resource
class_name TerrainModuleSocket

var piece: TerrainModuleInstance
var socket_name: String

func _init(_piece, _socket_name) -> void:
	piece = _piece
	socket_name = _socket_name
	
var socket:
	get:
		return piece.sockets[socket_name]

func get_piece_position() -> Vector3:
	# Piece origin in world space
	return piece.transform.origin

func get_socket_position() -> Vector3:
	var s : Node3D = socket
	assert(s != null)
	assert(piece.root != null)
	# socket -> root local transform
	var local_tf := Helper.to_root_tf(s, piece.root)
	# piece.transform is root's world transform
	return Helper.snap_vec3((piece.transform * local_tf).origin)

func _to_string() -> String:
	var tags := ",".join(piece.def.tags.tags)
	var pos := piece.root.global_position if piece.root else piece.transform.origin
	var gpos := get_socket_position() if piece.root else Vector3.ZERO
	return "TerrainModuleSocket(tags=[%s], socket=%s, piece_pos=%s, socket_pos=%s)" % [
		tags,
		socket_name,
		str(pos),
		str(gpos),
	]
