class_name WarrenMazeSourcePlan
extends RefCounted

## Sealed, resource-free authority for the solid-first maze front end. It
## records what the carver constructed; downstream adapters may translate it,
## but may not infer or repair its topology.
enum CellState { SOLID, PASSAGE, AIR }

const PASSAGE_SPINE := &"spine"
const PASSAGE_ALLEY := &"alley"
const PASSAGE_MARKET := &"market"
const PASSAGE_KINDS: Array[StringName] = [
	PASSAGE_SPINE, PASSAGE_ALLEY, PASSAGE_MARKET,
]
const MIN_HOUSE_BANDS := 4
const MAX_SPINE_STRAIGHT_RUN := 6
const MAX_ALLEY_STRAIGHT_RUN := 4

var world_seed: int
var scale_profile: WarrenVillageScaleProfile
var massif: WarrenMassif
var excavation: WarrenExcavation
var passage_kinds: Dictionary = {}
var market_zone: Array[Vector3i] = []
## One deliberately broad 2x2 public floor. Unlike an accidental plaza, every
## cell is named before the source seals and the common volume adapter carries
## the same typed exception into its breadth audit.
var market_square_cells: Array[Vector3i] = []
var feature_stamps: Array[Dictionary] = []
var summit_cell := Vector3i.ZERO
var block_thickness: Dictionary = {}
var audit: Dictionary = {}
var last_rejection := ""
var _sealed := false


func _init(p_world_seed: int, p_profile: WarrenVillageScaleProfile,
		p_massif: WarrenMassif, p_excavation: WarrenExcavation) -> void:
	world_seed = p_world_seed
	scale_profile = p_profile
	massif = p_massif
	excavation = p_excavation


func mark_passage(cell: Vector3i, kind: StringName) -> bool:
	if _sealed or kind not in PASSAGE_KINDS:
		return false
	if passage_kinds.has(cell) and passage_kinds[cell] != kind:
		return false
	passage_kinds[cell] = kind
	return true


func seal() -> bool:
	last_rejection = ""
	if _sealed or scale_profile == null or not scale_profile.validate() \
			or massif == null or not massif.is_sealed() or excavation == null \
			or not excavation.is_sealed():
		return _reject("missing sealed profile, massif, or excavation")
	var public := excavation.public_cells()
	if public.size() != passage_kinds.size():
		return _reject("%d public cells disagree with %d passage claims" % [
			public.size(), passage_kinds.size()])
	for cell: Vector3i in public:
		if not passage_kinds.has(cell):
			return _reject("public cell %s has no passage kind" % cell)
	if market_zone.is_empty() or market_zone.size() > excavation.route.size():
		return _reject("market zone is empty or longer than the spine")
	if not _has_typed_square(market_square_cells):
		return _reject("universal market is not one typed 2x2 square")
	if excavation.portals.size() != 1 \
			or excavation.portals[0] != excavation.route[0] \
			or not WarrenPassageLatticeRules.opens_to_exterior(
				massif, excavation.route[0]):
		return _reject("v1 requires one exterior entrance at the spine mouth")
	for index in market_zone.size():
		var cell := market_zone[index]
		if excavation.route[index] != cell \
				or passage_kinds.get(cell, &"") != PASSAGE_SPINE \
				or not WarrenPassageLatticeRules.is_at_grade(massif, cell):
			return _reject("market cell %s is not the spine's ground prefix" % cell)
	var market_touches_approach := false
	for cell: Vector3i in market_square_cells:
		if passage_kinds.get(cell, &"") not in [PASSAGE_SPINE, PASSAGE_MARKET]:
			return _reject("market square cell %s has no market passage claim" % cell)
		market_touches_approach = market_touches_approach or cell in market_zone
	if not market_touches_approach:
		return _reject("market square is detached from its spine approach")
	if summit_cell != excavation.route.back():
		return _reject("summit arrival is not the spine terminus")
	for column: Vector2i in massif.columns:
		if not block_thickness.has(column):
			return _reject("column %s has no block-thickness classification" % column)
	audit = _build_audit()
	if int(audit.get("max_spine_straight_run", 0)) \
			> MAX_SPINE_STRAIGHT_RUN \
			or int(audit.get("max_alley_straight_run", 0)) \
				> MAX_ALLEY_STRAIGHT_RUN:
		return _reject("a passage exceeds its straight-run cap")
	if float(audit.get("frontage_ratio", 0.0)) < 0.90:
		return _reject("frontage %.3f is below the 0.900 source floor" \
			% float(audit.frontage_ratio))
	_sealed = true
	return true


