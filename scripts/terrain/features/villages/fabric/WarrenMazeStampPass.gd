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
## forcing a whole footprint down to 1x1. Two further measures, born out of
## iterating against a corpus with NO terrain relief (ground_bands = {}, so
## every effective_base is 0 and this edit never fires): every 2-wide rect
## also tries the MIRRORED side of its threshold (an unmirrored shape always
## claims its second column on one fixed side, so a face whose free neighbor
## sits on the other side could never claim a 2-wide footprint at all), and
## a placed rectangular claim is grown afterward into whatever unclaimed
## columns border it, deepening and widening in alternating rounds so it can
## walk around a corridor's corners.
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
## picks whichever orientation actually fits. Every width-2 rect also gets a
## mirrored variant: an unmirrored 2-wide shape always claims its second
## column on the same fixed side of the threshold (matching
## WarrenMazeBlockPartitioner's own convention), so a face whose free
## neighbor sits on the OTHER side could never claim a 2-wide footprint at
## all -- that one-sidedness, not terrain, is what starved most faces down
## to 1x1 before the mirror was added.
const SHAPE_MENU: Array[Dictionary] = [
	{"id": &"2x3", "kind": &"rect", "width": 2, "depth": 3, "mirror": false},
	{"id": &"2x3", "kind": &"rect", "width": 2, "depth": 3, "mirror": true},
	{"id": &"2x2", "kind": &"rect", "width": 2, "depth": 2, "mirror": false},
	{"id": &"2x2", "kind": &"rect", "width": 2, "depth": 2, "mirror": true},
	{"id": &"L", "kind": &"l", "wing_lane": 1},
	{"id": &"L", "kind": &"l", "wing_lane": 0},
	{"id": &"1x2", "kind": &"rect", "width": 1, "depth": 2, "mirror": false},
	{"id": &"2x1", "kind": &"rect", "width": 2, "depth": 1, "mirror": false},
	{"id": &"2x1", "kind": &"rect", "width": 2, "depth": 1, "mirror": true},
	{"id": &"1x1", "kind": &"rect", "width": 1, "depth": 1, "mirror": false},
]
const ALL_SHAPE_INDICES: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
## <= 2 columns: 1x2, 2x1 (both orientations), 1x1 -- the infill pass's menu.
const SMALL_SHAPE_INDICES: Array[int] = [6, 7, 8, 9]
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

	var claimed_columns: Dictionary = {}
	for reservation: Dictionary in plan.reservations:
		for column: Vector2i in reservation.get("cells", []) as Array:
			claimed_columns[column] = true

	var faces := frontage_faces_from_plan(plan)
	var outcomes: Dictionary = {}
	var lineage_seed := {"count": 0}

	var main_candidates := _enumerate_candidates(plan, faces, claimed_columns,
		ALL_SHAPE_INDICES)
	main_candidates.sort_custom(Callable(WarrenMazeStampPass,
		"_compare_candidates"))
	_run_pass(plan, main_candidates, claimed_columns, outcomes, lineage_seed)

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
		_back_extend(plan, claimed_columns, outcomes, original_arm_depths)
		_lateral_extend(plan, claimed_columns, outcomes)

	var infill_candidates := _enumerate_candidates(plan, faces,
		claimed_columns, SMALL_SHAPE_INDICES)
	infill_candidates.sort_custom(Callable(WarrenMazeStampPass,
		"_compare_candidates"))
	_run_pass(plan, infill_candidates, claimed_columns, outcomes, lineage_seed)

	# Infill routinely lands several 1x1s that a face-by-face view cannot see
	# are actually contiguous: two 1x1s side by side, or a 1x1 sitting flush
	# against an edge of an existing rectangle. Absorbing those into one
	# larger rectangular claim (never into an L piece, and only when the
	# union is still a solid rectangle at a matching floor_band) is what
	# keeps a maze block's leftover frontage from reporting as a run of
	# separate pencils once it is this fragmented.
	_merge_small_claims(plan, outcomes)

	# A building is a lineage, not a single claim -- the L-shape already
	# treats its two arms that way. This bounded post-pass extends the same
	# idea to whatever the merge above could not fold into one rectangle
	# (e.g. a staircase-shaped blob), so a blob split into several small
	# rectangles for the footprint contract still reads as one stepped
	# building downstream.
	_group_lineages(plan, lineage_seed)

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
## Overhead (skywalk_span) reservations are excluded outright: their
## datum_band is a neighboring walkway's height, not a floor for THIS
## column, and claim_overhead never edits the flank columns' floors, so they
## already stand on grounded natural rock -- any entry here would drive
## slice-2's retained-foundation machinery to build a foundation for a
## column that never asked for one. Skywalk support is slice-2 composition's
## job, not this derivation's.
static func derive_foundations(plan: WarrenMazeSourcePlan) -> void:
	var foundation_columns: Dictionary = {}
	for claim: Dictionary in plan.parcel_claims:
		var floor_band := int(claim.floor_band)
		for column: Vector2i in claim.footprint as Array[Vector2i]:
			var depth := floor_band - plan.massif.base_at(column)
			if depth > 0:
				foundation_columns[column] = depth
	for reservation: Dictionary in plan.reservations:
		# Skip overhead reservations: datum is a neighboring walk band, not
		# this column's floor, and its flank columns are grounded natural
		# rock (claim_overhead records no edit).
		if not (reservation.get("walk_cells", []) as Array).is_empty():
			continue
		var datum := int(reservation.datum_band)
		for column: Vector2i in reservation.cells as Array[Vector2i]:
			var depth := datum - plan.massif.base_at(column)
			if depth > 0:
				foundation_columns[column] = depth
	plan.audit["foundation_columns"] = foundation_columns


