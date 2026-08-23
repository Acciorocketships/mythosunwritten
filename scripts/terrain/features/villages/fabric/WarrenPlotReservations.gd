class_name WarrenPlotReservations
extends RefCounted

## P3 of the 2026-08-21 plot-model design: catalog assets at their minimum
## terrain-modification site, then flat decks grown off the streets.
## WarrenPlotPlanner.reserve delegates here; the shared column, street, and
## roll helpers stay there and this file calls back into them.
##
## Nothing here rejects a town. A quota with no site left and an add_plot the
## source plan refuses are both outcomes in `audit["plot_outcomes"]`.

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
	{"kind_id": &"anchor.prefab.00", "width": 4, "depth": 6,
		"height_bands": 8},
	{"kind_id": &"anchor.prefab.01", "width": 5, "depth": 6,
		"height_bands": 7},
	{"kind_id": &"anchor.prefab.02", "width": 5, "depth": 6,
		"height_bands": 13},
	{"kind_id": &"anchor.prefab.03", "width": 16, "depth": 12,
		"height_bands": 23},
	{"kind_id": &"anchor.prefab.04", "width": 5, "depth": 5,
		"height_bands": 12},
	{"kind_id": &"anchor.prefab.06", "width": 7, "depth": 7,
		"height_bands": 11},
	{"kind_id": &"anchor.prefab.10", "width": 3, "depth": 3,
		"height_bands": 4},
	{"kind_id": &"anchor.prefab.12", "width": 4, "depth": 3,
		"height_bands": 4},
	{"kind_id": &"anchor.prefab.14", "width": 4, "depth": 3,
		"height_bands": 6},
	{"kind_id": &"anchor.prefab.17", "width": 6, "depth": 5,
		"height_bands": 8},
	{"kind_id": &"anchor.prefab.19", "width": 5, "depth": 6,
		"height_bands": 10},
	{"kind_id": &"anchor.prefab.21", "width": 5, "depth": 5,
		"height_bands": 7},
	{"kind_id": &"anchor.prefab.22", "width": 5, "depth": 5,
		"height_bands": 13},
	{"kind_id": &"anchor.prefab.23", "width": 7, "depth": 8,
		"height_bands": 11},
	{"kind_id": &"anchor.prefab.25", "width": 16, "depth": 14,
		"height_bands": 28},
	{"kind_id": &"anchor.prefab.31", "width": 3, "depth": 4,
		"height_bands": 9},
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
## One salt per seeded roll, so two rolls on the same cell cannot agree by
## accident. Both go through WarrenPassageLatticeRules.hash_key.
const ASSET_QUOTA_SALT := 0x51071
const DECK_QUOTA_SALT := 0x4dec5


## P3: assets first, then decks on what is left. Both write their outcomes into
## `plan.audit["plot_outcomes"]`.
static func reserve(plan: WarrenMazeSourcePlan,
		profile: WarrenVillageScaleProfile) -> void:
	var outcomes := WarrenPlotPlanner.outcomes(plan)
	var streets := WarrenPlotPlanner.street_bands(plan)
	var blocked := WarrenPlotPlanner.blocked_columns(plan)
	_place_assets(plan, profile, streets, blocked, outcomes)
	_grow_decks(plan, blocked, outcomes)