func is_sealed() -> bool:
	return _sealed


func state_at(cell: Vector3i) -> CellState:
	if passage_kinds.has(cell):
		return CellState.PASSAGE
	if excavation != null and excavation.carved.has(cell):
		return CellState.AIR
	var column := Vector2i(cell.x, cell.z)
	if massif != null and massif.has_column(column) \
			and cell.y >= massif.base_at(column) \
			and cell.y < massif.top_at(column):
		return CellState.SOLID
	return CellState.AIR


func passage_cells() -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	out.assign(passage_kinds.keys())
	out.sort_custom(Callable(WarrenMazeSourcePlan, "_cell_less"))
	return out


func deterministic_signature() -> String:
	var parts := PackedStringArray([
		String(scale_profile.deterministic_signature()),
		"summit:%d,%d,%d" % [summit_cell.x, summit_cell.y, summit_cell.z],
	])
	for cell: Vector3i in passage_cells():
		parts.append("p:%d,%d,%d:%s" % [cell.x, cell.y, cell.z,
			String(passage_kinds[cell])])
	for cell: Vector3i in market_zone:
		parts.append("m:%d,%d,%d" % [cell.x, cell.y, cell.z])
	for cell: Vector3i in market_square_cells:
		parts.append("ms:%d,%d,%d" % [cell.x, cell.y, cell.z])
	for stamp: Dictionary in feature_stamps:
		parts.append("stamp:%s:%s" % [String(stamp.get("kind", &"")),
			str(stamp.get("cells", []))])
	for cell: Vector3i in excavation.route:
		parts.append("r:%d,%d,%d" % [cell.x, cell.y, cell.z])
	for transition: Dictionary in excavation.transitions:
		parts.append("rt:%s>%s:%d" % [str(transition.from),
			str(transition.to), int(transition.kind)])
	for lane_index in excavation.lanes.size():
		var lane := excavation.lanes[lane_index]
		parts.append("l%d@%s" % [lane_index, str(lane.anchor)])
		for cell: Vector3i in lane.cells as Array[Vector3i]:
			parts.append("lc:%d,%d,%d" % [cell.x, cell.y, cell.z])
		for transition: Dictionary in lane.transitions as Array[Dictionary]:
			parts.append("lt:%s>%s:%d" % [str(transition.from),
				str(transition.to), int(transition.kind)])
	var air: Array[Vector3i] = []
	air.assign(excavation.carved.keys())
	air.sort_custom(Callable(WarrenMazeSourcePlan, "_cell_less"))
	for cell: Vector3i in air:
		parts.append("a:%d,%d,%d" % [cell.x, cell.y, cell.z])
	var columns: Array[Vector2i] = []
	columns.assign(block_thickness.keys())
	columns.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or a.y == b.y and a.x < b.x)
	for column: Vector2i in columns:
		parts.append("t:%d,%d:%d" % [column.x, column.y,
			int(block_thickness[column])])
	return "|".join(parts)


