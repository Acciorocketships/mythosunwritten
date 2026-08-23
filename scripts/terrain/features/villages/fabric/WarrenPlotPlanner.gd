class_name WarrenPlotPlanner
extends RefCounted

## P3 (assets, decks) and P4 (houses, heights, bridges) of the 2026-08-21
## plot-model design. Static and program-free: the only things it ever changes
## on a plan are `add_plot` and `audit`, and support, clearance, and
## disjointness stay WarrenMazeSourcePlan's rules, never re-derived here.
##
## Nothing here rejects a town: a quota that finds no site, a roof that cannot
## reach its own minimum, a span whose clearance was eaten are all outcomes in
## `audit["plot_outcomes"]` (rules become repairs), never a failed phase.

## Bands of solid mass a bearing plot needs directly beneath its floor.
## Identical to WarrenMazeStampPass.PLINTH_BANDS; a later task re-points
## WarrenBuildingParcel here and deletes that copy. Nothing in this planner
## reads it -- the support rule already answers "may a plot stand here" -- it
## lives here so the number ends up with one home.
const PLINTH_BANDS := 2
## Macro footprints of the catalog's `prefab_anchor` recipe family, derived ONCE
## so the planner never loads the catalog at runtime:
##
##   fine  = recipe.local_clearance_bounds.size / FabricRecipe.CELL_SIZE
##   width = ceili(fine.x / 2), depth = ceili(fine.z / 2)  # 2 fine = 1 macro
##   height_bands = ceili(fine.y)                          # 1 fine = 1 band
##
## One entry per UNIQUE (width, depth, height_bands), named by the first recipe
## in `program.recipes()` order to produce it; rounding is up in all three axes,
## because a template that does not enclose its own prefab is not a site.
## test_asset_templates_match_the_catalog recompiles the program and demands
## this table equal that derivation, so it can never drift.
const ASSET_TEMPLATES: Array[Dictionary] = [
	{"kind_id": &"anchor.prefab.00", "width": 4, "depth": 6, "height_bands": 8},
	{"kind_id": &"anchor.prefab.01", "width": 5, "depth": 6, "height_bands": 7},
	{"kind_id": &"anchor.prefab.02", "width": 5, "depth": 6, "height_bands": 13},
	{"kind_id": &"anchor.prefab.03", "width": 16, "depth": 12, "height_bands": 23},
	{"kind_id": &"anchor.prefab.04", "width": 5, "depth": 5, "height_bands": 12},
	{"kind_id": &"anchor.prefab.06", "width": 7, "depth": 7, "height_bands": 11},
	{"kind_id": &"anchor.prefab.10", "width": 3, "depth": 3, "height_bands": 4},
	{"kind_id": &"anchor.prefab.12", "width": 4, "depth": 3, "height_bands": 4},
	{"kind_id": &"anchor.prefab.14", "width": 4, "depth": 3, "height_bands": 6},
	{"kind_id": &"anchor.prefab.17", "width": 6, "depth": 5, "height_bands": 8},
	{"kind_id": &"anchor.prefab.19", "width": 5, "depth": 6, "height_bands": 10},
	{"kind_id": &"anchor.prefab.21", "width": 5, "depth": 5, "height_bands": 7},
	{"kind_id": &"anchor.prefab.22", "width": 5, "depth": 5, "height_bands": 13},
	{"kind_id": &"anchor.prefab.23", "width": 7, "depth": 8, "height_bands": 11},
	{"kind_id": &"anchor.prefab.25", "width": 16, "depth": 14, "height_bands": 28},
	{"kind_id": &"anchor.prefab.31", "width": 3, "depth": 4, "height_bands": 9},
]
## Smallest region worth calling a courtyard: one column is a gap between
## houses, not a public floor, so anything smaller is discarded.
const DECK_MIN := 2
## Largest deck a scale may grow, in macro columns. A deck is a hole in the
## fabric: past this it reads as missing town rather than as a courtyard, so
## growth halts here even where more flat ground remains.
const DECK_MAX: Dictionary = {
	&"compact": 4, &"standard": 6, &"large": 9, &"grand": 12,
}
## (min, max) decks a scale asks for; the seeded roll picks inside it. A compact
## town wants one breathing space, a grand one wants a few.
const DECK_QUOTA: Dictionary = {
	&"compact": Vector2i(1, 1), &"standard": Vector2i(1, 2),
	&"large": Vector2i(2, 3), &"grand": Vector2i(3, 4),
}
## Largest house footprint a scale may grow, in macro columns: what stops the
## greedy partition from letting one building eat a whole block.
const BUILDING_CAP: Dictionary = {
	&"compact": 4, &"standard": 5, &"large": 6, &"grand": 8,
}
## (min, max) storeys an untiered house may roll, floored at MIN_HOUSE_BANDS --
## a house shorter than the clearance the support rule reserved for it is not a
## house. A tiered house ignores this: its roof is the street above it.
const STOREY_BUDGET: Dictionary = {
	&"compact": Vector2i(1, 2), &"standard": Vector2i(1, 3),
	&"large": Vector2i(2, 3), &"grand": Vector2i(2, 4),
}
## One salt per seeded roll, so two rolls on the same cell can never agree by
## accident. Every roll here goes through WarrenPassageLatticeRules.hash_key;
## nothing in this file touches randi() or an RNG with state of its own.
const ASSET_QUOTA_SALT := 0x51071
const DECK_QUOTA_SALT := 0x4dec5
const STOREY_SALT := 0x570e5
## "This column may not join at all", distinct from -1, "it joins and binds no
## tier band".
const JOIN_REFUSED := -0x40000000