static func _place_assets(plan: WarrenMazeSourcePlan,
		profile: WarrenVillageScaleProfile, streets: Dictionary,
		blocked: Dictionary, outcomes: Dictionary) -> void:
	## One pass per quota slot: enumerate every (template, orientation, anchor,
	## datum) site the massif, the support rule, and the streets already carved
	## through the template's own height allow; take the cheapest; commit it. A
	## site the source plan still refuses is set aside and the next-cheapest
	## tried, so a refusal never silently costs the town a landmark.
	var records: Array[Dictionary] = []
	var quota := WarrenPlotPlanner.roll(plan, ASSET_QUOTA_SALT,
		plan.summit_cell, 0, profile.landmark_range)
	var columns: Array[Vector2i] = []
	columns.assign(plan.massif.columns.keys())
	columns.sort_custom(Callable(WarrenPlotPlanner, "column_less"))
	for index in quota:
		var id := StringName("asset.%02d" % index)
		var refused: Dictionary = {}
		var record := {"kind_id": &"", "site": null,
			"reason": "no street-fronting supportable site remains"}
		while true:
			var site := _best_asset_site(plan, streets, columns, blocked,
				refused)
			if site.is_empty():
				break
			var template := ASSET_TEMPLATES[int(site["template"])] as Dictionary
			var datum := int(site["datum"])
			if plan.add_plot({"id": id,
					"kind": WarrenMazeSourcePlan.PLOT_ASSET,
					"cells": site["cells"], "floor": datum,
					"top": datum + int(template["height_bands"]),
					"door_walk": site["door"], "building_id": id}):
				for cell_value: Variant in site["cells"] as Array:
					blocked[cell_value as Vector2i] = true
				record = {"kind_id": StringName(template["kind_id"]),
					"site": {"id": id, "anchor": site["anchor"],
						"datum": datum, "cost": int(site["cost"]),
						"orientation": int(site["orientation"])},
					"reason": ""}
				break
			refused[_site_key(site)] = true
			record["reason"] = plan.last_rejection
		records.append(record)
	outcomes["assets"] = records


static func _best_asset_site(plan: WarrenMazeSourcePlan, streets: Dictionary,
		columns: Array[Vector2i], blocked: Dictionary,
		refused: Dictionary) -> Dictionary:
	## Minimum terrain-modification cost -- the sum over the footprint of
	## |massif.top_at(c) - datum| -- over every legal site, with the door the
	## winner faces. Ties break by (datum, anchor.x, anchor.z, orientation,
	## template); the last key is there because two templates of different sizes
	## can both cost zero on flat ground, and a total order is the whole point.
	var best: Dictionary = {}
	for template_index in ASSET_TEMPLATES.size():
		var template := ASSET_TEMPLATES[template_index] as Dictionary
		var height := int(template["height_bands"])
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
						# The support rule reserves MIN_HOUSE_BANDS of
						# clearance; a template taller than that has to clear
						# its own height, or add_plot would refuse the winner.
						if not plan.plot_support_ok(member, datum) \
								or plan.first_carved_band(member, datum,
									datum + height) >= 0 \
								or not _no_street_left_hanging(streets, member,
									datum, datum + height):
							cost = -1
							break
						cost += absi(plan.massif.top_at(member) - datum)
					if cost < 0:
						continue
					var site := {"template": template_index,
						"orientation": orientation, "anchor": anchor,
						"datum": datum, "cost": cost, "cells": cells,
						"door": doors[datum]}
					if refused.has(_site_key(site)):
						continue
					if best.is_empty() or _site_less(site, best):
						best = site
	return best


static func _no_street_left_hanging(streets: Dictionary, column: Vector2i,
		datum: int, top: int) -> bool:
	## An asset's height is fixed by its template, so unlike a house it cannot
	## rise to meet a street above it. A passage on one of its columns is legal
	## only below the datum -- the asset bears on that street's own retained
	## roof -- or exactly at its top, where the street runs across it. Anything
	## between or above would lose the rock under that street's floor, because
	## above the lowest plot floor on a column solid mass is plots and nothing
	## else.
	for band: int in streets.get(column, []) as Array:
		if band >= datum and band != top:
			return false
	return true


static func _site_key(site: Dictionary) -> String:
	var anchor := site["anchor"] as Vector2i
	return "%d/%d/%d,%d/%d" % [int(site["template"]), int(site["orientation"]),
		anchor.x, anchor.y, int(site["datum"])]


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


