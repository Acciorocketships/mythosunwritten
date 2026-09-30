extends RefCounted
## Review probe for cliff_site_review: for every slope rock near SITE, the
## height of its mesh vertices above its material's contact plane
## (INSTANCE_CUSTOM: plane normal xz, offset). A rock whose vertices all lie
## within the contact band draws as the surface it sits in. Writes
## <output>/contact_probe.json.
const SITE := Vector3(333.0, 45.0, 965.0)
const RADIUS := 25.0

func run(review: Node) -> void:
	var rows: Array = []
	for node: Node in review.get_tree().root.find_children("*", "MultiMeshInstance3D", true, false):
		if not String(node.get_path()).contains("CliffSlopeRocks"):
			continue
		var mm := (node as MultiMeshInstance3D).multimesh
		var vertices := mm.mesh.get_faces()
		for i in mm.instance_count:
			var t: Transform3D = (node as Node3D).global_transform * mm.get_instance_transform(i)
			if Vector2(t.origin.x - SITE.x, t.origin.z - SITE.z).length() > RADIUS:
				continue
			var c := mm.get_instance_custom_data(i)
			var n := Vector3(c.r, sqrt(maxf(0.0, 1.0 - c.r * c.r - c.g * c.g)), c.g)
			var heights := PackedFloat32Array()
			for v: Vector3 in vertices:
				heights.append((t * v).dot(n) - c.b)
			heights.sort()
			rows.append({"node": String(node.name), "origin": [snappedf(t.origin.x, .01), snappedf(t.origin.y, .01), snappedf(t.origin.z, .01)],
				"normal": [snappedf(n.x, .01), snappedf(n.y, .01), snappedf(n.z, .01)],
				"h_min": snappedf(heights[0], .01), "h_median": snappedf(heights[heights.size() / 2], .01), "h_max": snappedf(heights[-1], .01)})
	FileAccess.open(review._output_dir + "/contact_probe.json", FileAccess.WRITE).store_string(JSON.stringify(rows, "  "))
	print("[contact_probe] ", rows.size())
