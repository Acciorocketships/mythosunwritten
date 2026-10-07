class_name WarrenElevatedFrontageSolver
extends RefCounted

## The elevated-courtyard measurements the one-pass feature selection and the
## production validator still read. The upper-gallery loop search that used to
## live here (`extend`, `variants`) was deleted October 7: nothing called it
## after the searched pipeline was removed.
const MIN_COURTYARD_UNDERBUILT_COLUMNS := 2
const MIN_COURTYARD_DAYLIGHT_COLUMNS := 2


static func _courtyard_vertical_route_floor_counts(court: Array[Vector3i],
		source: WarrenVolumePlan) -> Dictionary:
	## A swept-air cell above the court is not an upper pathway. In particular,
	## the old test admitted the headroom of a route whose actual floor sat only
	## one 1.5 m band over the court, producing the low timber ceiling visible in
	## review captures. Count only real public floor claims with a complete 3 m
	## storey of separation.
	var route_floors: Dictionary = {}
	for macro_floor: Vector3i in source.walk_cells:
		for fine: Vector3i in _fine_square(macro_floor):
			route_floors[fine] = true
	for transition: WarrenVolumeTransition in source.transitions:
		for fine: Vector3i in transition.surface_cells():
			route_floors[fine] = true
	var below: Dictionary = {}
	var above: Dictionary = {}
	for macro_floor: Vector3i in court:
		for floor: Vector3i in _fine_square(macro_floor):
			for offset in range(WarrenVolumePlan.HEADROOM_BANDS, 9):
				var below_cell := floor + Vector3i.DOWN * offset
				if route_floors.has(below_cell):
					below[below_cell] = true
			for offset in range(WarrenVolumePlan.HEADROOM_BANDS, 9):
				var above_cell := floor + Vector3i.UP * offset
				if route_floors.has(above_cell):
					above[above_cell] = true
	return {"below": below.size(), "above": above.size()}


static func _fine_square(macro_cell: Vector3i) -> Array[Vector3i]:
	var origin := Vector3i(macro_cell.x * 2, macro_cell.y,
		macro_cell.z * 2)
	return [origin, origin + Vector3i.RIGHT, origin + Vector3i.BACK,
		origin + Vector3i(1, 0, 1)] as Array[Vector3i]


static func _has_inhabited_mass_below(cell: Vector3i,
		source: WarrenVolumePlan) -> bool:
	## One complete 3 m storey immediately below the court is enough to make it
	## an upper-city room. Parcelization will turn that standing mass into an
	## addressed building; this stage merely proves the load-bearing volume was
	## not hollowed into public air.
	for offset in range(1, WarrenBuildingParcel.STOREY_BANDS + 1):
		if not source.has_mass(cell + Vector3i.DOWN * offset):
			return false
	return true
