extends RefCounted
## Review probe for cliff_site_review: slope rocks set into bare bedrock
## (instance COLOR.a = the substrate's rock exposure), nearest the owner's
## photo 3 site first. Writes <output>/bare_rocks.json.
const SITE := Vector3(288.9, 44.7, 904.9)

func run(review: Node) -> void:
	var rows: Array = []
	for node: Node in review.get_tree().root.find_children("*", "MultiMeshInstance3D", true, false):
		if not String(node.get_path()).contains("CliffSlopeRocks"):
			continue
		var mm := (node as MultiMeshInstance3D).multimesh
		for i in mm.instance_count:
			var t: Transform3D = (node as Node3D).global_transform * mm.get_instance_transform(i)
			var a := mm.get_instance_color(i).a
			if a > 0.25:
				rows.append({"node": String(node.name), "origin": [snappedf(t.origin.x, .01), snappedf(t.origin.y, .01), snappedf(t.origin.z, .01)],
					"exposure": snappedf(a, .01), "grade": snappedf(mm.get_instance_custom_data(i).a, .01),
					"d": snappedf(Vector2(t.origin.x - SITE.x, t.origin.z - SITE.z).length(), .1)})
	rows.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return x.d < y.d)
	FileAccess.open(review._output_dir + "/bare_rocks.json", FileAccess.WRITE).store_string(JSON.stringify(rows, "  "))
	print("[bare_rock_probe] ", rows.size())