## P3: catalog assets at their minimum-modification sites, then flat decks
## grown off the streets, both recorded in `plan.audit["plot_outcomes"]`.
static func reserve(plan: WarrenMazeSourcePlan,
		profile: WarrenVillageScaleProfile) -> void:
	if plan == null or profile == null or plan.is_sealed():
		return
	var outcomes := _outcomes(plan)
	var streets := _street_bands(plan)
	var blocked := _blocked_columns(plan)
	outcomes["assets"] = _place_assets(plan, profile, streets, blocked)
	outcomes["decks"] = _grow_decks(plan, blocked)


## P4: seed a house at every street-fronting column, grow the partition
## largest-building-first, raise each house to the street above it or to its
## storey roll, then drop a bridge onto every retained span.
static func partition(plan: WarrenMazeSourcePlan,
		profile: WarrenVillageScaleProfile) -> void:
	if plan == null or profile == null or plan.is_sealed():
		return
	var outcomes := _outcomes(plan)
	var streets := _street_bands(plan)
	var blocked := _blocked_columns(plan)
	var claims: Dictionary = {}
	var buildings := _seed_buildings(plan, streets, blocked, claims)
	_grow_buildings(plan, buildings, streets, blocked, claims)
	outcomes["buildings"] = _raise_buildings(plan, streets, claims, buildings)
	outcomes["bridges"] = _span_bridges(plan)
	var owned := _owned_columns(plan)
	var leftover := 0
	for column: Vector2i in plan.massif.columns:
		leftover += int(not owned.has(column))
	outcomes["leftover_columns"] = leftover
	var gaps := 0
	for cell: Vector3i in plan.passage_cells():
		gaps += int(not plan.solid_at(Vector3i(cell.x, cell.y - 1, cell.z)))
	outcomes["street_floor_gaps"] = gaps


# --- P3a assets ------------------------------------------------------------


