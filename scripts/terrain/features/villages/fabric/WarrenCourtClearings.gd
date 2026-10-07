class_name WarrenCourtClearings
extends RefCounted
## Courtyard clearings: open rooms reserved inside the massif while streets
## are bored. Placement is a biased draw, never a rule: columns far from any
## street (big uncut blocks) are more likely, ground level moderately
## favoured, size/shape/purpose drawn from the town's character. Only
## guardrails are hard: a legal deck column at the floor, minimum width 2
## (every cell lies in a fully contained 2x2 block), and no overlap with other
## reservations or earlier clearings. Pure: nothing is carved here.

const ATTEMPTS_PER_CLEARING := 24
const SALT_CENTRE := 0x434C4552
const SALT_FLOOR := 0x464C4F52
const SALT_GROW := 0x47524F57
const FLOOR_STEP := 2
const DECK_LEVEL_BANDS := 6


static func street_distance(massif: WarrenMassif, excavation: WarrenExcavation) -> Dictionary:
	## Column -> 4-neighbour steps over the massif to the nearest column holding
	## a public cell (those columns are 0). Columns no street reaches are absent.
	var distance := {}
	var frontier: Array[Vector2i] = []
	for cell: Vector3i in excavation.public_cells():
		var column := Vector2i(cell.x, cell.z)
		if massif.has_column(column) and not distance.has(column):
			distance[column] = 0
			frontier.append(column)
	frontier.sort_custom(WarrenPlotPlanner.column_less)
	var index := 0
	while index < frontier.size():
		var column := frontier[index]
		index += 1
		for direction: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
			var next := column + direction
			if massif.has_column(next) and not distance.has(next):
				distance[next] = int(distance[column]) + 1
				frontier.append(next)
	return distance


static func propose(world_seed: int, massif: WarrenMassif, excavation: WarrenExcavation,
		profile: WarrenVillageScaleProfile) -> Array[Dictionary]:
	var character := TownCharacter.of(profile, world_seed)
	var wanted := character.count(&"clearing_count")
	var out: Array[Dictionary] = []
	if wanted <= 0:
		return out
	var empty := WarrenMazeSourcePlan.new(world_seed, profile, massif, excavation)
	var blocked := WarrenPlotPlanner.blocked_columns(empty)
	var street := street_distance(massif, excavation)
	var candidates := _candidates(empty, street, blocked, character)
	var taken := {}
	var attempt := 0
	while out.size() < wanted and attempt < wanted * ATTEMPTS_PER_CLEARING and not candidates.is_empty():
		attempt += 1
		var centre := _weighted_pick(candidates, character.roll(&"clearing_block_bias", Vector2i(attempt, SALT_CENTRE)))
		if taken.has(centre.column):
			continue
		var floor_band := int(centre.floor)
		var shape := character.pick(&"clearing_shape", Vector2i(attempt, SALT_FLOOR))
		var cells := _grow(empty, centre.column as Vector2i, floor_band, character.count(&"clearing_area"),
			shape, blocked, taken, street, character, attempt)
		if cells.size() < 4:
			continue
		for column: Vector2i in cells:
			taken[column] = true
		var key := Vector2i(out.size(), floor_band)
		out.append({"cells": cells, "floor": floor_band, "shape": shape,
			"purpose": character.pick(&"clearing_purpose", key),
			"cover": character.pick(&"clearing_cover", key)})
	return out


static func _candidates(plan: WarrenMazeSourcePlan, street: Dictionary, blocked: Dictionary,
		character: TownCharacter) -> Array[Dictionary]:
	## (column, floor) pairs weighted by street distance ^ bias, ground x weight.
	var out: Array[Dictionary] = []
	var massif := plan.massif
	var bias := character.value(&"clearing_block_bias")
	var ground := character.value(&"clearing_ground_weight")
	var columns: Array = massif.columns.keys()
	columns.sort_custom(WarrenPlotPlanner.column_less)
	for column: Vector2i in columns:
		var distance := int(street.get(column, 0))
		if distance <= 0 or blocked.has(column):
			continue
		var low := massif.bearing_at(column)
		var high := massif.top_at(column)
		var base_weight := pow(maxf(0.01, float(distance)), bias)
		for floor_band in range(low, high + 1, FLOOR_STEP):
			if WarrenPlotReservations._deck_column_ok(plan, column, floor_band, {}, blocked, DECK_LEVEL_BANDS):
				out.append({"column": column, "floor": floor_band,
					"weight": base_weight * (ground if floor_band == low else 1.0)})
	return out


