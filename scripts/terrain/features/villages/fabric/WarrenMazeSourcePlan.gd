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

## The four things a plot can be (2026-08-21 plot-model design). A deck is a
## plot with zero height, a bridge is a plot whose floor is a street's own
## headroom top, an asset is a plot with a catalog footprint, and a house is
## anything the partition grows.
const PLOT_HOUSE := &"house"
const PLOT_ASSET := &"asset"
const PLOT_DECK := &"deck"
const PLOT_BRIDGE := &"bridge"
const PLOT_KINDS: Array[StringName] = [
	PLOT_HOUSE, PLOT_ASSET, PLOT_DECK, PLOT_BRIDGE,
]
## The minimum slab a COVERED passage keeps overhead: one band of retained
## mass between a tunnel's own headroom and whatever stands on it. A sealed
## rock shoulder never cuts below it, and a plot bearing on a tunnel roof
## sits exactly this far above that passage's headroom top. WarrenMazeStampPass
## and WarrenBuildingParcel still carry their own copy of this number; a later
## task re-points them here.
const TUNNEL_ROOF_BANDS := 1

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

## The town as plots (2026-08-21 plot-model design): {id: StringName, kind:
## StringName, cells: Array[Vector2i], floor: int, top: int, door_walk:
## Vector3i, building_id: StringName}. ROCK IS NEVER STORED -- solid_at
## derives it from these plus the massif, so this array plus the excavation is
## the whole town. Append through add_plot, which is the only thing that
## checks the support rule.
var plots: Array[Dictionary] = []
## Vector2i column -> Array[int] of indices into `plots`. Keeps solid_at O(the
## plots standing on one column) rather than O(the whole town).
var _plot_columns: Dictionary = {}
## Vector2i column -> int: the derived rock top of a column carrying NO plot,
## computed once at seal (see rock_shoulder). Empty while the plan is
## unsealed, where the massif envelope answers instead.
var _rock_shoulders: Dictionary = {}


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
	## For a PASSAGE-HOSTING column, this is the house/plot floor built
	## ABOVE that passage's own required headroom (a bridge deck, or a
	## claim bearing on a lower tunnel's own trimmed roof, per rule 4's
	## bridge-capable ledger) -- never "the bottom of this column's mass".
	## The real bottom of mass for such a column is state_at()'s job to
	## reconstruct (raw massif below the highest hosted passage's own
	## headroom, ledger-driven at and above it): this accessor alone answers
	## "where does the built floor sit", not "where does solid rock start".
	## For a non-passage column the two questions have always had the same
	## answer, and still do.
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
	##
	## Bridge-capable ledger (refined 2026-08-22, slice 1c task 1): a
	## passage-hosting column is no longer rejected outright -- a floor
	## raised to clear every passage cell that column hosts, plus
	## WarrenExcavation.HEADROOM_BANDS of required street air above the
	## highest one, is legal (a bridge house, or a skywalk_span's own deck
	## reservation, built directly on top of the street rather than beside
	## it). `_passage_headroom_floor` is the SAME shared bound record_trim's
	## own gate and seal()'s mirror of both already use, so "would this edit
	## cut into a passage's own headroom" can never disagree across the three
	## call sites. Streets stay otherwise immutable: any floor at or below
	## that bound -- including one that never reaches down into
	## [passage y, passage y + HEADROOM_BANDS) at all -- is still refused.
	if _sealed:
		return _reject("plan is sealed; the ledger is frozen")
	var headroom_floor := _passage_headroom_floor(column)
	if headroom_floor >= 0 and floor_band < headroom_floor:
		return _reject(
			("edit at column %s would cut into a passage's own headroom: " \
				+ "floor_band %d is below the required %d (passage y + " \
				+ "HEADROOM_BANDS)") % [column, floor_band, headroom_floor])
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