## Repeatedly finds a 1x1 claim next to another claim (1x1 or larger, but
## never an L piece) at the same floor_band whose union is still a solid
## axis-aligned rectangle, and folds the 1x1 into it. Runs to a fixed point:
## each successful merge removes one claim, so this always terminates, and a
## chain of three or more collinear 1x1s is absorbed one at a time (A+B -> a
## 1x2, then that 1x2 + C -> a 1x3, ...).
static func _merge_small_claims(plan: WarrenMazeSourcePlan,
		outcomes: Dictionary) -> void:
	while _merge_small_claims_once(plan, outcomes):
		pass


static func _merge_small_claims_once(plan: WarrenMazeSourcePlan,
		outcomes: Dictionary) -> bool:
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
			var floor_band := int(claim_b.floor_band)
			var new_top := _claim_top_band(plan, merged, floor_band, false)
			if new_top < 0:
				continue
			for edited_column: Vector2i in merged:
				if plan.column_edits.has(edited_column):
					var edit := plan.column_edits[edited_column] as Dictionary
					plan.record_edit(edited_column, int(edit.floor_band),
						new_top, StringName(edit.phase))
			claim_b["footprint"] = merged
			claim_b["top_band"] = new_top
			claim_b["shape_id"] = _shape_id_for_footprint(merged)
			plan.parcel_claims.remove_at(index)
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
		faces: Array[Dictionary], claimed_columns: Dictionary,
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
					int(entry.width), int(entry.depth),
					bool(entry.get("mirror", false)))
				candidate = _build_rect_candidate(plan, face_index,
					shape_index, entry, walk, door_column, frontage,
					footprint, claimed_columns)
			else:
				candidate = _build_l_candidate(plan, face_index, shape_index,
					entry, walk, door_column, frontage, into_block,
					claimed_columns)
			if not candidate.is_empty():
				out.append(candidate)
	return out


static func _build_rect_candidate(plan: WarrenMazeSourcePlan, face_index: int,
		shape_index: int, entry: Dictionary, walk: Vector3i,
		door_column: Vector2i, frontage: Vector2i,
		footprint: Array[Vector2i], claimed_columns: Dictionary) -> Dictionary:
	if not _footprint_available(plan, footprint, claimed_columns):
		return {}
	var datum_info := _column_datum(plan, footprint)
	if not bool(datum_info.get("ok", false)):
		return {}
	var offenders := datum_info.offenders as Array[Vector2i]
	var contact := _neighbor_contact_count(footprint, claimed_columns)
	var tie := posmod(WarrenPassageLatticeRules.hash_key(plan.world_seed,
		SCORE_SALT, walk, shape_index), 100)
	var score := footprint.size() * 10000 + contact * 400 \
		- offenders.size() * 50 + tie
	return {"face_index": face_index, "shape_index": shape_index,
		"score": score, "kind": &"rect", "footprint": footprint,
		"datum": int(datum_info.datum), "offenders": offenders, "walk": walk,
		"door_column": door_column, "frontage": frontage,
		"shape_id": StringName(entry.id), "is_1x1": footprint.size() == 1}


