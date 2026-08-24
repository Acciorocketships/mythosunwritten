class_name WarrenPassageLatticeRules
extends RefCounted

## Shared, resource-free geometry rules for passages excavated from a
## WarrenMassif. The legacy carver and the maze front end must describe the
## same stair/ramp swept volume when they hand work to WarrenVolumePlan.
const HEADROOM_BANDS := WarrenExcavation.HEADROOM_BANDS
const DIRECTIONS: Array[Vector2i] = [
	Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP,
]
const LEVEL := {
	"kind": WarrenVolumeTransition.Kind.LEVEL, "rise": 0, "run": 1,
}
const STAIR_UP := {
	"kind": WarrenVolumeTransition.Kind.STAIR, "rise": 1, "run": 2,
}
const STAIR_DOWN := {
	"kind": WarrenVolumeTransition.Kind.STAIR, "rise": -1, "run": 2,
}
const RAMP_UP := {
	"kind": WarrenVolumeTransition.Kind.RAMP, "rise": 1, "run": 3,
}
const RAMP_DOWN := {
	"kind": WarrenVolumeTransition.Kind.RAMP, "rise": -1, "run": 3,
}
const CLIMB_ACTIONS: Array[Dictionary] = [LEVEL, STAIR_UP, RAMP_UP]
## TASK E2. The mirror of CLIMB_ACTIONS, for the half of the spine that runs
## past the summit toward the far rim. It carries no rising stride at all, so
## "the street never climbs again after the crown" is structural rather than a
## weight that a lucky score could outvote.
const DESCEND_ACTIONS: Array[Dictionary] = [LEVEL, STAIR_DOWN, RAMP_DOWN]
const CONTOUR_ACTIONS: Array[Dictionary] = [
	LEVEL, STAIR_UP, STAIR_DOWN, RAMP_UP, RAMP_DOWN,
]


static func surface_band_span(rise: int, run: int, offset: int) -> Vector2i:
	## Exact macro-band span claimed by
	## WarrenVolumeTransition.surface_cells(). A two-cell stair owns both its
	## low and high tread in the intermediate macro cell.
	if rise == 0:
		return Vector2i.ZERO
	var gap := run * 2 - 2
	var low := rise
	var high := rise
	var found := false
	for along in range(1, gap + 1):
		if (along + 1) / 2 != offset:
			continue
		var band := roundi(lerpf(0.0, float(rise),
			float(along) / float(gap + 1)))
		low = band if not found else mini(low, band)
		high = band if not found else maxi(high, band)
		found = true
	return Vector2i(low, high)


static func stride_slot_bands(rise: int, run: int, offset: int) -> int:
	var span := surface_band_span(rise, run, offset)
	return span.y - span.x + HEADROOM_BANDS


static func stride_cells(massif: WarrenMassif,
		excavation: WarrenExcavation, occupied: Dictionary,
		current: Vector3i, direction: Vector2i, rise: int, run: int) \
		-> Array[Vector3i]:
	## Returns the complete physical stride, or an empty array when any part
	## leaves the solid, collides with previous excavation, revisits public
	## ground, or closes an accidental same-datum 2x2 public square.
	var out: Array[Vector3i] = []
	var trial := occupied.duplicate()
	for offset in range(1, run + 1):
		var span := surface_band_span(rise, run, offset)
		var cell := Vector3i(current.x + direction.x * offset,
			current.y + span.x, current.z + direction.y * offset)
		var bands := span.y - span.x + HEADROOM_BANDS
		if trial.has(cell) or not slot_is_borable(massif, excavation, cell,
				bands) or completes_public_square(trial, cell):
			return [] as Array[Vector3i]
		trial[cell] = true
		out.append(cell)
	return out


static func slot_is_borable(massif: WarrenMassif,
		excavation: WarrenExcavation, cell: Vector3i, bands: int) -> bool:
	var column := Vector2i(cell.x, cell.z)
	if massif == null or excavation == null or not massif.has_column(column):
		return false
	if cell.y < massif.base_at(column) or cell.y + bands > massif.top_at(column):
		return false
	# Keep a full solid separator between vertically crossing passages.
	for band in range(cell.y - 1, cell.y + bands + 1):
		if excavation.carved.has(Vector3i(cell.x, band, cell.z)):
			return false
	return true


static func completes_public_square(occupied: Dictionary,
		cell: Vector3i) -> bool:
	for x_offset in [-1, 0]:
		for z_offset in [-1, 0]:
			var origin := cell + Vector3i(x_offset, 0, z_offset)
			var complete := true
			for corner: Vector3i in [origin, origin + Vector3i.RIGHT,
					origin + Vector3i.BACK, origin + Vector3i(1, 0, 1)]:
				if corner != cell and not occupied.has(corner):
					complete = false
					break
			if complete:
				return true
	return false


static func carve_stride(excavation: WarrenExcavation,
		occupied: Dictionary, cells: Array[Vector3i], rise: int, run: int) \
		-> Array[Vector3i]:
	## Commits one previously validated stride and returns the exact air cells
	## added so a DFS branch can undo only its own edit.
	var carved: Array[Vector3i] = []
	for offset in range(1, run + 1):
		var cell := cells[offset - 1]
		excavation.route.append(cell)
		occupied[cell] = true
		for band in range(cell.y,
				cell.y + stride_slot_bands(rise, run, offset)):
			var air := Vector3i(cell.x, band, cell.z)
			excavation.carved[air] = true
			carved.append(air)
	return carved


static func carve_lane_stride(excavation: WarrenExcavation,
		occupied: Dictionary, lane_cells: Array[Vector3i],
		cells: Array[Vector3i], rise: int, run: int) -> Array[Vector3i]:
	var carved: Array[Vector3i] = []
	for offset in range(1, run + 1):
		var cell := cells[offset - 1]
		lane_cells.append(cell)
		occupied[cell] = true
		for band in range(cell.y,
				cell.y + stride_slot_bands(rise, run, offset)):
			var air := Vector3i(cell.x, band, cell.z)
			excavation.carved[air] = true
			carved.append(air)
	return carved


static func rollback(excavation: WarrenExcavation, occupied: Dictionary,
		walk_cells: Array[Vector3i], carved: Array[Vector3i]) -> void:
	for cell: Vector3i in walk_cells:
		occupied.erase(cell)
	for air: Vector3i in carved:
		excavation.carved.erase(air)


static func is_at_grade(massif: WarrenMassif, cell: Vector3i) -> bool:
	return cell.y == massif.base_at(Vector2i(cell.x, cell.z))


static func opens_to_exterior(massif: WarrenMassif, cell: Vector3i) -> bool:
	for direction: Vector2i in DIRECTIONS:
		if not massif.has_column(Vector2i(cell.x + direction.x,
				cell.z + direction.y)):
			return true
	return false


static func hash_key(world_seed: int, salt: int, cell: Vector3i,
		extra: int = 0) -> int:
	return posmod(Helper._mix64(world_seed ^ salt
		^ cell.x * 73856093 ^ cell.y * 19349663
		^ cell.z * 83492791 ^ extra * 50331653), 2147483647)