static func _place_assets(plan: WarrenMazeSourcePlan,
		profile: WarrenVillageScaleProfile, streets: Dictionary,
		blocked: Dictionary) -> Array[Dictionary]:
	## One pass per quota slot: enumerate every (template, orientation, anchor,
	## datum) site the massif and the support rule allow, take the cheapest,
	## commit it. Each placement narrows the next slot's candidate set, so the
	## slots are sequential rather than scored in one batch.
	var records: Array[Dictionary] = []
	var quota := _roll(plan, ASSET_QUOTA_SALT, plan.summit_cell, 0,
		profile.landmark_range)
	var columns: Array[Vector2i] = []
	columns.assign(plan.massif.columns.keys())
	columns.sort_custom(Callable(WarrenPlotPlanner, "_column_less"))
	for index in quota:
		var site := _best_asset_site(plan, streets, columns, blocked)
		if site.is_empty():
			records.append({"kind_id": &"", "site": null,
				"reason": "no street-fronting supportable site remains"})
			continue
		var id := StringName("asset.%02d" % index)
		var template := ASSET_TEMPLATES[int(site["template"])] as Dictionary
		var datum := int(site["datum"])
		var record := {"kind_id": StringName(template["kind_id"]),
			"site": {"id": id, "anchor": site["anchor"], "datum": datum,
				"cost": int(site["cost"]),
				"orientation": int(site["orientation"])}, "reason": ""}
		if plan.add_plot({"id": id, "kind": WarrenMazeSourcePlan.PLOT_ASSET,
				"cells": site["cells"], "floor": datum,
				"top": datum + int(template["height_bands"]),
				"door_walk": site["door"], "building_id": id}):
			for cell_value: Variant in site["cells"] as Array:
				blocked[cell_value as Vector2i] = true
		else:
			record["site"] = null
			record["reason"] = plan.last_rejection
		records.append(record)
	return records


static func _best_asset_site(plan: WarrenMazeSourcePlan, streets: Dictionary,
		columns: Array[Vector2i], blocked: Dictionary) -> Dictionary:
	## Minimum terrain-modification cost -- the sum over the footprint of
	## |massif.top_at(c) - datum| -- over every legal site, with the door the
	## winner faces. Ties break by (datum, anchor.x, anchor.z, orientation,
	## template); the last key is there because two templates of different sizes
	## can both cost zero on flat ground, and a total order is the whole point.
	var best: Dictionary = {}
	for template_index in ASSET_TEMPLATES.size():
		var template := ASSET_TEMPLATES[template_index] as Dictionary
		for orientation in 2:
			var flip := orientation == 1
			var width := int(template["depth" if flip else "width"])
			var depth := int(template["width" if flip else "depth"])
			for anchor: Vector2i in columns:
				var cells := _footprint(plan, anchor, width, depth, blocked)
				if cells.is_empty():
					continue
				var doors := _fronting_doors(cells, streets)
				var bands: Array = doors.keys()
				bands.sort()
				for datum: int in bands:
					var cost := 0
					for member: Vector2i in cells:
						if not plan.plot_support_ok(member, datum):
							cost = -1
							break
						cost += absi(plan.massif.top_at(member) - datum)
					if cost < 0:
						continue
					var site := {"template": template_index,
						"orientation": orientation, "anchor": anchor,
						"datum": datum, "cost": cost, "cells": cells,
						"door": doors[datum]}
					if best.is_empty() or _site_less(site, best):
						best = site
	return best


static func _footprint(plan: WarrenMazeSourcePlan, anchor: Vector2i,
		width: int, depth: int, blocked: Dictionary) -> Array[Vector2i]:
	## The width x depth block of massif columns at `anchor`, or empty when a
	## member is off the massif or already spoken for.
	var out: Array[Vector2i] = []
	for dz in depth:
		for dx in width:
			var member := anchor + Vector2i(dx, dz)
			if not plan.massif.has_column(member) or blocked.has(member):
				return [] as Array[Vector2i]
			out.append(member)
	return out


static func _fronting_doors(cells: Array[Vector2i],
		streets: Dictionary) -> Dictionary:
	## band -> the street cell this footprint addresses there. Every band a
	## street runs beside it is a candidate datum -- the datum IS the fronting
	## street's band -- and where several cells qualify the lowest-ordered one
	## wins, so the choice is made by order, never by enumeration.
	var members: Dictionary = {}
	for column: Vector2i in cells:
		members[column] = true
	var out: Dictionary = {}
	for column: Vector2i in cells:
		for direction: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
			var next := column + direction
			if members.has(next):
				continue
			for band: int in streets.get(next, []) as Array:
				var cell := Vector3i(next.x, band, next.y)
				var held: Vector3i = out.get(band, cell)
				out[band] = cell if cell.z < held.z \
					or cell.z == held.z and cell.x <= held.x else held
	return out