## The real, per-cell top of a passage cell's own carved headroom slot --
## cell.y + excavation.slot_bands(cell) -- controller ruling (2026-08-22):
## NOT cell.y + WarrenExcavation.HEADROOM_BANDS, which undercounts a
## stair/ramp intermediate stride cell's own taller carved slot (it carries
## both treads, one band more than a plain LEVEL cell -- see
## WarrenExcavation.slot_bands' own header). This is the ONE source of truth
## every headroom-measuring rule in this file, WarrenMazeStampPass, and
## WarrenMazeReservationPass must use instead of re-deriving the
## constant-based approximation that used to certify a claim as bearing on
## what a stair-adjacent column's real carved slot still shows as open air.
## HEADROOM_BANDS itself stays meaningful only where it genuinely names a
## MINIMUM (e.g. the carver's own span-legality mass check) -- never as a
## stand-in for a specific cell's own real headroom.
func passage_headroom_top(cell: Vector3i) -> int:
	return cell.y + excavation.slot_bands(cell)


## The lowest legal top_band a trim may ever leave on `column`: the highest
## passage_headroom_top() among every passage cell hosted there -- -1 (no
## floor) when the column hosts no passage cell at all. Shared between
## record_trim's own gate and seal()'s mirror of the same rule, so the two
## can never disagree about what "cuts into a passage's headroom" means.
func _passage_headroom_floor(column: Vector2i) -> int:
	var floor_needed := -1
	for cell: Vector3i in passage_kinds.keys():
		if cell.x == column.x and cell.z == column.y:
			floor_needed = maxi(floor_needed, passage_headroom_top(cell))
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
	var headroom_floor := _passage_headroom_floor(column)
	if headroom_floor >= 0 and floor_band < headroom_floor:
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
		# Streets stay immutable for a real (reserve/stamp) edit in the sense
		# that matters -- [passage y, passage y + HEADROOM_BANDS) is never
		# touched -- but a passage-hosting column is no longer rejected
		# outright (refined 2026-08-22, the bridge-capable ledger unlock,
		# slice 1c task 1): a floor at or above every hosted passage's own
		# headroom floor is a legal bridge house or skywalk_span deck.
		# Mirrors record_edit/can_record_edit's own gate exactly (same
		# _passage_headroom_floor bound), so the three can never disagree. A
		# trim is scoped out of this general check (the trim-specific
		# headroom check just below governs it instead) since a trim edit's
		# own "floor_band" entry is the column's pre-existing floor, not a
		# new one being placed.
		if not bool(edit.get("trimmed", false)):
			var edit_headroom_floor := _passage_headroom_floor(column)
			if edit_headroom_floor >= 0 \
					and int(edit.get("floor_band", 0)) < edit_headroom_floor:
				return _reject(
					("edit at column %s cuts into a passage's own headroom: " \
						+ "floor_band %d is below the required %d (passage " \
						+ "y + HEADROOM_BANDS)") \
						% [column, int(edit.get("floor_band", 0)),
							edit_headroom_floor])
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
					# Tunnel-roof exemption (rule 4, slice 1c task 1,
					# 2026-08-22): mirrors _column_bears' own SAME special
					# case exactly -- a floor landing exactly on a hosted
					# passage's own future-trimmed roof slab (passage y +
					# HEADROOM_BANDS + TUNNEL_ROOF_BANDS) bears automatically,
					# without the continuity walk below (whose plinth window
					# would otherwise dip into that passage's own carved
					# headroom and always fail it). Re-derived here against
					# the pre-edit, raw massif/excavation
					# (_passage_headroom_floor reads passage_kinds, not the
					# ledger), never trusting the recorded `bearing` flag
					# alone -- same discipline as the continuity walk it sits
					# beside.
					var headroom_floor := _passage_headroom_floor(column)
					if headroom_floor >= 0 and floor_band == headroom_floor \
							+ WarrenMazeStampPass.TUNNEL_ROOF_BANDS:
						bears = true
					else:
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
	# The plot model's own invariants (2026-08-21 design): solids contiguous
	# from terrain on every column, every plot still supported, no plot
	# standing in a carved street's headroom, plots pairwise disjoint. A town
	# with no plots satisfies all four trivially. Deliberately the LAST check:
	# it is the only one that leaves a cache behind (the sealed rock
	# shoulders), so this is the only rejecting return that has to throw one
	# away, and a rejected seal always leaves the plan as open as it found it.
	var plot_failure := _plot_rejection()
	if plot_failure != "":
		_rock_shoulders.clear()
		return _reject(plot_failure)
	# Rules become repairs: a street whose own floor is not solid is an audit
	# fact here, never a rejection.
	audit["street_floor_gaps"] = _street_floor_gaps()
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
##
## Bridge-capable columns (2026-08-22, controller ruling on slice 1c task
## 1): a PASSAGE-HOSTING column's ledger entry describes the floor built
## ABOVE that passage's own headroom, never the bottom of the column's
## mass (see effective_base()'s own comment) -- so below the highest
## hosted passage's own headroom floor, this reads the RAW, pre-ledger
## massif range instead of effective_base/effective_top. The rock under a
## street (and under any lower, unrelated tunnel's own roof slab) is real,
## untouched terrain that no edit ever legitimately reaches: record_edit's
## own gate requires floor_band >= _passage_headroom_floor(column) for a
## passage-hosting column, so a ledger edit's own floor can never land
## below that line, and record_trim's own gate refuses to trim a
## passage-hosting column's top below it either -- nothing in the ledger
## ever describes state below this line for such a column, so reading raw
## massif there is not an approximation, it is the only truthful reading.
## At or above that line, ledger-aware reporting is unchanged.
func state_at(cell: Vector3i) -> CellState:
	if passage_kinds.has(cell):
		return CellState.PASSAGE
	if excavation != null and excavation.carved.has(cell):
		return CellState.AIR
	var column := Vector2i(cell.x, cell.z)
	if massif == null or not massif.has_column(column):
		return CellState.AIR
	var headroom_floor := _passage_headroom_floor(column)
	if headroom_floor >= 0 and cell.y < headroom_floor:
		if cell.y >= massif.base_at(column) and cell.y < massif.top_at(column):
			return CellState.SOLID
		return CellState.AIR
	if cell.y >= effective_base(column) and cell.y < effective_top(column):
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


