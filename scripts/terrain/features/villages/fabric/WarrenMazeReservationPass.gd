class_name WarrenMazeReservationPass
extends RefCounted

## P3 -- reservation pass. Generalizes the existing universal-market stamp
## into a data-driven registry: each feature kind names its quota range per
## scale profile, its patch footprint, and the constructive edit op that
## claims it. Every outcome (landed, shrunk, skipped, not selected) is a
## reason-coded audit fact; reserve() only returns false on a contract
## violation such as being called with a sealed plan.
const REGISTRY: Array[Dictionary] = [
	# Rim sink-to-terrain RETIRED (2026-08-21 controller ruling, slice 1c
	# task 1): the user's direction is "no exposed ground" -- courtyard and
	# garden_terrace are street-level flat plots only, leveled to the
	# adjoining walk (level_to_walk), never sunk to a per-column terrain
	# average. See _apply_level_to_walk's own header.
	{"kind": &"courtyard", "optional": false, "quota": {"compact": Vector2i(0, 1),
		"standard": Vector2i(1, 1), "large": Vector2i(1, 2),
		"grand": Vector2i(1, 2)}, "patch": Vector2i(2, 2),
		"edit": &"level_to_walk"},
	{"kind": &"large_house", "optional": false, "quota": {"compact": Vector2i(0, 1),
		"standard": Vector2i(1, 2), "large": Vector2i(2, 3),
		"grand": Vector2i(2, 4)}, "patch": Vector2i(3, 2),
		"edit": &"level_to_datum"},
	{"kind": &"landmark_plot", "optional": true, "quota": {"compact": Vector2i(0, 1),
		"standard": Vector2i(0, 1), "large": Vector2i(1, 2),
		"grand": Vector2i(1, 2)}, "patch": Vector2i(3, 3),
		"edit": &"level_to_datum"},
	# Non-optional (slice 1c task 1, 2026-08-22): a skywalk is now a required
	# feature of every town, not a coin-flip -- see claim_overhead's own
	# comment for why it can still satisfy its quota even on a town whose
	# carver bridge_spans is empty (it falls back to the pre-existing flank
	# search).
	{"kind": &"skywalk_span", "optional": false, "quota": {"compact": Vector2i(1, 1),
		"standard": Vector2i(1, 2), "large": Vector2i(2, 3),
		"grand": Vector2i(3, 4)}, "patch": Vector2i.ZERO,
		"edit": &"claim_overhead"},
	{"kind": &"garden_terrace", "optional": true, "quota": {"compact": Vector2i(0, 1),
		"standard": Vector2i(0, 1), "large": Vector2i(0, 2),
		"grand": Vector2i(0, 2)}, "patch": Vector2i(2, 1),
		"edit": &"level_to_walk"},
]

const CARDINALS: Array[Vector2i] = [
	Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP,
]
## Reservation plot heights (2026-08-21 refinement): storeys above each
## kind's own datum -- skywalk_span is deliberately absent (claim_overhead
## never touches a floor at all; its flanks stand on grounded natural rock,
## untouched by this dictionary). 0-storey kinds (courtyard, garden_terrace)
## are open flat plots -- top == datum, no built mass above the leveled/
## sunk floor. large_house and landmark_plot get a real 3-storey envelope so
## the plot reads as a building site, not a hole.
const PLOT_STOREYS: Dictionary = {
	&"courtyard": 0, &"garden_terrace": 0, &"large_house": 3,
	&"landmark_plot": 3,
}

static var last_failure := ""


static func reserve(plan: WarrenMazeSourcePlan,
		profile: WarrenVillageScaleProfile) -> bool:
	last_failure = ""
	if plan == null or plan.is_sealed():
		return _fail("reservation pass requires an unsealed maze source plan")
	if profile == null or not profile.validate():
		return _fail("reservation pass requires a valid scale profile")
	if plan.massif == null or not plan.massif.is_sealed():
		return _fail("reservation pass requires a sealed massif")
	var outcomes: Array[Dictionary] = []
	var passage_columns := _passage_column_set(plan)
	var claimed_columns: Dictionary = {}
	var claimed_walk_cells: Dictionary = {}
	for entry: Dictionary in REGISTRY:
		var kind := entry.kind as StringName
		if bool(entry.optional) and not _optional_selected(plan.world_seed, kind):
			outcomes.append({"kind": kind, "result": &"optional_not_selected"})
			continue
		var quota := (entry.quota as Dictionary).get(
			String(profile.scale_id), Vector2i.ZERO) as Vector2i
		var target := _quota_roll(plan.world_seed, kind, quota)
		var placed := 0
		for instance_index in target:
			var outcome := _place_instance(plan, entry, passage_columns,
				claimed_columns, claimed_walk_cells, instance_index)
			outcomes.append(outcome)
			if bool(outcome.get("placed", false)):
				placed += 1
		if placed < quota.x:
			outcomes.append({"kind": kind, "result": &"quota_shortfall",
				"placed": placed, "minimum": quota.x, "target": target})
	plan.audit["reservation_outcomes"] = outcomes
	return true