func _build_audit() -> Dictionary:
	var total_mass := 0
	var retained_mass := 0
	var house_capable := 0
	var addressed_columns: Dictionary = {}
	var public := passage_cells()
	for column: Vector2i in massif.columns:
		var longest := 0
		var current := 0
		for band in range(massif.base_at(column), massif.top_at(column)):
			total_mass += 1
			var solid := not excavation.carved.has(
				Vector3i(column.x, band, column.y))
			retained_mass += int(solid)
			current = current + 1 if solid else 0
			longest = maxi(longest, current)
		house_capable += int(longest >= MIN_HOUSE_BANDS)
	var two_sided := 0
	var fronted_passages := 0
	var covered := 0
	var thickness_histogram: Dictionary = {}
	for cell: Vector3i in public:
		var sides := 0
		for direction: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
			var column := Vector2i(cell.x + direction.x,
				cell.z + direction.y)
			if _column_carries_house_at(column, cell.y):
				sides += 1
				addressed_columns[column] = true
		fronted_passages += int(sides >= 1)
		two_sided += int(sides >= 2)
		var column := Vector2i(cell.x, cell.z)
		var roof := Vector3i(cell.x,
			cell.y + excavation.slot_bands(cell), cell.z)
		covered += int(massif.top_at(column) > roof.y \
			and not excavation.carved.has(roof))
		var thickness := int(block_thickness.get(column, 0))
		thickness_histogram[thickness] = int(
			thickness_histogram.get(thickness, 0)) + 1
	return {
		"passage_cell_count": public.size(),
		"spine_cell_count": excavation.route.size(),
		"alley_cell_count": excavation.lane_cells().size(),
		"market_cell_count": _market_cell_count(),
		"market_approach_cell_count": market_zone.size(),
		"market_square_cell_count": market_square_cells.size(),
		"house_capable_column_count": house_capable,
		"fronted_house_column_count": addressed_columns.size(),
		# The sealed source invariant is path-centric: almost every public cell
		# must run beside inhabitable mass. Thick-block interior columns are
		# deliberately attached as the backs/upper mass of those front buildings
		# and are therefore reported separately rather than making a four-deep
		# house look 25% fronted.
		"frontage_ratio": float(fronted_passages) \
			/ float(maxi(1, public.size())),
		"addressed_column_ratio": float(addressed_columns.size()) \
			/ float(maxi(1, house_capable)),
		"two_sided_passage_ratio": float(two_sided) \
			/ float(maxi(1, public.size())),
		"covered_passage_ratio": float(covered) \
			/ float(maxi(1, public.size())),
		# Raw source-solid survival is useful topology guidance, but it is not the
		# design's 0.85 mass-assignment gate. That gate measures how much of the
		# SOLID LEFT AFTER CARVING becomes owned building parcels and can only be
		# sealed by the partition stage.
		"source_solid_retention_ratio": float(retained_mass) \
			/ float(maxi(1, total_mass)),
		"block_thickness_histogram": thickness_histogram,
		"route_span_bands": excavation.route_span_bands(),
		"max_spine_straight_run": _max_straight_run(excavation.route),
		"max_alley_straight_run": _max_alley_straight_run(),
	}


func _market_cell_count() -> int:
	var cells: Dictionary = {}
	for cell: Vector3i in market_zone:
		cells[cell] = true
	for cell: Vector3i in market_square_cells:
		cells[cell] = true
	return cells.size()


func _max_alley_straight_run() -> int:
	var out := 0
	for lane: Dictionary in excavation.lanes:
		var walk: Array[Vector3i] = [lane.anchor as Vector3i]
		walk.append_array(lane.cells as Array[Vector3i])
		out = maxi(out, _max_straight_run(walk))
	return out


static func _max_straight_run(walk: Array[Vector3i]) -> int:
	var longest := 0
	var current := 0
	var previous := Vector2i.ZERO
	for index in range(1, walk.size()):
		var delta := walk[index] - walk[index - 1]
		var direction := Vector2i(delta.x, delta.z)
		current = current + 1 if direction == previous else 1
		previous = direction
		longest = maxi(longest, current)
	return longest


func _column_carries_house_at(column: Vector2i, street_band: int) -> bool:
	if not massif.has_column(column) or street_band < massif.base_at(column) \
			or street_band + MIN_HOUSE_BANDS > massif.top_at(column):
		return false
	for band in range(street_band, street_band + MIN_HOUSE_BANDS):
		if excavation.carved.has(Vector3i(column.x, band, column.y)):
			return false
	return true


static func _has_typed_square(cells: Array[Vector3i]) -> bool:
	if cells.size() != 4:
		return false
	var claimed: Dictionary = {}
	for cell: Vector3i in cells:
		claimed[cell] = true
	for cell: Vector3i in cells:
		if claimed.has(cell + Vector3i.RIGHT) \
				and claimed.has(cell + Vector3i.BACK) \
				and claimed.has(cell + Vector3i(1, 0, 1)):
			return true
	return false


func _reject(reason: String) -> bool:
	last_rejection = reason
	return false


static func _cell_less(a: Vector3i, b: Vector3i) -> bool:
	if a.y != b.y:
		return a.y < b.y
	if a.z != b.z:
		return a.z < b.z
	return a.x < b.x
