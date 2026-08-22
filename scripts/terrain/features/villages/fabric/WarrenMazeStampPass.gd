class_name WarrenMazeStampPass
extends RefCounted

## P4 -- global largest-first stamping. Replaces the per-face greedy search
## (WarrenMazeBlockPartitioner's original loop) with one town-wide candidate
## pool: every (frontage face x shape) pair is scored once, sorted into a
## single deterministic order, and placed greedily. A candidate that only
## fails because its footprint crosses a terrace step -- some columns'
## effective_base sits up to one band above the footprint's own majority
## datum -- is rescued with a SMALL bounded edit (offender columns only, at
## most +/-1 band) instead of being discarded outright. On corpora with real
## per-column terrain relief this is what stops a raised threshold from
## forcing a whole footprint down to 1x1. A placed rectangular claim is also
## grown afterward into whatever unclaimed columns border it, deepening and
## widening in alternating rounds so it can walk around a corridor's corners.
##
## Every claim must stay TRANSLATABLE: WarrenParcelConstruction's authored
## templates fix a door at one specific end of the width axis (the minimum
## perpendicular-projection column of its own depth row) -- never a free
## choice, never mirrorable, since a template only carries one door position
## and address_door_phase is a 1.5m in-module shift, not a whole-column swap.
## An earlier round tried a MIRRORED variant of every 2-wide shape (claiming
## its second column on the OTHER side of the threshold) to fix a real
## one-sidedness starvation bug, but a mirrored footprint puts the door at
## the WRONG end -- WarrenBuildingParcel.seal() still succeeds (geometry is
## still a legal rectangle) yet WarrenParcelConstruction.door_serves_address
## always fails, since the authored template's fixed door position lands one
## macro column away from the real door. That variant is gone; every
## rectangular footprint here -- from direct placement, back-extension,
## lateral extension, or a 1x1 merge -- is checked (or by construction
## guaranteed) to keep door_column at that same minimum-projection position.
##
## Reads mass through the still-unsealed WarrenMazeSourcePlan directly
## (state_at / effective_top), never through a WarrenVolumePlan: P4 runs
## before any volume exists. frontage_faces_from_plan is the single shared
## implementation of frontage-face enumeration/sort/tie-break --
## WarrenMazeBlockPartitioner._frontage_faces delegates to it rather than
## keeping its own volume-backed copy, so the two paths cannot drift; see
## that method's comment for why the plan-based mass test and its own
## legacy volume.has_mass test agree for every caller it actually sees.

const CARDINALS: Array[Vector2i] = [
	Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP,
]

## Shape menu, in door-frontage frame (width = perpendicular to the door,
## depth = straight back from the door). The L is two rectangles -- a
## door-bearing 2x2 main arm and a 1x2 wing -- sharing one lineage_hint; both
## wing lanes are enumerated as separate menu entries so the global sort
## picks whichever orientation actually fits. No mirrored variants (see the
## class comment): every width-2 rect always claims its second column on the
## same fixed side of the threshold, at width_index 1 -- the minimum
## perpendicular-projection column (the threshold itself) stays door_column,
## matching what WarrenParcelConstruction's authored templates require.
const SHAPE_MENU: Array[Dictionary] = [
	{"id": &"2x3", "kind": &"rect", "width": 2, "depth": 3},
	{"id": &"2x2", "kind": &"rect", "width": 2, "depth": 2},
	{"id": &"L", "kind": &"l", "wing_lane": 1},
	{"id": &"L", "kind": &"l", "wing_lane": 0},
	{"id": &"1x2", "kind": &"rect", "width": 1, "depth": 2},
	{"id": &"2x1", "kind": &"rect", "width": 2, "depth": 1},
	{"id": &"1x1", "kind": &"rect", "width": 1, "depth": 1},
]
const ALL_SHAPE_INDICES: Array[int] = [0, 1, 2, 3, 4, 5, 6]
## <= 2 columns: 1x2, 2x1, 1x1 -- the infill pass's menu.
const SMALL_SHAPE_INDICES: Array[int] = [4, 5, 6]
## Back-extension deepens an already-placed rectangular claim into unclaimed
## interior columns directly behind it, at most this many extra columns.
const MAX_BACK_EXTENSION_DEPTH := 3
## Lateral extension widens an already-placed rectangular claim into
## unclaimed columns beside it, at most this many extra lanes per side.
const MAX_LATERAL_EXTENSION_WIDTH := 3
## Back- and lateral-extension are re-run this many times, alternating, so a
## claim can walk around a corridor's corners one straight lane at a time.
const EXTENSION_ROUNDS := 2
## Hard cap on how many claims one lineage (one building) may group.
const MAX_LINEAGE_SIZE := 3
const SCORE_SALT := 0x53544D50
## Per-scale (min, max) storey count a claim's roll may land in -- see
## _roll_storeys. Task 1 (2026-08-21): replaces the old massif-ceiling-derived
## house height (which made every house as tall as its column, up to a
## 14-band/7-storey tower) with a bounded, seeded storey budget.
const STOREY_BUDGET: Dictionary = {
	&"compact": Vector2i(2, 3), &"standard": Vector2i(2, 3),
	&"large": Vector2i(2, 4), &"grand": Vector2i(3, 4),
}
## Slice 1c task 1 (2026-08-22): a tiered claim's roof stops at the y of a
## real overhead street rather than a seeded roll -- see _find_tier_top --
## but a pathological street many bands above a shallow floor must still not
## produce an unbounded tower; this is the same kind of hard ceiling
## STOREY_BUDGET's own (min, max) already gives the seeded-roll path.
const MAX_TIER_STOREYS := 6
## A reservation cell's claimed interval: wide enough to exceed any real
## band value (bands run 0..~20) so it always covers the whole column,
## without risking int overflow the way INT32_MIN/MAX sentinels would in
## interval-arithmetic (e.g. `interval.x > floor_band`).
const RESERVATION_INTERVAL := Vector2i(-1000000, 1000000)
## Test-only escape hatch: stop() calls the skyline trim step (P4.5) by
## default; a test that needs the pre-trim plan flips this off rather than
## re-deriving stamp()'s whole pipeline up to a hypothetical stop_after.
static var skyline_trim_enabled := true
## Bands of built roof _skyline_trim leaves standing over a covered
## passage's own WarrenExcavation.HEADROOM_BANDS of required air -- refined
## 2026-08-21: a passage-hosting column is no longer exempt from trim
## outright (that left every covered tunnel standing under the FULL
## massif ceiling), but a bare street still wants a roof over its headroom,
## not just the headroom itself.
const TUNNEL_ROOF_BANDS := 1
## Plinth-bearing depth (refined 2026-08-21, replacing continuity-to-base):
## a footprint column bears at a candidate floor when only THIS many bands
## directly below the floor are solid (state_at, ledger-aware) -- not the
## whole column down to its own base. WarrenMazeSourcePlan.seal() re-derives
## the same test (against the pre-edit, raw massif/excavation) to validate a
## bearing stamp-phase edit cheaply; see _column_bears' own comment for why.
const PLINTH_BANDS := 2
## The only (width, depth) rectangles WarrenParcelConstruction.profile_for
## actually authors (tower/slim/row/building/long) -- WarrenBuildingParcel's
## own seal() independently forbids depth < width except for the row
## exception (width 2, depth 1), which is exactly this set. Extension and
## merge must never grow a claim's footprint past this vocabulary: a claim
## whose real footprint has no authored profile can never seal as a parcel,
## no matter how legal its geometry otherwise is.
const MENU_SHAPES: Array[Vector2i] = [
	Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 1), Vector2i(2, 2),
	Vector2i(2, 3),
]

static var last_failure := ""


