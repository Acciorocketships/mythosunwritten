extends RefCounted

## Exact cell evaluator for a frozen WaterSampler or one worker mesh build.
## Compile immutable corner values once; query-dependent wet weights and shore
## support remain identical to WaterField._fill_bilinear_sub.
const CAP := 8192
var _cells: Dictionary = {}
var _keys: Array[int] = []
var _next := 0
var _lock := Mutex.new()


func sample(ctx: Dictionary, p: Vector2) -> float:
	var fine: PackedFloat32Array = ctx.fill.get("sub_levels", PackedFloat32Array())
	if fine.is_empty():
		return _coarse(ctx, p)
	var columns := (int(ctx.get("fill_size", WaterField.FILL_M + 1)) - 1) * 2 + 1
	var rows := int(fine.size() / columns)
	var fx: float = (p.x - ctx.fill_base.x) / WaterField.FILL_SUB_STEP
	var fz: float = (p.y - ctx.fill_base.y) / WaterField.FILL_SUB_STEP
	var i := clampi(int(floor(fx)), 0, columns - 2)
	var j := clampi(int(floor(fz)), 0, rows - 2)
	var key := j * columns + i
	_lock.lock()
	var cell: Variant = _cells.get(key)
	_lock.unlock()
	if cell == null:
		cell = _compile(ctx, i, j, columns)
		_lock.lock()
		if not _cells.has(key):
			if _keys.size() < CAP:
				_keys.append(key)
			else:
				_cells.erase(_keys[_next])
				_keys[_next] = key
				_next = (_next + 1) % CAP
		_cells[key] = cell
		_lock.unlock()
	if cell.is_empty():
		return _coarse(ctx, p)
	var tx := clampf(fx - float(i), 0.0, 1.0)
	var tz := clampf(fz - float(j), 0.0, 1.0)
	var weights := PackedFloat64Array(
		[(1.0 - tx) * (1.0 - tz), tx * (1.0 - tz), (1.0 - tx) * tz, tx * tz]
	)
	var wet_weight := 0.0
	var wet_acc := 0.0
	for k in 4:
		var level: float = cell[k]
		if level != -INF and level > cell[k + 4] + WaterField.EPS:
			wet_acc += level * weights[k]
			wet_weight += weights[k]
	if wet_weight <= 0.0:
		return -INF
	if wet_weight >= 1.0 - .000001:
		return wet_acc
	var wet_ref := wet_acc / wet_weight
	var acc := 0.0
	var dry := PackedFloat32Array([INF, INF, INF, INF])
	# The reference stores these corners into float32 before its mixed-shore
	# pass. Preserve that rounding even though its first wet sum used double.
	for k in 4:
		var level: float = cell[k + 8]
		if level == -INF or level <= cell[k + 12] + WaterField.EPS:
			dry[k] = cell[k + 12]
			level = minf(wet_ref, cell[k + 12] + WaterField.EPS - WaterField.SHORE_DRY_DEPTH)
		acc += level * weights[k]
	return WaterField._shore_support_level(
		ctx,
		p,
		acc,
		wet_ref,
		ctx.fill_base + Vector2(i, j) * WaterField.FILL_SUB_STEP,
		WaterField.FILL_SUB_STEP,
		dry
	)


func _compile(ctx: Dictionary, i: int, j: int, columns: int) -> PackedFloat64Array:
	var fine: PackedFloat32Array = ctx.fill.sub_levels
	var ground: PackedFloat32Array = ctx.fill.sub_ground
	var dry: PackedByteArray = ctx.fill.get("sub_dry", PackedByteArray())
	var indices := PackedInt32Array(
		[j * columns + i, j * columns + i + 1, (j + 1) * columns + i, (j + 1) * columns + i + 1]
	)
	var touched := false
	for index: int in indices:
		if fine[index] != -INF or (not dry.is_empty() and dry[index] != 0):
			touched = true
	if not touched:
		return PackedFloat64Array()
	var out := PackedFloat64Array()
	out.resize(16)
	for k in 4:
		var index := indices[k]
		var q: Vector2 = (
			ctx.fill_base + Vector2(i + k % 2, j + int(k / 2)) * WaterField.FILL_SUB_STEP
		)
		var height: float = ground[index]
		if height == INF:
			height = WaterField._surface_ground_y(ctx.region, q.x, q.y)
		var level: float = fine[index]
		if not dry.is_empty() and dry[index] != 0:
			level = -INF
		elif level == -INF:
			# The frozen snapshot owns the locked ground memo. Do not write
			# WaterField's planner-only node_ground array from consumer calls.
			var corner_ctx := ctx.duplicate()
			corner_ctx.erase("node_ground")
			level = WaterField._fill_bilinear_coarse(corner_ctx, q)
		out[k] = level
		out[k + 4] = height
	var rounded := PackedFloat32Array()
	rounded.resize(8)
	for k in 8:
		rounded[k] = out[k]
		out[k + 8] = rounded[k]
	return out