# --- Plot model ------------------------------------------------------------
# The 2026-08-21 plot-model design: one plot concept, rock derived rather than
# stored, and one support rule that replaces bearing, plinth, flush-stack,
# tunnel-roof, and per-cell headroom. Everything below is independent of the
# edit ledger above, which a later task deletes; nothing here reads it.


## Adds one plot, after checking everything the model can check about it: its
## shape (every key present and typed, a non-empty 4-connected footprint of
## unique columns, top >= floor, a deck exactly flat, an unused id), the one
## support rule on every column, that no carved cell stands inside the band
## interval it occupies, and that it stays disjoint from the plots already on
## those columns. Stores a COPY, so a caller may reuse and mutate its own
## dictionary. False with `last_rejection` naming the failed rule otherwise;
## a sealed plan accepts nothing.
##
## `top` is NOT clamped to the massif: the envelope is a planning reference
## and the rock of a column with no plot, never a ceiling.
func add_plot(plot: Dictionary) -> bool:
	# FIRST, before anything below touches state: a sealed plan is finished,
	# and a refused plot may not move so much as a cached band of it. The
	# shoulders below it are the sealed town's own derivation and nothing
	# rebuilds them once _sealed is true.
	if _sealed:
		return _reject("plan is sealed; no plot may be added")
	last_rejection = ""
	# Sealed shoulders describe a FINISHED town. seal() already throws its
	# own cache away on the one path that can leave one behind (its plot
	# checks run last for exactly that reason), so this is the belt to that
	# brace: however seal's checks are ever reordered, a plot on an OPEN plan
	# is judged against the envelope that is really standing, never against
	# the shoulders of an attempt that failed.
	_rock_shoulders.clear()
	var shape := _plot_shape_rejection(plot)
	if shape != "":
		return _reject(shape)
	var placement := _plot_placement_rejection(plot, -1)
	if placement != "":
		return _reject(placement)
	var cells: Array[Vector2i] = []
	cells.assign(plot["cells"])
	plots.append({
		"id": StringName(plot["id"]),
		"kind": StringName(plot["kind"]),
		"cells": cells,
		"floor": int(plot["floor"]),
		"top": int(plot["top"]),
		"door_walk": plot["door_walk"] as Vector3i,
		"building_id": StringName(plot["building_id"]),
	})
	for column: Vector2i in cells:
		var indices: Array = _plot_columns.get(column, [])
		indices.append(plots.size() - 1)
		_plot_columns[column] = indices
	return true