static func stamp(plan: WarrenMazeSourcePlan,
		profile: WarrenVillageScaleProfile) -> bool:
	last_failure = ""
	if plan == null or plan.is_sealed():
		return _fail("stamp pass requires an unsealed maze source plan")
	if profile == null or not profile.validate():
		return _fail("stamp pass requires a valid scale profile")
	if plan.massif == null or not plan.massif.is_sealed():
		return _fail("stamp pass requires a sealed massif")

	## claimed_intervals: Vector2i column -> Array[Vector2i(floor_band,
	## top_band)], half-open bands. Replaces a plain 2D claimed-or-not map so a
	## column can carry more than one claim -- an upper street's frontage
	## stacked above a lower house's roof -- as long as their band ranges
	## stay disjoint. A reservation still claims the WHOLE column, at every
	## band, via RESERVATION_INTERVAL.
	var claimed_intervals: Dictionary = {}
	for reservation: Dictionary in plan.reservations:
		for column: Vector2i in reservation.get("cells", []) as Array:
			claimed_intervals[column] = [RESERVATION_INTERVAL]

	var faces := frontage_faces_from_plan(plan)
	var outcomes: Dictionary = {}
	var lineage_seed := {"count": 0}

	var main_candidates := _enumerate_candidates(plan, faces, claimed_intervals,
		ALL_SHAPE_INDICES)
	main_candidates.sort_custom(Callable(WarrenMazeStampPass,
		"_compare_candidates"))
	_run_pass(plan, main_candidates, claimed_intervals, outcomes, lineage_seed)

	# The door-arm depth every rectangular claim placed at, snapshotted once
	# here (before any extension round) and never recomputed from a
	# since-extended footprint -- back-extension reads this to cap its own
	# CUMULATIVE growth across every round at MAX_BACK_EXTENSION_DEPTH total,
	# not per round. Also published into the audit, keyed by door_column
	# (stable across every later merge/lineage step), so a test can check the
	# cap held on the final claims.
	var original_arm_depths: Dictionary = {}
	var original_arm_depth_by_door: Dictionary = {}
	for index in plan.parcel_claims.size():
		var claim := plan.parcel_claims[index] as Dictionary
		if String(claim.get("shape_id", "")).begins_with("L."):
			continue
		var into_block := -(claim.frontage as Vector2i)
		var depth := _footprint_depth(claim.footprint as Array[Vector2i],
			into_block)
		original_arm_depths[index] = depth
		original_arm_depth_by_door[claim.door_column as Vector2i] = depth
	plan.audit["stamp_original_arm_depth"] = original_arm_depth_by_door

	# Both extension passes preserve rectangularity (a lane is claimed only
	# all-or-nothing), so alternating them repeatedly lets an existing claim
	# grow around a corner one straight lane at a time: a maze block is
	# usually a thin winding corridor, not a compact box, so widening after
	# deepening (or vice versa) routinely opens room the first attempt in
	# that direction did not have yet.
	for _round in EXTENSION_ROUNDS:
		_back_extend(plan, claimed_intervals, outcomes, original_arm_depths)
		_lateral_extend(plan, claimed_intervals, outcomes)

	var infill_candidates := _enumerate_candidates(plan, faces,
		claimed_intervals, SMALL_SHAPE_INDICES)
	infill_candidates.sort_custom(Callable(WarrenMazeStampPass,
		"_compare_candidates"))
	_run_pass(plan, infill_candidates, claimed_intervals, outcomes, lineage_seed)

	# Infill routinely lands several 1x1s that a face-by-face view cannot see
	# are actually contiguous: two 1x1s side by side, or a 1x1 sitting flush
	# against an edge of an existing rectangle. Absorbing those into one
	# larger rectangular claim (never into an L piece, and only when the
	# union is still a solid rectangle at a matching floor_band) is what
	# keeps a maze block's leftover frontage from reporting as a run of
	# separate pencils once it is this fragmented.
	_merge_small_claims(plan, claimed_intervals, outcomes)

	# A building is a lineage, not a single claim -- the L-shape already
	# treats its two arms that way. This bounded post-pass extends the same
	# idea to whatever the merge above could not fold into one rectangle
	# (e.g. a staircase-shaped blob), so a blob split into several small
	# rectangles for the footprint contract still reads as one stepped
	# building downstream.
	_group_lineages(plan, lineage_seed)

	# P4.5 -- skyline trim: every claimed column's mass above its own roof
	# (or, if unclaimed, above the tallest adjacent claim's roof, or all the
	# way to terrain when no claimed neighbour exists) is now dead weight the
	# storey budget above left behind. Runs after lineage grouping (so a
	# roof line reflects every claim, including anything a merge folded in)
	# and before derive_foundations (foundations are read off the FINAL,
	# trimmed edit ledger). skyline_trim_enabled exists solely so a test can
	# compare a stamped plan's pre- and post-trim tops.
	if skyline_trim_enabled:
		plan.audit["trim_outcomes"] = _skyline_trim(plan)

	derive_foundations(plan)

	plan.audit["stamp_outcomes"] = outcomes
	return true


## Pure derivation, run last: for every claimed or reserved column whose
## datum (a claim's floor_band, a reservation's datum_band) sits above the
## column's own terrain sample, records how many bands of rock foundation
## that datum now stands on. Never rejects, never edits -- foundations are
## read off the ledger the earlier passes already committed, not a new gate
## on it. A column at grade (datum == terrain) is omitted entirely, so a
## consumer can treat "column present" as "this column needs a foundation".
## Stacked columns (Task 1): a column may now carry more than one claim at
## different floor_bands. Only the LOWEST claim on a column ever needs a
## foundation reaching down to terrain -- everything stacked above it is
## supported by the mass (and, when present, the claim) below, never by an
## independent foundation of its own -- so foundation depth is keyed by each
## column's minimum floor_band across every claim that touches it, not by
## whichever claim happened to be recorded last.
## Overhead (skywalk_span) reservations from the FLANK-search fallback are
## excluded outright: their datum_band is a neighboring walkway's height, not
## a floor for THIS column, and that path never edits the flank columns'
## floors, so they already stand on grounded natural rock -- any entry here
## would drive slice-2's retained-foundation machinery to build a foundation
## for a column that never asked for one. Refined 2026-08-22 (slice 1c task
## 1, the bridge-consuming path): a skywalk_span reservation drawn from
## `plan.excavation.bridge_spans` instead genuinely DOES edit its own cells
## (the retained bridge deck's own columns, raised to datum_band via
## record_edit -- see WarrenMazeReservationPass._claim_bridge_span) and
## therefore genuinely does need a foundation entry, exactly like any other
## edited column; it carries a `plot_top` key the flank fallback never sets,
## which is what distinguishes the two below. Skywalk support beyond that is
## still slice-2 composition's job, not this derivation's.
static func derive_foundations(plan: WarrenMazeSourcePlan) -> void:
	var min_floor_band: Dictionary = {}
	for claim: Dictionary in plan.parcel_claims:
		var floor_band := int(claim.floor_band)
		for column: Vector2i in claim.footprint as Array[Vector2i]:
			if not min_floor_band.has(column) \
					or floor_band < int(min_floor_band[column]):
				min_floor_band[column] = floor_band
	var foundation_columns: Dictionary = {}
	for column: Vector2i in min_floor_band.keys():
		var depth := int(min_floor_band[column]) - plan.massif.base_at(column)
		if depth > 0:
			foundation_columns[column] = depth
	for reservation: Dictionary in plan.reservations:
		# Skip a FLANK-search overhead reservation only -- datum is a
		# neighboring walk band, not this column's floor, and that path's
		# flank columns are grounded natural rock (no edit was ever
		# recorded). A bridge-consumed skywalk_span reservation (identified
		# by the `plot_top` key the flank path never sets -- see this
		# function's own header) DID edit its own cells and falls through to
		# the normal accounting below like any other reservation.
		if not (reservation.get("walk_cells", []) as Array).is_empty() \
				and not reservation.has("plot_top"):
			continue
		var datum := int(reservation.datum_band)
		for column: Vector2i in reservation.cells as Array[Vector2i]:
			var depth := datum - plan.massif.base_at(column)
			if depth > 0:
				foundation_columns[column] = depth
	plan.audit["foundation_columns"] = foundation_columns


## P4.5 -- discards unclaimed mass above whatever roofline the claims below
## actually reach, instead of leaving a column's full massif-ceiling silhouette
## standing over a 2-4 storey house. For every massif column, in deterministic
## sorted order: a SKYWALK-FLANK column (claim_overhead never edits a floor at
## all -- its flanks stand on grounded natural rock) stays exempt outright,
## untouched. A RESERVATION column (refined 2026-08-21: every other kind now
## carries a real ledger top -- see WarrenMazeReservationPass.PLOT_STOREYS --
## so it no longer needs a blanket exemption either) trims down to its own
## plot_top, exactly like a claimed column trims to its own roof -- deliberately
## routed here rather than falling into the unclaimed shoulder/discard branch
## below, since a reservation's datum is its own floor, not stray unassigned
## mass. A CLAIMED column (one owned by at least one parcel_claims footprint,
## possibly stacked) trims down to the tallest claim's own top_band -- its
## real roofline, never higher, never lower, since a trim can only lower.
## A PASSAGE-HOSTING column (refined 2026-08-21: no longer exempt outright,
## which used to leave every covered tunnel -- ~47% of the network --
## standing under the full massif) keeps `keep = max(any claim's own top on
## this column, highest passage cell y + WarrenExcavation.HEADROOM_BANDS +
## TUNNEL_ROOF_BANDS)`, then folds in the same 4-neighbour "shoulder" an
## unclaimed column uses (a tunnel between two tall buildings should read at
## least as tall as they do, not just clear its own headroom) -- trims to
## `max(keep, shoulder)`. An UNCLAIMED, non-passage, non-reservation column
## takes its "shoulder" from the tallest claim among its four cardinal
## neighbours; with no claimed neighbour at all, the column is genuinely
## isolated mass and is discarded flush to its own terrain (the old
## pipeline's `_discard_unassigned_mass`). Every target is computed first,
## entirely from the PRE-trim claim tops and PRE-trim effective_top --
## trimming one column never changes another column's target -- then applied
## in the same sorted order, so the result is independent of Dictionary
## iteration order. Returns counts by outcome kind for
## `plan.audit["trim_outcomes"]`.
static func _skyline_trim(plan: WarrenMazeSourcePlan) -> Dictionary:
	var passage_max_y: Dictionary = {}
	for cell: Vector3i in plan.passage_cells():
		var column := Vector2i(cell.x, cell.z)
		passage_max_y[column] = maxi(int(passage_max_y.get(column, cell.y)),
			cell.y)
	var skywalk_flank_columns: Dictionary = {}
	var reservation_tops: Dictionary = {}
	for reservation: Dictionary in plan.reservations:
		# A FLANK-search skywalk_span (no `plot_top` -- see derive_
		# foundations' own header for the same discriminator) never edits a
		# floor at all; its flank columns stay exempt from trim outright,
		# same as always. A BRIDGE-consumed skywalk_span (refined 2026-08-22,
		# slice 1c task 1) genuinely owns its own cells -- the retained
		# deck's own columns, already at their final plot_top via record_edit
		# -- and is routed through the ordinary reservation_tops branch below
		# like any other reservation kind, so a stray taller pre-edit ceiling
		# would still get trimmed down to it (record_edit already sets
		# effective_top to plot_top directly, so this is normally a no-op,
		# but the invariant should hold by the same mechanism every other
		# reservation kind uses, not by a coincidence of edit ordering).
		if StringName(reservation.get("kind", &"")) == &"skywalk_span" \
				and not reservation.has("plot_top"):
			for column: Vector2i in reservation.get("cells", []) as Array:
				skywalk_flank_columns[column] = true
			continue
		var plot_top := int(reservation.get("plot_top", 0))
		for column: Vector2i in reservation.get("cells", []) as Array:
			reservation_tops[column] = plot_top
	var claim_tops: Dictionary = {}
	for claim: Dictionary in plan.parcel_claims:
		var top := int(claim.top_band)
		for column: Vector2i in claim.footprint as Array[Vector2i]:
			claim_tops[column] = maxi(int(claim_tops.get(column, top)), top)

	var columns: Array[Vector2i] = []
	columns.assign(plan.massif.columns.keys())
	columns.sort_custom(Callable(WarrenMazeStampPass, "_column_less"))

	var targets: Array[Dictionary] = []
	for column: Vector2i in columns:
		if skywalk_flank_columns.has(column):
			continue
		var current_top := plan.effective_top(column)
		if reservation_tops.has(column):
			var plot_roof := int(reservation_tops[column])
			if current_top > plot_roof:
				targets.append({"column": column, "top": plot_roof,
					"kind": &"reservation_roof"})
			continue
		if passage_max_y.has(column):
			var keep := int(claim_tops.get(column, -2147483648))
			keep = maxi(keep, int(passage_max_y[column]) \
				+ WarrenExcavation.HEADROOM_BANDS + TUNNEL_ROOF_BANDS)
			var passage_shoulder := -2147483648
			for direction: Vector2i in CARDINALS:
				var neighbor := column + direction
				if claim_tops.has(neighbor):
					passage_shoulder = maxi(passage_shoulder,
						int(claim_tops[neighbor]))
			var target := maxi(keep, passage_shoulder)
			if current_top > target:
				targets.append({"column": column, "top": target,
					"kind": &"tunnel_roof"})
			continue
		if claim_tops.has(column):
			var roof := int(claim_tops[column])
			if current_top > roof:
				targets.append({"column": column, "top": roof,
					"kind": &"claimed_roof"})
			continue
		var shoulder := -2147483648
		for direction: Vector2i in CARDINALS:
			var neighbor := column + direction
			if claim_tops.has(neighbor):
				shoulder = maxi(shoulder, int(claim_tops[neighbor]))
		if shoulder > -2147483648:
			if current_top > shoulder:
				targets.append({"column": column, "top": shoulder,
					"kind": &"shoulder"})
		else:
			var base := plan.effective_base(column)
			if current_top > base:
				targets.append({"column": column, "top": base,
					"kind": &"discarded"})

	var trim_outcomes: Dictionary = {}
	for target: Dictionary in targets:
		if plan.record_trim(target.column as Vector2i, int(target.top)):
			_bump(trim_outcomes, String(target.kind as StringName))
		else:
			_bump(trim_outcomes, "rejected")
	return trim_outcomes


