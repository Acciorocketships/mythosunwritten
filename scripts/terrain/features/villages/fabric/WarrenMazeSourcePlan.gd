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

## Constructive edit ledger: Vector2i column -> {floor_band, top_band, phase}.
## Overlays the sealed massif; a raised floor_band leaves a rock foundation
## below it (foundation_depth), a lowered one is forbidden -- terrain is the
## immutable floor and carved passage cells are never edited.
var column_edits: Dictionary = {}
## Stamped houses as data: {footprint: Array[Vector2i], floor_band: int,
## top_band: int, door_walk: Vector3i, door_column: Vector2i,
## frontage: Vector2i, lineage_hint: StringName, shape_id: StringName}.
var parcel_claims: Array[Dictionary] = []
## Typed large features: {kind: StringName, cells: Array[Vector2i],
## datum_band: int, walk_cells: Array[Vector3i], audit: Dictionary}.
var reservations: Array[Dictionary] = []


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


func effective_base(column: Vector2i) -> int:
	if column_edits.has(column):
		return int((column_edits[column] as Dictionary).get("floor_band", 0))
	return massif.base_at(column)


func effective_top(column: Vector2i) -> int:
	if column_edits.has(column):
		return int((column_edits[column] as Dictionary).get("top_band", 0))
	return massif.top_at(column)


func foundation_depth(column: Vector2i) -> int:
	## Bands of rock a raised floor now stands on above the sampled terrain.
	## Zero when the ledger never touched this column or only lowered it --
	## record_edit already forbids sinking below the terrain sample, so the
	## clamp only guards a column with no edit at all.
	return maxi(0, effective_base(column) - massif.base_at(column))


func record_edit(column: Vector2i, floor_band: int, top_band: int,
		phase: StringName, bearing: bool = false) -> bool:
	## `bearing` (refined 2026-08-21, the tiers unlock): true when this
	## floor-raising edit stands on continuous pre-edit rock rather than a
	## within-+/-1-band terrain correction -- WarrenMazeStampPass._column_bears
	## decides which, at the moment the offender is committed. Recorded on
	## the edit itself so seal() can re-validate the +/-1 stamp-phase budget
	## cheaply (a massif-range check) instead of re-walking every band, and
	## so a consumer (the debug view) can render bearing mass distinctly.
	if _sealed:
		return _reject("plan is sealed; the ledger is frozen")
	if _column_has_passage(column):
		return _reject("edit at column %s would touch a carved passage cell" \
			% column)
	if massif == null or not massif.has_column(column):
		return _reject("edit at column %s has no massif column" % column)
	if floor_band < massif.base_at(column):
		return _reject("edit at column %s would sink its floor below terrain" \
			% column)
	column_edits[column] = {"floor_band": floor_band, "top_band": top_band,
		"phase": phase, "bearing": bearing}
	return true