static func _site_less(a: Dictionary, b: Dictionary) -> bool:
	for key: String in ["cost", "datum"]:
		if int(a[key]) != int(b[key]):
			return int(a[key]) < int(b[key])
	var anchor_a := a["anchor"] as Vector2i
	var anchor_b := b["anchor"] as Vector2i
	if anchor_a != anchor_b:
		return anchor_a.x < anchor_b.x if anchor_a.x != anchor_b.x \
			else anchor_a.y < anchor_b.y
	if int(a["orientation"]) != int(b["orientation"]):
		return int(a["orientation"]) < int(b["orientation"])
	return int(a["template"]) < int(b["template"])


# --- P3b decks -------------------------------------------------------------


static func _grow_decks(plan: WarrenMazeSourcePlan,
		blocked: Dictionary) -> Array[Dictionary]:
	## Walk the streets in order and grow the flattest region beside each one,
	## keeping them until the scale's quota is met. The seeded variation is the
	## quota roll: a candidate is never skipped on a coin flip, or the same town
	## would grow its decks elsewhere the moment its walk order shifted.
	var records: Array[Dictionary] = []
	var scale := plan.scale_profile.scale_id
	var quota := _roll(plan, DECK_QUOTA_SALT, plan.summit_cell, 0,
		DECK_QUOTA.get(scale, Vector2i(1, 1)))
	var cap := int(DECK_MAX.get(scale, DECK_MIN))
	for street: Vector3i in _walk_order(plan):
		if records.size() >= quota:
			break
		var region := _deck_region(plan, street, blocked, cap)
		if region.size() < DECK_MIN or not plan.add_plot({
				"id": StringName("deck.%02d" % records.size()),
				"kind": WarrenMazeSourcePlan.PLOT_DECK, "cells": region,
				"floor": street.y, "top": street.y, "door_walk": street,
				"building_id": StringName("deck.%02d" % records.size())}):
			continue
		for column: Vector2i in region:
			blocked[column] = true
		records.append({"id": StringName("deck.%02d" % (records.size())),
			"size": region.size(), "datum": street.y})
	return records


static func _deck_region(plan: WarrenMazeSourcePlan, street: Vector3i,
		blocked: Dictionary, cap: int) -> Array[Vector2i]:
	## Cheapest-first growth from the street's own four neighbours over columns
	## whose envelope stands within a band of the datum and that the support
	## rule accepts there. Cheapest is |top_at - datum|, then column order.
	var datum := street.y
	var region: Array[Vector2i] = []
	var frontier: Array[Vector2i] = []
	var expand: Array[Vector2i] = [Vector2i(street.x, street.z)]
	var seen: Dictionary = {}
	while region.size() < cap:
		while not expand.is_empty():
			var from := expand.pop_back() as Vector2i
			for direction: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
				var next := from + direction
				if seen.has(next) or blocked.has(next) \
						or not plan.massif.has_column(next) \
						or absi(plan.massif.top_at(next) - datum) > 1 \
						or not plan.plot_support_ok(next, datum):
					continue
				seen[next] = true
				frontier.append(next)
		if frontier.is_empty():
			break
		var choice := 0
		for index in range(1, frontier.size()):
			if _closer(plan, frontier[index], frontier[choice], datum):
				choice = index
		region.append(frontier[choice])
		expand.append(frontier[choice])
		frontier.remove_at(choice)
	return region


static func _closer(plan: WarrenMazeSourcePlan, a: Vector2i, b: Vector2i,
		datum: int) -> bool:
	## Which column a growth step would rather have: the one whose envelope is
	## nearest the datum, then the one that sorts first.
	var cost_a := absi(plan.massif.top_at(a) - datum)
	var cost_b := absi(plan.massif.top_at(b) - datum)
	return cost_a < cost_b if cost_a != cost_b else _column_less(a, b)


# --- P4 partition ----------------------------------------------------------


static func _seed_buildings(plan: WarrenMazeSourcePlan, streets: Dictionary,
		blocked: Dictionary, claims: Dictionary) -> Array[Dictionary]:
	## One seed per (column, band): a street cell claims each of its four
	## neighbour columns at its own band, which is exactly what lets an upper
	## street's house stack on the roof of the lower street's tiered house.
	var out: Array[Dictionary] = []
	for street: Vector3i in _walk_order(plan):
		for direction: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
			var column := Vector2i(street.x, street.z) + direction
			var tier := _join_tier(plan, column, street.y, streets, blocked,
				claims, -1)
			if tier == JOIN_REFUSED:
				continue
			claims[column] = (claims.get(column, []) as Array) + [street.y]
			out.append({"id": StringName("house.%03d" % out.size()),
				"seed": column, "cells": [column] as Array[Vector2i],
				"floor": street.y, "door": street, "tier": tier})
	return out


