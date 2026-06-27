# scripts/terrain/tools/SlopeAtlas.gd
# Samples the grass (top-surface) texel UV from an existing KayKit top piece so
# generated slope meshes map into the exact same palette swatch.
class_name SlopeAtlas
extends RefCounted

const TOP_PIECE := "res://terrain/gltf/hill/hill_top_e_center_color_12.tscn"
const CLIFF_PIECE := "res://terrain/gltf/hill/hill_cliff_tall_h_side_color_12.tscn"

static func grass_uv() -> Vector2:
	var packed := load(TOP_PIECE) as PackedScene
	var inst := packed.instantiate()
	var mi := _first_mesh_instance(inst)
	assert(mi != null, "no MeshInstance3D in top piece")
	var arrays := mi.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	# Average UVs of up-facing (grass top) vertices.
	var sum := Vector2.ZERO
	var n := 0
	for i in verts.size():
		if normals.size() == verts.size() and uvs.size() == verts.size() and normals[i].y > 0.9:
			sum += uvs[i]
			n += 1
	var result := (sum / n) if n > 0 else (uvs[0] if uvs.size() > 0 else Vector2.ZERO)
	inst.free()
	return result

static func cliff_uv() -> Vector2:
	var packed := load(CLIFF_PIECE) as PackedScene
	var inst := packed.instantiate()
	var mi := _first_mesh_instance(inst)
	assert(mi != null, "no MeshInstance3D in cliff piece")
	var arrays := mi.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var sum := Vector2.ZERO
	var n := 0
	for i in verts.size():
		if normals.size() == verts.size() and uvs.size() == verts.size() and absf(normals[i].y) < 0.3:
			sum += uvs[i]
			n += 1
	var result := (sum / n) if n > 0 else (uvs[0] if uvs.size() > 0 else Vector2.ZERO)
	inst.free()
	return result

static func _first_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for c in node.get_children():
		var found := _first_mesh_instance(c)
		if found != null:
			return found
	return null
