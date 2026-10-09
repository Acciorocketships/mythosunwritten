extends SceneTree

func _init() -> void:
	var faces := PackedVector3Array()
	for i in 30000:
		var x := float(i % 200) * 0.7
		var z := float(i / 200) * 0.7
		var y := sin(x * 0.1) * 10 + cos(z * 0.1) * 8
		faces.append_array(PackedVector3Array([Vector3(x, y, z), Vector3(x, y + 0.2, z + 0.7), Vector3(x + 0.7, y - 0.1, z)]))
	for size in [30000, RockSkirt.COLLISION_TRIANGLES_PER_STEP]:
		var times: Array[int] = []
		var total := 0
		for repeat in 5:
			for first in range(0, faces.size(), size * 3):
				var t := Time.get_ticks_usec()
				var shape := ConcavePolygonShape3D.new()
				shape.set_faces(faces.slice(first, first + size * 3))
				var elapsed := Time.get_ticks_usec() - t
				times.append(elapsed)
				total += elapsed
			times.sort()
		print("SKIRT_COLLISION triangles_per_step=", size, " p50_us=", times[times.size() / 2], " max_us=", times[-1], " total_per_chunk_us=", total / 5)
	quit()
