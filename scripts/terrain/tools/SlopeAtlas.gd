# scripts/terrain/tools/SlopeAtlas.gd
# Samples the grass (top-surface) texel UV from an existing KayKit top piece so
# generated slope meshes map into the exact same palette swatch.
class_name SlopeAtlas
extends RefCounted

const TOP_VISUAL := "res://terrain/environment/visuals/kaykit/kaykit_terrain_top_center.tres"
const CLIFF_VISUAL := "res://terrain/environment/visuals/kaykit/kaykit_cliff_wall.tres"

static func grass_uv() -> Vector2:
	var mesh := _mesh(TOP_VISUAL)
	var arrays := mesh.surface_get_arrays(0)
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
	return result

static func cliff_uv() -> Vector2:
	var mesh := _mesh(CLIFF_VISUAL)
	var arrays := mesh.surface_get_arrays(0)
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
	return result

static func _mesh(path: String) -> Mesh:
	var visual := load(path) as EnvironmentVisual
	assert(visual != null and not visual.pieces.is_empty(), "invalid environment visual: %s" % path)
	return visual.pieces[0].mesh
