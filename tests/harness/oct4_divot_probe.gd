extends RefCounted
## Run through cliff_site_review's `probe` command (October 4 owner review,
## divots): around each reported site, the rendered surface (physics ray) minus
## the tile kernel on a 1 m grid over a 48 m square, the kernel's walls there,
## and the kernel heights, so a dent can be attributed to the kernel (its
## height map) or to a dressing layer over it (sheet, rocks).
const SITES := {"P1": Vector2(496, 868), "P23": Vector2(-330, 1474), "P23_north": Vector2(-340, 1494)}

func run(review: Node3D) -> void:
	var space := review.get_world_3d().direct_space_state
	var out := FileAccess.open(review._output_dir + "/divot_probe.txt", FileAccess.WRITE)
	for id: String in SITES:
		var c: Vector2 = SITES[id]
		var chunk := FieldTerrainStreamer.chunk_of(Vector3(c.x, 0, c.y))
		if not review._inputs.has(chunk):
			out.store_line("%s: chunk %s not loaded" % [id, chunk])
			continue
		var region = review._inputs[chunk].region
		out.store_line("== %s centre %s chunk %s" % [id, c, chunk])
		var worst := 0.0
		var worst_at := Vector2.ZERO
		var rows: PackedStringArray = []
		for k in 49:
			var z := c.y - 24.0 + k
			var row := "z=%7.1f " % z
			for i in 49:
				var x := c.x - 24.0 + i
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 400, z), Vector3(x, -100, z)))
				if hit.is_empty():
					row += "  ?  "
					continue
				var d: float = hit.position.y - TerrainTileField.surface_y(region, x, z)
				row += "%5.1f" % d
				if absf(d) > absf(worst):
					worst = d
					worst_at = Vector2(x, z)
			rows.append(row)
		out.store_line("largest rendered-kernel %.2f m at %s" % [worst, worst_at])
		for seg: Dictionary in TerrainTileField.wall_segments(region, Rect2(c - Vector2(24, 24), Vector2(48, 48))):
			out.store_line("  wall %s-%s top %s bottom %s normal %s" % [seg.a, seg.b, seg.top, seg.bottom, seg.normal])
		out.store_line("rendered - kernel (x from %.0f, 1 m):" % (c.x - 24.0))
		for row in rows:
			out.store_line(row)
		out.store_line("kernel heights (2 m):")
		for k in 25:
			var z := c.y - 24.0 + k * 2.0
			var row := "z=%7.1f " % z
			for i in 25:
				row += "%6.1f" % TerrainTileField.surface_y(region, c.x - 24.0 + i * 2.0, z)
			out.store_line(row)
	out.close()
	print("[oct4_divot_probe] done")