static func _grow_decks(plan: WarrenMazeSourcePlan, blocked: Dictionary,
		outcomes: Dictionary) -> void:
	## Walk the streets in order and grow the flattest connected region beside
	## each one, keeping them until the scale's quota is met. The seeded
	## variation is the quota roll: a candidate is never skipped on a coin flip,
	## or the same town would grow its decks elsewhere the moment its walk order
	## shifted. A region the source plan refuses is recorded with its reason and
	## does not count against the quota.
	var records: Array[Dictionary] = []
	var scale := plan.scale_profile.scale_id
	var quota := WarrenPlotPlanner.roll(plan, DECK_QUOTA_SALT,
		plan.summit_cell, 0, DECK_QUOTA.get(scale, Vector2i(1, 1)))
	var cap := int(DECK_MAX.get(scale, DECK_MIN))
	var accepted := 0
	for street: Vector3i in WarrenPlotPlanner.walk_order(plan):
		if accepted >= quota:
			break
		var region := _deck_region(plan, street, blocked, cap)
		if region.size() < DECK_MIN:
			continue
		var id := StringName("deck.%02d" % records.size())
		var record := {"id": id, "size": region.size(), "datum": street.y,
			"reason": ""}
		if plan.add_plot({"id": id, "kind": WarrenMazeSourcePlan.PLOT_DECK,
				"cells": region, "floor": street.y, "top": street.y,
				"door_walk": street, "building_id": id}):
			for column: Vector2i in region:
				blocked[column] = true
			accepted += 1
		else:
			record["reason"] = plan.last_rejection
		records.append(record)
	outcomes["decks"] = records
	outcomes["decks_short"] = quota - accepted


static func _deck_region(plan: WarrenMazeSourcePlan, street: Vector3i,
		blocked: Dictionary, cap: int) -> Array[Vector2i]:
	## Try each of the street's four neighbours as a root, cheapest first, and
	## keep the first region that reaches DECK_MIN. One root at a time is what
	## makes a deck connected: two opposite neighbours of the same street cell
	## are not adjacent to each other, so a frontier seeded with both can grow
	## two islands the source plan would rightly refuse as one footprint.
	var roots: Array[Vector2i] = []
	var origin := Vector2i(street.x, street.z)
	for direction: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
		var root := origin + direction
		if _deck_column_ok(plan, root, street.y, blocked):
			roots.append(root)
	roots.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return WarrenPlotPlanner.closer(plan, a, b, street.y))
	for root: Vector2i in roots:
		var region := _deck_from(plan, root, street.y, blocked, cap)
		if region.size() >= DECK_MIN:
			return region
	return [] as Array[Vector2i]


static func _deck_from(plan: WarrenMazeSourcePlan, root: Vector2i, datum: int,
		blocked: Dictionary, cap: int) -> Array[Vector2i]:
	## Cheapest-first growth from one root. Every frontier column is a
	## 4-neighbour of a column already in the region, so the result is one
	## connected floor by construction.
	var region: Array[Vector2i] = [root]
	var frontier: Array[Vector2i] = []
	var expand: Array[Vector2i] = [root]
	var seen: Dictionary = {root: true}
	while region.size() < cap:
		while not expand.is_empty():
			var from := expand.pop_back() as Vector2i
			for direction: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
				var next := from + direction
				if seen.has(next) \
						or not _deck_column_ok(plan, next, datum, blocked):
					continue
				seen[next] = true
				frontier.append(next)
		if frontier.is_empty():
			break
		var choice := 0
		for index in range(1, frontier.size()):
			if WarrenPlotPlanner.closer(plan, frontier[index],
					frontier[choice], datum):
				choice = index
		region.append(frontier[choice])
		expand.append(frontier[choice])
		frontier.remove_at(choice)
	return region


static func _deck_column_ok(plan: WarrenMazeSourcePlan, column: Vector2i,
		datum: int, blocked: Dictionary) -> bool:
	## A deck column: unclaimed, on the massif, standing within a band of the
	## street's own datum, and accepted by the support rule there.
	return not blocked.has(column) and plan.massif.has_column(column) \
		and absi(plan.massif.top_at(column) - datum) <= 1 \
		and plan.plot_support_ok(column, datum)
