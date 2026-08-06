class_name WarrenVolumeTransition
extends RefCounted

## One atomic exterior connection in the volumetric warren plan.  A vertical
## transition owns two square landings plus the complete span between them;
## stairs and ramps can therefore never be emitted as detached decorations or
## squeezed into a zero-length seam between adjacent floor squares.
enum Kind {
	LEVEL,
	RAMP,
	STAIR,
}

var stable_id: StringName
var from_cell: Vector3i
var to_cell: Vector3i
var kind: Kind
var direction: Vector2i
var run_cells: int
var swept_air_cells: Array[Vector3i] = []
var _sealed := false


func _init(p_stable_id: StringName, p_from_cell: Vector3i,
		p_to_cell: Vector3i, p_kind: Kind,
		p_swept_air_cells: Array[Vector3i]) -> void:
	stable_id = p_stable_id
	from_cell = p_from_cell
	to_cell = p_to_cell
	kind = p_kind
	swept_air_cells.assign(p_swept_air_cells)
	var delta := to_cell - from_cell
	run_cells = absi(delta.x) + absi(delta.z)
	if run_cells > 0:
		direction = Vector2i(signi(delta.x), signi(delta.z))


func seal() -> bool:
	if _sealed or stable_id.is_empty() or from_cell == to_cell \
			or kind < Kind.LEVEL or kind > Kind.STAIR:
		return false
	var delta := to_cell - from_cell
	var rise := absi(delta.y)
	if delta.x != 0 and delta.z != 0:
		return false
	if rise > 1 or run_cells < 1:
		return false
	match kind:
		Kind.LEVEL:
			if rise != 0 or run_cells != 1:
				return false
		Kind.RAMP:
			# The landing squares consume one half-cell at each endpoint. Three
			# macro cells leave at least 6 m for a shallow 1.5 m rise.
			if rise != 1 or run_cells < 3:
				return false
		Kind.STAIR:
			# Two macro cells leave one complete 3 m stair footprint between
			# the square landings.
			if rise != 1 or run_cells != 2:
				return false
	var seen: Dictionary = {}
	for cell: Vector3i in swept_air_cells:
		var key := _cell_key(cell)
		if seen.has(key):
			return false
		seen[key] = true
	_sealed = true
	return true


func is_sealed() -> bool:
	return _sealed


func is_vertical() -> bool:
	return from_cell.y != to_cell.y


func connects(cell: Vector3i) -> bool:
	return from_cell == cell or to_cell == cell


func other(cell: Vector3i) -> Vector3i:
	assert(connects(cell))
	return to_cell if cell == from_cell else from_cell


func surface_cells() -> Array[Vector3i]:
	## Exact two-lane public surface between the endpoint squares. Keeping this on
	## the sealed transition lets every downstream solver reserve the same stair/
	## ramp footprint instead of reconstructing it independently.
	if not is_vertical():
		return [] as Array[Vector3i]
	var gap_length := run_cells * 2 - 2
	if gap_length < 1:
		return [] as Array[Vector3i]
	var source_lanes := _facing_lane_columns(from_cell, direction)
	if source_lanes.size() != 2:
		return [] as Array[Vector3i]
	var out: Array[Vector3i] = []
	for along in range(1, gap_length + 1):
		var ratio := float(along) / float(gap_length + 1)
		var y := roundi(lerpf(float(from_cell.y), float(to_cell.y), ratio))
		for source_lane: Vector2i in source_lanes:
			var column := source_lane + direction * along
			out.append(Vector3i(column.x, y, column.y))
	return out


func deterministic_signature() -> String:
	return "%s:%d:%d:%d>%d:%d:%d:%d:%d" % [stable_id,
		from_cell.x, from_cell.y, from_cell.z,
		to_cell.x, to_cell.y, to_cell.z, kind, run_cells]


static func _cell_key(cell: Vector3i) -> String:
	return "%d:%d:%d" % [cell.x, cell.y, cell.z]


static func _facing_lane_columns(macro_cell: Vector3i,
		direction_value: Vector2i) -> Array[Vector2i]:
	var origin := Vector2i(macro_cell.x * 2, macro_cell.z * 2)
	if direction_value == Vector2i.RIGHT:
		return [origin + Vector2i.RIGHT,
			origin + Vector2i(1, 1)] as Array[Vector2i]
	if direction_value == Vector2i.LEFT:
		return [origin, origin + Vector2i.DOWN] as Array[Vector2i]
	if direction_value == Vector2i.DOWN:
		return [origin + Vector2i.DOWN,
			origin + Vector2i(1, 1)] as Array[Vector2i]
	if direction_value == Vector2i.UP:
		return [origin, origin + Vector2i.RIGHT] as Array[Vector2i]
	return [] as Array[Vector2i]