static func _place_instance(plan: WarrenMazeSourcePlan, entry: Dictionary,
		passage_columns: Dictionary, claimed_columns: Dictionary,
		claimed_walk_cells: Dictionary, instance_index: int) -> Dictionary:
	var kind := entry.kind as StringName
	var edit := entry.edit as StringName
	if edit == &"claim_overhead":
		return _place_overhead(plan, kind, passage_columns, claimed_columns,
			claimed_walk_cells, instance_index)
	return _place_patch(plan, entry, passage_columns, claimed_columns,
		instance_index)


static func _place_patch(plan: WarrenMazeSourcePlan, entry: Dictionary,
		passage_columns: Dictionary, claimed_columns: Dictionary,
		instance_index: int) -> Dictionary:
	var kind := entry.kind as StringName
	var edit := entry.edit as StringName
	var patch := entry.patch as Vector2i
	var candidates := _patch_candidates(plan, kind, patch, passage_columns,
		claimed_columns)
	if candidates.is_empty():
		return {"kind": kind, "result": &"skip", "reason": "no_candidates"}
	var start := posmod(Helper._mix64(plan.world_seed ^ int(kind.hash())
		^ instance_index * 0x9E3779B1), candidates.size())
	for offset in candidates.size():
		var candidate := candidates[(start + offset) % candidates.size()] \
			as Dictionary
		var footprint := candidate.footprint as Array[Vector2i]
		var placed := _try_fit_and_edit(plan, kind, edit, footprint)
		if not placed.is_empty():
			for column: Vector2i in footprint:
				claimed_columns[column] = true
			return placed
		# Shrink: drop the last column along the longer dimension and retry
		# at the same anchor/orientation before moving to the next candidate.
		for shrunk: Array[Vector2i] in _shrink_variants(footprint):
			placed = _try_fit_and_edit(plan, kind, edit, shrunk)
			if not placed.is_empty():
				for column: Vector2i in shrunk:
					claimed_columns[column] = true
				placed["result"] = &"shrink"
				return placed
	return {"kind": kind, "result": &"skip", "reason": "no_fit"}


static func _place_overhead(plan: WarrenMazeSourcePlan, kind: StringName,
		passage_columns: Dictionary, claimed_columns: Dictionary,
		claimed_walk_cells: Dictionary, instance_index: int) -> Dictionary:
	## Rule 3 (skywalk spans non-optional, slice 1c task 1, 2026-08-22): a
	## carver bridge_span -- overhead mass the excavation already retained
	## over an open street specifically so a skywalk deck could stand on it
	## -- is a strictly better site than the flank search below (real
	## retained rock, not a wall this pass has to hope stays solid), so it is
	## always tried FIRST, in bridge_spans' own order. `claimed_walk_cells`
	## is shared across every instance of this kind within one reserve() run
	## (passed by reference from _place_instance's caller), so the first
	## unconsumed span in array order is always the next one _claim_bridge_
	## span reaches -- no separate cursor needed. Only once every span is
	## either consumed or blocked does this fall through to the pre-existing
	## flank search, so a town with an empty bridge_spans (or one already
	## exhausted by an earlier instance) still satisfies its quota exactly as
	## it always could.
	var bridge_result := _claim_bridge_span(plan, kind, claimed_columns,
		claimed_walk_cells)
	if not bridge_result.is_empty():
		return bridge_result
	var candidates := _overhead_candidates(plan, passage_columns,
		claimed_columns, claimed_walk_cells)
	if candidates.is_empty():
		return {"kind": kind, "result": &"skip", "reason": "no_candidates"}
	var start := posmod(Helper._mix64(plan.world_seed ^ int(kind.hash())
		^ instance_index * 0x9E3779B1), candidates.size())
	for offset in candidates.size():
		var candidate := candidates[(start + offset) % candidates.size()] \
			as Dictionary
		var walk: Vector3i = candidate.walk
		var flanks := candidate.flanks as Array[Vector2i]
		if claimed_walk_cells.has(walk) or claimed_columns.has(flanks[0]) \
				or claimed_columns.has(flanks[1]):
			continue
		claimed_walk_cells[walk] = true
		claimed_columns[flanks[0]] = true
		claimed_columns[flanks[1]] = true
		plan.reservations.append({"kind": kind, "cells": flanks.duplicate(),
			"datum_band": walk.y, "walk_cells": [walk] as Array[Vector3i],
			"audit": {}})
		return {"kind": kind, "result": &"fit", "placed": true}
	return {"kind": kind, "result": &"skip", "reason": "no_fit"}