## The one support rule. A plot may occupy `cell` at `floor` when
##
##   1. the band below the floor is solid -- rock, a retained tunnel-roof
##      slab, or another plot's top (solid_at answers all three), and
##   2. no carved air stands in the MIN_HOUSE_BANDS of clearance above it.
##
## Rule 2 is CLEARANCE, not "above every passage in this column" (controller
## ruling, 2026-08-22): a house tiered under an upper street has that street's
## own band as its top and must stay legal. Its consequence at the bottom end
## is that a plot can never sit AT a passage's headroom top -- the band below
## it would be carved -- so a tunnel-roof or bridge plot sits one band higher,
## on the retained roof slab that is its rock.
func plot_support_ok(cell: Vector2i, floor: int) -> bool:
	if not solid_at(Vector3i(cell.x, floor - 1, cell.y)):
		return false
	return _first_carved_band(cell, floor, floor + MIN_HOUSE_BANDS) < 0


## Derived solid mass; rock is never stored. A carved street cell or its
## headroom is air, a band inside some plot's [floor, top) is that plot's own
## mass, everything below the lowest plot floor on the column is rock down to
## the terrain, and a column carrying no plot is rock up to its shoulder.
## Everything else is air -- including the envelope standing above a plot's
## top, which is exactly the mass the old skyline trim used to have to remove.
##
## Terrain is solid (controller ruling, 2026-08-22): below massif.base_at the
## ground is untouched sample, which is what lets a house fronting a grade
## street stand at floor == base_at. A column outside the massif is air
## everywhere. A deck contributes nothing here: its [floor, top) is empty.
func solid_at(cell: Vector3i) -> bool:
	if passage_kinds.has(cell):
		return false
	if excavation != null and excavation.carved.has(cell):
		return false
	var column := Vector2i(cell.x, cell.z)
	if massif == null or not massif.has_column(column):
		return false
	if cell.y < massif.base_at(column):
		return true
	var indices: Array = _plot_columns.get(column, [])
	if indices.is_empty():
		return cell.y < rock_shoulder(column)
	for index: int in indices:
		var plot := plots[index] as Dictionary
		if cell.y >= int(plot["floor"]) and cell.y < int(plot["top"]):
			return true
	return cell.y < _lowest_plot_floor(column)


## The top of derived rock on `column`.
##
## A column that carries plots of its own answers with its lowest plot floor:
## rock fills the column from terrain up to the building standing on it.
##
## A column with no plot answers the massif envelope while the plan is
## UNSEALED -- the envelope stands during planning, or nothing could ever be
## placed on it -- and, once SEALED, the lowest plot floor bordering the
## connected no-plot region this column belongs to, so leftover rock steps
## down to meet the town instead of towering over it. A region that touches no
## plot at all keeps its envelope. A column outside the massif carries no rock
## at all.
func rock_shoulder(column: Vector2i) -> int:
	if massif == null or not massif.has_column(column):
		return 0
	if _plot_columns.has(column):
		return _lowest_plot_floor(column)
	if _rock_shoulders.has(column):
		return int(_rock_shoulders[column])
	return massif.top_at(column)


