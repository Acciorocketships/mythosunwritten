extends RefCounted
## Review probe for cliff_site_review (`echo res://tests/harness/rock_placement_probe.gd > <output>/probe`).
## Lists every rendered rock instance near the owner's reported points and the
## system that owns it: ambient dressing (EnvironmentCommitQueue container) or
## cliff slope rocks (CliffRockFormations/CliffSlopeRocks). It also samples the
## rendered terrain under each rock's lowest visible vertices (gap = rock base
## above ground) using physics rays against the committed collision.
const SITES := {
	"plateau": Vector3(328.2, 63.5, 901.8),
	"crest": Vector3(371.4, 67.9, 873.7),
	"embed": Vector3(321.2, 50.8, 954.9),
}
const RADIUS := 40.0

func run(review: Node) -> void:
	var rows: Array = []
	for node: Node in review.get_tree().root.find_children("*", "MultiMeshInstance3D", true, false):
		var mmi := node as MultiMeshInstance3D
		var path := String(mmi.get_path())
		if not ("rock" in path.to_lower()):
			continue
		var mm := mmi.multimesh
		for i in mm.instance_count:
			var t: Transform3D = mmi.global_transform * mm.get_instance_transform(i)
			for site: String in SITES:
				var p: Vector3 = SITES[site]
				if Vector2(t.origin.x - p.x, t.origin.z - p.z).length() > RADIUS:
					continue
				var system := "slope" if "CliffSlopeRocks" in path else ("ambient" if "rock" in mmi.name else "other")
				var box := mm.mesh.get_aabb()
				rows.append({"site": site, "system": system, "node": String(mmi.name), "path": path,
					"origin": [t.origin.x, t.origin.y, t.origin.z],
					"scale": t.basis.get_scale().x, "gap": _gap(review, t, box)})
	var out: String = review._output_dir + "/rock_probe.json"
	FileAccess.open(out, FileAccess.WRITE).store_string(JSON.stringify(rows, "  "))
	var counts := {}
	for row: Dictionary in rows:
		var key := "%s/%s" % [row.site, row.system]
		counts[key] = int(counts.get(key, 0)) + 1
	print("[rock_probe] ", JSON.stringify(counts), " -> ", out)

static var _exclude: Array[RID] = []
## Height of the rock's lowest bottom-ring sample above the ground under it.
static func _gap(review: Node, t: Transform3D, box: AABB) -> float:
	var space := (review as Node3D).get_world_3d().direct_space_state
	if _exclude.is_empty():
		for body: Node in review.get_tree().root.find_children("*", "StaticBody3D", true, false):
			if body.get_children().any(func(c: Node) -> bool: return "rock" in String(c.name)):
				_exclude.append((body as StaticBody3D).get_rid())
	var worst := -INF
	for k in 8:
		var a := k * TAU / 8.0
		var local := box.get_center() + Vector3(cos(a) * box.size.x * .35, -box.size.y * .5, sin(a) * box.size.z * .35)
		var p := t * local
		var query := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 30.0, p - Vector3.UP * 30.0)
		query.exclude = _exclude
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			continue
		worst = maxf(worst, p.y - (hit.position as Vector3).y)
	return worst