## Rule 3's bridge-consuming path: the first entry of `plan.excavation.
## bridge_spans` not already consumed by an earlier skywalk_span instance and
## not blocked by another reservation/claim, in array order (bridge_spans'
## own order is already deterministic -- see WarrenMazeCarver._select_bridge_
## spans). {} when none qualifies, so the caller falls through to the
## pre-existing flank search.
##
## Unlike the flank search (which never edits a floor at all), this DOES
## edit -- the reservation's own `cells` are the span's PASSAGE columns
## themselves (the retained bridge deck), not flanking wall columns: `datum`
## is the deck's own floor, one HEADROOM_BANDS clear of the street below (the
## same bound record_edit/can_record_edit/seal() now all share via
## WarrenMazeSourcePlan._passage_headroom_floor -- rule 4's bridge-capable
## ledger unlock is exactly what makes this edit legal), and `plot_top` is
## one storey above that. All-or-nothing, mirroring
## WarrenMazeStampPass._record_offender_batch's own pattern: every column is
## validated via can_record_edit before any of them commits via record_edit,
## so a span that (should never, but) fails partway through is walked away
## from with the ledger untouched rather than left half-edited.
static func _claim_bridge_span(plan: WarrenMazeSourcePlan, kind: StringName,
		claimed_columns: Dictionary, claimed_walk_cells: Dictionary) -> Dictionary:
	for span_value: Variant in plan.excavation.bridge_spans:
		var span := span_value as Array[Vector3i]
		if span.is_empty():
			continue
		var already_used := false
		for cell: Vector3i in span:
			if claimed_walk_cells.has(cell):
				already_used = true
				break
		if already_used:
			continue
		var columns: Array[Vector2i] = []
		var seen_columns: Dictionary = {}
		var blocked := false
		for cell: Vector3i in span:
			var column := Vector2i(cell.x, cell.z)
			if claimed_columns.has(column):
				blocked = true
				break
			if not seen_columns.has(column):
				seen_columns[column] = true
				columns.append(column)
		if blocked:
			continue
		# Per-cell real headroom (controller ruling, 2026-08-22): the deck's
		# own floor is the MAX of plan.passage_headroom_top(cell) -- cell.y +
		# excavation.slot_bands(cell) -- across every span cell, never
		# span[0].y + the flat HEADROOM_BANDS constant, which undercounts a
		# stair/ramp intermediate stride cell's own taller carved slot. Span
		# cells are a LEVEL-stride run and normally share one slot height, but
		# this stays correct even if one cell's own slot happens to differ.
		var datum := plan.passage_headroom_top(span[0])
		for cell: Vector3i in span:
			datum = maxi(datum, plan.passage_headroom_top(cell))
		var plot_top := datum + WarrenBuildingParcel.STOREY_BANDS
		var edit_ok := true
		for column: Vector2i in columns:
			if not plan.can_record_edit(column, datum):
				edit_ok = false
				break
		if not edit_ok:
			continue
		for column: Vector2i in columns:
			if not plan.record_edit(column, datum, plot_top, &"reserve"):
				# Unreachable given the can_record_edit pre-check above (the
				# same mirrored gates), but never leave a half-edited span if
				# the two ever somehow disagree.
				return {}
		for cell: Vector3i in span:
			claimed_walk_cells[cell] = true
		for column: Vector2i in columns:
			claimed_columns[column] = true
		plan.reservations.append({"kind": kind, "cells": columns.duplicate(),
			"datum_band": datum, "plot_top": plot_top,
			"walk_cells": span.duplicate(), "audit": {}})
		return {"kind": kind, "result": &"fit", "placed": true}
	return {}