## Repeatedly finds a 1x1 claim next to another claim (1x1 or larger, but
## never an L piece) at the same floor_band whose union is still a solid
## axis-aligned rectangle, and folds the 1x1 into it. Runs to a fixed point:
## each successful merge removes one claim, so this always terminates, and a
## chain of three or more collinear 1x1s is absorbed one at a time (A+B -> a
## 1x2, then that 1x2 + C -> a 1x3, ...).
static func _merge_small_claims(plan: WarrenMazeSourcePlan,
		claimed_intervals: Dictionary, outcomes: Dictionary) -> void:
	while _merge_small_claims_once(plan, claimed_intervals, outcomes):
		pass


static func _merge_small_claims_once(plan: WarrenMazeSourcePlan,
		claimed_intervals: Dictionary, outcomes: Dictionary) -> bool:
	var column_to_claim: Dictionary = {}
	for index in plan.parcel_claims.size():
		var claim := plan.parcel_claims[index] as Dictionary
		if String(claim.get("shape_id", "")).begins_with("L."):
			continue
		for column: Vector2i in claim.footprint as Array[Vector2i]:
			column_to_claim[column] = index
	for index in plan.parcel_claims.size():
		var claim_a := plan.parcel_claims[index] as Dictionary
		var footprint_a := claim_a.footprint as Array[Vector2i]
		if footprint_a.size() != 1 \
				or String(claim_a.get("shape_id", "")).begins_with("L."):
			continue
		var column := footprint_a[0]
		for direction: Vector2i in CARDINALS:
			var neighbor := column + direction
			if not column_to_claim.has(neighbor):
				continue
			var other_index := int(column_to_claim[neighbor])
			if other_index == index:
				continue
			var claim_b := plan.parcel_claims[other_index] as Dictionary
			if int(claim_a.floor_band) != int(claim_b.floor_band):
				continue
			var footprint_b := claim_b.footprint as Array[Vector2i]
			var merged := footprint_b.duplicate()
			merged.append(column)
			if not _is_axis_rectangle(merged):
				continue
			# Invariant 2: refuse a merge that would leave the size menu, the
			# same rule extension already follows -- `into_block` here is
			# claim_b's own axis, and `_footprint_depth`/size division give
			# exactly the (width, depth) WarrenBuildingParcel.seal() would
			# derive from this same rectangle via frontage_direction.
			var into_block_b := -(claim_b.frontage as Vector2i)
			var merged_depth := _footprint_depth(merged, into_block_b)
			var merged_width := merged.size() / merged_depth
			if not _is_menu_shape(merged_width, merged_depth):
				continue
			# Invariant 3: the absorbed 1x1 must land behind/beside
			# door_column, never in front of or ahead of it in projection
			# order -- claim_a's own door is discarded (it stops being an
			# independent claim), so only claim_b's door survives, and it
			# must stay the merged footprint's minimum-projection column.
			if not _door_position_valid(merged,
					claim_b.door_column as Vector2i, into_block_b):
				continue
			var floor_band := int(claim_b.floor_band)
			var top_result := _claim_top_band(plan, merged, floor_band, false,
				claim_b.door_walk as Vector3i, claimed_intervals)
			var new_top := int(top_result.top)
			if new_top < 0:
				continue
			_refresh_stacked_edit_tops(plan, merged, new_top)
			claim_b["footprint"] = merged
			claim_b["top_band"] = new_top
			claim_b["tiered"] = bool(top_result.tiered)
			claim_b["shape_id"] = _shape_id_for_footprint(merged)
			plan.parcel_claims.remove_at(index)
			_claim_interval(claimed_intervals, merged, floor_band, new_top)
			_bump(outcomes, "infill_merged")
			return true
	return false


static func _is_axis_rectangle(footprint: Array[Vector2i]) -> bool:
	if footprint.is_empty():
		return false
	var min_x := 2147483647
	var max_x := -2147483648
	var min_z := 2147483647
	var max_z := -2147483648
	var seen: Dictionary = {}
	for column: Vector2i in footprint:
		if seen.has(column):
			return false
		seen[column] = true
		min_x = mini(min_x, column.x)
		max_x = maxi(max_x, column.x)
		min_z = mini(min_z, column.y)
		max_z = maxi(max_z, column.y)
	return (max_x - min_x + 1) * (max_z - min_z + 1) == footprint.size()


## Whether (width, depth), measured relative to `into_block` exactly as
## WarrenBuildingParcel.seal() measures its own width_cells/depth_cells from
## frontage_direction, is one of the five authored parcel profiles. A growth
## step (back-extension, lateral extension, or a 1x1 merge) that would leave
## this vocabulary must be refused outright, not committed and hoped for --
## WarrenParcelConstruction.profile_for returns {} for anything else, which
## fails door_serves_address unconditionally.
static func _is_menu_shape(width: int, depth: int) -> bool:
	return Vector2i(width, depth) in MENU_SHAPES


## Invariant 3's general form: door_column must be the footprint's own
## frontmost, then leftmost, column -- minimum projection onto into_block
## (depth) first, then minimum projection onto perpendicular (width) among
## whatever shares that same minimum depth -- exactly where
## WarrenParcelConstruction's authored templates fix their door. True by
## construction for direct placement (_rect_footprint never mirrors) and for
## back-extension (which only ever adds rows strictly behind door_column's
## own), so this exists to gate the two paths that could otherwise violate it
## on either axis: lateral extension growing the wrong way, and a 1x1 merge
## landing in front of or beside door_column on the wrong side.
static func _door_position_valid(footprint: Array[Vector2i],
		door_column: Vector2i, into_block: Vector2i) -> bool:
	var perpendicular := Vector2i(-into_block.y, into_block.x)
	var door_depth := door_column.x * into_block.x + door_column.y * into_block.y
	var door_projection := door_column.x * perpendicular.x \
		+ door_column.y * perpendicular.y
	for column: Vector2i in footprint:
		var depth := column.x * into_block.x + column.y * into_block.y
		if depth < door_depth:
			return false
		if depth > door_depth:
			continue
		var projection := column.x * perpendicular.x + column.y * perpendicular.y
		if projection < door_projection:
			return false
	return true


static func _shape_id_for_footprint(footprint: Array[Vector2i]) -> StringName:
	var min_x := 2147483647
	var max_x := -2147483648
	var min_z := 2147483647
	var max_z := -2147483648
	for column: Vector2i in footprint:
		min_x = mini(min_x, column.x)
		max_x = maxi(max_x, column.x)
		min_z = mini(min_z, column.y)
		max_z = maxi(max_z, column.y)
	return StringName("%dx%d" % [max_x - min_x + 1, max_z - min_z + 1])


