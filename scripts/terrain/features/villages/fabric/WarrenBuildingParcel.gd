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
## Additive (2026-08-22, controller ruling on the plot model): something
## stands ON this parcel's top band -- an upper street, a terrace, or another
## building -- so its roof is a slab rather than the authored pitched
## reservation, and its height owes the storey grid nothing beyond one storey
## and that slab (see `_height_is_legal`). Defaulted false and never set by a
## legacy caller, so every parcel the route-first pipeline builds keeps the
## exact contract it always had.
##
## READ BY THE PLAN'S SUPPORT RULE since Task C3: a flat roof is one band of
## SLAB, so a building stacked on this parcel stands on `top_band` rather than
## on `roof_base_band()`, and `WarrenParcelPlan._building_support_is_valid`
## admits exactly that seam for a flat-roofed parent.
##
## THE ROOF COMPILER STILL DOES NOT READ IT. It shares a name with
## `proposal["flat_roof"]` -- the older staggered roof flag
## `WarrenAssetCompiler` sets at :951/:952 and :987/:988 and
## `StaggeredFabricCompiler` consumes at :458 -- but the two are NOT wired
## together, so beyond the support seam this flag governs the parcel's height
## contract (`_height_is_legal`, `storey_count`, `roof_base_band`) and nothing
## else. The name is deliberate and stays: they mean the same thing about a
## building. Phase C is what must join them -- seed `proposal["flat_roof"]`
## from `parcel.flat_roof` where the maze proposals are built, so a plot the
## planner tiered actually composes a flat roof instead of a pitched one.
var flat_roof := false
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
		p_address_door_phase: int = 0,
		p_flat_roof: bool = false) -> void:
	stable_id = p_stable_id
	footprint.assign(p_footprint)
	base_band = p_base_band
	top_band = p_top_band
	address_walk_cell = p_address_walk_cell
	threshold_column = p_threshold_column
	frontage_direction = p_frontage_direction
	address_door_phase = p_address_door_phase
	flat_roof = p_flat_roof


func seal(volume: WarrenVolumePlan) -> bool:
	if _sealed or stable_id.is_empty() or volume == null \
			or not volume.is_sealed() or footprint.is_empty() \
			or not _height_is_legal() \
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
	# A 6 x 3 m rowhouse is the one deliberate broad/shallow member of the
	# construction grammar. It owns a complete two-module street facade and the
	# paired-gable roof authored for `room.row`; admitting it here lets source
	# parcelization choose that macro shape instead of first creating two 3 x 3 m
	# towers and asking a later visual pass to disguise the seam.
	if depth_cells < width_cells \
			and not (width_cells == 2 and depth_cells == 1):
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


## Whole storeys plus the authored roof reservation -- unless something sits
## ON this roof (`flat_roof`), where the top band is that street's, terrace's
## or upper building's own and owes the storey grid nothing. A flat-roofed
## parcel still has to be a building: one storey and one band of slab.
func _height_is_legal() -> bool:
	if flat_roof:
		return top_band - base_band >= STOREY_BANDS + 1
	return top_band - base_band >= STOREY_BANDS + ROOF_RESERVATION_BANDS \
		and posmod(top_band - base_band - ROOF_RESERVATION_BANDS,
			STOREY_BANDS) == 0


func is_sealed() -> bool:
	return _sealed


func occupied_cells() -> Array[Vector3i]:
	return _occupied_cells.duplicate()


func area_cells() -> int:
	return footprint.size()


func height_bands() -> int:
	return top_band - base_band


## Whole storeys of room under the roof. A flat-roofed parcel reserves ONE
## band for its slab -- the street, terrace or building standing on it needs
## nothing more -- instead of the authored pitched roof's own
## ROOF_RESERVATION_BANDS, and the integer division leaves any odd remainder
## with that slab rather than crediting it as habitable storey.
func storey_count() -> int:
	if flat_roof:
		return (height_bands() - 1) / STOREY_BANDS
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
	# `/R` is `flat_roof` (review finding 2026-08-23, Important 2): it changes
	# the height rule, the storey count and the roof base band, so two parcels
	# that differ only in it are two different buildings and may not share an
	# identity.
	return "%s@%d..%d>A%d:%d/F%d:%d/D%d/O%d/P%s:%d/R%d" % [
		",".join(footprint_parts), base_band, top_band,
		address_walk_cell.x, address_walk_cell.z,
		frontage_direction.x, frontage_direction.y, address_door_phase,
		int(has_occupied_overpass), String(support_parent_parcel_id),
		support_parent_storey_index, int(flat_roof)]


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


