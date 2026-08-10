class_name WarrenBuildingParcel
extends RefCounted

## One resource-free, roofable orthogonal building envelope selected from the
## residual WarrenVolumePlan mass.  Asset choice is deliberately deferred; the
## parcel owns only geometry, a real exterior address, and bearing opportunity.
const STOREY_BANDS := 2
const ROOF_RESERVATION_BANDS := 2
var stable_id: StringName
var source: WarrenVolumePlan
var footprint: Array[Vector2i] = []
var base_band: int
var top_band: int
var address_walk_cell: Vector3i
var threshold_column: Vector2i
## Cardinal direction from the threshold toward its public walk cell.
var frontage_direction: Vector2i
## Which half of the authored 3 m door module owns the exact 1.5 m threshold.
## Phase zero preserves the original high-local-X threshold; phase one selects
## the other half without moving the facade module or changing the footprint.
var address_door_phase: int
var bearing_columns: Array[Vector2i] = []
var support_mode: StringName
## Optional explicit building-on-building bearing seam. The upper parcel keeps
## its addressed base instead of descending through the lower building, and its
## first room names the exact lower source storey in the volumetric support DAG.
var support_parent_parcel_id: StringName = &""
var support_parent_storey_index := -1
var has_occupied_overpass := false
var width_cells: int
var depth_cells: int
var _occupied_cells: Array[Vector3i] = []
var _sealed := false


func _init(p_stable_id: StringName, p_footprint: Array[Vector2i],
		p_base_band: int, p_top_band: int, p_address_walk_cell: Vector3i,
		p_threshold_column: Vector2i,
		p_frontage_direction: Vector2i,
		p_address_door_phase: int = 0) -> void:
	stable_id = p_stable_id
	footprint.assign(p_footprint)
	base_band = p_base_band
	top_band = p_top_band
	address_walk_cell = p_address_walk_cell
	threshold_column = p_threshold_column
	frontage_direction = p_frontage_direction
	address_door_phase = p_address_door_phase


func seal(volume: WarrenVolumePlan) -> bool:
	if _sealed or stable_id.is_empty() or volume == null \
			or not volume.is_sealed() or footprint.is_empty() \
			or top_band - base_band < STOREY_BANDS + ROOF_RESERVATION_BANDS \
			or posmod(top_band - base_band - ROOF_RESERVATION_BANDS,
				STOREY_BANDS) != 0 \
			or address_walk_cell.y != base_band \
			or not volume.has_frontage(address_walk_cell) \
			or absi(frontage_direction.x) + absi(frontage_direction.y) != 1 \
			or address_door_phase < 0 or address_door_phase > 1:
		return false
	if support_parent_parcel_id.is_empty() != (support_parent_storey_index < 0) \
			or not support_parent_parcel_id.is_empty() \
				and support_parent_parcel_id == stable_id:
		return false
	var unique: Dictionary = {}
	var minimum := Vector2i(2147483647, 2147483647)
	var maximum := Vector2i(-2147483648, -2147483648)
	for column: Vector2i in footprint:
		if unique.has(column):
			return false
		unique[column] = true
		minimum = minimum.min(column)
		maximum = maximum.max(column)
	if not unique.has(threshold_column):
		return false
	var address_column := Vector2i(address_walk_cell.x, address_walk_cell.z)
	if threshold_column + frontage_direction != address_column:
		return false
	var size := maximum - minimum + Vector2i.ONE
	if size.x * size.y != footprint.size():
		return false
	for x in range(minimum.x, maximum.x + 1):
		for z in range(minimum.y, maximum.y + 1):
			if not unique.has(Vector2i(x, z)):
				return false
	if frontage_direction.x != 0:
		depth_cells = size.x
		width_cells = size.y
	else:
		depth_cells = size.y
		width_cells = size.x
	if depth_cells < width_cells:
		return false
	for column: Vector2i in footprint:
		for y in range(base_band, top_band):
			var cell := Vector3i(column.x, y, column.y)
			if not volume.has_mass(cell):
				return false
			_occupied_cells.append(cell)
		if _has_continuous_bearing(volume, column):
			bearing_columns.append(column)
	if bearing_columns.size() * 2 < footprint.size():
		return false
	support_mode = &"building" if not support_parent_parcel_id.is_empty() \
		else &"terrain" if bearing_columns.size() == footprint.size() \
		else &"mixed_span"
	has_occupied_overpass = _covers_lower_walk(volume)
	source = volume
	_sealed = true
	return true


func is_sealed() -> bool:
	return _sealed


func occupied_cells() -> Array[Vector3i]:
	return _occupied_cells.duplicate()


func area_cells() -> int:
	return footprint.size()


func height_bands() -> int:
	return top_band - base_band


func storey_count() -> int:
	return (height_bands() - ROOF_RESERVATION_BANDS) / STOREY_BANDS


func set_building_support(parent_id: StringName,
		parent_storey_index: int) -> bool:
	if _sealed or parent_id.is_empty() or parent_id == stable_id \
			or parent_storey_index < 0:
		return false
	support_parent_parcel_id = parent_id
	support_parent_storey_index = parent_storey_index
	return true


func roof_base_band() -> int:
	return base_band + storey_count() * STOREY_BANDS


func deterministic_signature() -> String:
	var footprint_parts := PackedStringArray()
	for column: Vector2i in footprint:
		footprint_parts.append("%d:%d" % [column.x, column.y])
	footprint_parts.sort()
	return "%s@%d..%d>A%d:%d/F%d:%d/D%d/O%d/P%s:%d" % [
		",".join(footprint_parts), base_band, top_band,
		address_walk_cell.x, address_walk_cell.z,
		frontage_direction.x, frontage_direction.y, address_door_phase,
		int(has_occupied_overpass), String(support_parent_parcel_id),
		support_parent_storey_index]


func slot_signature() -> String:
	## Identity of the immutable horizontal construction slot. Vertical variants
	## deliberately share this signature, allowing reservations to bind to an
	## exterior address/socket contract instead of one provisional roof height.
	var footprint_parts := PackedStringArray()
	for column: Vector2i in footprint:
		footprint_parts.append("%d:%d" % [column.x, column.y])
	footprint_parts.sort()
	return "%s@%d>A%d:%d/T%d:%d/F%d:%d/D%d" % [",".join(footprint_parts),
		base_band, address_walk_cell.x, address_walk_cell.z,
		threshold_column.x, threshold_column.y,
		frontage_direction.x, frontage_direction.y, address_door_phase]


func _has_continuous_bearing(volume: WarrenVolumePlan,
		column: Vector2i) -> bool:
	var ground := volume.envelope.ground_at(column)
	if base_band < ground:
		return false
	for y in range(ground, base_band):
		if not volume.has_mass(Vector3i(column.x, y, column.y)):
			return false
	return true


func _covers_lower_walk(volume: WarrenVolumePlan) -> bool:
	var footprint_set: Dictionary = {}
	for column: Vector2i in footprint:
		footprint_set[column] = true
	for walk: Vector3i in volume.walk_cells:
		if footprint_set.has(Vector2i(walk.x, walk.z)) \
				and base_band - walk.y >= WarrenVolumePlan.HEADROOM_BANDS:
			return true
	return false
