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