func _coarse(ctx: Dictionary, p: Vector2) -> float:
	var columns: int = ctx.get("fill_size", WaterField.FILL_M + 1)
	var levels: PackedFloat32Array = ctx.fill.levels
	var fx: float = (p.x - ctx.fill_base.x) / WaterField.FILL_STEP
	var fz: float = (p.y - ctx.fill_base.y) / WaterField.FILL_STEP
	var i := clampi(int(floor(fx)), 0, columns - 2)
	var j := clampi(int(floor(fz)), 0, int(levels.size() / columns) - 2)
	var key := -1 - (j * columns + i)
	_lock.lock()
	var cell: Variant = _cells.get(key)
	_lock.unlock()
	if cell == null:
		cell = PackedFloat64Array()
		cell.resize(9)
		for k in 4:
			cell[k] = levels[(j + int(k / 2)) * columns + i + k % 2]
			var q: Vector2 = (
				ctx.fill_base + Vector2(i + k % 2, j + int(k / 2)) * WaterField.FILL_STEP
			)
			cell[k + 4] = WaterField._surface_ground_y(ctx.region, q.x, q.y)
		cell[8] = float(
			(
				(
					maxf(maxf(cell[4], cell[5]), maxf(cell[6], cell[7]))
					- minf(minf(cell[4], cell[5]), minf(cell[6], cell[7]))
				)
				>= WaterField.WALL_GATE
			)
		)
		_lock.lock()
		if not _cells.has(key):
			if _keys.size() < CAP:
				_keys.append(key)
			else:
				_cells.erase(_keys[_next])
				_keys[_next] = key
				_next = (_next + 1) % CAP
		_cells[key] = cell
		_lock.unlock()
	var tx := clampf(fx - float(i), 0.0, 1.0)
	var tz := clampf(fz - float(j), 0.0, 1.0)
	var weights := PackedFloat64Array(
		[(1.0 - tx) * (1.0 - tz), tx * (1.0 - tz), (1.0 - tx) * tz, tx * tz]
	)
	var wet_weight := 0.0
	var wet_acc := 0.0
	for k in 4:
		if cell[k] != -INF:
			wet_acc += cell[k] * weights[k]
			wet_weight += weights[k]
	if wet_weight <= 0.0:
		return -INF
	var wet_ref := wet_acc / wet_weight
	var values := PackedFloat32Array([0, 0, 0, 0])
	var dry := PackedFloat32Array([INF, INF, INF, INF])
	for k in 4:
		var level: float = cell[k]
		if level == -INF:
			dry[k] = cell[k + 4]
			level = minf(wet_ref, cell[k + 4] + WaterField.EPS - WaterField.SHORE_DRY_DEPTH)
		values[k] = level
	var x0: float = ctx.fill_base.x + float(i) * WaterField.FILL_STEP
	var z0: float = ctx.fill_base.y + float(j) * WaterField.FILL_STEP
	var acc: float
	if cell[8] > 0.0:
		var px := clampf(p.x, x0, x0 + WaterField.FILL_STEP)
		var pz := clampf(p.y, z0, z0 + WaterField.FILL_STEP)
		var pitch := TerrainTileField.spacing(ctx.region)
		var row0 := WaterField._wall_span(
			ctx.region, pitch, values[0], values[1], cell[0] != -INF, cell[1] != -INF, x0, px, pz, 0
		)
		var row1 := WaterField._wall_span(
			ctx.region, pitch, values[2], values[3], cell[2] != -INF, cell[3] != -INF, x0, px, pz, 0
		)
		acc = WaterField._wall_span(
			ctx.region,
			pitch,
			row0,
			row1,
			cell[0] != -INF or cell[1] != -INF,
			cell[2] != -INF or cell[3] != -INF,
			z0,
			pz,
			px,
			1
		)
	else:
		acc = lerpf(lerpf(values[0], values[1], tx), lerpf(values[2], values[3], tx), tz)
	if wet_weight >= 1.0 - .000001:
		return acc
	return WaterField._shore_support_level(
		ctx, p, acc, wet_ref, Vector2(x0, z0), WaterField.FILL_STEP, dry
	)
