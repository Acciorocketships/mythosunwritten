# Surface-decoration sockets must sit ON the sloped walkable surface, not at the
# old flat y=0. The slope-cliff variant scenes are baked by copying each original
# sheer-cliff `Sockets` node verbatim; the top-surface sockets (topcenter/topfront/
# topback/topleft/topright) kept y=0, but the new sloped geometry drops the surface
# below 0 wherever a socket sits over a slope band. Decorations attach socket-to-
# socket (no raycast), so any such socket left at y=0 makes its decoration float.
#
# This guard samples each baked slope scene's ACTUAL mesh surface (triangle-accurate,
# no physics, independent of the profile math) at every top* socket's (x,z) and
# asserts the socket's local Y is on that surface. Adjacency sockets (front/back/
# left/right, diagonals, bottom) are intentionally left at y=0 for adjacency parity
# and are NOT checked.
extends GutTest

const SCENE_DIR := "res://terrain/scenes/slope"
const TOL := 0.4   # mesh is 1u-resolution; socket must sit within this of the surface

func _scene_paths() -> Array:
	var out := []
	var d := DirAccess.open(SCENE_DIR)
	assert_not_null(d, "cannot open %s" % SCENE_DIR)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".tscn"):
			out.append("%s/%s" % [SCENE_DIR, f])
	out.sort()
	return out

func _mesh_instances(node: Node, out: Array) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		_mesh_instances(c, out)

# Gather every triangle of the tile in tile-local space.
func _gather(root: Node3D) -> Array:
	var tris := []
	var mis := []
	_mesh_instances(root, mis)
	for mi in mis:
		var mesh: Mesh = mi.mesh
		if mesh == null:
			continue
		var xf: Transform3D = _local_xf(mi, root)
		for s in range(mesh.get_surface_count()):
			var arr: Array = mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			if verts.is_empty():
				continue
			var idx_v = arr[Mesh.ARRAY_INDEX]
			var idx := PackedInt32Array()
			if idx_v == null or (idx_v as PackedInt32Array).is_empty():
				for i in range(verts.size()):
					idx.append(i)
			else:
				idx = idx_v
			for t in range(0, idx.size() - 2, 3):
				tris.append([xf * verts[idx[t]], xf * verts[idx[t + 1]], xf * verts[idx[t + 2]]])
	return tris

func _local_xf(node: Node3D, root: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var n: Node3D = node
	while n != root and n != null:
		xf = n.transform * xf
		n = n.get_parent() as Node3D
	return xf

func _tri_h(p: Vector2, a: Vector3, b: Vector3, c: Vector3) -> float:
	var det := (b.z - c.z) * (a.x - c.x) + (c.x - b.x) * (a.z - c.z)
	if absf(det) < 1e-9:
		return -INF
	var l1 := ((b.z - c.z) * (p.x - c.x) + (c.x - b.x) * (p.y - c.z)) / det
	var l2 := ((c.z - a.z) * (p.x - c.x) + (a.x - c.x) * (p.y - c.z)) / det
	var l3 := 1.0 - l1 - l2
	var e := -0.001
	if l1 < e or l2 < e or l3 < e:
		return -INF
	return l1 * a.y + l2 * b.y + l3 * c.y

# Highest triangle covering (x,z) = the walkable top surface.
func _surface_h(tris: Array, x: float, z: float) -> float:
	var best := -INF
	var p := Vector2(x, z)
	for tri in tris:
		var h := _tri_h(p, tri[0], tri[1], tri[2])
		if h > best:
			best = h
	return best

func test_top_sockets_sit_on_surface() -> void:
	var offenders := []
	for path in _scene_paths():
		var packed := load(path) as PackedScene
		if packed == null:
			continue
		var root := packed.instantiate() as Node3D
		add_child_autofree(root)
		var sockets := root.get_node_or_null("Sockets")
		if sockets == null:
			continue
		var tris := _gather(root)
		for m in sockets.get_children():
			if not (m is Marker3D) or not String(m.name).begins_with("top"):
				continue
			var p: Vector3 = m.transform.origin
			var surf := _surface_h(tris, p.x, p.z)
			if surf < -1e8:
				offenders.append("%s: %s at (%.0f,%.0f) has no surface below it" % [
					path.get_file(), m.name, p.x, p.z])
				continue
			if absf(p.y - surf) > TOL:
				offenders.append("%s: %s floats %.2f (socket y=%.2f, surface y=%.2f) at (%.0f,%.0f)" % [
					path.get_file(), m.name, absf(p.y - surf), p.y, surf, p.x, p.z])
		root.queue_free()
	assert_eq(offenders.size(), 0,
		"%d surface-socket(s) not on the slope surface:\n%s" % [
			offenders.size(), "\n".join(PackedStringArray(offenders.slice(0, 25)))])