static func _grow_buildings(plan: WarrenMazeSourcePlan,
		buildings: Array[Dictionary], streets: Dictionary,
		blocked: Dictionary, claims: Dictionary) -> void:
	## The single priority loop: the largest building that can still grow (ties
	## to the lowest id) takes its one best adjacent column, and the loop runs
	## again. A building that finds no candidate is stalled for good -- columns
	## are only claimed, never released -- so this terminates after at most one
	## stall per building plus one growth step per column.
	var cap := int(BUILDING_CAP.get(plan.scale_profile.scale_id, 4))
	var stalled: Array[bool] = []
	stalled.resize(buildings.size())
	while true:
		var choice := -1
		var largest := 0
		for index in buildings.size():
			var size := (buildings[index]["cells"] as Array).size()
			if stalled[index] or size >= cap or size <= largest:
				continue
			largest = size
			choice = index
		if choice < 0:
			break
		var building := buildings[choice]
		var pick := _best_join(plan, building, streets, blocked, claims)
		if pick.is_empty():
			stalled[choice] = true
			continue
		var column := pick["column"] as Vector2i
		(building["cells"] as Array[Vector2i]).append(column)
		if int(pick["tier"]) >= 0:
			building["tier"] = int(pick["tier"])
		claims[column] = (claims.get(column, []) as Array) \
			+ [int(building["floor"])]


static func _best_join(plan: WarrenMazeSourcePlan, building: Dictionary,
		streets: Dictionary, blocked: Dictionary,
		claims: Dictionary) -> Dictionary:
	## The adjacent column this building would rather have, and the tier band
	## taking it would bind.
	var floor_band := int(building["floor"])
	var members: Dictionary = {}
	for column: Vector2i in building["cells"] as Array[Vector2i]:
		members[column] = true
	var best: Dictionary = {}
	for column: Vector2i in building["cells"] as Array[Vector2i]:
		for direction: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
			var next := column + direction
			if members.has(next):
				continue
			var tier := _join_tier(plan, next, floor_band, streets, blocked,
				claims, int(building["tier"]))
			if tier == JOIN_REFUSED:
				continue
			members[next] = true
			if best.is_empty() \
					or _closer(plan, next, best["column"], floor_band):
				best = {"column": next, "tier": tier}
	return best


static func _join_tier(plan: WarrenMazeSourcePlan, column: Vector2i,
		floor_band: int, streets: Dictionary, blocked: Dictionary,
		claims: Dictionary, bound: int) -> int:
	## May `column` carry a house at `floor_band`, and what tier band does that
	## bind? JOIN_REFUSED when it may not, -1 when it joins and binds nothing,
	## otherwise the single street band it hosts above the floor -- a column
	## hosting two never joins, and one hosting a street that disagrees with the
	## footprint's already-bound tier never joins either.
	##
	## Two strengthenings of the stated rule, both to keep the town sealable
	## rather than strict for its own sake: `blocked` holds every column an
	## asset, a deck, or a retained bridge span owns (a house under a deck
	## strands it -- a deck adds no solid mass, so everything above it floats --
	## and one under an asset strands the asset unless their bands meet), and
	## two houses may share a column only MIN_HOUSE_BANDS apart or more, so the
	## lower one's roof can always reach the upper one's floor.
	if blocked.has(column) or not plan.massif.has_column(column):
		return JOIN_REFUSED
	for other: int in claims.get(column, []) as Array:
		if absi(other - floor_band) < WarrenMazeSourcePlan.MIN_HOUSE_BANDS:
			return JOIN_REFUSED
	if not plan.plot_support_ok(column, floor_band):
		return JOIN_REFUSED
	var tier := -1
	for band: int in streets.get(column, []) as Array:
		if band < floor_band:
			continue
		if tier >= 0 and band != tier:
			return JOIN_REFUSED
		tier = band
	if tier >= 0 and (tier < floor_band + WarrenMazeSourcePlan.MIN_HOUSE_BANDS \
			or bound >= 0 and tier != bound):
		return JOIN_REFUSED
	return tier


