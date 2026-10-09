extends RefCounted


func run(review: Node) -> void:
	var p := Vector2(-26, 1142)
	var chunk := FieldTerrainStreamer.chunk_of(Vector3(p.x, 0, p.y))
	var water: WaterFieldContext = review._streamer._fields.water(chunk)
	var rows := []
	var region = water._region
	var claims := WaterField._river_claims(water._ctx, region)
	for trace: RiverTrace in water._ctx.rivers:
		var best := INF
		var nearest := Vector2.ZERO
		var width := 0.0
		var station := 0
		for i in trace.points.size() - 1:
			var a := trace.points[i]
			var b := trace.points[i + 1]
			var ab := b - a
			var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), .000001), 0, 1)
			var q := a + ab * t
			if q.distance_to(p) < best:
				best = q.distance_to(p)
				nearest = q
				width = lerpf(trace.widths[i], trace.widths[i + 1], t)
				station = i
		if best > 50:
			continue
		var prof: Dictionary = WaterField.profile(trace, region)
		var a: Vector2 = trace.points[station]
		var b: Vector2 = trace.points[station + 1]
		var t := clampf((nearest - a).dot(b - a) / maxf((b - a).length_squared(), .000001), 0, 1)
		var head := lerpf(prof.levels[station], prof.levels[station + 1], t)
		var maximum_ground := -INF
		var offered := []
		for point: Vector2 in [nearest, p]:
			var heads := PackedFloat32Array([-INF])
			var margins := WaterField._claim_rivers(claims, point, 1, heads)
			offered.append(
				{
					"at": str(point),
					"head": heads[0] if is_finite(heads[0]) else null,
					"margin": margins[0]
				}
			)
		var section := []
		for j in 41:
			var q := nearest.lerp(p, j / 40.0)
			var level := water.level_at(q)
			maximum_ground = maxf(maximum_ground, TerrainTileField.surface_y(region, q.x, q.y))
			section.append(
				{
					"at": str(q),
					"ground": TerrainTileField.surface_y(water._region, q.x, q.y),
					"water": level if is_finite(level) else null
				}
			)
		rows.append(
			{
				"source": str(trace.source_cell),
				"nearest": str(nearest),
				"distance": best,
				"width": width,
				"station": station,
				"section": section,
				"offered": offered,
				"raw_profile_head": head,
				"cross_section_max_ground": maximum_ground
			}
		)
	(
		FileAccess
		. open(review._output_dir + "/bank-fragment-claim.json", FileAccess.WRITE)
		. store_string(JSON.stringify(rows, "  "))
	)
	print("BANK_FRAGMENT_CLAIM done")
