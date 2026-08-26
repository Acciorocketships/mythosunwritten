@tool
extends SceneTree

## The asset-by-asset reading of the KayKit pack, for diffing a re-bake instead
## of trusting it. Every fact a consumer can see is printed: the descriptor's
## own fields, each visual piece's mesh (surfaces, vertices, indices, AABB,
## format) with hashes of its vertex and UV streams, its material and every
## `BaseMaterial3D` parameter, and each collision piece's shape class, extent
## and transform. Deterministic ordering and fixed-width floats, so `diff` of
## two runs IS the comparison.
##
## Written for task H2c, where a manifest edit re-ran all 29 assets through a
## ten-version tool drift and the pack had to be proven unchanged except in the
## two places the change was aimed at. Run it before a re-bake, run it after,
## diff the two.
##
## Usage:
##   Godot --headless --path . -s res://tools/environment_bake/kaykit_pack_probe.gd

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var dir := DirAccess.open("res://terrain/environment/catalog/descriptors")
	if dir == null:
		printerr("no descriptor directory")
		quit(1)
		return
	var names := dir.get_files()
	names.sort()
	for file_name: String in names:
		if not file_name.begins_with("kaykit_") or not file_name.ends_with(".tres"):
			continue
		_dump(load("res://terrain/environment/catalog/descriptors/%s" % file_name))
	quit(0)


func _dump(descriptor: EnvironmentAssetDescriptor) -> void:
	print("ASSET %s" % String(descriptor.id))
	print("  tags %s" % str(descriptor.tags))
	print("  aabb %s" % _aabb(descriptor.measured_aabb))
	print("  tint %s instance_color %s" % [String(descriptor.tint_group),
		str(descriptor.supports_instance_color)])
	print("  declared_collision_pieces %d" % descriptor.collision_piece_count)
	print("  ground_contact %d" % descriptor.ground_contact_points.size())
	print("  visual %s" % descriptor.visual_path)
	var visual := load(descriptor.visual_path) as EnvironmentVisual
	if visual == null:
		print("  VISUAL MISSING")
		return
	print("  pieces %d collisions %d" % [visual.pieces.size(),
		visual.collisions.size()])
	for index in visual.pieces.size():
		var piece := visual.pieces[index]
		var mesh := piece.mesh
		print("  piece %d xform %s use_instance_color %s override %s" % [index,
			_xform(piece.local_transform), str(piece.use_instance_color),
			"" if piece.material_override == null \
				else piece.material_override.resource_path])
		if mesh == null:
			print("    MESH MISSING")
			continue
		print("    mesh %s surfaces %d aabb %s" % [mesh.resource_path,
			mesh.get_surface_count(), _aabb(mesh.get_aabb())])
		for surface in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(surface)
			var vertices := (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			var indices := (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size()
			var material := mesh.surface_get_material(surface)
			print("    surface %d verts %d indices %d format %d" % [surface,
				vertices, indices, mesh.surface_get_format(surface)])
			print("      vertex_hash %s" % _hash_vec3(
				arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array))
			print("      uv_hash %s" % _hash_vec2(arrays[Mesh.ARRAY_TEX_UV]))
			print("      material %s" % _material(material))
	for index in visual.collisions.size():
		var collision := visual.collisions[index]
		var shape := collision.shape
		print("  collision %d xform %s" % [index, _xform(collision.local_transform)])
		if shape == null:
			print("    SHAPE MISSING")
			continue
		print("    shape %s %s" % [shape.get_class(), shape.resource_path])
		if shape is ConvexPolygonShape3D:
			var points := (shape as ConvexPolygonShape3D).points
			print("    points %d hash %s bounds %s" % [points.size(),
				_hash_vec3(points), _aabb(_points_aabb(points))])
		elif shape is BoxShape3D:
			print("    size %s" % _vec((shape as BoxShape3D).size))
		elif shape is CylinderShape3D:
			var cylinder := shape as CylinderShape3D
			print("    height %.6f radius %.6f" % [cylinder.height,
				cylinder.radius])
		elif shape is CapsuleShape3D:
			var capsule := shape as CapsuleShape3D
			print("    height %.6f radius %.6f" % [capsule.height,
				capsule.radius])
		elif shape is ConcavePolygonShape3D:
			var faces := (shape as ConcavePolygonShape3D).get_faces()
			print("    faces %d hash %s" % [faces.size(), _hash_vec3(faces)])


func _material(material: Material) -> String:
	if material == null:
		return "<none>"
	var out := "%s %s" % [material.get_class(), material.resource_path]
	if material is BaseMaterial3D:
		var standard := material as BaseMaterial3D
		var texture := standard.albedo_texture
		out += " albedo %s tex %s cull %d shading %d" % [
			_color(standard.albedo_color),
			"<none>" if texture == null else texture.resource_path,
			int(standard.cull_mode), int(standard.shading_mode)]
		out += " vcol %s roughness %.4f metallic %.4f" % [
			str(standard.vertex_color_use_as_albedo), standard.roughness,
			standard.metallic]
	return out


func _points_aabb(points: PackedVector3Array) -> AABB:
	if points.is_empty():
		return AABB()
	var out := AABB(points[0], Vector3.ZERO)
	for point: Vector3 in points:
		out = out.expand(point)
	return out


func _hash_vec3(values: Variant) -> String:
	var points := values as PackedVector3Array
	if points == null or points.is_empty():
		return "<empty>"
	var text := ""
	for point: Vector3 in points:
		text += "%.5f,%.5f,%.5f;" % [point.x, point.y, point.z]
	return text.sha256_text().left(16)


func _hash_vec2(values: Variant) -> String:
	if not values is PackedVector2Array:
		return "<none>"
	var points := values as PackedVector2Array
	if points.is_empty():
		return "<empty>"
	var text := ""
	for point: Vector2 in points:
		text += "%.5f,%.5f;" % [point.x, point.y]
	return text.sha256_text().left(16)


func _vec(value: Vector3) -> String:
	return "(%.6f, %.6f, %.6f)" % [value.x, value.y, value.z]


func _color(value: Color) -> String:
	return "(%.4f, %.4f, %.4f, %.4f)" % [value.r, value.g, value.b, value.a]


func _aabb(value: AABB) -> String:
	return "pos%s size%s" % [_vec(value.position), _vec(value.size)]


func _xform(value: Transform3D) -> String:
	return "x%s y%s z%s o%s" % [_vec(value.basis.x), _vec(value.basis.y),
		_vec(value.basis.z), _vec(value.origin)]
