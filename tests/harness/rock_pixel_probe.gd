extends RefCounted
## Review probe for cliff_site_review: the world point and collider under
## given pixels of a view, and the slope-sheet triangles around it (normals,
## areas). Edit VIEW/PIXELS, then `echo <this path> > <output>/probe`.
const VIEW := [Vector3(326, 50, 975), Vector3(336, 44, 965), 50.0]
const PIXELS := [Vector2(300, 150), Vector2(1300, 300), Vector2(500, 250)]

func run(review: Node) -> void:
	var camera: Camera3D = review._camera
	camera.fov = VIEW[2]
	camera.look_at_from_position(VIEW[0], VIEW[1], Vector3.UP)
	camera.force_update_transform()
	var scale := Vector2(camera.get_viewport().get_visible_rect().size) / Vector2(1600, 900)
	var space := (review as Node3D).get_world_3d().direct_space_state
	var sheets: Array = []
	for node: Node in review.get_tree().root.find_children("*", "MultiMeshInstance3D", true, false):
		var mm := (node as MultiMeshInstance3D).multimesh
		if mm.instance_count == 1 and String(node.get_path()).contains("CliffRockFormations"):
			sheets.append([node, mm.mesh, (node as Node3D).global_transform * mm.get_instance_transform(0)])
	var rows: Array = []
	for pixel: Vector2 in PIXELS:
		var from := camera.project_ray_origin(pixel * scale)
		var dir := camera.project_ray_normal(pixel * scale)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + dir * 200.0))
		var row := {"pixel": [pixel.x, pixel.y], "hit": [], "collider": "", "tris": []}
		# Nearest rendered sheet triangle along the ray (visual, not physics).
		var best := INF
		for entry: Array in sheets:
			var mesh: Mesh = entry[1]
			var pose: Transform3D = entry[2]
			for s in mesh.get_surface_count():
				var arrays := mesh.surface_get_arrays(s)
				var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
				var c: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
				var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2] if arrays[Mesh.ARRAY_TEX_UV2] != null else PackedVector2Array()
				var index = arrays[Mesh.ARRAY_INDEX]
				var indexed: bool = index != null and (index as PackedInt32Array).size() > 0
				var count: int = (index as PackedInt32Array).size() if indexed else v.size()
				for t in range(0, count, 3):
					var ids := [index[t] if indexed else t, index[t + 1] if indexed else t + 1, index[t + 2] if indexed else t + 2]
					var a := pose * v[ids[0]]
					var b := pose * v[ids[1]]
					var cc := pose * v[ids[2]]
					var p = Geometry3D.ray_intersects_triangle(from, dir, a, b, cc)
					if p == null:
						p = Geometry3D.ray_intersects_triangle(from, dir, a, cc, b)
					if p == null or from.distance_to(p) >= best:
						continue
					best = from.distance_to(p)
					var face := (cc - a).cross(b - a)
					row["sheet_hit"] = [p.x, p.y, p.z]
					row["sheet_node"] = String(entry[0].name)
					row["tri"] = {"v": [a, b, cc], "face_normal": face.normalized(), "area": face.length() * .5,
						"normals": [n[ids[0]], n[ids[1]], n[ids[2]]] if n.size() > 0 else [],
						"alpha": [c[ids[0]].a, c[ids[1]].a, c[ids[2]].a] if c.size() > 0 else [],
						"color": str(c[ids[0]]) if c.size() > 0 else "",
						"instance_color": str((entry[0] as MultiMeshInstance3D).multimesh.get_instance_color(0)),
						"uv2": [uv2[ids[0]], uv2[ids[1]], uv2[ids[2]]] if uv2.size() > 0 else []}
		if not hit.is_empty():
			row.hit = [hit.position.x, hit.position.y, hit.position.z]
			row.collider = String((hit.collider as Node).get_path())
		rows.append(row)
	var out: String = review._output_dir + "/pixel_probe.json"
	FileAccess.open(out, FileAccess.WRITE).store_string(JSON.stringify(rows, "  "))
	print("[pixel_probe] ", rows.size(), " -> ", out)
