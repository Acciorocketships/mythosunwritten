extends RefCounted
## Measured native facades in fabric coordinates. Roofs and conservative private
## reservation boxes are not walls; test actual baked wall/opening triangles.


static func build(fabric: SettlementFabricPlan, catalog: EnvironmentCatalog) -> Array[Dictionary]:
	var surfaces: Array[Dictionary] = []
	var meshes := {}
	for unit: FabricUnit in fabric.units:
		var recipe := fabric.recipe(unit.recipe_id)
		if not recipe.has_tag(&"native_grammar"):
			continue
		for part: Dictionary in recipe.placements:
			var id := String(part.asset_id)
			var module := id.trim_prefix("pure_village.native.")
			if not (
				module.begins_with("wall_")
				or module.begins_with("wallstone_")
				or module.begins_with("window_")
				or module.begins_with("door_")
			):
				continue
			var descriptor := catalog.descriptor(part.asset_id)
			if not meshes.has(id):
				var visual: EnvironmentVisual = load(descriptor.visual_path)
				var faces := PackedVector3Array()
				for piece: EnvironmentVisualPiece in visual.pieces:
					for vertex in piece.mesh.get_faces():
						faces.append(piece.local_transform * vertex)
				meshes[id] = faces
			var pose: Transform3D = unit.transform() * part.transform
			surfaces.append(
				{
					"inverse": pose.affine_inverse(),
					"bounds": descriptor.measured_aabb,
					"faces": meshes[id]
				}
			)
	return surfaces


static func blocks_ray(surfaces: Array[Dictionary], start: Vector3, end: Vector3) -> bool:
	for surface in surfaces:
		var a: Vector3 = surface.inverse * start
		var b: Vector3 = surface.inverse * end
		if surface.bounds.intersects_segment(a, b) == null:
			continue
		var faces: PackedVector3Array = surface.faces
		for index in range(0, faces.size(), 3):
			if (
				Geometry3D.segment_intersects_triangle(
					a, b, faces[index], faces[index + 1], faces[index + 2]
				)
				!= null
			):
				return true
	return false