## Legacy behaviour (unchanged): a column bears when it is SOLID, without
## gaps, from the envelope's own ground up to this parcel's own floor.
## Additive branch below (controller ruling, 2026-08-22): when that fails,
## a column may still bear on a TUNNEL'S OWN ROOF -- the same case
## the source plan's own support rule already proves legal at the source-plan
## level (task 1's plinth refinement) before a maze claim is ever allowed to
## place. This function only ever ADDS a second way to pass; the first
## branch's own check and return value are untouched, so any caller whose
## column already bore under the old rule bears identically under the new
## one -- the legacy (non-maze) partitioner path, which never has a
## public-realm carved gap in its own footprint columns, can never reach the
## second branch's own true-returning paths (no carved cell means
## `lowest_carved` stays -1 and it returns false, same as the old code
## simply returning false outright).
func _has_continuous_bearing(volume: WarrenVolumePlan,
		column: Vector2i) -> bool:
	var ground := volume.envelope.ground_at(column)
	if base_band < ground:
		return false
	var continuous := true
	for y in range(ground, base_band):
		if not volume.has_mass(Vector3i(column.x, y, column.y)):
			continuous = false
			break
	if continuous:
		return true
	return _has_tunnel_roof_bearing(volume, column, ground)


## Second branch of _has_continuous_bearing (additive, 2026-08-22): legal
## iff (a) every non-solid cell between `ground` and this parcel's own floor
## is PUBLIC REALM -- a passage cell or its swept headroom, read through the
## volume's own `has_public_air` (the authoritative accessor
## WarrenExcavationVolumeAdapter._add_transitions populates via
## `add_public_air` for exactly the cells `WarrenExcavation.carved` removed;
## never reaches into the source plan directly, per the ruling), (b) the
## PLINTH_BANDS bands directly below `base_band` are solid -- the tunnel's
## own roof slab this parcel actually bears on -- UNLESS `base_band` lands
## exactly `TUNNEL_ROOF_BANDS` above the carved run's own top, which is
## where the source plan stands a bridge. Its support rule asks only that
## `solid_at(floor - 1)` hold, and the retained roof slab is exactly that
## one band of rock, so demanding a full PLINTH_BANDS window there would
## reject the very plot the source plan already proved legal before this
## parcel was ever translated -- and (c) below
## the LOWEST carved cell found, mass is solid all the way down to
## `ground`: real rock under the street, not a second unrelated gap. Both
## constants are referenced from the plot layer that owns them
## (WarrenMazeSourcePlan.TUNNEL_ROOF_BANDS, WarrenPlotPlanner.PLINTH_BANDS),
## never duplicated, so the two bearing checks can never quietly drift apart.
func _has_tunnel_roof_bearing(volume: WarrenVolumePlan, column: Vector2i,
		ground: int) -> bool:
	var lowest_carved := -1
	var carved_top := -1
	for y in range(ground, base_band):
		var cell := Vector3i(column.x, y, column.y)
		if volume.has_mass(cell):
			continue
		if not volume.has_public_air(cell):
			return false
		if lowest_carved < 0 or y < lowest_carved:
			lowest_carved = y
		carved_top = maxi(carved_top, y + 1)
	if lowest_carved < 0:
		# Unreachable given the loop above (any non-solid, non-carved cell
		# already returned false, so completing the loop with no carved cell
		# found means every band was solid -- the first branch would already
		# have returned true and this function would never have been
		# called), kept as a defensive refusal rather than a silent accept.
		return false
	if base_band != carved_top + WarrenMazeSourcePlan.TUNNEL_ROOF_BANDS:
		var plinth_floor := maxi(ground,
			base_band - WarrenPlotPlanner.PLINTH_BANDS)
		for y in range(plinth_floor, base_band):
			if not volume.has_mass(Vector3i(column.x, y, column.y)):
				return false
	for y in range(ground, lowest_carved):
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