static func _build_l_candidate(plan: WarrenMazeSourcePlan, face_index: int,
		shape_index: int, entry: Dictionary, walk: Vector3i,
		door_column: Vector2i, frontage: Vector2i, into_block: Vector2i,
		claimed_columns: Dictionary) -> Dictionary:
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
	if not _footprint_available(plan, combined, claimed_columns):
		return {}
	var datum_info := _column_datum(plan, combined)
	if not bool(datum_info.get("ok", false)):
		return {}
	var offenders := datum_info.offenders as Array[Vector2i]
	var contact := _neighbor_contact_count(combined, claimed_columns)
	var tie := posmod(WarrenPassageLatticeRules.hash_key(plan.world_seed,
		SCORE_SALT, walk, shape_index), 100)
	var score := combined.size() * 10000 + contact * 400 \
		- offenders.size() * 50 + tie
	return {"face_index": face_index, "shape_index": shape_index,
		"score": score, "kind": &"l", "main_footprint": main,
		"wing_footprint": wing, "datum": int(datum_info.datum),
		"offenders": offenders, "walk": walk, "door_column": door_column,
		"frontage": frontage, "is_1x1": false}


static func _compare_candidates(left: Dictionary, right: Dictionary) -> bool:
	if int(left.score) != int(right.score):
		return int(left.score) > int(right.score)
	if int(left.face_index) != int(right.face_index):
		return int(left.face_index) < int(right.face_index)
	return int(left.shape_index) < int(right.shape_index)


static func _run_pass(plan: WarrenMazeSourcePlan,
		candidates: Array[Dictionary], claimed_columns: Dictionary,
		outcomes: Dictionary, lineage_seed: Dictionary) -> void:
	for candidate: Dictionary in candidates:
		if StringName(candidate.kind) == &"rect":
			_try_place_rect(plan, candidate, claimed_columns, outcomes)
		else:
			_try_place_l(plan, candidate, claimed_columns, outcomes,
				lineage_seed)


static func _try_place_rect(plan: WarrenMazeSourcePlan, candidate: Dictionary,
		claimed_columns: Dictionary, outcomes: Dictionary) -> void:
	var footprint := candidate.footprint as Array[Vector2i]
	if not _footprint_available(plan, footprint, claimed_columns):
		_bump(outcomes, "column_taken")
		return
	var floor_band := int(candidate.datum)
	var top_band := _claim_top_band(plan, footprint, floor_band,
		bool(candidate.is_1x1))
	if top_band < 0:
		_bump(outcomes, "insufficient_height")
		return
	var offenders := candidate.offenders as Array[Vector2i]
	for column: Vector2i in offenders:
		if not plan.record_edit(column, floor_band, top_band, &"stamp"):
			_bump(outcomes, "edit_rejected")
			return
	plan.parcel_claims.append({"footprint": footprint.duplicate(),
		"floor_band": floor_band, "top_band": top_band,
		"door_walk": candidate.walk as Vector3i,
		"door_column": candidate.door_column as Vector2i,
		"frontage": candidate.frontage as Vector2i, "lineage_hint": &"",
		"shape_id": candidate.shape_id as StringName})
	for column: Vector2i in footprint:
		claimed_columns[column] = true
	_bump(outcomes, "placed")