static func _raise_buildings(plan: WarrenMazeSourcePlan, streets: Dictionary,
		claims: Dictionary, buildings: Array[Dictionary]) -> Array[Dictionary]:
	## Heights, then commit, in ascending floor order -- so a tiered house is
	## already standing when the house stacked on its roof asks the support rule
	## whether the band below it is solid.
	var records: Array[Dictionary] = []
	var order: Array[int] = []
	order.assign(range(buildings.size()))
	order.sort_custom(func(a: int, b: int) -> bool:
		var floor_a := int(buildings[a]["floor"])
		var floor_b := int(buildings[b]["floor"])
		return floor_a < floor_b if floor_a != floor_b else a < b)
	for index: int in order:
		var building := buildings[index]
		var floor_band := int(building["floor"])
		var roof := _building_top(plan, streets, claims, building)
		var id := StringName(building["id"])
		var cells := building["cells"] as Array[Vector2i]
		cells.sort_custom(Callable(WarrenPlotPlanner, "_column_less"))
		var top := int(roof["top"])
		var record := {"id": id, "cells": cells.size(), "floor": floor_band,
			"top": top, "tiered": bool(roof["tiered"]), "reason": ""}
		if top < floor_band + WarrenMazeSourcePlan.MIN_HOUSE_BANDS:
			record["reason"] = "no footprint here reaches MIN_HOUSE_BANDS"
		elif not plan.add_plot({"id": id,
				"kind": WarrenMazeSourcePlan.PLOT_HOUSE, "cells": cells,
				"floor": floor_band, "top": top,
				"door_walk": building["door"], "building_id": id}):
			record["reason"] = plan.last_rejection
		records.append(record)
	return records


static func _building_top(plan: WarrenMazeSourcePlan, streets: Dictionary,
		claims: Dictionary, building: Dictionary) -> Dictionary:
	## A roof is, in order of preference, the street running through this
	## footprint (the tier the whole model exists for), the lowest street past
	## its one-column apron, or the scale's seeded storey budget. It then has to
	## agree with whatever else is claimed above this floor on the same columns,
	## and a column it cannot agree with leaves the footprint -- hence the loop:
	## a smaller footprint sees a different street and a different ceiling.
	var floor_band := int(building["floor"])
	var minimum := floor_band + WarrenMazeSourcePlan.MIN_HOUSE_BANDS
	var rolled := floor_band + maxi(WarrenMazeSourcePlan.MIN_HOUSE_BANDS,
		WarrenBuildingParcel.STOREY_BANDS * _roll(plan, STOREY_SALT,
			building["door"] as Vector3i, 0, STOREY_BUDGET.get(
				plan.scale_profile.scale_id, Vector2i(1, 2))))
	var cells := building["cells"] as Array[Vector2i]
	var street_top := -1
	var top := floor_band
	while true:
		# Re-derived from the columns that survived, never from the flag growth
		# bound: a shrunken footprint may have lost the street it meant to meet.
		street_top = _lowest_street(streets, cells, minimum, false)
		if street_top < 0:
			street_top = _lowest_street(streets, cells, minimum, true)
		top = street_top if street_top >= 0 else rolled
		# Something is claimed above this floor on one of these columns. Meet
		# it: a roof that stops short of the house stacked on it strands that
		# house, and the stack invariant fails the whole town for it. A street
		# in the gap stops the climb, and then the column has to go instead.
		var cap := _lowest_above(claims, cells, floor_band)
		if cap >= 0:
			top = cap if _uncarved(plan, cells, floor_band, cap) \
				else mini(top, cap)
		# A column whose ceiling stands above this roof would leave whatever is
		# up there floating over the gap; one whose ceiling is below the minimum
		# is the design's own shrink clause (the join rule keeps that half
		# empty, but it is computed rather than assumed, so a looser join rule
		# can never quietly produce a two-band house).
		var dropped: Dictionary = {}
		for column: Vector2i in cells:
			var ceiling := _lowest_above(claims, [column] as Array[Vector2i],
				floor_band)
			if ceiling >= 0 and (ceiling > top or ceiling < minimum):
				dropped[column] = true
		if dropped.is_empty() or cells.size() <= 1:
			break
		cells = _keep_component(cells, dropped, building["seed"] as Vector2i)
		building["cells"] = cells
	return {"top": top, "tiered": street_top >= 0 and top == street_top}