## The highest band anything on `column` can reach: its massif envelope, the
## rock shoulder a taller neighbour left it, or the tallest plot top standing
## on it -- whichever is highest. A plot is NOT clamped to the massif and a
## no-plot column's shoulder can stand above its own envelope, so this is the
## one reach rule every consumer scanning a column bottom-to-top shares
## (WarrenMazeVolumeAdapter's derived top, the translator's ownership sweep,
## and the tests that falsify both). Zero outside the massif.
func column_ceiling(column: Vector2i) -> int:
	if massif == null or not massif.has_column(column):
		return 0
	var out := maxi(massif.top_at(column), rock_shoulder(column))
	for index: int in _plot_columns.get(column, []) as Array:
		out = maxi(out, int((plots[index] as Dictionary)["top"]))
	return out


## The derived facts composition reads off a plot: `roofed` (no plot stands on
## any of its columns at its own top -- a roof deck up there means this plot
## has no roof of its own), `bears_on_rock` (every column's floor - 1 is rock
## rather than another plot, which is the existing terrain_bearing ->
## .base.rock composition rule stated at the source), and `tiered` (its top is
## an upper street's own band, within the footprint or its 1-column apron).
func plot_facts(plot: Dictionary) -> Dictionary:
	var id := StringName(plot.get("id", &""))
	var floor_band := int(plot.get("floor", 0))
	var top_band := int(plot.get("top", 0))
	var roofed := true
	var bears_on_rock := not (plot.get("cells", []) as Array).is_empty()
	var apron: Dictionary = {}
	for cell_value: Variant in plot.get("cells", []) as Array:
		var column := cell_value as Vector2i
		apron[column] = true
		for direction: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
			apron[column + direction] = true
		if not solid_at(Vector3i(column.x, floor_band - 1, column.y)):
			bears_on_rock = false
		for index: int in _plot_columns.get(column, []) as Array:
			var other := plots[index] as Dictionary
			if StringName(other["id"]) == id:
				continue
			var other_floor := int(other["floor"])
			var other_top := _plot_reserved_top(other)
			if top_band >= other_floor and top_band < other_top:
				roofed = false
			if floor_band - 1 >= other_floor and floor_band - 1 < other_top:
				bears_on_rock = false
	var tiered := false
	for cell: Vector3i in passage_kinds.keys():
		if cell.y == top_band and apron.has(Vector2i(cell.x, cell.z)):
			tiered = true
			break
	return {"roofed": roofed, "bears_on_rock": bears_on_rock,
		"tiered": tiered}


func _lowest_plot_floor(column: Vector2i) -> int:
	var out := 0
	var found := false
	for index: int in _plot_columns.get(column, []) as Array:
		var floor_band := int((plots[index] as Dictionary)["floor"])
		out = floor_band if not found else mini(out, floor_band)
		found = true
	return out


static func _plot_reserved_top(plot: Dictionary) -> int:
	## The band interval a plot RESERVES on its columns is [floor, this),
	## which is [floor, top) for anything with height and the single floor
	## band for a deck. A deck adds no solid mass (solid_at reads [floor,
	## top), which is empty for it) but two decks may still not share a band.
	return maxi(int(plot["top"]), int(plot["floor"]) + 1)


## The lowest carved band in [from_band, to_band) on `column`, -1 when the
## range is clear -- the public form of the reading the support rule, add_plot,
## and seal all share, so a planner asking "is a street in the way of this
## mass" never has to walk `excavation.carved` for itself.
func first_carved_band(column: Vector2i, from_band: int,
		to_band: int) -> int:
	return _first_carved_band(column, from_band, to_band)