## P4.5 skyline trim: lowers a column's top_band to discard mass no claim
## ever reaches. Unlike record_edit, this can only ever LOWER top_band --
## trim never raises mass, and never touches floor_band or phase for a
## column that already carries an edit (an offender correction from stamp,
## or an earlier reservation edit): only top_band moves. A column with no
## prior edit gets a brand-new entry at its own effective_base, phase
## &"trim", so foundation_depth (base-derived) is unaffected either way.
## Rejects: a sealed ledger, a requested top_band below the column's own
## effective_base (a trim may lower mass, never sink the floor), and --
## refined 2026-08-21 -- a requested top_band that would cut into a
## passage-hosting column's own headroom. Passage-hosting columns are no
## longer exempt outright (a covered tunnel's roof gets trimmed too, just
## never below HEADROOM_BANDS of air over the passage cell itself); streets
## remain otherwise immutable via record_edit/can_record_edit, which still
## reject ANY edit -- floor or top -- on a passage column outright.
func record_trim(column: Vector2i, top_band: int) -> bool:
	if _sealed:
		return _reject("plan is sealed; the ledger is frozen")
	if massif == null or not massif.has_column(column):
		return _reject("trim at column %s has no massif column" % column)
	var floor_band := effective_base(column)
	if top_band < floor_band:
		return _reject("trim at column %s would sink below its own floor" \
			% column)
	var headroom_floor := _passage_headroom_floor(column)
	if headroom_floor >= 0 and top_band < headroom_floor:
		return _reject(
			("trim at column %s would cut into a passage's own headroom: " \
				+ "top_band %d is below the required %d (passage y + " \
				+ "HEADROOM_BANDS)") % [column, top_band, headroom_floor])
	var phase := StringName(&"trim")
	var bearing := false
	if column_edits.has(column):
		var existing := column_edits[column] as Dictionary
		floor_band = int(existing.get("floor_band", floor_band))
		phase = StringName(existing.get("phase", &"trim"))
		# A trim never changes floor_band or bearing status -- only top_band
		# moves -- so a bearing stamp-phase edit that later gets trimmed
		# must keep carrying bearing: true, or seal()'s own re-validation
		# would wrongly re-apply the +/-1 budget to it.
		bearing = bool(existing.get("bearing", false))
	# "Only lowers": a requested top_band that would RAISE this column's
	# current top is simply clamped away rather than applied or rejected.
	var new_top := mini(top_band, effective_top(column))
	column_edits[column] = {"floor_band": floor_band, "top_band": new_top,
		"phase": phase, "trimmed": true, "bearing": bearing}
	return true


## The lowest legal top_band a trim may ever leave on `column`: the highest
## passage cell hosted there, plus WarrenExcavation.HEADROOM_BANDS of
## required air above it -- -1 (no floor) when the column hosts no passage
## cell at all. Shared between record_trim's own gate and seal()'s mirror of
## the same rule, so the two can never disagree about what "cuts into a
## passage's headroom" means.
func _passage_headroom_floor(column: Vector2i) -> int:
	var floor_needed := -1
	for cell: Vector3i in passage_kinds.keys():
		if cell.x == column.x and cell.z == column.y:
			floor_needed = maxi(floor_needed, cell.y + WarrenExcavation.HEADROOM_BANDS)
	return floor_needed