static func _try_place_l(plan: WarrenMazeSourcePlan, candidate: Dictionary,
		claimed_columns: Dictionary, outcomes: Dictionary,
		lineage_seed: Dictionary) -> void:
	var main := candidate.main_footprint as Array[Vector2i]
	var wing := candidate.wing_footprint as Array[Vector2i]
	var combined: Array[Vector2i] = []
	combined.append_array(main)
	combined.append_array(wing)
	if not _footprint_available(plan, combined, claimed_columns):
		_bump(outcomes, "column_taken")
		return
	var floor_band := int(candidate.datum)
	var top_band := _claim_top_band(plan, combined, floor_band, false)
	if top_band < 0:
		_bump(outcomes, "insufficient_height")
		return
	var offenders := candidate.offenders as Array[Vector2i]
	for column: Vector2i in offenders:
		if not plan.record_edit(column, floor_band, top_band, &"stamp"):
			_bump(outcomes, "edit_rejected")
			return
	lineage_seed.count = int(lineage_seed.count) + 1
	var lineage := StringName("maze.lineage.%d" % int(lineage_seed.count))
	plan.parcel_claims.append({"footprint": main.duplicate(),
		"floor_band": floor_band, "top_band": top_band,
		"door_walk": candidate.walk as Vector3i,
		"door_column": candidate.door_column as Vector2i,
		"frontage": candidate.frontage as Vector2i, "lineage_hint": lineage,
		"shape_id": &"L.main"})
	plan.parcel_claims.append({"footprint": wing.duplicate(),
		"floor_band": floor_band, "top_band": top_band,
		"door_walk": candidate.walk as Vector3i,
		"door_column": candidate.door_column as Vector2i,
		"frontage": candidate.frontage as Vector2i, "lineage_hint": lineage,
		"shape_id": &"L.wing"})
	for column: Vector2i in combined:
		claimed_columns[column] = true
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
static func _back_extend(plan: WarrenMazeSourcePlan, claimed_columns: Dictionary,
		outcomes: Dictionary, original_depths: Dictionary) -> void:
	for index in plan.parcel_claims.size():
		var claim := plan.parcel_claims[index] as Dictionary
		if not String(claim.get("shape_id", "")).begins_with("L."):
			_back_extend_claim(plan, claim, index, claimed_columns, outcomes,
				original_depths)


static func _back_extend_claim(plan: WarrenMazeSourcePlan, claim: Dictionary,
		claim_index: int, claimed_columns: Dictionary, outcomes: Dictionary,
		original_depths: Dictionary) -> void:
	var footprint := (claim.footprint as Array[Vector2i]).duplicate()
	var into_block := -(claim.frontage as Vector2i)
	var width_columns := _lateral_lane(footprint, into_block)
	if width_columns.is_empty():
		return
	var floor_band := int(claim.floor_band)
	var top_band := int(claim.top_band)
	var depth_used := _footprint_depth(footprint, into_block)
	var original_depth: int = original_depths.get(claim_index, depth_used)
	var already_added := depth_used - original_depth
	var remaining_budget := maxi(0, MAX_BACK_EXTENSION_DEPTH - already_added)
	for extra in remaining_budget:
		var row: Array[Vector2i] = []
		for lane_column: Vector2i in width_columns:
			row.append(lane_column + into_block * (depth_used + extra))
		if not _footprint_available(plan, row, claimed_columns):
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
		var extended_top := _claim_top_band(plan, extended_footprint,
			floor_band, false)
		if extended_top < top_band:
			break
		for column: Vector2i in offenders:
			if not plan.record_edit(column, floor_band, extended_top,
					&"stamp"):
				_bump(outcomes, "edit_rejected")
				return
		for column: Vector2i in row:
			claimed_columns[column] = true
		footprint.append_array(row)
		top_band = extended_top
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
		claimed_columns: Dictionary, outcomes: Dictionary) -> void:
	for claim: Dictionary in plan.parcel_claims:
		if not String(claim.get("shape_id", "")).begins_with("L."):
			_lateral_extend_claim(plan, claim, claimed_columns, outcomes)


static func _lateral_extend_claim(plan: WarrenMazeSourcePlan,
		claim: Dictionary, claimed_columns: Dictionary,
		outcomes: Dictionary) -> void:
	var footprint := (claim.footprint as Array[Vector2i]).duplicate()
	var into_block := -(claim.frontage as Vector2i)
	var perpendicular := Vector2i(-into_block.y, into_block.x)
	var floor_band := int(claim.floor_band)
	var top_band := int(claim.top_band)
	for direction: Vector2i in [perpendicular, -perpendicular]:
		for extra in MAX_LATERAL_EXTENSION_WIDTH:
			var row := _outer_lane(footprint, into_block, direction)
			if not _footprint_available(plan, row, claimed_columns):
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
			var extended_footprint := footprint.duplicate()
			extended_footprint.append_array(row)
			var extended_top := _claim_top_band(plan, extended_footprint,
				floor_band, false)
			if extended_top < top_band:
				break
			for column: Vector2i in offenders:
				if not plan.record_edit(column, floor_band, extended_top,
						&"stamp"):
					_bump(outcomes, "edit_rejected")
					return
			for column: Vector2i in row:
				claimed_columns[column] = true
			footprint.append_array(row)
			top_band = extended_top
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


