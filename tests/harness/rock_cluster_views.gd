extends RefCounted
## Review probe for cliff_site_review: finds loaded slope-foot rock clusters
## (and ambient dressing rocks) nearest the review site and appends a close
## downhill view of each to `<output>/views.txt` (then touch
## `<output>/recapture`). Views are frozen once written, so later iterations
## reuse identical cameras.
const COUNT := 4
const AMBIENT_COUNT := 2

func run(review: Node) -> void:
	var path: String = review._output_dir + "/views.txt"
	var existing := FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
	if existing.contains("cluster_") and existing.contains("ambient_"):
		return
	var lines := existing
	if not existing.contains("cluster_"):
		lines += _views(review, "cluster", COUNT, func(n: Node) -> bool:
			return "CliffSlopeRocks" in String(n.get_path()) and String(n.name).begins_with("angry_"))
	if not existing.contains("ambient_"):
		lines += _views(review, "ambient", AMBIENT_COUNT, func(n: Node) -> bool:
			return "/Dressing/" in String(n.get_path()) and String(n.name).begins_with("meadow_rock_"))
	FileAccess.open(path, FileAccess.WRITE).store_string(lines)
	print("[rock_cluster_views] ", lines.replace("\n", " | "))

func _views(review: Node, prefix: String, count: int, wanted: Callable) -> String:
	var rocks: Array = []
	for node: Node in review.get_tree().root.find_children("*", "MultiMeshInstance3D", true, false):
		if not wanted.call(node):
			continue
		var mm := (node as MultiMeshInstance3D).multimesh
		for i in mm.instance_count:
			var t := (node as MultiMeshInstance3D).global_transform * mm.get_instance_transform(i)
			var c := mm.get_instance_custom_data(i)
			rocks.append({"p": t.origin, "down": Vector2(c.r, c.g) if prefix == "cluster" else Vector2.ZERO})
	var at: Vector3 = review._at
	rocks.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a.p as Vector3).distance_to(at) < (b.p as Vector3).distance_to(at))
	var chosen: Array[Vector3] = []
	var lines := ""
	for rock: Dictionary in rocks:
		if chosen.size() >= count:
			break
		if chosen.any(func(p: Vector3) -> bool: return p.distance_to(rock.p) < 20.0):
			continue
		chosen.append(rock.p)
		var down: Vector2 = rock.down if (rock.down as Vector2).length() > 0.05 else Vector2(0, 1)
		var side := down.normalized().rotated(0.5) * 8.0
		var target: Vector3 = rock.p
		var eye := target + Vector3(side.x, 3.2, side.y)
		lines += "%s_%d:%.2f,%.2f,%.2f:%.2f,%.2f,%.2f:55\n" % [prefix, chosen.size(),
			eye.x, eye.y, eye.z, target.x, target.y, target.z]
	return lines
