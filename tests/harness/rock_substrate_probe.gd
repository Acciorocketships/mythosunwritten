extends RefCounted
## Review probe for cliff_site_review (September 27 judging, rocks stream):
## (1) every rendered rock instance near the owner's photo 3 / photo 6 points
## with its owning system, and (2) sharp one-vertex spikes (a vertex standing
## well above every neighbour of its welded 1-ring) in every rendered mesh
## near photo 3, with the owning node. Writes <output>/substrate_probe.json.
##   echo res://tests/harness/rock_substrate_probe.gd > <output>/probe
const SITES := {"p3": Vector3(288.9, 44.7, 904.9), "p6": Vector3(330.4, 44.0, 968.5)}
const RADIUS := 12.0
const SPIKE := 0.04

func run(review: Node) -> void:
	var rocks: Array = []
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
				rocks.append({"site": site, "system": "slope" if "CliffSlopeRocks" in path else "ambient",
					"node": String(mmi.name), "origin": [snappedf(t.origin.x, .01), snappedf(t.origin.y, .01), snappedf(t.origin.z, .01)],
					"color": str(mm.get_instance_color(i)) if mm.use_colors else "",
					"custom": str(mm.get_instance_custom_data(i)) if mm.use_custom_data else ""})
	var spikes: Array = []
	var centre: Vector3 = SITES.p3
	var scanned: Array = []
	# Plain meshes, and single-instance MultiMeshes (the slope sheet, crags).
	var meshes: Array = []
	for node: Node in review.get_tree().root.find_children("*", "GeometryInstance3D", true, false):
		if not (node as GeometryInstance3D).is_visible_in_tree():
			continue
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			meshes.append([node, (node as MeshInstance3D).mesh, (node as Node3D).global_transform])
		elif node is MultiMeshInstance3D and (node as MultiMeshInstance3D).multimesh.instance_count == 1:
			var mm := (node as MultiMeshInstance3D).multimesh
			meshes.append([node, mm.mesh, (node as Node3D).global_transform * mm.get_instance_transform(0)])
	for entry: Array in meshes:
		var mi: Node3D = entry[0]
		var mesh: Mesh = entry[1]
		var pose: Transform3D = entry[2]
		var box := pose * mesh.get_aabb()
		if box.position.x > centre.x + RADIUS or box.end.x < centre.x - RADIUS or box.position.z > centre.z + RADIUS or box.end.z < centre.z - RADIUS:
			continue
		scanned.append(String(mi.get_path()).right(60))
		for s in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(s)
			var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var index = arrays[Mesh.ARRAY_INDEX]
			var indexed: bool = index != null and (index as PackedInt32Array).size() > 0
			var count: int = (index as PackedInt32Array).size() if indexed else v.size()
			var ring := {}
			var normal := {}
			for t in range(0, count, 3):
				var tri: Array[Vector3] = []
				for k in 3:
					tri.append((pose * v[index[t + k] if indexed else t + k]).snapped(Vector3.ONE * .001))
				# Godot front faces: (v2 - v0) x (v1 - v0) is the outward normal.
				var face := (tri[2] - tri[0]).cross(tri[1] - tri[0])
				for k in 3:
					var a: Vector3 = tri[k]
					if not ring.has(a):
						ring[a] = {}
						normal[a] = Vector3.ZERO
					ring[a][tri[(k + 1) % 3]] = true
					ring[a][tri[(k + 2) % 3]] = true
					normal[a] += face
			for a: Vector3 in ring:
				if Vector2(a.x - centre.x, a.z - centre.z).length() > RADIUS or (normal[a] as Vector3).length() < 1e-9:
					continue
				var mean := Vector3.ZERO
				var reach := 0.0
				for b: Vector3 in ring[a]:
					mean += b / ring[a].size()
					reach = maxf(reach, a.distance_to(b))
				var d := (a - mean).dot((normal[a] as Vector3).normalized())
				if ring[a].size() >= 3 and absf(d) > SPIKE:
					spikes.append({"node": String(mi.get_path()).get_file(), "path": String(mi.get_path()), "surface": s,
						"p": [a.x, a.y, a.z], "out": snappedf(d, .001), "ring": ring[a].size(), "reach": snappedf(reach, .01)})
		continue
	var out: String = review._output_dir + "/substrate_probe.json"
	FileAccess.open(out, FileAccess.WRITE).store_string(JSON.stringify({"rocks": rocks, "spikes": spikes, "scanned": scanned}, "  "))
	print("[substrate_probe] rocks=%d spikes=%d -> %s" % [rocks.size(), spikes.size(), out])