## How many passage cells have nothing solid under the band they walk on. An
## audit fact, never a gate; seal records the same number under
## `audit["street_floor_gaps"]` once the town is finished.
func street_floor_gaps() -> int:
	return _street_floor_gaps()


func _first_carved_band(column: Vector2i, from_band: int,
		to_band: int) -> int:
	## The lowest carved band in [from_band, to_band) on `column`, -1 when the
	## range is clear. `excavation.carved` is every cell the bore removed --
	## each walk cell plus the void above it -- so this is the ONE reading of
	## "a street or its headroom is in the way" the support rule, add_plot,
	## and seal all share.
	if excavation == null:
		return -1
	for band in range(from_band, to_band):
		if excavation.carved.has(Vector3i(column.x, band, column.y)):
			return band
	return -1


func _plot_shape_rejection(plot: Dictionary) -> String:
	## "" when the dictionary really is a plot, else why it is not. Shape
	## alone: nothing here looks at the town around it.
	for key: String in ["id", "kind", "cells", "floor", "top", "door_walk",
			"building_id"]:
		if not plot.has(key):
			return "plot is missing the %s key" % key
	if typeof(plot["id"]) != TYPE_STRING_NAME \
			or typeof(plot["kind"]) != TYPE_STRING_NAME \
			or typeof(plot["building_id"]) != TYPE_STRING_NAME:
		return "plot id, kind, and building_id must be StringNames"
	if typeof(plot["cells"]) != TYPE_ARRAY or typeof(plot["floor"]) != TYPE_INT \
			or typeof(plot["top"]) != TYPE_INT \
			or typeof(plot["door_walk"]) != TYPE_VECTOR3I:
		return "plot cells, floor, top, or door_walk has the wrong type"
	var id := StringName(plot["id"])
	var kind := StringName(plot["kind"])
	if kind not in PLOT_KINDS:
		return "plot %s has unknown kind %s" % [id, kind]
	for existing: Dictionary in plots:
		if StringName(existing["id"]) == id:
			return "plot id %s is already taken" % id
	var cells: Array = plot["cells"]
	if cells.is_empty():
		return "plot %s has an empty footprint" % id
	var members: Dictionary = {}
	for cell_value: Variant in cells:
		if typeof(cell_value) != TYPE_VECTOR2I:
			return "plot %s has a footprint member that is not a column" % id
		var column := cell_value as Vector2i
		if members.has(column):
			return "plot %s repeats column %s" % [id, column]
		members[column] = true
	if not _footprint_is_connected(members, cells[0] as Vector2i):
		return "plot %s has a disconnected footprint" % id
	if int(plot["top"]) < int(plot["floor"]):
		return "plot %s has a top below its floor" % id
	if kind == PLOT_DECK and int(plot["top"]) != int(plot["floor"]):
		return "deck %s must be flat: top must equal floor" % id
	if kind != PLOT_DECK and int(plot["top"]) == int(plot["floor"]):
		return "plot %s has no height: only a deck may be flat" % id
	return ""


static func _footprint_is_connected(members: Dictionary,
		start: Vector2i) -> bool:
	var frontier: Array[Vector2i] = [start]
	var seen: Dictionary = {start: true}
	var head := 0
	while head < frontier.size():
		var column := frontier[head]
		head += 1
		for direction: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
			var next := column + direction
			if members.has(next) and not seen.has(next):
				seen[next] = true
				frontier.append(next)
	return seen.size() == members.size()


func _rebuild_plot_columns() -> void:
	## Seal re-derives the per-column index from `plots` themselves rather
	## than trusting add_plot's own running bookkeeping -- the same discipline
	## the claim validations above follow.
	_plot_columns.clear()
	for index in plots.size():
		for cell_value: Variant in (plots[index] as Dictionary)["cells"] \
				as Array:
			var column := cell_value as Vector2i
			var indices: Array = _plot_columns.get(column, [])
			indices.append(index)
			_plot_columns[column] = indices


