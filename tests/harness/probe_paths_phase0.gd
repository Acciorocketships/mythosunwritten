extends SceneTree

## Deterministic calibration corpus for the path/feature design. It consumes
## only runtime terrain/water APIs and checked-in primitive bridge candidates.
const SITES := [
	{"seed": 2697992464, "chunk": Vector2i(0, -6)},
	{"seed": 2697992464, "chunk": Vector2i(-4, -18)},
	{"seed": 2697992464, "chunk": Vector2i(-8, 6)},
	{"seed": 3046246887, "chunk": Vector2i(-3, -3)},
]
const BRIDGE_CANDIDATES := {
	"1.0x1.0x4.0": 38.4,
	"1.1x1.0x5.0": 48.0,
	"1.2x1.0x6.0": 57.6,
}
const DRY_LANDING_TOTAL := 8.0
const SAMPLE_STEP := 3.0

func _init() -> void:
	var all_spans: Array[float] = []
	var perpendicular: Array[float] = []
	var oblique: Array[float] = []
	var planning_samples := 0
	var planning_mismatches := 0
	var block_times: Array[float] = []
	var water_times: Array[float] = []
	for site: Dictionary in SITES:
		var seed: int = site.seed
		var chunk: Vector2i = site.chunk
		var water := WaterPlan.new(seed, 22.0, 8)
		var plan := HeightfieldPlan.new(seed, 22.0, 8, "mean", 3)
		plan.set_water_plan(water)
		var mesher := TerrainChunkMesher.new()
		var started := Time.get_ticks_usec()
		var centre := chunk * TerrainChunkMesher.CELLS_PER_CHUNK \
			+ Vector2i.ONE * (TerrainChunkMesher.CELLS_PER_CHUNK / 2)
		var region: HeightfieldRegion = plan.compute_region(centre.x, centre.y,
			TerrainChunkMesher.CELLS_PER_CHUNK)
		block_times.append(float(Time.get_ticks_usec() - started) / 1000.0)
		var core := Rect2(Vector2(chunk) * TerrainChunkMesher.CHUNK_WORLD,
			Vector2.ONE * TerrainChunkMesher.CHUNK_WORLD)
		started = Time.get_ticks_usec()
		var context := WaterFieldContext.build(water, core, region, 0.0)
		water_times.append(float(Time.get_ticks_usec() - started) / 1000.0)
		for axis in 2:
			var direction := Vector2.RIGHT if axis == 0 else Vector2.DOWN
			for lane in TerrainChunkMesher.CELLS_PER_CHUNK:
				var offset := (float(lane) + 0.5) * WaterPlan.TILE
				var a := core.position + (Vector2(0.0, offset) if axis == 0
					else Vector2(offset, 0.0))
				var b := a + direction * TerrainChunkMesher.CHUNK_WORLD
				var exact := context.wet_intervals(a, b)
				var planning := water.planning_intervals(a, b)
				for interval: Vector2 in exact:
					if interval.x <= 0.0001 or interval.y >= 0.9999:
						continue
					var span := (interval.y - interval.x) * a.distance_to(b)
					all_spans.append(span)
					var shore := a.lerp(b, interval.x)
					var normal := _depth_gradient(context, shore)
					if normal.length_squared() > 0.0001 \
							and absf(direction.dot(normal.normalized())) >= 0.7:
						perpendicular.append(span)
					else:
						oblique.append(span)
				var sample_count := int(ceil(a.distance_to(b) / SAMPLE_STEP))
				for sample in sample_count + 1:
					var t := float(sample) / float(sample_count)
					planning_samples += 1
					if _contains(planning, t) != context.is_wet(a.lerp(b, t)):
						planning_mismatches += 1

	all_spans.sort()
	perpendicular.sort()
	oblique.sort()
	print("=== path Phase 0 crossing corpus ===")
	print("sites=%d crossings=%d perpendicular=%d oblique=%d" % [
		SITES.size(), all_spans.size(), perpendicular.size(), oblique.size()])
	_print_quantiles("all wet spans", all_spans)
	_print_quantiles("perpendicular", perpendicular)
	_print_quantiles("oblique", oblique)
	for label: String in BRIDGE_CANDIDATES:
		var usable: float = BRIDGE_CANDIDATES[label]
		var covered := 0
		for span: float in all_spans:
			if span + DRY_LANDING_TOTAL <= usable:
				covered += 1
		print("bridge %s usable=%.1fm coverage=%d/%d (%.1f%%)" % [label, usable,
			covered, all_spans.size(), 100.0 * float(covered) / maxf(1.0, all_spans.size())])
	print("planning/exact sample mismatches=%d/%d (%.3f%%)" % [planning_mismatches,
		planning_samples, 100.0 * float(planning_mismatches) / maxf(1.0, planning_samples)])
	_print_quantiles("canonical region build ms", block_times)
	_print_quantiles("exact water build ms", water_times)
	_probe_topology()
	_probe_halo_scan()
	assert(all_spans.size() >= 8, "Corpus must exercise real dry-to-dry crossings")
	quit()

