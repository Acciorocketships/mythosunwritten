class_name WarrenPrunedMassPlan
extends RefCounted

## Exhaustive interpretation of the provisional Gaussian mass after building
## parcels are selected.  Bearing cells are opportunities for the later common
## support/inhabited-stack solver, not permission to render solid rock columns.
enum Classification {
	BUILDING,
	BEARING_OPPORTUNITY,
	PRUNED_EXTERIOR_AIR,
	OUTSIDE_CORE,
}

const CARDINAL_COLUMNS: Array[Vector2i] = [
	Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN,
]

var stable_id: StringName
var source: WarrenVolumePlan
var parcels: WarrenParcelPlan
var building_cells: Dictionary = {}
var bearing_opportunity_cells: Dictionary = {}
var pruned_exterior_air_cells: Dictionary = {}
var outside_core_cells: Dictionary = {}
var daylight_void_columns: Dictionary = {}
var audit: Dictionary = {}
var last_rejection := ""
var _sealed := false


func _init(p_stable_id: StringName, p_source: WarrenVolumePlan,
		p_parcels: WarrenParcelPlan) -> void:
	stable_id = p_stable_id
	source = p_source
	parcels = p_parcels


func seal() -> bool:
	if _sealed or stable_id.is_empty() or source == null \
			or not source.is_sealed() or parcels == null \
			or not parcels.is_sealed() or parcels.source != source:
		return _reject("missing or mismatched source and parcel plan")
	building_cells = parcels.retained_mass_cells.duplicate()
	daylight_void_columns = parcels.daylight_void_columns.duplicate()
	for parcel: WarrenBuildingParcel in parcels.parcels:
		for column: Vector2i in parcel.bearing_columns:
			var ground := source.envelope.ground_at(column)
			for y in range(ground, parcel.base_band):
				var cell := Vector3i(column.x, y, column.y)
				if source.has_mass(cell) and not building_cells.has(cell):
					bearing_opportunity_cells[cell] = true
	var classified_count := 0
	for cell_value: Variant in source.mass_cells.keys():
		var cell := cell_value as Vector3i
		var classification_count := int(building_cells.has(cell)) \
			+ int(bearing_opportunity_cells.has(cell))
		if classification_count == 0:
			var column := Vector2i(cell.x, cell.z)
			if parcels.urban_core_columns.has(column):
				pruned_exterior_air_cells[cell] = true
			else:
				outside_core_cells[cell] = true
			classification_count = 1
		if classification_count != 1:
			return _reject("mass classification overlap at %s" % cell)
		classified_count += 1
	if classified_count != source.mass_cells.size():
		return _reject("mass classification is not exhaustive")
	for column_value: Variant in daylight_void_columns.keys():
		var column := column_value as Vector2i
		if not parcels.urban_core_columns.has(column) \
				or _column_has_building_or_walk(column):
			return _reject("daylight void is outside core or contains structure")
	audit = {
		"source_mass_cell_count": source.mass_cells.size(),
		"building_cell_count": building_cells.size(),
		"bearing_opportunity_cell_count": bearing_opportunity_cells.size(),
		"pruned_exterior_air_cell_count": pruned_exterior_air_cells.size(),
		"outside_core_cell_count": outside_core_cells.size(),
		"classified_mass_cell_count": classified_count,
		"classification_overlap_count": 0,
		"unclassified_mass_cell_count": 0,
		"urban_core_column_count": parcels.urban_core_columns.size(),
		"daylight_void_column_count": daylight_void_columns.size(),
		"max_raw_daylight_void_component_size":
			_max_daylight_void_component_size(),
		"urban_core_open_column_ratio": parcels.audit.urban_core_open_column_ratio,
	}
	_sealed = true
	return true


func is_sealed() -> bool:
	return _sealed


func classification_at(cell: Vector3i) -> int:
	if building_cells.has(cell):
		return Classification.BUILDING
	if bearing_opportunity_cells.has(cell):
		return Classification.BEARING_OPPORTUNITY
	if pruned_exterior_air_cells.has(cell):
		return Classification.PRUNED_EXTERIOR_AIR
	if outside_core_cells.has(cell):
		return Classification.OUTSIDE_CORE
	return -1


func deterministic_signature() -> String:
	var daylight_parts := PackedStringArray()
	for column_value: Variant in daylight_void_columns.keys():
		var column := column_value as Vector2i
		daylight_parts.append("%d:%d" % [column.x, column.y])
	daylight_parts.sort()
	return "%s|daylight=%s" % [parcels.deterministic_signature(),
		",".join(daylight_parts)]


func _column_has_building_or_walk(column: Vector2i) -> bool:
	for transition: WarrenVolumeTransition in source.transitions:
		for air_cell: Vector3i in transition.swept_air_cells:
			if Vector2i(air_cell.x, air_cell.z) == column:
				return true
	for y in range(source.envelope.ground_at(column),
			source.envelope.top_at(column)):
		var cell := Vector3i(column.x, y, column.y)
		if building_cells.has(cell) or source.has_walk(cell):
			return true
	return false


func _max_daylight_void_component_size() -> int:
	## Measure the raw parcel-stage holes before a platform is allowed to hide
	## them. A large component is a composition failure: covering it afterward
	## would manufacture the broad empty suspended floor seen in visual review.
	var remaining := daylight_void_columns.duplicate()
	var largest := 0
	while not remaining.is_empty():
		var start := remaining.keys().front() as Vector2i
		var frontier: Array[Vector2i] = [start]
		remaining.erase(start)
		var size := 0
		while not frontier.is_empty():
			var column: Vector2i = frontier.pop_back()
			size += 1
			for direction: Vector2i in CARDINAL_COLUMNS:
				var neighbor := column + direction
				if remaining.has(neighbor):
					remaining.erase(neighbor)
					frontier.append(neighbor)
		largest = maxi(largest, size)
	return largest


func _reject(reason: String) -> bool:
	last_rejection = reason
	return false