## Bounded lineage-grouping post-pass: within each connected blob of claimed
## columns, groups ADJACENT claims into shared lineage_hints when their
## floor_bands differ by at most one band, capped at MAX_LINEAGE_SIZE claims
## per lineage. Processes claims in a deterministic sorted order (by each
## claim's own minimum column) and greedily attaches an ungrouped claim to
## the first adjacent, floor-compatible group with room, else opens a new
## one -- so a chain longer than the cap becomes several lineages, each
## still internally adjacent. An L pair already carries a shared
## lineage_hint and is seeded as one two-member group up front, so a third
## claim can still join it (counting toward the cap) but the pair itself is
## never broken apart. A claim with no adjacent, compatible neighbor becomes
## a lineage of one -- still assigned a unique hint, never left blank, so a
## consumer that groups by lineage_hint never accidentally lumps every
## isolated claim into one bucket.
static func _group_lineages(plan: WarrenMazeSourcePlan,
		lineage_seed: Dictionary) -> void:
	var claims := plan.parcel_claims
	if claims.is_empty():
		return
	var order: Array[int] = []
	for index in claims.size():
		order.append(index)
	order.sort_custom(func(left: int, right: int) -> bool:
		return _column_less(_claim_min_column(claims[left].footprint as \
				Array[Vector2i]),
			_claim_min_column(claims[right].footprint as Array[Vector2i])))

	var groups: Array[Dictionary] = []
	var hint_to_group: Dictionary = {}
	var claim_group: Dictionary = {}
	for index: int in order:
		var claim := claims[index] as Dictionary
		var hint := StringName(claim.get("lineage_hint", &""))
		if hint == &"":
			continue
		if not hint_to_group.has(hint):
			hint_to_group[hint] = groups.size()
			groups.append({"hint": hint, "members": [] as Array[int],
				"columns": {}, "floors": [] as Array[int]})
		var group_index: int = hint_to_group[hint]
		_add_claim_to_group(groups[group_index], index, claim)
		claim_group[index] = group_index

	for index: int in order:
		if claim_group.has(index):
			continue
		var claim := claims[index] as Dictionary
		var footprint := claim.footprint as Array[Vector2i]
		var floor_band := int(claim.floor_band)
		var attached := -1
		for group_index in groups.size():
			var group := groups[group_index]
			if (group.members as Array).size() >= MAX_LINEAGE_SIZE:
				continue
			var floors := (group.floors as Array).duplicate()
			floors.append(floor_band)
			var lowest: int = floors[0]
			var highest: int = floors[0]
			for value: int in floors:
				lowest = mini(lowest, value)
				highest = maxi(highest, value)
			if highest - lowest > 1:
				continue
			if not _footprints_adjacent(footprint,
					group.columns as Dictionary):
				continue
			attached = group_index
			break
		if attached < 0:
			lineage_seed.count = int(lineage_seed.count) + 1
			attached = groups.size()
			groups.append({"hint": StringName("maze.lineage.%d" \
				% int(lineage_seed.count)), "members": [] as Array[int],
				"columns": {}, "floors": [] as Array[int]})
		_add_claim_to_group(groups[attached], index, claim)
		claim_group[index] = attached

	for group: Dictionary in groups:
		var hint := group.hint as StringName
		for index: int in group.members as Array[int]:
			(claims[index] as Dictionary)["lineage_hint"] = hint


static func _add_claim_to_group(group: Dictionary, index: int,
		claim: Dictionary) -> void:
	(group.members as Array).append(index)
	(group.floors as Array).append(int(claim.floor_band))
	var columns := group.columns as Dictionary
	for column: Vector2i in claim.footprint as Array[Vector2i]:
		columns[column] = true


static func _footprints_adjacent(footprint: Array[Vector2i],
		group_columns: Dictionary) -> bool:
	for column: Vector2i in footprint:
		for direction: Vector2i in CARDINALS:
			if group_columns.has(column + direction):
				return true
	return false


static func _claim_min_column(footprint: Array[Vector2i]) -> Vector2i:
	var best := footprint[0]
	for column: Vector2i in footprint:
		if _column_less(column, best):
			best = column
	return best


static func _column_less(a: Vector2i, b: Vector2i) -> bool:
	if a.y != b.y:
		return a.y < b.y
	return a.x < b.x


## The single shared frontage-face enumeration: every (passage cell x
## cardinal direction) pair whose wall column is solid, deduplicated and
## sorted into one deterministic total order. Both P4 (this file, before any
## WarrenVolumePlan exists) and the legacy WarrenMazeBlockPartitioner (after
## one exists) call this exact implementation -- extracted so the two could
## not silently drift, per a duplication finding on an earlier round of this
## file, which had kept a byte-for-byte copy in each place.
##
## Reads solidity through the plan (state_at == SOLID, plus
## effective_top(column) > the passage's own band -- a wall column a P3
## reservation already flattened to zero height is not a real wall) rather
## than through a WarrenVolumePlan.has_mass(wall) test, which is what the
## legacy partitioner used to test directly. Those two tests agree exactly
## for the only caller that still reaches this code through the legacy path
## (WarrenMazeBlockPartitioner._frontage_faces, called from partition() with
## an unedited `source`: every partition() caller carves first and never
## stamps): WarrenExcavationVolumeAdapter builds `volume.mass_cells` as the
## massif's full per-column [base, top) range minus `excavation.carved` (see
## that adapter's own header comment), which is precisely what
## `state_at(cell) == SOLID` tests; and an unedited plan's `column_edits` is
## empty, so `effective_top` reads through to `massif.top_at` everywhere,
## making the extra effective_top guard here trivially true whenever
## `state_at(wall) == SOLID` is (a solid cell is by definition inside its
## column's [base, top) range) -- so it can never diverge from what
## volume.has_mass(wall) would already have excluded. The carver regression
## suite (test_warren_maze_carver.gd) pins this equivalence: the partitioner
## must still produce byte-identical parcels through this shared path.
static func frontage_faces_from_plan(
		plan: WarrenMazeSourcePlan) -> Array[Dictionary]:
	var faces: Array[Dictionary] = []
	var seen: Dictionary = {}
	for passage: Vector3i in plan.passage_cells():
		for into_block: Vector2i in CARDINALS:
			var column := Vector2i(passage.x, passage.z) + into_block
			var wall := Vector3i(column.x, passage.y, column.y)
			if plan.state_at(wall) != WarrenMazeSourcePlan.CellState.SOLID:
				continue
			if plan.effective_top(column) <= wall.y:
				continue
			var key := "%d:%d:%d:%d:%d" % [column.x, passage.y, column.y,
				into_block.x, into_block.y]
			if seen.has(key):
				continue
			seen[key] = true
			faces.append({"walk": passage, "column": column,
				"into_block": into_block,
				"tie": WarrenPassageLatticeRules.hash_key(plan.world_seed,
					0x50415243, wall, into_block.x * 3 + into_block.y)})
	faces.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_walk := left.walk as Vector3i
		var right_walk := right.walk as Vector3i
		if left_walk.y != right_walk.y:
			return left_walk.y < right_walk.y
		if int(left.tie) != int(right.tie):
			return int(left.tie) < int(right.tie)
		return _cell_less(left_walk, right_walk))
	return faces


