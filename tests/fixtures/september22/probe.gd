extends SceneTree
## Identifies the placements seen at canvas pixels of one photo camera.
## Usage: -s probe.gd -- --town=town-e --payload=payload --photo=photo2 --pixels=x:y,x:y [--out=FILE]
const SPOTS := preload("res://tests/fixtures/september22/spots.gd")
func _init() -> void: run.call_deferred()
func run() -> void:
	var town := "town-e"; var name := "payload"; var photo := "photo1"; var out := ""
	var pixels: Array[Vector2] = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--town="): town = arg.trim_prefix("--town=")
		if arg.begins_with("--payload="): name = arg.trim_prefix("--payload=")
		if arg.begins_with("--photo="): photo = arg.trim_prefix("--photo=")
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
		if arg.begins_with("--pixels="):
			for pair in arg.trim_prefix("--pixels=").split(","):
				var p := pair.split(":"); pixels.append(Vector2(float(p[0]), float(p[1])))
	var camera := Camera3D.new()
	var viewport := SubViewport.new()
	viewport.size = SPOTS.SIZE
	root.add_child(viewport)
	viewport.add_child(camera)
	camera.fov = 75
	await process_frame
	var spot: Dictionary = SPOTS.SPOTS[photo]
	camera.position = SPOTS.eye(spot.feet, spot.aim)
	camera.look_at(SPOTS.pivot(spot.feet))
	var data: Dictionary = FileAccess.open("res://docs/qa/2026-09-22-manual/%s/%s.bin" % [town, name], FileAccess.READ).get_var()
	var base: Transform3D = Transform3D.IDENTITY if name == "payload" else data.transform
	var catalog := EnvironmentCatalog.load_default()
	var visuals := {}
	var result := []
	for pixel: Vector2 in pixels:
		var start := camera.project_ray_origin(pixel)
		var direction := camera.project_ray_normal(pixel)
		var hits := []
		for asset: StringName in data.batches:
			var descriptor := catalog.descriptor(asset)
			if descriptor == null: continue
			var batch: Dictionary = data.batches[asset]
			for index in batch.transforms.size():
				var transform: Transform3D = base * batch.transforms[index]
				if (transform * descriptor.measured_aabb).grow(.05).intersects_ray(start, direction) == null: continue
				if not visuals.has(asset): visuals[asset] = load(descriptor.visual_path)
				var nearest := INF
				for piece: EnvironmentVisualPiece in visuals[asset].pieces:
					var faces := EnvironmentBakeGeometry.triangle_faces(piece.mesh, transform * piece.local_transform)
					for i in range(0, faces.size(), 3):
						var hit = Geometry3D.ray_intersects_triangle(start, direction, faces[i], faces[i+1], faces[i+2])
						if hit != null: nearest = minf(nearest, start.distance_to(hit))
				if nearest < INF:
					hits.append({"id": String(batch.ids[index]), "asset": String(asset), "distance": snappedf(nearest, .001),
						"point": str((start + direction * nearest).snappedf(.01)),
						"local_origin": str((base.affine_inverse() * transform).origin) if name == "payload" else str(batch.transforms[index].origin)})
		hits.sort_custom(func(a, b): return a.distance < b.distance)
		result.append({"pixel": str(pixel), "hits": hits.slice(0, 6)})
		print("PIXEL ", pixel)
		for hit in hits.slice(0, 4): print("  ", hit.distance, " ", hit.point, " ", hit.asset, " ", hit.id)
	if out != "": FileAccess.open(out, FileAccess.WRITE).store_string(JSON.stringify(result, "  "))
	quit()