static func _rect_footprint(walk: Vector3i, into_block: Vector2i,
		width: int, depth: int, mirror: bool = false) -> Array[Vector2i]:
	var perpendicular := Vector2i(-into_block.y, into_block.x)
	var threshold := Vector2i(walk.x, walk.z) + into_block
	var start := -(width - 1) if mirror else 0
	var out: Array[Vector2i] = []
	for depth_offset in depth:
		for width_index in width:
			out.append(threshold + into_block * depth_offset \
				+ perpendicular * (start + width_index))
	return out


static func _footprint_available(plan: WarrenMazeSourcePlan,
		footprint: Array[Vector2i], claimed_columns: Dictionary) -> bool:
	if footprint.is_empty():
		return false
	var seen: Dictionary = {}
	for column: Vector2i in footprint:
		if seen.has(column):
			return false
		seen[column] = true
		if not plan.massif.has_column(column) or claimed_columns.has(column):
			return false
	return true


## The largest common effective_base among the footprint's columns becomes
## the claim's floor_band; any column below it is a within-budget offender
## (raised at most one band), and any column above it makes the whole
## footprint infeasible -- the immutable-floor rule (record_edit) forbids
## ever lowering a column's floor below its own terrain sample, so an
## outlier that is genuinely taller than the datum can never be reconciled
## by editing, only by choosing a different footprint.
static func _column_datum(plan: WarrenMazeSourcePlan,
		footprint: Array[Vector2i]) -> Dictionary:
	var counts: Dictionary = {}
	for column: Vector2i in footprint:
		var base := plan.effective_base(column)
		counts[base] = int(counts.get(base, 0)) + 1
	var values: Array = counts.keys()
	values.sort()
	var datum: int = values[0]
	var best_count := int(counts[datum])
	for value: Variant in values:
		var count := int(counts[value])
		if count > best_count or (count == best_count and int(value) > datum):
			datum = int(value)
			best_count = count
	var offenders: Array[Vector2i] = []
	for column: Vector2i in footprint:
		var base := plan.effective_base(column)
		if base == datum:
			continue
		if base > datum or datum - base > 1:
			return {"ok": false}
		offenders.append(column)
	return {"ok": true, "datum": datum, "offenders": offenders}


static func _column_ceiling(plan: WarrenMazeSourcePlan, column: Vector2i,
		floor_band: int) -> int:
	var top_limit := plan.massif.top_at(column)
	var y := floor_band
	while y < top_limit and plan.state_at(Vector3i(column.x, y, column.y)) \
			== WarrenMazeSourcePlan.CellState.SOLID:
		y += 1
	return y


static func _claim_top_band(plan: WarrenMazeSourcePlan,
		footprint: Array[Vector2i], floor_band: int, is_1x1: bool) -> int:
	var min_top := 2147483647
	for column: Vector2i in footprint:
		min_top = mini(min_top, _column_ceiling(plan, column, floor_band))
	var top := min_top - posmod(min_top - floor_band,
		WarrenBuildingParcel.STOREY_BANDS)
	if top - floor_band < WarrenMazeSourcePlan.MIN_HOUSE_BANDS:
		return -1
	if is_1x1:
		top = mini(top, floor_band + 2 * WarrenBuildingParcel.STOREY_BANDS)
	return top


static func _neighbor_contact_count(footprint: Array[Vector2i],
		claimed_columns: Dictionary) -> int:
	var footprint_set: Dictionary = {}
	for column: Vector2i in footprint:
		footprint_set[column] = true
	var contacts: Dictionary = {}
	for column: Vector2i in footprint:
		for direction: Vector2i in CARDINALS:
			var neighbor := column + direction
			if not footprint_set.has(neighbor) \
					and claimed_columns.has(neighbor):
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
