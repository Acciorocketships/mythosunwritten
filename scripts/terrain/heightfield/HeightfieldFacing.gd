class_name HeightfieldFacing
extends RefCounted

## World (dx, dz) tile-offset -> socket name, grounded in the tile scene's socket
## markers (see test_heightfield_facing). Diagonals included for inner-corner
## detection. Filled from the CliffSide.tscn socket positions.
##
## Discovery output (CliffSide.tscn, Sockets node, Marker3D positions):
##   front      -> (0, 0, -12)   => -Z => Vector2i(0, -1)
##   back       -> (0, 0,  12)   => +Z => Vector2i(0,  1)
##   left       -> (-12, 0, 0)   => -X => Vector2i(-1, 0)
##   right      -> ( 12, 0, 0)   => +X => Vector2i( 1, 0)
##   frontleft  -> (-12, 0, -12) =>      Vector2i(-1, -1)
##   frontright -> ( 12, 0, -12) =>      Vector2i( 1, -1)
##   backleft   -> (-12, 0,  12) =>      Vector2i(-1,  1)
##   backright  -> ( 12, 0,  12) =>      Vector2i( 1,  1)
const OFFSET_TO_SOCKET: Dictionary = {
	Vector2i(0, -1): "front",
	Vector2i(1, 0): "right",
	Vector2i(0, 1): "back",
	Vector2i(-1, 0): "left",
	Vector2i(1, -1): "frontright",
	Vector2i(1, 1): "backright",
	Vector2i(-1, 1): "backleft",
	Vector2i(-1, -1): "frontleft",
}


static func socket_to_offset(socket_name: String) -> Vector2i:
	for off in OFFSET_TO_SOCKET.keys():
		if OFFSET_TO_SOCKET[off] == socket_name:
			return off
	return Vector2i.ZERO


## Yaw (radians) to apply so a variant's canonical wall set lands on its actual
## missing sides: PI/2 * ((4 - steps) % 4).
static func yaw_for_rotation_steps(rotation_steps: int) -> float:
	return PI * 0.5 * float((4 - rotation_steps) % 4)