static func _enumerate_candidates(plan: WarrenMazeSourcePlan,
		faces: Array[Dictionary], claimed_intervals: Dictionary,
		shape_indices: Array[int]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for face_index in faces.size():
		var face := faces[face_index]
		var walk := face.walk as Vector3i
		var into_block := face.into_block as Vector2i
		var door_column := face.column as Vector2i
		var frontage := -into_block
		for shape_index: int in shape_indices:
			var entry := SHAPE_MENU[shape_index]
			var candidate: Dictionary
			if StringName(entry.kind) == &"rect":
				var footprint := _rect_footprint(walk, into_block,
					int(entry.width), int(entry.depth))
				candidate = _build_rect_candidate(plan, face_index,
					shape_index, entry, walk, door_column, frontage,
					footprint, claimed_intervals)
			else:
				candidate = _build_l_candidate(plan, face_index, shape_index,
					entry, walk, door_column, frontage, into_block,
					claimed_intervals)
			if not candidate.is_empty():
				out.append(candidate)
	return out


static func _build_rect_candidate(plan: WarrenMazeSourcePlan, face_index: int,
		shape_index: int, entry: Dictionary, walk: Vector3i,
		door_column: Vector2i, frontage: Vector2i,
		footprint: Array[Vector2i],
		claimed_intervals: Dictionary) -> Dictionary:
	var floor_band := walk.y
	# A probe availability check (the one-band window [floor, floor+1)) --
	# the real [floor, top) window isn't known until _claim_top_band runs at
	# placement time, so this only rules out a footprint that already sits
	# INSIDE some existing claim's or reservation's band range at its own
	# floor. _try_place_rect re-checks with the real top before committing.
	if not _footprint_available(plan, footprint, claimed_intervals,
			floor_band, floor_band + 1):
		return {}
	# Always true by construction (_rect_footprint never mirrors) -- a
	# defensive invariant-3 check anyway, since this is the one place every
	# rectangular candidate is born.
	if not _door_position_valid(footprint, door_column, -frontage):
		return {}
	var datum_info := _footprint_offenders(plan, footprint, floor_band,
		claimed_intervals)
	if not bool(datum_info.get("ok", false)):
		return {}
	var offenders := datum_info.offenders as Array[Vector2i]
	var bearing_columns := datum_info.bearing_columns as Dictionary
	var contact := _neighbor_contact_count(footprint, claimed_intervals)
	var tie := posmod(WarrenPassageLatticeRules.hash_key(plan.world_seed,
		SCORE_SALT, walk, shape_index), 100)
	var score := footprint.size() * 10000 + contact * 400 \
		- offenders.size() * 50 + tie
	return {"face_index": face_index, "shape_index": shape_index,
		"score": score, "kind": &"rect", "footprint": footprint,
		"datum": floor_band, "offenders": offenders,
		"bearing_columns": bearing_columns, "walk": walk,
		"door_column": door_column, "frontage": frontage,
		"shape_id": StringName(entry.id), "is_1x1": footprint.size() == 1}


static func _build_l_candidate(plan: WarrenMazeSourcePlan, face_index: int,
		shape_index: int, entry: Dictionary, walk: Vector3i,
		door_column: Vector2i, frontage: Vector2i, into_block: Vector2i,
		claimed_intervals: Dictionary) -> Dictionary:
	var main := _rect_footprint(walk, into_block, 2, 2)
	var perpendicular := Vector2i(-into_block.y, into_block.x)
	var threshold := Vector2i(walk.x, walk.z) + into_block
	var wing_lane := int(entry.wing_lane)
	var wing: Array[Vector2i] = []
	for depth_offset in range(2, 4):
		wing.append(threshold + into_block * depth_offset \
			+ perpendicular * wing_lane)
	var combined: Array[Vector2i] = []
	combined.append_array(main)
	combined.append_array(wing)
	var floor_band := walk.y
	# See _build_rect_candidate: a one-band probe, the real window isn't
	# known until placement time.
	if not _footprint_available(plan, combined, claimed_intervals,
			floor_band, floor_band + 1):
		return {}
	var datum_info := _footprint_offenders(plan, combined, floor_band,
		claimed_intervals)
	if not bool(datum_info.get("ok", false)):
		return {}
	var offenders := datum_info.offenders as Array[Vector2i]
	var bearing_columns := datum_info.bearing_columns as Dictionary
	# The wing arm needs its OWN door -- a passage cell at this same
	# floor_band, adjacent to one of its own columns -- or it can never
	# independently seal as a parcel (WarrenBuildingParcel.seal() requires
	# `unique.has(threshold_column)`, and the wing's footprint never contains
	# the main arm's door_column). No legal wing door means no L here; the
	# plain 2x2 main-arm-only rectangle is a separately enumerated candidate
	# at this same face and remains free to compete on its own.
	var wing_door := _find_wing_door(plan, wing, floor_band)
	if wing_door.is_empty():
		return {}
	var contact := _neighbor_contact_count(combined, claimed_intervals)
	var tie := posmod(WarrenPassageLatticeRules.hash_key(plan.world_seed,
		SCORE_SALT, walk, shape_index), 100)
	var score := combined.size() * 10000 + contact * 400 \
		- offenders.size() * 50 + tie
	return {"face_index": face_index, "shape_index": shape_index,
		"score": score, "kind": &"l", "main_footprint": main,
		"wing_footprint": wing, "datum": floor_band,
		"offenders": offenders, "bearing_columns": bearing_columns,
		"walk": walk, "door_column": door_column,
		"frontage": frontage, "wing_door_walk": wing_door.door_walk,
		"wing_door_column": wing_door.door_column,
		"wing_frontage": wing_door.frontage, "is_1x1": false}


## First passage cell (in a fixed, deterministic column/direction order)
## exactly at `floor_band`, cardinal-adjacent to one of `wing`'s own columns
## -- a legal door for the wing arm to address independently, per invariant
## 3. Empty when none exists.
static func _find_wing_door(plan: WarrenMazeSourcePlan,
		wing: Array[Vector2i], floor_band: int) -> Dictionary:
	for column: Vector2i in wing:
		for direction: Vector2i in CARDINALS:
			var neighbor := column + direction
			var candidate_walk := Vector3i(neighbor.x, floor_band, neighbor.y)
			if not plan.passage_kinds.has(candidate_walk):
				continue
			# The wing's own frontage need not align with the main arm's --
			# it addresses whichever passage it actually found. Invariant 3
			# still applies against THAT axis: this candidate door_column
			# must be the wing's own minimum-projection column, or this
			# particular (column, direction) pair is not a legal wing door
			# even though a passage sits there.
			if not _door_position_valid(wing, column, -direction):
				continue
			return {"door_walk": candidate_walk, "door_column": column,
				"frontage": direction}
	return {}


static func _compare_candidates(left: Dictionary, right: Dictionary) -> bool:
	if int(left.score) != int(right.score):
		return int(left.score) > int(right.score)
	if int(left.face_index) != int(right.face_index):
		return int(left.face_index) < int(right.face_index)
	return int(left.shape_index) < int(right.shape_index)


## All-or-nothing offender commit: validates every offender in the batch
## against WarrenMazeSourcePlan.can_record_edit (a passage-hosting column, or
## a floor sinking below terrain -- record_edit's own gates, checked without
## mutating the ledger) BEFORE recording any of them. Only once the whole
## batch clears does it call record_edit for real, once per offender. All
## four call sites in this file (direct rect/L placement, back-extension,
## lateral extension) used to call plan.record_edit per offender inline and
## abort mid-loop on the first rejection -- which could leave an earlier
## offender in the same batch already committed to the ledger with no claim
## ever recorded to match it (an orphaned floor/top edit), since a rejection
## only ever happens when an offender turns out to host a passage on some
## other band (state the ±1-band datum gate in _footprint_offenders never
## checks) or -- for extension, where budget/geometry gates already ran --
## essentially never. Returns false (and bumps "edit_rejected" once) without
## recording anything if any offender fails; true once every offender in the
## batch is actually committed. `bearing_columns` (only ever non-empty from
## the two direct-placement call sites, which alone can produce a bearing
## offender via _footprint_offenders) marks which offenders in THIS batch
## are bearing -- extension's own inline offender check has no bearing
## concept and always passes {}.
static func _record_offender_batch(plan: WarrenMazeSourcePlan,
		offenders: Array[Vector2i], floor_band: int, top_band: int,
		phase: StringName, outcomes: Dictionary,
		bearing_columns: Dictionary) -> bool:
	for column: Vector2i in offenders:
		if not plan.can_record_edit(column, floor_band):
			_bump(outcomes, "edit_rejected")
			return false
	for column: Vector2i in offenders:
		if not plan.record_edit(column, floor_band, top_band, phase,
				bearing_columns.has(column)):
			# Unreachable given the validation pass above (can_record_edit
			# mirrors record_edit's own gates exactly), but never leave a
			# partially-committed batch if the two ever somehow disagree.
			_bump(outcomes, "edit_rejected")
			return false
	return true


static func _run_pass(plan: WarrenMazeSourcePlan,
		candidates: Array[Dictionary], claimed_intervals: Dictionary,
		outcomes: Dictionary, lineage_seed: Dictionary) -> void:
	for candidate: Dictionary in candidates:
		if StringName(candidate.kind) == &"rect":
			_try_place_rect(plan, candidate, claimed_intervals, outcomes)
		else:
			_try_place_l(plan, candidate, claimed_intervals, outcomes,
				lineage_seed)


static func _try_place_rect(plan: WarrenMazeSourcePlan, candidate: Dictionary,
		claimed_intervals: Dictionary, outcomes: Dictionary) -> void:
	var footprint := candidate.footprint as Array[Vector2i]
	var floor_band := int(candidate.datum)
	var door_walk := candidate.walk as Vector3i
	if not _footprint_available(plan, footprint, claimed_intervals,
			floor_band, floor_band + 1):
		_bump(outcomes, "column_taken")
		return
	# Re-derive offenders/bearing against the LIVE claimed_intervals, never
	# the stale enumeration-time snapshot cached on `candidate` -- see
	# _footprint_offenders' own comment: a bearing verdict in particular can
	# go stale the instant an EARLIER candidate in this same sorted pass
	# commits a claim over ground this one also needs, since main_candidates
	# is scored once, entirely up front, before anything is placed.
	var datum_info := _footprint_offenders(plan, footprint, floor_band,
		claimed_intervals)
	if not bool(datum_info.get("ok", false)):
		_bump(outcomes, "column_taken")
		return
	var top_result := _claim_top_band(plan, footprint, floor_band,
		bool(candidate.is_1x1), door_walk, claimed_intervals)
	var top_band := int(top_result.top)
	if top_band < 0:
		_bump(outcomes, "insufficient_height")
		return
	if not _footprint_available(plan, footprint, claimed_intervals,
			floor_band, top_band):
		_bump(outcomes, "column_taken")
		return
	var offenders := datum_info.offenders as Array[Vector2i]
	var bearing_columns := datum_info.bearing_columns as Dictionary
	if not _record_offender_batch(plan, offenders, floor_band, top_band,
			&"stamp", outcomes, bearing_columns):
		return
	_refresh_stacked_edit_tops(plan, footprint, top_band)
	plan.parcel_claims.append({"footprint": footprint.duplicate(),
		"floor_band": floor_band, "top_band": top_band,
		"door_walk": door_walk,
		"door_column": candidate.door_column as Vector2i,
		"frontage": candidate.frontage as Vector2i, "lineage_hint": &"",
		"shape_id": candidate.shape_id as StringName,
		"tiered": bool(top_result.tiered)})
	_claim_interval(claimed_intervals, footprint, floor_band, top_band)
	_bump(outcomes, "placed")


static func _try_place_l(plan: WarrenMazeSourcePlan, candidate: Dictionary,
		claimed_intervals: Dictionary, outcomes: Dictionary,
		lineage_seed: Dictionary) -> void:
	var main := candidate.main_footprint as Array[Vector2i]
	var wing := candidate.wing_footprint as Array[Vector2i]
	var combined: Array[Vector2i] = []
	combined.append_array(main)
	combined.append_array(wing)
	var floor_band := int(candidate.datum)
	var door_walk := candidate.walk as Vector3i
	if not _footprint_available(plan, combined, claimed_intervals,
			floor_band, floor_band + 1):
		_bump(outcomes, "column_taken")
		return
	# See _try_place_rect: re-derive against the LIVE claimed_intervals,
	# never the stale enumeration-time snapshot cached on `candidate`.
	var datum_info := _footprint_offenders(plan, combined, floor_band,
		claimed_intervals)
	if not bool(datum_info.get("ok", false)):
		_bump(outcomes, "column_taken")
		return
	var top_result := _claim_top_band(plan, combined, floor_band, false,
		door_walk, claimed_intervals)
	var top_band := int(top_result.top)
	if top_band < 0:
		_bump(outcomes, "insufficient_height")
		return
	if not _footprint_available(plan, combined, claimed_intervals,
			floor_band, top_band):
		_bump(outcomes, "column_taken")
		return
	var offenders := datum_info.offenders as Array[Vector2i]
	var bearing_columns := datum_info.bearing_columns as Dictionary
	if not _record_offender_batch(plan, offenders, floor_band, top_band,
			&"stamp", outcomes, bearing_columns):
		return
	_refresh_stacked_edit_tops(plan, combined, top_band)
	lineage_seed.count = int(lineage_seed.count) + 1
	var lineage := StringName("maze.lineage.%d" % int(lineage_seed.count))
	var tiered := bool(top_result.tiered)
	plan.parcel_claims.append({"footprint": main.duplicate(),
		"floor_band": floor_band, "top_band": top_band,
		"door_walk": door_walk,
		"door_column": candidate.door_column as Vector2i,
		"frontage": candidate.frontage as Vector2i, "lineage_hint": lineage,
		"shape_id": &"L.main", "tiered": tiered})
	plan.parcel_claims.append({"footprint": wing.duplicate(),
		"floor_band": floor_band, "top_band": top_band,
		"door_walk": candidate.wing_door_walk as Vector3i,
		"door_column": candidate.wing_door_column as Vector2i,
		"frontage": candidate.wing_frontage as Vector2i, "tiered": tiered,
		"lineage_hint": lineage, "shape_id": &"L.wing"})
	_claim_interval(claimed_intervals, combined, floor_band, top_band)
	_bump(outcomes, "placed")


## Deepens every already-placed, purely-rectangular claim into unclaimed
## interior columns directly behind it (same width, same datum rules) before
## the small-shape infill pass runs -- but never past MAX_BACK_EXTENSION_DEPTH
## TOTAL, no matter how many EXTENSION_ROUNDS it takes: `original_depths`
## (claim index -> depth at the moment the main pass placed it, snapshotted
## once before any round) is what bounds this call's own budget, rather than
## always re-deriving up to MAX_BACK_EXTENSION_DEPTH more from the CURRENT
## (possibly already-extended-this-round-or-a-prior-one) footprint, which
## would let a claim's depth grow unboundedly across rounds instead of
## capping at a true one-building depth. This is what turns a 2-wide claim
## that stopped short of a terrace step into a proper building instead of
## leaving the columns behind it to straggle in as separate 1x1 infill.
static func _back_extend(plan: WarrenMazeSourcePlan,
		claimed_intervals: Dictionary, outcomes: Dictionary,
		original_depths: Dictionary) -> void:
	for index in plan.parcel_claims.size():
		var claim := plan.parcel_claims[index] as Dictionary
		if not String(claim.get("shape_id", "")).begins_with("L."):
			_back_extend_claim(plan, claim, index, claimed_intervals, outcomes,
				original_depths)


static func _back_extend_claim(plan: WarrenMazeSourcePlan, claim: Dictionary,
		claim_index: int, claimed_intervals: Dictionary, outcomes: Dictionary,
		original_depths: Dictionary) -> void:
	var footprint := (claim.footprint as Array[Vector2i]).duplicate()
	var into_block := -(claim.frontage as Vector2i)
	var width_columns := _lateral_lane(footprint, into_block)
	if width_columns.is_empty():
		return
	var floor_band := int(claim.floor_band)
	var top_band := int(claim.top_band)
	var width := width_columns.size()
	var depth_used := _footprint_depth(footprint, into_block)
	var original_depth: int = original_depths.get(claim_index, depth_used)
	var already_added := depth_used - original_depth
	var remaining_budget := maxi(0, MAX_BACK_EXTENSION_DEPTH - already_added)
	for extra in remaining_budget:
		# Invariant 2: a growth step that would leave the authored size menu
		# is refused outright, before even checking geometry -- WarrenMassif
		# columns run far deeper than any real building footprint, so without
		# this a claim would happily deepen past what the parcel translator
		# can ever construct.
		if not _is_menu_shape(width, depth_used + extra + 1):
			break
		var row: Array[Vector2i] = []
		for lane_column: Vector2i in width_columns:
			row.append(lane_column + into_block * (depth_used + extra))
		if not _footprint_available(plan, row, claimed_intervals, floor_band,
				floor_band + 1):
			break
		# Anchor to the claim's already-committed floor_band (not a fresh
		# per-row majority): a column below it needs at most one band of
		# extra foundation; a column above it can never be reconciled (the
		# immutable-floor rule forbids lowering it), so the whole row -- and
		# the extension -- stops there.
		var offenders: Array[Vector2i] = []
		var feasible := true
		for column: Vector2i in row:
			var base := plan.effective_base(column)
			if base == floor_band:
				continue
			if base > floor_band or floor_band - base > 1:
				feasible = false
				break
			offenders.append(column)
		if not feasible:
			break
		var extended_footprint := footprint.duplicate()
		extended_footprint.append_array(row)
		var extended_result := _claim_top_band(plan, extended_footprint,
			floor_band, false, claim.door_walk as Vector3i, claimed_intervals)
		var extended_top := int(extended_result.top)
		if extended_top < top_band:
			break
		if not _footprint_available(plan, row, claimed_intervals, floor_band,
				extended_top):
			break
		if not _record_offender_batch(plan, offenders, floor_band,
				extended_top, &"stamp", outcomes, {}):
			return
		footprint.append_array(row)
		top_band = extended_top
		claim["tiered"] = bool(extended_result.tiered)
		_refresh_stacked_edit_tops(plan, footprint, top_band)
		_claim_interval(claimed_intervals, footprint, floor_band, top_band)
		_bump(outcomes, "back_extended")
	claim["footprint"] = footprint
	claim["top_band"] = top_band


## The lane of columns along the claim's outer (widthwise) edge, ordered so
## `lane + into_block * depth` walks straight back through the footprint.
static func _lateral_lane(footprint: Array[Vector2i],
		into_block: Vector2i) -> Array[Vector2i]:
	var perpendicular := Vector2i(-into_block.y, into_block.x)
	var by_depth: Dictionary = {}
	for column: Vector2i in footprint:
		var depth := 0
		var probe := column
		while footprint.has(probe - into_block):
			probe -= into_block
			depth += 1
		by_depth[depth] = by_depth.get(depth, []) as Array
		(by_depth[depth] as Array).append(column)
	if not by_depth.has(0):
		return []
	var lane: Array[Vector2i] = []
	lane.assign(by_depth[0])
	lane.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var a_offset := a - footprint[0]
		var b_offset := b - footprint[0]
		var a_lateral := a_offset.x * perpendicular.x + a_offset.y * perpendicular.y
		var b_lateral := b_offset.x * perpendicular.x + b_offset.y * perpendicular.y
		return a_lateral < b_lateral)
	return lane


