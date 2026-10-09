extends RefCounted


## Post-adjustment supply rule, shared by the solver and its numeric tests.
## A point receives the highest head reachable from a genuine source, bounded
## by every offered surface and bed on that path. A low reach cannot supply a
## higher hillside, but a harmless surface bump over a low bed can be lowered.
static func constrain(
	levels: PackedFloat32Array, ground: PackedFloat32Array, columns: int, roots: PackedInt32Array
) -> PackedFloat32Array:
	assert(columns > 0 and levels.size() == ground.size() and levels.size() % columns == 0)
	var result := levels.duplicate()
	result.fill(-INF)
	var rows := int(levels.size() / columns)
	var queue := PriorityQueue.new()
	for index in roots:
		assert(index >= 0 and index < levels.size())
		if (
			is_finite(levels[index])
			and levels[index] > ground[index] + WaterField.EPS
			and result[index] == -INF
		):
			result[index] = levels[index]
			queue.push(index, -levels[index])
	var settled := PackedByteArray()
	settled.resize(levels.size())
	while not queue.is_empty():
		var index: int = queue.pop()
		if settled[index] != 0:
			continue
		settled[index] = 1
		var x := index % columns
		var z := int(index / columns)
		for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next := Vector2i(x, z) + direction
			if next.x < 0 or next.x >= columns or next.y < 0 or next.y >= rows:
				continue
			var ni := next.y * columns + next.x
			if settled[ni] != 0 or not is_finite(levels[ni]):
				continue
			var head := minf(result[index], levels[ni])
			if head <= ground[ni] + WaterField.EPS or head <= result[ni]:
				continue
			result[ni] = head
			queue.push(ni, -head)
	queue.free()
	return result


## Runs on the canonical source domain, before any chunk crops it. Fine
## overrides are sparse; an explicit dry byte distinguishes rejection from
## the ordinary "no override, inherit the coarse surface" sentinel.
static func apply(
	c: Dictionary, region, base: Vector2, columns: int, coarse: PackedFloat32Array, fine: Dictionary
) -> void:
	var started := Time.get_ticks_usec()
	var n := (columns - 1) * 2 + 1
	var rows := int(fine.levels.size() / n)
	var levels := PackedFloat32Array()
	levels.resize(n * rows)
	levels.fill(-INF)
	var ground: PackedFloat32Array = fine.ground
	var node_ground := PackedFloat64Array()
	node_ground.resize(coarse.size())
	node_ground.fill(INF)
	var ctx := {
		"fill_base": base,
		"fill_size": columns,
		"region": region,
		"node_ground": node_ground,
		"fill": {"levels": coarse, "sub_levels": fine.levels, "sub_ground": ground}
	}
	var coarse_rows := int(coarse.size() / columns)
	var wet := 0
	for z in rows:
		for x in n:
			var index := z * n + x
			var cx := mini(x / 2, columns - 2)
			var cz := mini(z / 2, coarse_rows - 2)
			if (
				fine.levels[index] == -INF
				and coarse[cz * columns + cx] == -INF
				and coarse[cz * columns + cx + 1] == -INF
				and coarse[(cz + 1) * columns + cx] == -INF
				and coarse[(cz + 1) * columns + cx + 1] == -INF
			):
				continue
			var point := base + Vector2(x, z) * WaterField.FILL_SUB_STEP
			var head := sample_node(ctx, point, index)
			if not is_finite(head):
				continue
			if ground[index] == INF:
				ground[index] = TerrainTileField.surface_y(region, point.x, point.y)
			if head <= ground[index] + WaterField.EPS:
				continue
			levels[index] = head
			wet += 1
	var roots := PackedInt32Array()
	var marked := PackedByteArray()
	marked.resize(levels.size())
	for trace: RiverTrace in c.rivers:
		if trace.points.is_empty():
			continue
		for segment in maxi(1, trace.points.size() - 1):
			var a := trace.points[segment]
			var b := trace.points[mini(segment + 1, trace.points.size() - 1)]
			var steps := maxi(1, ceili(a.distance_to(b) / WaterField.FILL_SUB_STEP))
			for station in steps + 1:
				var local := (a.lerp(b, float(station) / steps) - base) / WaterField.FILL_SUB_STEP
				# Both bracketing nodes preserve narrow channels between grid
				# lines without treating the whole variable-width capsule as source.
				for dz in 2:
					for dx in 2:
						var x := floori(local.x) + dx
						var z := floori(local.y) + dz
						if x < 0 or z < 0 or x >= n or z >= rows:
							continue
						var index := z * n + x
						if marked[index] == 0 and is_finite(levels[index]):
							marked[index] = 1
							roots.append(index)
	for pond: PondStamp in c.ponds:
		var radius := pond.bound_radius()
		var lo := ((pond.center - Vector2.ONE * radius - base) / WaterField.FILL_SUB_STEP).floor()
		var hi := ((pond.center + Vector2.ONE * radius - base) / WaterField.FILL_SUB_STEP).ceil()
		for z in range(maxi(0, int(lo.y)), mini(rows, int(hi.y) + 1)):
			for x in range(maxi(0, int(lo.x)), mini(n, int(hi.x) + 1)):
				var index := z * n + x
				if (
					marked[index] != 0
					or not is_finite(levels[index])
					or levels[index] > pond.surface_y() + WaterField.EPS
				):
					continue
				if pond.footprint_t(base + Vector2(x, z) * WaterField.FILL_SUB_STEP) >= 1.0:
					continue
				marked[index] = 1
				roots.append(index)
	var sampled := Time.get_ticks_usec()
	var supported := solve(levels, ground, n, roots)
	var dry := PackedByteArray()
	dry.resize(levels.size())
	var removed := 0
	var lowered := 0
	for index in levels.size():
		if not is_finite(levels[index]) or supported[index] == levels[index]:
			continue
		fine.levels[index] = supported[index]
		if supported[index] == -INF:
			dry[index] = 1
			removed += 1
		else:
			lowered += 1
	fine["ground"] = ground
	if removed > 0:
		fine["dry"] = dry
	print(
		"WATER_SOURCE_SUPPORT ",
		JSON.stringify(
			{
				"size": Vector2i(n, rows),
				"wet": wet,
				"roots": roots.size(),
				"removed": removed,
				"lowered": lowered,
				"sample_ms": (sampled - started) / 1000.0,
				"support_ms": (Time.get_ticks_usec() - sampled) / 1000.0
			}
		)
	)


## Equivalent at an exact fine-grid node, before support rejection.
## Unknown ground retains the full path, including its double-precision gate.
static func sample_node(ctx: Dictionary, point: Vector2, index: int) -> float:
	var head: float
	if ctx.fill.sub_ground[index] == INF:
		head = WaterField._fill_bilinear(ctx, point)
	elif ctx.fill.has("sub_dry") and ctx.fill.sub_dry[index] != 0:
		return -INF
	else:
		head = ctx.fill.sub_levels[index]
		if head == -INF:
			head = WaterField._fill_bilinear_coarse(ctx, point)
	return head


static func solve(
	levels: PackedFloat32Array, ground: PackedFloat32Array, columns: int, roots: PackedInt32Array
) -> PackedFloat32Array:
	var native = WaterField.NATIVE_FILL
	if native.on():
		var result: PackedFloat32Array = native.source_support(levels, ground, columns, roots)
		if result.size() == levels.size():
			return result
	return constrain(levels, ground, columns, roots)