static func _try_fit_and_edit(plan: WarrenMazeSourcePlan, kind: StringName,
		edit: StringName, footprint: Array[Vector2i]) -> Dictionary:
	if footprint.is_empty():
		return {}
	match edit:
		&"level_to_datum":
			return _apply_level_to_datum(plan, kind, footprint)
		&"level_to_walk":
			return _apply_level_to_walk(plan, kind, footprint)
	return {}


## Rule 2 (street-level courtyards/gardens, slice 1c task 1, 2026-08-22;
## rim sink-to-terrain retired 2026-08-21 by controller ruling -- "no
## exposed ground": courtyard and garden_terrace level to the adjoining
## walk ONLY, never sink to a per-column terrain average). courtyard and
## garden_terrace's own registry edit. datum is the y of the lowest passage
## cell cardinally adjacent to the patch -- "the adjoining walk cell the
## patch was enumerated from" -- never a terrain majority, so the plot
## always reads as an extension of the street it opens off, not a dip or a
## mound. Every column becomes a perfectly flat open plot at that one
## shared elevation (`{floor: datum, top: datum}`, zero built height,
## `plot_kind: &"flat"` on the reservation for consumers). A candidate with
## no adjoining passage cell at all (anchored purely at the settlement's
## rim, nowhere near a street) has no walk datum to level to and simply
## fails fit here, same as any other unmet precondition -- there is no
## per-column terrain-sink fallback for that case; `_patch_candidates`
## no longer even enumerates rim-only anchors for these two kinds (removed
## alongside the old sink op: confirmed by direct measurement across the
## full seeds 1-12 x {compact, standard} corpus that they never produced a
## placement the passage-adjacent anchor set did not already reach).
static func _apply_level_to_walk(plan: WarrenMazeSourcePlan,
		kind: StringName, footprint: Array[Vector2i]) -> Dictionary:
	var walk := _adjoining_walk_cell(plan, footprint)
	if walk.is_empty():
		return {}
	var datum := int(walk.y)
	for column: Vector2i in footprint:
		if plan.massif.base_at(column) > datum:
			return {}
	for column: Vector2i in footprint:
		if not plan.record_edit(column, datum, datum, &"reserve"):
			return {}
	plan.reservations.append({"kind": kind, "cells": footprint.duplicate(),
		"datum_band": datum, "plot_top": datum, "plot_kind": &"flat",
		"walk_cells": [] as Array[Vector3i], "audit": {}})
	return {"kind": kind, "result": &"fit", "placed": true,
		"cells": footprint.size()}


## The lowest passage y cardinally adjacent to any column of `footprint` --
## {} when the patch borders no passage cell at all (a candidate anchored
## purely at the settlement's rim, nowhere near a street). The minimum, not
## whichever cell is found first, so the result stays independent of
## `passage_cells()`'s own (y, z, x) sort order -- a footprint bordering two
## streets at different elevations always levels to the LOWER one, the one
## that needs the least grading to reach.
static func _adjoining_walk_cell(plan: WarrenMazeSourcePlan,
		footprint: Array[Vector2i]) -> Dictionary:
	var columns: Dictionary = {}
	for column: Vector2i in footprint:
		columns[column] = true
	var found := false
	var best_y := 0
	for cell: Vector3i in plan.passage_cells():
		var passage_column := Vector2i(cell.x, cell.z)
		var adjacent := false
		for direction: Vector2i in CARDINALS:
			if columns.has(passage_column + direction):
				adjacent = true
				break
		if not adjacent:
			continue
		if not found or cell.y < best_y:
			found = true
			best_y = cell.y
	return {"y": best_y} if found else {}