static func _lowest_street(streets: Dictionary, cells: Array[Vector2i],
		minimum: int, apron: bool) -> int:
	## The lowest street band at or above `minimum` running through these
	## columns, or -1. `apron` looks one column further out -- the difference
	## between a street crossing this roof and one running past it.
	var columns: Dictionary = {}
	for column: Vector2i in cells:
		columns[column] = true
		if not apron:
			continue
		for direction: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
			columns[column + direction] = true
	var out := -1
	for column: Vector2i in columns:
		for band: int in streets.get(column, []) as Array:
			if band >= minimum:
				out = band if out < 0 else mini(out, band)
	return out


static func _uncarved(plan: WarrenMazeSourcePlan, cells: Array[Vector2i],
		from_band: int, to_band: int) -> bool:
	## Could a plot fill [from_band, to_band) on these columns at all, or does a
	## street run through it? Streets are immutable, so this is the one thing
	## that stops a roof from rising to meet the plot above it.
	for column: Vector2i in cells:
		for band in range(from_band, to_band):
			if plan.excavation.carved.has(Vector3i(column.x, band, column.y)):
				return false
	return true


static func _lowest_above(claims: Dictionary, cells: Array[Vector2i],
		floor_band: int) -> int:
	## The lowest floor another house claims above this one on these columns, or
	## -1 when the sky is clear. Assets and decks never share a column with a
	## house (see _join_tier), so houses are the whole story.
	var out := -1
	for column: Vector2i in cells:
		for band: int in claims.get(column, []) as Array:
			if band > floor_band:
				out = band if out < 0 else mini(out, band)
	return out


static func _keep_component(cells: Array[Vector2i], dropped: Dictionary,
		seed_column: Vector2i) -> Array[Vector2i]:
	## The seed's connected component once the offending columns leave, so a
	## shrunken footprint is still the 4-connected footprint add_plot demands.
	var members: Dictionary = {}
	for column: Vector2i in cells:
		if not dropped.has(column):
			members[column] = true
	if not members.has(seed_column):
		return [seed_column] as Array[Vector2i]
	var out: Array[Vector2i] = [seed_column]
	var seen: Dictionary = {seed_column: true}
	var head := 0
	while head < out.size():
		for direction: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
			var next := out[head] + direction
			if members.has(next) and not seen.has(next):
				seen[next] = true
				out.append(next)
		head += 1
	return out


# --- P4 bridges ------------------------------------------------------------


static func _span_bridges(plan: WarrenMazeSourcePlan) -> Array[Dictionary]:
	## Every span whose overhead mass the carver retained becomes a one-storey
	## plot on that slab, one band above the highest headroom the span owns.
	## Placed last, so an adjacent house sharing the bridge's own floor is
	## already standing and can lend it a building id.
	var records: Array[Dictionary] = []
	for index in plan.excavation.bridge_spans.size():
		var span: Array = plan.excavation.bridge_spans[index]
		var cells: Array[Vector2i] = []
		var floor_band := 0
		for cell_value: Variant in span:
			var cell := cell_value as Vector3i
			var column := Vector2i(cell.x, cell.z)
			if not cells.has(column):
				cells.append(column)
			floor_band = maxi(floor_band, plan.passage_headroom_top(cell)
				+ WarrenMazeSourcePlan.TUNNEL_ROOF_BANDS)
		var id := StringName("bridge.%02d" % index)
		var top := floor_band + WarrenBuildingParcel.STOREY_BANDS
		var owner := _bridge_owner(plan, cells, floor_band, id)
		var record := {"id": id, "cells": cells.size(), "floor": floor_band,
			"top": top, "building_id": owner, "reason": ""}
		if not plan.add_plot({"id": id,
				"kind": WarrenMazeSourcePlan.PLOT_BRIDGE, "cells": cells,
				"floor": floor_band, "top": top,
				"door_walk": span[0] as Vector3i, "building_id": owner}):
			record["reason"] = plan.last_rejection
		records.append(record)
	return records