static func _contains(intervals: Array[Vector2], t: float) -> bool:
	for interval: Vector2 in intervals:
		if t >= interval.x and t <= interval.y:
			return true
	return false

static func _depth_gradient(context: WaterFieldContext, point: Vector2) -> Vector2:
	var coverage := context.coverage()
	if not coverage.grow(-1.0).has_point(point):
		return Vector2.ZERO
	return Vector2(
		context.signed_depth_at(point + Vector2.RIGHT)
			- context.signed_depth_at(point - Vector2.RIGHT),
		context.signed_depth_at(point + Vector2.DOWN)
			- context.signed_depth_at(point - Vector2.DOWN)) * 0.5

static func _quantile(values: Array[float], q: float) -> float:
	if values.is_empty():
		return 0.0
	var index := clampi(int(roundf(q * float(values.size() - 1))), 0, values.size() - 1)
	return values[index]

static func _print_quantiles(label: String, values: Array[float]) -> void:
	print("%s n=%d p50=%.2f p90=%.2f p95=%.2f max=%.2f" % [label, values.size(),
		_quantile(values, 0.5), _quantile(values, 0.9), _quantile(values, 0.95),
		_quantile(values, 1.0)])

static func _probe_topology() -> void:
	var nodes: Array[Vector2i] = []
	for z in 6:
		for x in 6:
			if Helper._hash01(Helper._mix64(x + z * 17 + 991)) < 0.72:
				nodes.append(Vector2i(x, z))
	var edges: Array[Vector4i] = []
	for node: Vector2i in nodes:
		for direction in [Vector2i.RIGHT, Vector2i.DOWN]:
			var other: Vector2i = node + direction
			if other in nodes and Helper._hash01(Helper._mix64(
					node.x + node.y * 31 + other.x * 131 + other.y * 521)) < 0.8:
				edges.append(Vector4i(node.x, node.y, other.x, other.y))
	var selected: Dictionary = {}
	for node: Vector2i in nodes:
		var incident: Array[Vector4i] = []
		for edge: Vector4i in edges:
			if Vector2i(edge.x, edge.y) == node or Vector2i(edge.z, edge.w) == node:
				incident.append(edge)
		incident.sort_custom(func(a: Vector4i, b: Vector4i) -> bool:
			return str(a) < str(b))
		if not incident.is_empty():
			selected[incident[0]] = true
	var loops := 0
	for edge: Vector4i in edges:
		if selected.has(edge):
			continue
		if Helper._hash01(Helper._mix64(hash(edge) + 0x51A7)) < 0.18:
			selected[edge] = true
			loops += 1
	var isolated := 0
	for node: Vector2i in nodes:
		var connected := false
		for edge: Vector4i in selected:
			connected = connected or Vector2i(edge.x, edge.y) == node \
				or Vector2i(edge.z, edge.w) == node
		if not connected:
			isolated += 1
	print("synthetic topology nodes=%d feasible=%d selected=%d loops=%d isolated=%d" % [
		nodes.size(), edges.size(), selected.size(), loops, isolated])

static func _probe_halo_scan() -> void:
	var ready: Dictionary = {}
	var started := Time.get_ticks_usec()
	for z in range(-1, 2):
		for x in range(-1, 2):
			ready[Vector2i(x, z)] = false
	var records_usec := Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	var all_ready := true
	for z in range(-1, 2):
		for x in range(-1, 2):
			all_ready = all_ready and ready.has(Vector2i(x, z))
	var scan_usec := Time.get_ticks_usec() - started
	assert(all_ready)
	print("nine empty-ready records=%dus nine-key scan=%dus" % [records_usec, scan_usec])