## Non-mutating pre-flight for record_edit's own gates (sealed ledger, a
## carved passage cell, a floor sinking below terrain), without writing to
## column_edits or touching last_rejection. A caller that must commit a whole
## batch of edits atomically -- WarrenMazeStampPass records several offender
## columns per placed/extended claim -- validates every member of the batch
## with this first; only once every member passes does it call record_edit
## for real. Without this, a batch loop that calls record_edit directly and
## aborts on the first rejection strands whatever it already committed for
## earlier offenders in the same batch (a claim with no matching edit, or an
## edit with no claim). Mirrors record_edit's checks exactly, so "would
## record_edit accept this" and "does can_record_edit say yes" can never
## disagree.
func can_record_edit(column: Vector2i, floor_band: int) -> bool:
	if _sealed:
		return false
	if _column_has_passage(column):
		return false
	if massif == null or not massif.has_column(column):
		return false
	if floor_band < massif.base_at(column):
		return false
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
	if excavation.loop_edges.is_empty():
		return _reject("public passage graph is a branch tree without a loop join")
	for column: Vector2i in massif.columns:
		if not block_thickness.has(column):
			return _reject("column %s has no block-thickness classification" % column)
	# Claims must be pairwise disjoint -- WarrenMazeStampPass's own
	# claimed_intervals bookkeeping is the only thing that ever enforced this
	# during generation, so seal() re-checks it as a real invariant rather
	# than trusting that bookkeeping never lied. Band-aware (Task 1,
	# 2026-08-21): two claims may legally share a column -- an upper street's
	# house stacked above a lower one -- as long as their own [floor, top)
	# band ranges stay disjoint; only an actual band overlap is rejected. The
	# same pass also builds the footprint-plus-1-column apron every
	# stamp-phase edit below must land inside, and `claim_tops` (the tallest
	# claim on each column) is what the trim-validity check below measures
	# against.
	var claim_owner: Dictionary = {}
	var claim_tops: Dictionary = {}
	var apron_columns: Dictionary = {}
	for index in parcel_claims.size():
		var claim := parcel_claims[index] as Dictionary
		var claim_floor := int(claim.get("floor_band", 0))
		var claim_top := int(claim.get("top_band", 0))
		for member: Vector2i in claim.get("footprint", []) as Array[Vector2i]:
			var owners: Array = claim_owner.get(member, [])
			for owner: Dictionary in owners:
				if claim_floor < int(owner.top) and claim_top > int(owner.floor):
					return _reject(
						("claim %d and claim %d both claim column %s -- " \
							+ "claims must be pairwise disjoint") \
							% [int(owner.index), index, member])
			owners.append({"index": index, "floor": claim_floor,
				"top": claim_top})
			claim_owner[member] = owners
			claim_tops[member] = maxi(int(claim_tops.get(member, claim_top)),
				claim_top)
			apron_columns[member] = true
			for direction: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
				apron_columns[member + direction] = true
	var edit_columns: Array[Vector2i] = []
	edit_columns.assign(column_edits.keys())
	edit_columns.sort_custom(Callable(WarrenMazeSourcePlan, "_column_less"))
	for column: Vector2i in edit_columns:
		var edit := column_edits[column] as Dictionary
		if not massif.has_column(column):
			return _reject("edit at column %s has no massif column" % column)
		if int(edit.get("floor_band", 0)) < massif.base_at(column):
			return _reject(
				"edit at column %s sinks its floor below terrain" % column)
		# Streets stay immutable for a real (reserve/stamp) edit -- passage
		# columns never get a floor correction or a leveling edit. A trim is
		# the one deliberate exception (refined 2026-08-21): a covered
		# passage's own roof gets trimmed too, so this general check is
		# scoped to non-trim edits; the trim-specific headroom check just
		# below is what actually bounds a trim on a passage column.
		if not bool(edit.get("trimmed", false)) and _column_has_passage(column):
			return _reject(
				"edit at column %s touches a carved passage cell" % column)
		# A trim may only ever discard mass no claim reaches -- never cut into
		# one, and never into a passage's own required headroom.
		# claim_tops (built above from parcel_claims, band-aware) is the
		# tallest roof any claim on this column actually needs; a trim whose
		# own top_band lands below that has quietly amputated a house.
		# _passage_headroom_floor mirrors record_trim's own gate exactly, so
		# the two can never disagree about what "cuts into a passage's
		# headroom" means.
		if bool(edit.get("trimmed", false)):
			if claim_tops.has(column) \
					and int(edit.get("top_band", 0)) < int(claim_tops[column]):
				return _reject(
					("trim at column %s cuts into a claim: top_band %d is " \
						+ "below the tallest claim's own top %d") \
						% [column, int(edit.get("top_band", 0)),
							int(claim_tops[column])])
			var headroom_floor := _passage_headroom_floor(column)
			if headroom_floor >= 0 \
					and int(edit.get("top_band", 0)) < headroom_floor:
				return _reject(
					("trim at column %s cuts into a passage's own headroom: " \
						+ "top_band %d is below the required %d (passage y " \
						+ "+ HEADROOM_BANDS)") \
						% [column, int(edit.get("top_band", 0)),
							headroom_floor])
		# Reservation-phase edits may level/sink a reservation's footprint
		# further than one band by design (a market approach, a landmark plinth)
		# and never claim a footprint of their own to be inside the apron of --
		# only stamp-phase (parcel-claim offender) edits are held to the
		# +/-1-band-OR-bearing, in-apron budget WarrenMazeStampPass's own
		# candidate enumeration (_footprint_offenders) already meant to
		# guarantee. Refined 2026-08-21 (plinth bearing): a drift beyond +/-1
		# is legal when the edit is bearing -- re-validated here with the
		# SAME plinth test WarrenMazeStampPass._column_bears applies at
		# placement time (only the PLINTH_BANDS immediately below the floor
		# need to be solid, not the whole column down to its own base --
		# "lower tunnels beneath are allowed"), against the PRE-EDIT, RAW
		# massif/excavation via state_at_raw (never the ledger: the ledger is
		# exactly what's being checked, and never trusting the recorded
		# `bearing` flag alone either).
		if StringName(edit.get("phase", &"")) == &"stamp":
			var floor_band := int(edit.get("floor_band", 0))
			var drift := absi(floor_band - massif.base_at(column))
			if drift > 1:
				var bears := false
				if bool(edit.get("bearing", false)):
					var plinth_floor := maxi(massif.base_at(column),
						floor_band - WarrenMazeStampPass.PLINTH_BANDS)
					bears = true
					for y in range(plinth_floor, floor_band):
						if state_at_raw(Vector3i(column.x, y, column.y)) \
								!= CellState.SOLID:
							bears = false
							break
				if not bears:
					return _reject(
						("stamp edit at column %s moves its floor %d " \
							+ "bands from the pre-edit surface, past the " \
							+ "+/-1 budget, and is not a bearing edit onto " \
							+ "a solid plinth") % [column, drift])
			if not apron_columns.has(column):
				return _reject(
					("stamp edit at column %s is outside every claim's " \
						+ "footprint and its 1-column apron") % column)
	# Fix round 1 (2026-08-21 review, Important finding): the trim-specific
	# check above only ever looks at TRIMMED edits, so a column that never
	# got trimmed but whose recorded top_band is stale for another reason
	# (a flush-stacked claim's own placement is deliberately exempt from
	# ever writing that column's offender edit -- see
	# WarrenMazeStampPass._stacks_on_existing_claim -- so a lower tier's own
	# offender-correction edit could in principle be left stuck below a
	# later, taller claim stacked on the same column) would sail through
	# unnoticed. This is the general form of the same invariant, over every
	# claimed column regardless of trim status: effective_top can never sit
	# below the tallest claim actually built there. A column with no edit at
	# all trivially satisfies this (effective_top reads massif.top_at, and no
	# claim's ceiling can ever exceed that), so only edited columns can ever
	# fail it in practice -- but this checks every claimed column, not just
	# the edited subset, so bookkeeping is never trusted over the real claim
	# data.
	for column: Vector2i in claim_tops.keys():
		var claim_top := int(claim_tops[column])
		if effective_top(column) < claim_top:
			return _reject(
				("stacked column %s effective_top %d is below the tallest " \
					+ "claim actually built there (top %d)") \
					% [column, effective_top(column), claim_top])
	# Phases (reserve/stamp) already wrote audit facts before seal runs; seal
	# contributes its own freshly computed keys, it never destroys theirs.
	var built := _build_audit()
	audit.merge(built, true)
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