static func _footprint_depth(footprint: Array[Vector2i],
		into_block: Vector2i) -> int:
	var depth := 1
	var growing := true
	while growing:
		growing = false
		for column: Vector2i in footprint:
			if footprint.has(column + into_block * depth):
				growing = true
				break
		if growing:
			depth += 1
	return depth


## Widens every already-placed, purely-rectangular claim into unclaimed
## columns beside it (either lateral side, same datum rules) before the
## small-shape infill pass runs. The main pass frequently strands 1-wide
## slivers next to a claimed neighbor -- most maze blocks are only 2-3
## columns deep before the next lane, so a deep shape (2x3, L) crosses that
## lane's headroom and gets skipped, leaving narrow leftovers on both sides
## of whatever did land. Absorbing those leftovers sideways is what turns
## "one wide building plus a run of 1x1 pencils" into "one wide building"
## and is what actually moves the median, since back-extension alone cannot
## reach past a lane that is right behind the claim.
static func _lateral_extend(plan: WarrenMazeSourcePlan,
		claimed_intervals: Dictionary, outcomes: Dictionary) -> void:
	for claim: Dictionary in plan.parcel_claims:
		if not String(claim.get("shape_id", "")).begins_with("L."):
			_lateral_extend_claim(plan, claim, claimed_intervals, outcomes)


static func _lateral_extend_claim(plan: WarrenMazeSourcePlan,
		claim: Dictionary, claimed_intervals: Dictionary,
		outcomes: Dictionary) -> void:
	var footprint := (claim.footprint as Array[Vector2i]).duplicate()
	var into_block := -(claim.frontage as Vector2i)
	var perpendicular := Vector2i(-into_block.y, into_block.x)
	var door_column := claim.door_column as Vector2i
	var floor_band := int(claim.floor_band)
	var top_band := int(claim.top_band)
	# Depth never changes during lateral extension (only width does), so it
	# is computed once.
	var depth := _footprint_depth(footprint, into_block)
	var width := footprint.size() / depth
	# Grow toward +perpendicular ONLY, never -perpendicular: -perpendicular
	# would insert a new column BEFORE door_column in projection order,
	# breaking invariant 3 (door_column must stay the footprint's own
	# minimum-projection column -- see _door_position_valid). This is the
	# same direction _rect_footprint always uses for width_index 1, so it
	# never leaves an already-valid door position invalid; the explicit
	# check below is a defensive belt on top of that.
	for extra in MAX_LATERAL_EXTENSION_WIDTH:
		# Invariant 2: refuse a growth step that would leave the menu.
		if not _is_menu_shape(width + 1, depth):
			break
		var row := _outer_lane(footprint, into_block, perpendicular)
		if not _footprint_available(plan, row, claimed_intervals, floor_band,
				floor_band + 1):
			break
		var prospective := footprint.duplicate()
		prospective.append_array(row)
		if not _door_position_valid(prospective, door_column, into_block):
			break
		var offenders: Array[Vector2i] = []
		var feasible := true
		for column: Vector2i in row:
			var base := plan.effective_base(column)
			if base == floor_band:
				continue
			if base > floor_band or floor_band - base > 1:
				feasible = false
				break
			offenders.append(column)
		if not feasible:
			break
		var extended_result := _claim_top_band(plan, prospective, floor_band,
			false, claim.door_walk as Vector3i, claimed_intervals)
		var extended_top := int(extended_result.top)
		if extended_top < top_band:
			break
		if not _footprint_available(plan, row, claimed_intervals, floor_band,
				extended_top):
			break
		if not _record_offender_batch(plan, offenders, floor_band,
				extended_top, &"stamp", outcomes, {}):
			return
		footprint.append_array(row)
		top_band = extended_top
		width += 1
		claim["tiered"] = bool(extended_result.tiered)
		_refresh_stacked_edit_tops(plan, footprint, top_band)
		_claim_interval(claimed_intervals, footprint, floor_band, top_band)
		_bump(outcomes, "lateral_extended")
	claim["footprint"] = footprint
	claim["top_band"] = top_band


## For each distinct depth row in a rectangular footprint (grouped by
## projection onto into_block), the column farthest along `direction`, offset
## one more step in `direction`: the next new lane widening the footprint
## that way. Works on any rectangular footprint regardless of its absolute
## origin or how many rows back-extension has already appended.
static func _outer_lane(footprint: Array[Vector2i], into_block: Vector2i,
		direction: Vector2i) -> Array[Vector2i]:
	var groups: Dictionary = {}
	for column: Vector2i in footprint:
		var depth := column.x * into_block.x + column.y * into_block.y
		if not groups.has(depth):
			groups[depth] = [] as Array[Vector2i]
		(groups[depth] as Array).append(column)
	var out: Array[Vector2i] = []
	var depth_keys: Array = groups.keys()
	depth_keys.sort()
	for depth_key: Variant in depth_keys:
		var group := groups[depth_key] as Array
		var best: Vector2i = group[0]
		var best_projection := best.x * direction.x + best.y * direction.y
		for column: Vector2i in group:
			var projection := column.x * direction.x + column.y * direction.y
			if projection > best_projection:
				best = column
				best_projection = projection
		out.append(best + direction)
	return out