func _rebuild_rock_shoulders() -> void:
	## One shoulder per no-plot column, computed once at seal: flood the
	## 4-neighbour regions of columns that carry no plot and give every member
	## of a region the lowest floor of the plots bordering it, or the massif
	## envelope where a region borders no plot at all. Region membership and a
	## minimum are both order-free, so the sorted seed walk is belt and braces.
	##
	## A region shoulder may never cut the ground out from under a street
	## (controller ruling, 2026-08-22): a column hosting passages keeps at
	## least what _street_rock_floors says those passages need, so an
	## un-built tunnel keeps its roof slab and a street keeps the rock it
	## stands on even where the town around it stepped down.
	_rock_shoulders.clear()
	if massif == null:
		return
	var street_floors := _street_rock_floors()
	var columns: Array[Vector2i] = []
	columns.assign(massif.columns.keys())
	columns.sort_custom(Callable(WarrenMazeSourcePlan, "_column_less"))
	var seen: Dictionary = {}
	for column: Vector2i in columns:
		if _plot_columns.has(column) or seen.has(column):
			continue
		var region: Array[Vector2i] = [column]
		seen[column] = true
		var shoulder := -1
		var head := 0
		while head < region.size():
			var current := region[head]
			head += 1
			for direction: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
				var next := current + direction
				if not massif.has_column(next):
					continue
				if _plot_columns.has(next):
					var floor_band := _lowest_plot_floor(next)
					shoulder = floor_band if shoulder < 0 \
						else mini(shoulder, floor_band)
				elif not seen.has(next):
					seen[next] = true
					region.append(next)
		for member: Vector2i in region:
			var derived := shoulder if shoulder >= 0 \
				else massif.top_at(member)
			_rock_shoulders[member] = maxi(derived,
				int(street_floors.get(member, derived)))


func _street_rock_floors() -> Dictionary:
	## Vector2i column -> the rock top the passages it hosts need under and
	## over them: the highest hosted passage's own headroom top, plus
	## TUNNEL_ROOF_BANDS where the carver left that passage COVERED (the
	## retained slab is the tunnel's roof; an open passage is carved to the
	## envelope, so its headroom top already is that envelope). One pass over
	## the passages, so a shoulder walk stays a column lookup. Columns hosting
	## no passage at all are absent.
	var out: Dictionary = {}
	for cell: Vector3i in passage_kinds.keys():
		var column := Vector2i(cell.x, cell.z)
		var need := passage_headroom_top(cell)
		if excavation != null and bool(excavation.covered.get(cell, false)):
			need += TUNNEL_ROOF_BANDS
		out[column] = maxi(int(out.get(column, need)), need)
	return out


func _street_floor_gaps() -> int:
	## Audit fact, never a gate (rules become repairs): how many passage cells
	## have nothing solid under the band they walk on. A cell at its own
	## terrain band counts as grounded -- solid_at answers true for the
	## untouched ground below massif.base_at -- so this counts real holes: a
	## street left hanging where a lower passage's headroom eats its floor, or
	## where the plot layer has yet to build the mass it stands on.
	var out := 0
	for cell: Vector3i in passage_cells():
		if not solid_at(Vector3i(cell.x, cell.y - 1, cell.z)):
			out += 1
	return out


