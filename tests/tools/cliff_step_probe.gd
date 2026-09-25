extends SceneTree
## Lists lateral step faces (normals along the wall) inside one wall formation.
## godot --headless --path . -s res://tests/tools/cliff_step_probe.gd -- x y z width height left right
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var crags = load("res://scripts/terrain/field/CliffRockCrags.gd")
	crags.prepare()
	var pose := Transform3D(Basis.IDENTITY, Vector3(float(a[0]), float(a[1]), float(a[2])))
	var form: Dictionary = crags.make(pose, float(a[3]), float(a[4]), 2697992464, null, a[5] == "1", a[6] == "1")[0]
	var faces: PackedVector3Array = form.faces
	var total := 0.0
	var buckets := {}
	for i in range(0, faces.size(), 3):
		var p: Vector3 = faces[i]; var q: Vector3 = faces[i + 1]; var r: Vector3 = faces[i + 2]
		if minf(p.z, minf(q.z, r.z)) < .3: continue
		var n := (r - p).cross(q - p)
		var area := n.length() * .5
		if area < 1e-5: continue
		n = n.normalized()
		if absf(n.x) < .8: continue
		total += area
		var key := snappedf((p.x + q.x + r.x) / 3.0, .25)
		buckets[key] = buckets.get(key, 0.0) + area
	var keys := buckets.keys(); keys.sort()
	for k in keys:
		if buckets[k] > .05: print("STEP x=%.2f area=%.3f" % [k, buckets[k]])
	print("STEP_TOTAL %.3f" % total)
	quit()
