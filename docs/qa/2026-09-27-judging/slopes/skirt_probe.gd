extends RefCounted
## cliff_site_review probe: list visible rock-skirt triangles with a small
## vertical extent (edge-on slivers) near the review site, and the gap between
## the skirt top and the slope solid under it.
func run(review) -> void:
	var out := PackedStringArray()
	for chunk: Vector2i in review._streamer._built:
		var root: Node3D = review._streamer._built[chunk]
		var faces := root.get_node_or_null("CliffFaces") as MeshInstance3D
		if faces == null or faces.mesh == null: continue
		var arrays := faces.mesh.surface_get_arrays(0)
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx = arrays[Mesh.ARRAY_INDEX]
		var ids := PackedInt32Array(idx) if idx != null else PackedInt32Array()
		if ids.is_empty():
			for i in v.size(): ids.append(i)
		for t in range(0, ids.size(), 3):
			var a := v[ids[t]]; var b := v[ids[t + 1]]; var c := v[ids[t + 2]]
			var lo := minf(a.y, minf(b.y, c.y)); var hi := maxf(a.y, maxf(b.y, c.y))
			out.append("%s tri a=%s b=%s c=%s span=%.2f" % [chunk, a, b, c, hi - lo])
	FileAccess.open(review._output_dir + "/skirts.txt", FileAccess.WRITE).store_string("\n".join(out))
	print("[skirt_probe] triangles=", out.size())