func _plot_rejection() -> String:
	## Seal's plot half: the stack invariant on every column, then every plot
	## re-checked against the finished town. "" when the town is sound.
	_rebuild_plot_columns()
	_rebuild_rock_shoulders()
	var columns: Array[Vector2i] = []
	columns.assign(massif.columns.keys())
	columns.sort_custom(Callable(WarrenMazeSourcePlan, "_column_less"))
	for column: Vector2i in columns:
		# Solids must be contiguous from terrain: rock, then plots in floor
		# order. A carved band is a permitted gap (a street runs through the
		# block, and the mass above it is a real roof); any OTHER air band
		# with solid mass above it means something floats.
		var scan_top := massif.top_at(column)
		for index: int in _plot_columns.get(column, []) as Array:
			scan_top = maxi(scan_top, _plot_reserved_top(plots[index]))
		var air_band := -1
		for band in range(massif.base_at(column), scan_top):
			var cell := Vector3i(column.x, band, column.y)
			if solid_at(cell):
				if air_band >= 0:
					return ("column %s floats: solid mass at band %d stands " \
						+ "over open air at band %d") % [column, band, air_band]
			elif air_band < 0 and not excavation.carved.has(cell):
				air_band = band
	for index in plots.size():
		var placement := _plot_placement_rejection(plots[index], index)
		if placement != "":
			return placement
	return ""


func _plot_placement_rejection(plot: Dictionary, self_index: int) -> String:
	## Why this plot may not stand where it says it does -- the one support
	## rule, a carved cell inside the band interval it occupies, or an overlap
	## with a plot already standing on one of its columns -- and "" when it
	## may. `self_index` is the plot's own slot in `plots` when it is already
	## stored (seal re-checking a finished town) and -1 when it is not
	## (add_plot vetting a newcomer), so add_plot's own gate and seal's mirror
	## of it can never disagree about what a legal plot is.
	##
	## The carved check is where "every passage cell and its carved headroom
	## stays air" actually lives: solid_at answers air for a carved cell
	## whatever a plot claims, so the invariant that can really fail is the
	## one stated from the plot's side -- no plot claims a carved band.
	var id := StringName(plot["id"])
	var floor_band := int(plot["floor"])
	var reserved_top := _plot_reserved_top(plot)
	for cell_value: Variant in plot["cells"] as Array:
		var column := cell_value as Vector2i
		if not plot_support_ok(column, floor_band):
			if not solid_at(Vector3i(column.x, floor_band - 1, column.y)):
				return ("plot %s breaks support rule 1 at column %s: band %d " \
					+ "below its floor is not solid") \
					% [id, column, floor_band - 1]
			return ("plot %s breaks support rule 2 at column %s: carved air " \
				+ "stands inside its clearance [%d, %d)") \
				% [id, column, floor_band, floor_band + MIN_HOUSE_BANDS]
		var carved := _first_carved_band(column, floor_band, reserved_top)
		if carved >= 0:
			return ("plot %s covers carved band %d at column %s -- a street " \
				+ "and its headroom are immutable") % [id, carved, column]
		for index: int in _plot_columns.get(column, []) as Array:
			if index == self_index:
				continue
			var other := plots[index] as Dictionary
			if floor_band < _plot_reserved_top(other) \
					and reserved_top > int(other["floor"]):
				return "plot %s overlaps plot %s at column %s" \
					% [id, StringName(other["id"]), column]
	return ""


# --- End plot model --------------------------------------------------------


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
	# `plot:`, not `p:` -- that prefix already belongs to the passage cells
	# above. Ids are unique, so sorting the whole line sorts by id and the
	# order plots were added can never show in the signature.
	var plot_lines := PackedStringArray()
	for plot: Dictionary in plots:
		var plot_cells: Array[Vector2i] = []
		plot_cells.assign(plot["cells"])
		plot_cells.sort_custom(Callable(WarrenMazeSourcePlan, "_column_less"))
		var plot_text := PackedStringArray()
		for cell: Vector2i in plot_cells:
			plot_text.append("%d,%d" % [cell.x, cell.y])
		var door: Vector3i = plot["door_walk"]
		plot_lines.append("plot:%s:%s:%s:%d,%d:%d,%d,%d:%s" % [
			String(plot["id"]), String(plot["kind"]),
			"+".join(plot_text), int(plot["floor"]), int(plot["top"]),
			door.x, door.y, door.z, String(plot["building_id"])])
	plot_lines.sort()
	for line: String in plot_lines:
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