static func _weighted_pick(candidates: Array[Dictionary], r: float) -> Dictionary:
	var total := 0.0
	for c: Dictionary in candidates:
		total += float(c.weight)
	var target := r * total
	for c: Dictionary in candidates:
		target -= float(c.weight)
		if target < 0.0:
			return c
	return candidates.back()


static func _legal(plan: WarrenMazeSourcePlan, column: Vector2i, floor_band: int,
		blocked: Dictionary, taken: Dictionary, street: Dictionary) -> bool:
	return not taken.has(column) and int(street.get(column, 0)) > 0 \
		and WarrenPlotReservations._deck_column_ok(plan, column, floor_band, {}, blocked, DECK_LEVEL_BANDS)


static func _grow(plan: WarrenMazeSourcePlan, centre: Vector2i, floor_band: int, area: int,
		shape: StringName, blocked: Dictionary, taken: Dictionary, street: Dictionary,
		character: TownCharacter, attempt: int) -> Array[Vector2i]:
	## 1-3 rectangles (each at least 2x2) or a blob of 2x2 blocks, grown from
	## the centre. A piece is added whole or not at all, so every cell stays in
	## a fully contained 2x2 block; the first piece must succeed.
	var cells := {}
	var rect_count: int = {&"rect": 1, &"two_rect": 2, &"three_rect": 3}.get(shape, 0)
	var pieces := rect_count if rect_count > 0 else maxi(1, area / 4)
	var per_piece := maxi(4, area / (rect_count if rect_count > 0 else pieces)) if rect_count > 0 else 4
	for piece in pieces * 3:
		if piece >= pieces and (cells.size() >= area or cells.is_empty()):
			break
		var key := Vector3i(attempt, piece, SALT_GROW)
		var w := 2
		var d := 2
		if rect_count > 0:
			w = 2 + int(character.roll(&"clearing_area", key) * maxf(1.0, sqrt(float(per_piece)) - 1.0))
			d = maxi(2, per_piece / w)
		var anchor := centre
		if not cells.is_empty():
			var keys := cells.keys()
			keys.sort_custom(WarrenPlotPlanner.column_less)
			anchor = keys[int(character.roll(&"clearing_shape", key) * float(keys.size())) % keys.size()]
		# The rectangle's lower corner sits so the anchor is inside or touching it.
		var lx := int(character.roll(&"clearing_cover", key) * float(w + 1)) - w
		var lz := int(character.roll(&"clearing_purpose", key) * float(d + 1)) - d
		var corner := anchor + Vector2i(lx, lz)
		if not cells.is_empty() and rect_count == 0:
			# Blobs grow by one 2x2 block touching the anchor cell's side.
			var side := int(character.roll(&"clearing_extra_link_chance", key) * 4.0) % 4
			var slide := int(character.roll(&"clearing_extra_link_chance", Vector3i(attempt, piece, SALT_FLOOR)) * 2.0) - 1
			var offsets: Array[Vector2i] = [Vector2i(1, slide), Vector2i(slide, 1), Vector2i(-2, slide), Vector2i(slide, -2)]
			corner = anchor + offsets[side]
		var block: Array[Vector2i] = []
		var legal := true
		for x in w:
			for z in d:
				var column := corner + Vector2i(x, z)
				if cells.has(column):
					continue
				if not _legal(plan, column, floor_band, blocked, taken, street):
					legal = false
					break
				block.append(column)
			if not legal:
				break
		if legal:
			for column: Vector2i in block:
				cells[column] = true
		elif cells.is_empty():
			if piece >= 6:
				break
	var out: Array[Vector2i] = []
	out.assign(cells.keys())
	out.sort_custom(WarrenPlotPlanner.column_less)
	return out