## width_index 0 is always the threshold (door_column) itself -- the
## door position WarrenParcelConstruction's authored templates fix, at the
## minimum perpendicular-projection column of the door's own depth row (see
## the class comment). Never mirrored: there is no valid alternative.
static func _rect_footprint(walk: Vector3i, into_block: Vector2i,
		width: int, depth: int) -> Array[Vector2i]:
	var perpendicular := Vector2i(-into_block.y, into_block.x)
	var threshold := Vector2i(walk.x, walk.z) + into_block
	var out: Array[Vector2i] = []
	for depth_offset in depth:
		for width_index in width:
			out.append(threshold + into_block * depth_offset \
				+ perpendicular * width_index)
	return out


## `claimed_intervals` overlay: no footprint column may overlap ANY existing
## claimed or reserved [floor, top) band range on that column. `(floor_band,
## floor_band + 1)` is the standard probe a candidate builder uses before its
## own real top is known (see _build_rect_candidate); a placement site
## re-checks with the real computed top before committing.
static func _footprint_available(plan: WarrenMazeSourcePlan,
		footprint: Array[Vector2i], claimed_intervals: Dictionary,
		floor_band: int, top_band: int) -> bool:
	if footprint.is_empty():
		return false
	var seen: Dictionary = {}
	for column: Vector2i in footprint:
		if seen.has(column):
			return false
		seen[column] = true
		if not plan.massif.has_column(column):
			return false
		for interval: Vector2i in claimed_intervals.get(column, []) as Array:
			if floor_band < interval.y and top_band > interval.x:
				return false
	return true


## The datum is the addressing street's own elevation (`walk.y` of the face a
## candidate is anchored to), never the footprint's own terrain majority --
## WarrenBuildingParcel.seal()'s very first check is
## `address_walk_cell.y != base_band -> false`, an unconditional invariant, so
## floor_band can only ever be the door's own band. A footprint column within
## one band of that fixed datum is a within-budget offender (raised to match,
## same record_edit rules as before); a column further away, in either
## direction, makes the WHOLE footprint infeasible at this shape UNLESS it
## BEARS (see _column_bears) -- not edited, not substituted -- so the
## candidate simply does not exist at this size and a smaller shape
## (independently enumerated at the same face) is free to succeed instead.
##
## A column already carrying a claimed interval whose own top sits exactly
## (flush -- see _stacks_on_existing_claim) at this candidate's datum is
## exempt from the terrain check entirely -- it isn't standing on raw
## terrain, it's standing on the mass (and, by construction, the
## previously-cleared offender budget) the claim below it already
## established. Without this, an upper street's frontage could never
## stack above a lower house: `effective_base` reads the column's TERRAIN
## floor, which for a claim several bands up a climbing street is nowhere
## near within the +/-1 budget, even though the column is solid, claimed,
## and fully able to carry a second storey directly on top of the first.
##
## Refined 2026-08-21 (the tiers unlock): a column whose mass is BEARING --
## continuous SOLID rock from its own effective_base up to (not including)
## datum, checked band-by-band, no gap -- is likewise exempt from the +/-1
## budget, regardless of how far above terrain datum actually sits. The
## column isn't floating: an upper-street house standing on this rock is
## standing on real mountain, and the depth below it becomes deep foundation
## (derive_foundations already computes floor - terrain for exactly this).
## A column whose mass does NOT reach the floor -- any gap, a carved
## passage, genuinely empty air -- would float if built on, and stays
## subject to the existing +/-1 rule exactly as before. Returns which
## offenders are bearing (as opposed to within-budget) in `bearing_columns`,
## so the caller can record `bearing: true` on those specific edits for
## seal()'s own (cheaper, massif-range) re-validation of the same rule.
static func _footprint_offenders(plan: WarrenMazeSourcePlan,
		footprint: Array[Vector2i], datum: int,
		claimed_intervals: Dictionary) -> Dictionary:
	var offenders: Array[Vector2i] = []
	var bearing_columns: Dictionary = {}
	for column: Vector2i in footprint:
		if _stacks_on_existing_claim(claimed_intervals, column, datum):
			continue
		var base := plan.effective_base(column)
		if base == datum:
			continue
		if base > datum:
			return {"ok": false}
		if _column_bears(plan, column, datum, claimed_intervals):
			offenders.append(column)
			bearing_columns[column] = true
			continue
		if datum - base > 1:
			return {"ok": false}
		offenders.append(column)
	return {"ok": true, "offenders": offenders, "bearing_columns": bearing_columns}


static func _stacks_on_existing_claim(claimed_intervals: Dictionary,
		column: Vector2i, datum: int) -> bool:
	## Flush only: the candidate's own floor must land exactly on an existing
	## claim's own top on this column -- a storey built directly on the roof
	## of the one below, no void between them. A wider (any-gap) allowance
	## was tried and measurably over-produces: dozens of small, mutually
	## non-adjacent stacked 1x1 infill claims per town, each an unavoidable
	## lineage of one, which drags the town's MEDIAN lineage footprint (a
	## protected corpus metric) below 2 -- see the plan doc's measured
	## before/after. Flush-only keeps the mechanism (and the corpus test that
	## proves it fires) while bounding it to genuine "next storey up" tiers.
	for interval: Vector2i in claimed_intervals.get(column, []) as Array:
		if interval.y == datum:
			return true
	return false


## Whether `column` is BEARING at `floor_band`: PLINTH-BASED (refined
## 2026-08-21, replacing "continuous solid all the way down to the column's
## own base") -- only the PLINTH_BANDS immediately below the floor need to
## be SOLID, not the whole column's depth. "Lower tunnels beneath are
## allowed" is the point: a room built directly over a covered passage's own
## roof is by design (a real 2-band slab separates it from the tunnel below,
## the passage's own carved headroom notwithstanding), so requiring
## continuity all the way to base -- which the old rule did -- rejected
## every candidate anywhere near a tunnel even though only a thin plinth
## directly under the new floor actually needs to hold it up. `state_at`
## (ledger-aware, so an already-recorded edit or an earlier claim's own
## committed mass counts, same as before) already returns non-SOLID for a
## passage cell, so "no passage cell in the plinth range" falls out of the
## same per-band SOLID check, no separate test needed. The occupancy check
## (no OTHER claim's own interval overlaps the plinth range) is unchanged
## from the continuity-to-base version and for the same reason: state_at
## alone cannot tell "raw mountain rock" from "another claim's own footprint
## that hasn't been trimmed away yet" (trim never runs until every claim in
## this pass is placed), so without it a bearing candidate could silently
## double-claim a column another claim already owns.
## A column whose own base already sits at or above floor_band has nothing
## to check and does not bear (the base==datum and base>datum cases are
## handled by the caller before this is ever reached).
static func _column_bears(plan: WarrenMazeSourcePlan, column: Vector2i,
		floor_band: int, claimed_intervals: Dictionary) -> bool:
	var base := plan.effective_base(column)
	if base >= floor_band:
		return false
	# Fix round 5 (translation-drop regression, found via the standard-scale
	# sweep the compact-only pinned corpus never exercised): bearing must
	# refuse a column that ANY other claim already occupies, at ANY band --
	# not just a band that overlaps this candidate's own plinth range.
	# record_edit overwrites column_edits[column] WHOLESALE (floor_band AND
	# top_band together, since a column carries only one ledger entry), so a
	# bearing edit here would silently rewrite another, non-overlapping
	# claim's own floor the moment WarrenMazeVolumeAdapter reads
	# effective_base for that column -- that claim's own [floor, top) range
	# would no longer exist in the adapted volume at all, and
	# WarrenBuildingParcel.seal() would reject it, later, at translation, far
	# from where the real cause was written. A plinth-range-only overlap
	# check (the first version of this fix) missed exactly this: two claims
	# whose BANDS never touch can still collide on the SAME column's single
	# ledger entry.
	if claimed_intervals.has(column):
		return false
	# Bridge-capable ledger (rule 4, slice 1c task 1, 2026-08-22): a column
	# that hosts a passage elsewhere in its own vertical extent -- typically
	# a lower tunnel crossing beneath this footprint column, exactly the
	# "lower tunnels beneath are allowed" case this function's own header
	# already describes -- bears automatically the instant its floor lands
	# EXACTLY on that tunnel's own future-trimmed roof slab (passage y +
	# WarrenExcavation.HEADROOM_BANDS + TUNNEL_ROOF_BANDS): the same flush
	# exemption _stacks_on_existing_claim grants an already-placed claim's
	# own roof, extended to the not-yet-claimed tunnel roof skyline trim will
	# leave standing there regardless. Mirrors record_edit/can_record_edit/
	# seal()'s shared _passage_headroom_floor bound, offset by one more
	# TUNNEL_ROOF_BANDS for the roof slab itself. Any OTHER floor on a
	# passage-hosting column -- above or below that exact threshold -- falls
	# through unmodified to the plinth continuity walk below, which
	# (correctly) fails for anything still inside the passage's own carved
	# headroom.
	var headroom_floor := plan._passage_headroom_floor(column)
	if headroom_floor >= 0 and floor_band == headroom_floor + TUNNEL_ROOF_BANDS:
		return true
	var plinth_floor := maxi(base, floor_band - PLINTH_BANDS)
	for y in range(plinth_floor, floor_band):
		if plan.state_at(Vector3i(column.x, y, column.y)) \
				!= WarrenMazeSourcePlan.CellState.SOLID:
			return false
	return true


