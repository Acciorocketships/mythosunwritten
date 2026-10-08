class_name EnvironmentImposter
extends Resource

## Baked distant-tree card set: `frames` azimuth views side by side in each atlas.
@export var albedo: Texture2D            # RGB albedo under white instance tint, A coverage
## RGB: normal * 0.5 + 0.5 in frame f's basis (a = TAU * f / frames): x = frame right
## (cos a, 0, -sin a), y = world up, z = toward the capture eye (sin a, 0, cos a). A: tint response.
@export var normal: Texture2D
@export var frames: int = 8
@export var size: Vector2 = Vector2.ONE  # world metres covered by one frame (width, height)
@export var pivot_height: float = 0.0    # metres from the asset origin to the frame's bottom edge (frames are centred on the asset's vertical axis)
@export var crown_centre: Vector3 = Vector3.ZERO
## geometry_signature(visual) of the tree it was captured from; a re-bake that
## changes the tree's geometry or scale must recapture (--imposters-only).
@export var geometry_signature: String = ""

## Fingerprint of the drawn geometry: each piece's local transform, mesh AABB
## and per-surface vertex count (mm precision, so identical re-bakes match).
static func geometry_signature_of(visual: EnvironmentVisual) -> String:
	var parts := PackedStringArray()
	for piece: EnvironmentVisualPiece in visual.pieces:
		if piece == null or piece.mesh == null:
			parts.append("-")
			continue
		var t := piece.local_transform
		var aabb := piece.mesh.get_aabb()
		var counts := PackedStringArray()
		for surface in piece.mesh.get_surface_count():
			var count: int = piece.mesh.surface_get_array_len(surface) if piece.mesh is ArrayMesh \
				else (piece.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			counts.append(str(count))
		parts.append("%s|%s|%s|%s" % [_mm([t.basis.x, t.basis.y, t.basis.z, t.origin]),
			_mm([aabb.position, aabb.size]), ",".join(counts), piece.mesh.get_surface_count()])
	return ";".join(parts).md5_text()

static func _mm(vectors: Array) -> String:
	var out := PackedStringArray()
	for v: Vector3 in vectors:
		out.append("%d,%d,%d" % [roundi(v.x * 1000.0), roundi(v.y * 1000.0), roundi(v.z * 1000.0)])
	return " ".join(out)
