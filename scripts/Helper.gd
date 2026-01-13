extends RefCounted
class_name Helper

const SNAP_POS: float = 1.0

# Node3D -> transform relative to a given root (no scene tree needed)
static func to_root_tf(n: Node3D, root: Node3D) -> Transform3D:
	var tf := n.transform
	var p := n.get_parent()
	while p != null and p != root:
		if p is Node3D:
			tf = (p as Node3D).transform * tf
		p = p.get_parent()
	return tf


# Socket world position given a piece/world transform and socket node
static func socket_world_pos(piece_tf: Transform3D, socket_node: Node3D, root: Node3D) -> Vector3:
	return snap_vec3((piece_tf * to_root_tf(socket_node, root)).origin)

static func snap_vec3(v: Vector3, snap: float = SNAP_POS) -> Vector3:
	var new_pos = Vector3(
		snappedf(v.x, snap),
		snappedf(v.y, snap),
		snappedf(v.z, snap)
	)
	return new_pos

static func snap_transform_origin(tf: Transform3D, snap: float = SNAP_POS) -> Transform3D:
	var out := tf
	out.origin = snap_vec3(tf.origin, snap)
	return out