static func _bridge_owner(plan: WarrenMazeSourcePlan, cells: Array[Vector2i],
		floor_band: int, own_id: StringName) -> StringName:
	## The house a bridge belongs to: one standing at the bridge's own floor on
	## a column beside the span, lowest id where several qualify -- so the
	## answer never depends on the order plots happened to be added.
	var members: Dictionary = {}
	for column: Vector2i in cells:
		members[column] = true
	var out := own_id
	for plot: Dictionary in plan.plots:
		if StringName(plot["kind"]) != WarrenMazeSourcePlan.PLOT_HOUSE \
				or int(plot["floor"]) != floor_band:
			continue
		var beside := false
		for cell_value: Variant in plot["cells"] as Array:
			var column := cell_value as Vector2i
			for direction: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
				beside = beside or members.has(column + direction)
		var id := StringName(plot["building_id"])
		if beside and (out == own_id or String(id) < String(out)):
			out = id
	return out


# --- Shared ----------------------------------------------------------------


static func _outcomes(plan: WarrenMazeSourcePlan) -> Dictionary:
	## The single audit record both phases write into. Seal merges its own keys
	## over the top without destroying this one.
	if not plan.audit.has("plot_outcomes"):
		plan.audit["plot_outcomes"] = {"assets": [], "decks": [],
			"buildings": [], "bridges": [], "leftover_columns": 0,
			"street_floor_gaps": 0}
	return plan.audit["plot_outcomes"] as Dictionary


static func _walk_order(plan: WarrenMazeSourcePlan) -> Array[Vector3i]:
	## Street cells in the order the town is walked: the spine, then each lane
	## from its anchor outward, then -- so nothing is ever missed -- whatever
	## passage cells that walk did not reach, in sorted order.
	var out: Array[Vector3i] = []
	var seen: Dictionary = {}
	var walks: Array[Array] = [plan.excavation.route]
	for lane: Dictionary in plan.excavation.lanes:
		var walk: Array[Vector3i] = [lane.anchor as Vector3i]
		walk.append_array(lane.cells as Array[Vector3i])
		walks.append(walk)
	walks.append(plan.passage_cells())
	for walk: Array in walks:
		for cell_value: Variant in walk:
			var cell := cell_value as Vector3i
			if not seen.has(cell):
				seen[cell] = true
				out.append(cell)
	return out


static func _street_bands(plan: WarrenMazeSourcePlan) -> Dictionary:
	## Vector2i column -> sorted Array[int] of the bands a passage walks there.
	var out: Dictionary = {}
	for cell: Vector3i in plan.passage_cells():
		var column := Vector2i(cell.x, cell.z)
		var bands: Array = out.get(column, [])
		if not bands.has(cell.y):
			bands.append(cell.y)
			bands.sort()
		out[column] = bands
	return out


static func _owned_columns(plan: WarrenMazeSourcePlan) -> Dictionary:
	var out: Dictionary = {}
	for plot: Dictionary in plan.plots:
		for cell_value: Variant in plot["cells"] as Array:
			out[cell_value as Vector2i] = true
	return out


static func _blocked_columns(plan: WarrenMazeSourcePlan) -> Dictionary:
	## Columns nothing new may claim: whatever already carries a plot, plus the
	## retained bridge spans. The carver kept that overhead mass precisely so a
	## bridge could stand on it, so no earlier phase may build the column out
	## from under it.
	var out := _owned_columns(plan)
	for span_value: Variant in plan.excavation.bridge_spans:
		for cell_value: Variant in span_value as Array:
			var cell := cell_value as Vector3i
			out[Vector2i(cell.x, cell.z)] = true
	return out


static func _roll(plan: WarrenMazeSourcePlan, salt: int, cell: Vector3i,
		extra: int, range_value: Vector2i) -> int:
	## One seeded integer in the inclusive range, from the lattice's own hash.
	return range_value.x + posmod(WarrenPassageLatticeRules.hash_key(
		plan.world_seed, salt, cell, extra),
		maxi(1, range_value.y - range_value.x + 1))


static func _column_less(a: Vector2i, b: Vector2i) -> bool:
	return a.x < b.x if a.y == b.y else a.y < b.y