## Walks up from `floor_band` while the column stays SOLID, same as before --
## but also stops at the floor of the lowest claimed interval strictly above
## `floor_band` on this column, so a lower claim's own ceiling computation can
## never reach up through mass an upper, already-placed stacked claim already
## owns. Self-intervals (an interval whose own floor equals `floor_band` --
## this exact claim, mid extension or merge) never cap: the strict `>` skips
## them.
##
## Reads state_at_raw, NOT the ledger-aware state_at: at the point this ever
## runs (mid-stamping, before this or any later claim commits, long before
## skyline trim), nothing has genuinely been removed yet. An earlier claim
## sharing this SAME column at a lower tier may already carry a stamp-phase
## offender edit recording ITS OWN roof -- that is bookkeeping for skyline
## trim and foundation depth, not proof the mass above it is gone. Reading
## the ledger-aware state_at here would make a flush-stacked claim's own
## ceiling collapse to floor_band (zero usable height) the instant the claim
## below it happened to need a floor correction -- the claimed_intervals cap
## just below is the correct, purpose-built way to bound this walk by
## another claim's territory; the raw walk only ever answers "is there still
## physical rock here", never "has some other claim already decided its own
## roof is here".
static func _column_ceiling(plan: WarrenMazeSourcePlan, column: Vector2i,
		floor_band: int, claimed_intervals: Dictionary) -> int:
	var top_limit := plan.massif.top_at(column)
	var y := floor_band
	while y < top_limit and plan.state_at_raw(Vector3i(column.x, y, column.y)) \
			== WarrenMazeSourcePlan.CellState.SOLID:
		y += 1
	for interval: Vector2i in claimed_intervals.get(column, []) as Array:
		if interval.x > floor_band:
			y = mini(y, interval.x)
	return y


## `door_walk` seeds a per-claim storey roll inside STOREY_BUDGET[scale_id]
## (min, max) storeys -- the task-1 fix for the old massif-ceiling-derived
## house height. Slice 1c task 1 (2026-08-22, tier-driven height): when a
## real overhead street exists (_find_tier_top), the roof rises to MEET it --
## `top == tier_top` exactly, not the seeded roll -- clamped by the same
## storey-aligned ceiling term the seeded-roll path already computes (so a
## claim can never be built taller than its column's own solid extent or
## another claim already stacked above it) and by MAX_TIER_STOREYS. Every
## candidate compared against `top` in the min() below is itself
## floor_band + a whole multiple of STOREY_BANDS -- `ceiling_top` by its own
## rounding, the MAX_TIER_STOREYS term by construction, and tier_top because
## _find_tier_top only ever returns a passage y at that same parity -- so the
## result always satisfies WarrenBuildingParcel.seal()'s own
## `(top_band - base_band - ROOF_RESERVATION_BANDS) % STOREY_BANDS == 0`
## requirement, whether or not the tier path fires. `tiered` is true only
## when the final top is UNCLAMPED tier_top -- a claim whose street target
## got cut short by a lower physical ceiling or the MAX_TIER_STOREYS cap (or
## the 1x1 clamp below) reports tiered: false, since its roof no longer
## actually equals any real street. When no tier exists at all, the
## pre-task-1 seeded-roll path is unchanged. MIN_HOUSE_BANDS and the 1x1
## clamp still apply on top of either path.
static func _claim_top_band(plan: WarrenMazeSourcePlan,
		footprint: Array[Vector2i], floor_band: int, is_1x1: bool,
		door_walk: Vector3i, claimed_intervals: Dictionary) -> Dictionary:
	var min_top := 2147483647
	for column: Vector2i in footprint:
		min_top = mini(min_top, _column_ceiling(plan, column, floor_band,
			claimed_intervals))
	var ceiling_top := min_top - posmod(min_top - floor_band,
		WarrenBuildingParcel.STOREY_BANDS)
	var tier_top := _find_tier_top(plan, footprint, floor_band)
	var top: int
	var tiered := false
	if tier_top >= 0:
		var tier_ceiling := mini(ceiling_top, floor_band \
			+ MAX_TIER_STOREYS * WarrenBuildingParcel.STOREY_BANDS)
		top = mini(tier_top, tier_ceiling)
		tiered = top == tier_top
	else:
		var storeys := _roll_storeys(plan, door_walk)
		top = mini(ceiling_top,
			floor_band + storeys * WarrenBuildingParcel.STOREY_BANDS)
	if top - floor_band < WarrenMazeSourcePlan.MIN_HOUSE_BANDS:
		return {"top": -1, "tiered": false}
	if is_1x1:
		var clamped := mini(top, floor_band + 2 * WarrenBuildingParcel.STOREY_BANDS)
		if clamped != top:
			tiered = false
		top = clamped
	return {"top": top, "tiered": tiered}


## Rule 1 (tier-driven height, slice 1c task 1, 2026-08-22): the lowest
## passage cell y that both (a) sits at least MIN_HOUSE_BANDS above this
## candidate's own floor -- a street directly at or barely above the floor
## can never be a roof, it would leave no usable storey beneath it -- and (b)
## lies in one of `footprint`'s own columns (an upper street running directly
## OVER part of the block) or in its 1-column cardinal apron (a street
## running BESIDE the block). -1 when no such passage cell exists, in which
## case _claim_top_band falls back to the pre-task-1 seeded roll.
##
## Pre-filtered to the SAME parity WarrenBuildingParcel.seal() requires of
## every top_band (STOREY_BANDS-aligned relative to floor_band) -- a passage
## y at the wrong parity is skipped outright rather than returned and later
## silently rounded down to a height that no longer equals any real street,
## which would make `tiered: true` a lie. MIN_HOUSE_BANDS (4) is itself a
## whole multiple of STOREY_BANDS (2), so the two filters compose cleanly.
static func _find_tier_top(plan: WarrenMazeSourcePlan,
		footprint: Array[Vector2i], floor_band: int) -> int:
	var columns: Dictionary = {}
	for column: Vector2i in footprint:
		columns[column] = true
		for direction: Vector2i in CARDINALS:
			columns[column + direction] = true
	var min_needed := floor_band + WarrenMazeSourcePlan.MIN_HOUSE_BANDS
	var tier_top := -1
	for cell_value: Variant in plan.passage_kinds.keys():
		var cell := cell_value as Vector3i
		if cell.y < min_needed:
			continue
		if posmod(cell.y - floor_band, WarrenBuildingParcel.STOREY_BANDS) != 0:
			continue
		if not columns.has(Vector2i(cell.x, cell.z)):
			continue
		if tier_top < 0 or cell.y < tier_top:
			tier_top = cell.y
	return tier_top


static func _roll_storeys(plan: WarrenMazeSourcePlan,
		door_walk: Vector3i) -> int:
	var budget: Vector2i = STOREY_BUDGET.get(plan.scale_profile.scale_id,
		Vector2i(2, 3))
	var mixed := Helper._mix64(plan.world_seed ^ Helper._mix64(
		door_walk.x * 73856093 ^ door_walk.y * 19349663 \
			^ door_walk.z * 83492791))
	return posmod(mixed, budget.y - budget.x + 1) + budget.x


## Records (or, for a column already carrying THIS SAME claim -- same
## floor_band -- re-records) one claim's [floor_band, top_band) on every
## footprint column. A claim's top can only ever grow (extension, merge), so
## a later call for the same floor_band always supersedes the earlier one
## rather than appending a second, stale entry beside it.
static func _claim_interval(claimed_intervals: Dictionary,
		footprint: Array[Vector2i], floor_band: int, top_band: int) -> void:
	for column: Vector2i in footprint:
		var kept: Array[Vector2i] = []
		for interval: Vector2i in claimed_intervals.get(column, []) as Array:
			if interval.x != floor_band:
				kept.append(interval)
		kept.append(Vector2i(floor_band, top_band))
		claimed_intervals[column] = kept


## Fix round 1 (2026-08-21 review, Important finding): a flush-stacked claim's
## own placement is deliberately exempt from _footprint_offenders on the
## column it stacks on (see _stacks_on_existing_claim), so that column never
## reaches _record_offender_batch for THIS claim -- only the claim below it
## ever wrote column_edits for that column, at the LOWER claim's own top.
## Without this refresh, that entry stays stuck at the lower tier's top
## forever: effective_top(column) would keep reading the lower tier's roof
## even after a second claim is flush-stacked on top of it, which is wrong
## (the column's real known-built extent now reaches the UPPER tier's top)
## and, worse, is invisible to skyline trim's own self-heal (current_top >
## roof never fires when current_top is already BELOW roof, not above it).
## Called after every claim placement/extension/merge commit, over the
## claim's own full footprint: any column already carrying an edit gets its
## top_band raised to max(existing, this claim's own top) -- floor_band and
## phase are always preserved, only top_band ever moves, and only upward. A
## column with no edit at all is untouched (nothing to refresh).
static func _refresh_stacked_edit_tops(plan: WarrenMazeSourcePlan,
		footprint: Array[Vector2i], top_band: int) -> void:
	for column: Vector2i in footprint:
		if not plan.column_edits.has(column):
			continue
		var edit := plan.column_edits[column] as Dictionary
		var existing_top := int(edit.get("top_band", 0))
		if top_band > existing_top:
			# Preserve bearing: a raise here must never quietly demote a
			# bearing column back to a within-budget-only one, or seal()'s
			# own re-validation would wrongly re-apply the +/-1 rule to it.
			plan.record_edit(column, int(edit.get("floor_band", 0)), top_band,
				StringName(edit.get("phase", &"stamp")),
				bool(edit.get("bearing", false)))


static func _neighbor_contact_count(footprint: Array[Vector2i],
		claimed_intervals: Dictionary) -> int:
	var footprint_set: Dictionary = {}
	for column: Vector2i in footprint:
		footprint_set[column] = true
	var contacts: Dictionary = {}
	for column: Vector2i in footprint:
		for direction: Vector2i in CARDINALS:
			var neighbor := column + direction
			if not footprint_set.has(neighbor) \
					and claimed_intervals.has(neighbor):
				contacts[neighbor] = true
	return contacts.size()


static func _bump(outcomes: Dictionary, reason: String) -> void:
	outcomes[reason] = int(outcomes.get(reason, 0)) + 1


static func _cell_less(left: Vector3i, right: Vector3i) -> bool:
	if left.y != right.y:
		return left.y < right.y
	if left.x != right.x:
		return left.x < right.x
	return left.z < right.z


static func _fail(reason: String) -> bool:
	last_failure = reason
	return false
