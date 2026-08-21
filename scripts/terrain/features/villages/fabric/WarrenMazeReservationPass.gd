class_name WarrenMazeReservationPass
extends RefCounted

## P3 -- reservation pass. Generalizes the existing universal-market stamp
## into a data-driven registry: each feature kind names its quota range per
## scale profile, its patch footprint, and the constructive edit op that
## claims it. Every outcome (landed, shrunk, skipped, not selected) is a
## reason-coded audit fact; reserve() only returns false on a contract
## violation such as being called with a sealed plan.
const REGISTRY: Array[Dictionary] = [
	{"kind": &"courtyard", "optional": false, "quota": {"compact": Vector2i(0, 1),
		"standard": Vector2i(1, 1), "large": Vector2i(1, 2),
		"grand": Vector2i(1, 2)}, "patch": Vector2i(2, 2),
		"edit": &"sink_to_terrain"},
	{"kind": &"large_house", "optional": false, "quota": {"compact": Vector2i(0, 1),
		"standard": Vector2i(1, 2), "large": Vector2i(2, 3),
		"grand": Vector2i(2, 4)}, "patch": Vector2i(3, 2),
		"edit": &"level_to_datum"},
	{"kind": &"landmark_plot", "optional": true, "quota": {"compact": Vector2i(0, 1),
		"standard": Vector2i(0, 1), "large": Vector2i(1, 2),
		"grand": Vector2i(1, 2)}, "patch": Vector2i(3, 3),
		"edit": &"level_to_datum"},
	{"kind": &"skywalk_span", "optional": true, "quota": {"compact": Vector2i(0, 1),
		"standard": Vector2i(1, 2), "large": Vector2i(2, 3),
		"grand": Vector2i(3, 4)}, "patch": Vector2i.ZERO,
		"edit": &"claim_overhead"},
	{"kind": &"garden_terrace", "optional": true, "quota": {"compact": Vector2i(0, 1),
		"standard": Vector2i(0, 1), "large": Vector2i(0, 2),
		"grand": Vector2i(0, 2)}, "patch": Vector2i(2, 1),
		"edit": &"level_to_datum"},
]

const CARDINALS: Array[Vector2i] = [
	Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP,
]
const RIM_KINDS: Array[StringName] = [&"courtyard", &"garden_terrace"]

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


static func _try_fit_and_edit(plan: WarrenMazeSourcePlan, kind: StringName,
		edit: StringName, footprint: Array[Vector2i]) -> Dictionary:
	if footprint.is_empty():
		return {}
	match edit:
		&"sink_to_terrain":
			return _apply_sink_to_terrain(plan, kind, footprint)
		&"level_to_datum":
			return _apply_level_to_datum(plan, kind, footprint)
	return {}


static func _apply_sink_to_terrain(plan: WarrenMazeSourcePlan,
		kind: StringName, footprint: Array[Vector2i]) -> Dictionary:
	var datum := 2147483647
	for column: Vector2i in footprint:
		datum = mini(datum, plan.massif.base_at(column))
	for column: Vector2i in footprint:
		var floor_band := plan.massif.base_at(column)
		if not plan.record_edit(column, floor_band, floor_band, &"reserve"):
			return {}
	plan.reservations.append({"kind": kind, "cells": footprint.duplicate(),
		"datum_band": datum, "walk_cells": [] as Array[Vector3i], "audit": {}})
	return {"kind": kind, "result": &"fit", "placed": true,
		"cells": footprint.size()}


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
	for column: Vector2i in footprint:
		var top := maxi(plan.effective_top(column), datum)
		if not plan.record_edit(column, datum, top, &"reserve"):
			return {}
	plan.reservations.append({"kind": kind, "cells": footprint.duplicate(),
		"datum_band": datum, "walk_cells": [] as Array[Vector3i], "audit": {}})
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
	var anchors: Dictionary = _passage_adjacent_columns(plan, passage_columns)
	if kind in RIM_KINDS:
		for column: Vector2i in _rim_columns(plan.massif, passage_columns):
			anchors[column] = true
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


static func _rim_columns(massif: WarrenMassif,
		passage_columns: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for column: Vector2i in massif.columns.keys():
		if passage_columns.has(column):
			continue
		for direction: Vector2i in CARDINALS:
			if not massif.has_column(column + direction):
				out[column] = true
				break
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