static func _apply_level_to_datum(plan: WarrenMazeSourcePlan,
		kind: StringName, footprint: Array[Vector2i]) -> Dictionary:
	var datum := _majority_base(plan, footprint)
	# Terrain is the immutable floor (record_edit forbids sinking below it), so
	# a column can only be leveled up to the datum, never down; the ruling's
	# +/-1 band tolerance is therefore one-directional here: at most one band
	# of foundation is spent raising a lower column to the datum.
	for column: Vector2i in footprint:
		var base := plan.effective_base(column)
		if base > datum or datum - base > 1:
			return {}
	# Reservation plots get real heights (2026-08-21 refinement): every
	# column in the patch shares ONE top, datum + this kind's own storey
	# budget in bands -- an open flat plot for a 0-storey kind (garden_
	# terrace), a real building envelope for large_house/landmark_plot.
	# Replaces the old maxi(effective_top, datum), which kept whatever the
	# raw massif ceiling already was for that column -- the same
	# massif-ceiling-derived-height bug Task 1 fixed for houses.
	var plot_top := datum \
		+ int(PLOT_STOREYS.get(kind, 0)) * WarrenBuildingParcel.STOREY_BANDS
	for column: Vector2i in footprint:
		if not plan.record_edit(column, datum, plot_top, &"reserve"):
			return {}
	plan.reservations.append({"kind": kind, "cells": footprint.duplicate(),
		"datum_band": datum, "plot_top": plot_top,
		"walk_cells": [] as Array[Vector3i], "audit": {}})
	return {"kind": kind, "result": &"fit", "placed": true,
		"cells": footprint.size()}


static func _majority_base(plan: WarrenMazeSourcePlan,
		footprint: Array[Vector2i]) -> int:
	var counts: Dictionary = {}
	for column: Vector2i in footprint:
		var base := plan.effective_base(column)
		counts[base] = int(counts.get(base, 0)) + 1
	var values: Array = counts.keys()
	values.sort()
	var best: int = values[0]
	var best_count := int(counts[best])
	for value: Variant in values:
		var count := int(counts[value])
		if count > best_count:
			best = int(value)
			best_count = count
	return best


static func _shrink_variants(footprint: Array[Vector2i]) -> Array:
	## "patch minus one column": drop the column farthest along X and,
	## separately, the column farthest along Z, producing up to two smaller
	## footprints to retry at the same anchor before moving on.
	var out: Array = []
	if footprint.size() <= 1:
		return out
	var max_x := -2147483648
	var max_z := -2147483648
	for column: Vector2i in footprint:
		max_x = maxi(max_x, column.x)
		max_z = maxi(max_z, column.y)
	var without_x: Array[Vector2i] = []
	var without_z: Array[Vector2i] = []
	for column: Vector2i in footprint:
		if column.x != max_x:
			without_x.append(column)
		if column.y != max_z:
			without_z.append(column)
	if not without_x.is_empty() and without_x.size() < footprint.size():
		out.append(without_x)
	if not without_z.is_empty() and without_z.size() < footprint.size() \
			and without_z != without_x:
		out.append(without_z)
	return out


static func _patch_candidates(plan: WarrenMazeSourcePlan, kind: StringName,
		patch: Vector2i, passage_columns: Dictionary,
		claimed_columns: Dictionary) -> Array[Dictionary]:
	# Rim-only anchors (WarrenMassif boundary columns not already
	# passage-adjacent) were removed from this enumeration alongside the
	# retired sink_to_terrain rim fallback (2026-08-21 controller ruling):
	# _apply_level_to_walk requires a real adjoining passage cell regardless
	# of which anchor a candidate footprint was enumerated from, and a
	# direct measurement across the full seeds 1-12 x {compact, standard}
	# corpus confirmed rim-only anchors never produced a courtyard/
	# garden_terrace placement the passage-adjacent anchor set did not
	# already reach on its own (byte-identical reservation counts with the
	# rim addition removed).
	var anchors: Dictionary = _passage_adjacent_columns(plan, passage_columns)
	var anchor_list: Array[Vector2i] = []
	anchor_list.assign(anchors.keys())
	anchor_list.sort_custom(_column_less)
	var orientations: Array[Vector2i] = [patch]
	if patch.x != patch.y:
		orientations.append(Vector2i(patch.y, patch.x))
	var out: Array[Dictionary] = []
	for anchor: Vector2i in anchor_list:
		for orientation_index in orientations.size():
			var orientation := orientations[orientation_index]
			for corner_index in 4:
				var origin := _corner_origin(anchor, orientation, corner_index)
				var footprint := _footprint_from_origin(origin, orientation)
				if not _footprint_is_available(plan, footprint,
						passage_columns, claimed_columns):
					continue
				out.append({"anchor": anchor, "orientation_index":
					orientation_index, "corner_index": corner_index,
					"footprint": footprint})
	out.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_anchor := left.anchor as Vector2i
		var right_anchor := right.anchor as Vector2i
		if left_anchor != right_anchor:
			return _column_less(left_anchor, right_anchor)
		if int(left.orientation_index) != int(right.orientation_index):
			return int(left.orientation_index) < int(right.orientation_index)
		return int(left.corner_index) < int(right.corner_index))
	return out