## SOLID reads through the edit ledger (effective_base/effective_top), not
## the raw sealed massif -- P4.5's skyline trim lowers a column's recorded
## top to discard mass no claim reaches, and a raised floor (an offender
## correction, or a reservation edit) can also open a gap below a claim's own
## floor; both must stop reporting as SOLID here or every state_at consumer
## (frontage-face enumeration, ceiling walks, the debug view, anything that
## asks "is there still rock here") keeps seeing ghost mass the ledger has
## already discarded. Passage cells and carved air are unaffected -- the
## ledger never edits those, and they are checked first regardless.
func state_at(cell: Vector3i) -> CellState:
	if passage_kinds.has(cell):
		return CellState.PASSAGE
	if excavation != null and excavation.carved.has(cell):
		return CellState.AIR
	var column := Vector2i(cell.x, cell.z)
	if massif != null and massif.has_column(column) \
			and cell.y >= effective_base(column) \
			and cell.y < effective_top(column):
		return CellState.SOLID
	return CellState.AIR


## The RAW, pre-ledger physical state -- passage/carved-air exclusions are
## identical to state_at (the ledger never edits those), but the solid range
## is the SEALED MASSIF's own [base_at, top_at), never effective_base/
## effective_top. Exists for exactly one caller class: a mid-stamping ceiling
## walk (WarrenMazeStampPass._column_ceiling) that must find how much
## PHYSICAL rock still stands above a column, independent of what an
## earlier, already-placed claim on that SAME column recorded as ITS OWN
## roof. A stamp-phase offender edit's top_band is bookkeeping for THAT
## claim (skyline trim, foundation depth) -- it does not mean the mass above
## it was removed (nothing is removed until skyline trim runs, at the very
## end of stamp(), long after every ceiling walk has already happened) -- so
## state_at()'s ledger-aware upper bound would incorrectly collapse a
## flush-stacked claim's ceiling to zero the moment the claim below it
## happened to need a floor correction. A caller that wants the FINAL,
## trim-aware truth (the translator, the debug view, anything reading a
## sealed plan) wants state_at(), not this.
func state_at_raw(cell: Vector3i) -> CellState:
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
	for edge: Dictionary in excavation.loop_edges:
		parts.append("loop:%s>%s:%d" % [str(edge.from), str(edge.to),
			int(edge.kind)])
	for span_index in excavation.bridge_spans.size():
		var span := excavation.bridge_spans[span_index] as Array[Vector3i]
		for cell: Vector3i in span:
			parts.append("b:%d:%d,%d,%d" % [span_index, cell.x, cell.y, cell.z])
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
	var edit_columns: Array[Vector2i] = []
	edit_columns.assign(column_edits.keys())
	edit_columns.sort_custom(Callable(WarrenMazeSourcePlan, "_column_less"))
	for column: Vector2i in edit_columns:
		var edit := column_edits[column] as Dictionary
		parts.append("e:%d,%d:%d,%d:%s%s" % [column.x, column.y,
			int(edit.get("floor_band", 0)), int(edit.get("top_band", 0)),
			String(edit.get("phase", &"")),
			":t" if bool(edit.get("trimmed", false)) else ""])
	var claim_lines := PackedStringArray()
	for claim: Dictionary in parcel_claims:
		var footprint: Array = claim.get("footprint", [])
		var footprint_cells: Array[Vector2i] = []
		footprint_cells.assign(footprint)
		footprint_cells.sort_custom(Callable(WarrenMazeSourcePlan,
			"_column_less"))
		var footprint_text := PackedStringArray()
		for cell: Vector2i in footprint_cells:
			footprint_text.append("%d,%d" % [cell.x, cell.y])
		var door_walk: Vector3i = claim.get("door_walk", Vector3i.ZERO)
		var door_column: Vector2i = claim.get("door_column", Vector2i.ZERO)
		var frontage: Vector2i = claim.get("frontage", Vector2i.ZERO)
		claim_lines.append("c:%s:%d,%d:%d,%d,%d:%d,%d:%d,%d:%s:%s" % [
			"+".join(footprint_text),
			int(claim.get("floor_band", 0)), int(claim.get("top_band", 0)),
			door_walk.x, door_walk.y, door_walk.z,
			door_column.x, door_column.y,
			frontage.x, frontage.y,
			String(claim.get("lineage_hint", &"")),
			String(claim.get("shape_id", &""))])
	claim_lines.sort()
	for line: String in claim_lines:
		parts.append(line)
	var reservation_lines := PackedStringArray()
	for reservation: Dictionary in reservations:
		var cells: Array = reservation.get("cells", [])
		var reservation_cells: Array[Vector2i] = []
		reservation_cells.assign(cells)
		reservation_cells.sort_custom(Callable(WarrenMazeSourcePlan,
			"_column_less"))
		var cells_text := PackedStringArray()
		for cell: Vector2i in reservation_cells:
			cells_text.append("%d,%d" % [cell.x, cell.y])
		reservation_lines.append("r:%s:%s" % [
			String(reservation.get("kind", &"")),
			"+".join(cells_text)])
	reservation_lines.sort()
	for line: String in reservation_lines:
		parts.append(line)
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
		"loop_join_count": excavation.loop_edges.size(),
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


func _column_has_passage(column: Vector2i) -> bool:
	for cell: Vector3i in passage_kinds.keys():
		if cell.x == column.x and cell.z == column.y:
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


static func _column_less(a: Vector2i, b: Vector2i) -> bool:
	if a.y != b.y:
		return a.y < b.y
	return a.x < b.x