static func _corner_origin(anchor: Vector2i, orientation: Vector2i,
		corner_index: int) -> Vector2i:
	var origin := anchor
	if corner_index & 1:
		origin.x -= orientation.x - 1
	if corner_index & 2:
		origin.y -= orientation.y - 1
	return origin


static func _footprint_from_origin(origin: Vector2i,
		orientation: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dx in orientation.x:
		for dz in orientation.y:
			out.append(origin + Vector2i(dx, dz))
	return out


static func _footprint_is_available(plan: WarrenMazeSourcePlan,
		footprint: Array[Vector2i], passage_columns: Dictionary,
		claimed_columns: Dictionary) -> bool:
	if footprint.is_empty():
		return false
	for column: Vector2i in footprint:
		if not plan.massif.has_column(column) or passage_columns.has(column) \
				or claimed_columns.has(column):
			return false
	return true


static func _passage_column_set(plan: WarrenMazeSourcePlan) -> Dictionary:
	var out: Dictionary = {}
	for cell: Vector3i in plan.passage_cells():
		out[Vector2i(cell.x, cell.z)] = true
	return out


static func _passage_adjacent_columns(plan: WarrenMazeSourcePlan,
		passage_columns: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for cell: Vector3i in plan.passage_cells():
		for direction: Vector2i in CARDINALS:
			var column := Vector2i(cell.x, cell.z) + direction
			if plan.massif.has_column(column) \
					and not passage_columns.has(column):
				out[column] = true
	return out


static func _overhead_candidates(plan: WarrenMazeSourcePlan,
		passage_columns: Dictionary, claimed_columns: Dictionary,
		claimed_walk_cells: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var axis_pairs := [
		[Vector2i.RIGHT, Vector2i.LEFT], [Vector2i.DOWN, Vector2i.UP],
	]
	for cell: Vector3i in plan.passage_cells():
		var column := Vector2i(cell.x, cell.z)
		if cell.y + 2 >= plan.effective_top(column):
			continue
		if claimed_walk_cells.has(cell):
			continue
		for pair: Array in axis_pairs:
			var flank_a := column + (pair[0] as Vector2i)
			var flank_b := column + (pair[1] as Vector2i)
			# A flank column may itself carry a vertically crossing passage at
			# a different band (WarrenPassageLatticeRules keeps a full solid
			# separator between them, not a whole-column exclusion), so SOLID
			# at this one band is not enough -- reject any flank that hosts a
			# passage cell anywhere in its column.
			if passage_columns.has(flank_a) or passage_columns.has(flank_b):
				continue
			if claimed_columns.has(flank_a) or claimed_columns.has(flank_b):
				continue
			if plan.state_at(Vector3i(flank_a.x, cell.y, flank_a.y)) \
						!= WarrenMazeSourcePlan.CellState.SOLID \
					or plan.state_at(Vector3i(flank_b.x, cell.y, flank_b.y)) \
						!= WarrenMazeSourcePlan.CellState.SOLID:
				continue
			out.append({"walk": cell,
				"flanks": [flank_a, flank_b] as Array[Vector2i],
				"tie": WarrenPassageLatticeRules.hash_key(plan.world_seed,
					0x5B79A15, cell, flank_a.x * 3 + flank_a.y)})
	out.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_walk := left.walk as Vector3i
		var right_walk := right.walk as Vector3i
		if left_walk != right_walk:
			return _cell_less(left_walk, right_walk)
		return int(left.tie) < int(right.tie))
	return out


static func _quota_roll(world_seed: int, kind: StringName,
		quota: Vector2i) -> int:
	if quota.y <= quota.x:
		return maxi(quota.x, 0)
	var span := quota.y - quota.x + 1
	return quota.x + posmod(Helper._mix64(world_seed ^ int(kind.hash())), span)


static func _optional_selected(world_seed: int, kind: StringName) -> bool:
	return posmod(Helper._mix64(world_seed ^ int(kind.hash())
		^ 0x0FF71047A1), 2) == 1


static func _column_less(a: Vector2i, b: Vector2i) -> bool:
	if a.y != b.y:
		return a.y < b.y
	return a.x < b.x


static func _cell_less(a: Vector3i, b: Vector3i) -> bool:
	if a.y != b.y:
		return a.y < b.y
	if a.z != b.z:
		return a.z < b.z
	return a.x < b.x


static func _fail(reason: String) -> bool:
	last_failure = reason
	return false
