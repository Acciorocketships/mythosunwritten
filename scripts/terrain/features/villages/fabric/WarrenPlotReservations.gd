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
## so the planner never loads the catalog at runtime.
##
## TASK C5b RULING 3 -- the row is now what REALISATION needs, not what the
## clearance AABB happened to measure. C2 measured all three asset plots in the
## corpus refused by `WarrenVolumetricSolver._maze_asset_landmark`, and the
## reason was the derivation: a footprint rounded up from
## `local_clearance_bounds` guarantees the prefab fits SOMEWHERE inside the
## plot and says nothing about where it lands when it is anchored by its own
## DOORWAY, which is what the landmark contract does. So every extent below is
## measured from the entrance cell, in FINE cells, in the entrance's own frame:
##
##   forward = into the mass, from the doorway cell (which is offset 0)
##   left / right = across it, from the doorway lane
##
##   reach_*   = the union of the recipe's body (solid + headroom + walk) and
##               its measured visual clearance -- everything that must land on
##               mass this plot owns, or `_maze_landmark_refusal` reports a
##               body that does not fit or a clearance that overlaps a
##               neighbouring plot
##   bearing_* = the recipe's `terrain_bearing_cells`, which must meet natural
##               ground (`WarrenMassif.bearing_at`) at the plot's own datum
##
##   width  = ceili((reach_left + reach_right + 1) / 2) + 1   # 2 fine = 1 macro
##   depth  = ceili((reach_forward + 1) / 2)
##   height_bands = the body's own rise above the entrance band, plus that band
##
## The extra macro column of WIDTH is the doorway's freedom: the plot cannot
## choose which fine lane of its fronting street cell the prefab opens onto, so
## the footprint has to hold the body for more than one of them or `_best_asset
## _site` would only ever accept a door that landed on exactly the right lane.
##
## One entry per UNIQUE derived row, named by the first recipe in
## `program.recipes()` order to produce it; rounding is up in all three axes,
## because a template that does not enclose its own prefab is not a site.
## test_asset_templates_match_the_catalog recompiles the program and demands
## this table equal that derivation, so it can never drift.
const ASSET_TEMPLATES: Array[Dictionary] = [
	{"kind_id": &"anchor.prefab.00", "width": 5, "depth": 6,
		"height_bands": 8, "reach_forward": 11,
		"reach_left": 4, "reach_right": 3,
		"bearing_forward": 9, "bearing_left": 4,
		"bearing_right": 3},
	{"kind_id": &"anchor.prefab.01", "width": 7, "depth": 6,
		"height_bands": 7, "reach_forward": 11,
		"reach_left": 6, "reach_right": 5,
		"bearing_forward": 9, "bearing_left": 4,
		"bearing_right": 4},
	{"kind_id": &"anchor.prefab.02", "width": 6, "depth": 6,
		"height_bands": 13, "reach_forward": 11,
		"reach_left": 5, "reach_right": 4,
		"bearing_forward": 10, "bearing_left": 5,
		"bearing_right": 4},
	{"kind_id": &"anchor.prefab.03", "width": 17, "depth": 12,
		"height_bands": 23, "reach_forward": 23,
		"reach_left": 16, "reach_right": 15,
		"bearing_forward": 22, "bearing_left": 13,
		"bearing_right": 12},
	{"kind_id": &"anchor.prefab.04", "width": 7, "depth": 5,
		"height_bands": 12, "reach_forward": 9,
		"reach_left": 6, "reach_right": 5,
		"bearing_forward": 7, "bearing_left": 3,
		"bearing_right": 2},
	{"kind_id": &"anchor.prefab.06", "width": 9, "depth": 7,
		"height_bands": 11, "reach_forward": 13,
		"reach_left": 8, "reach_right": 7,
		"bearing_forward": 11, "bearing_left": 5,
		"bearing_right": 5},
	{"kind_id": &"anchor.prefab.10", "width": 3, "depth": 3,
		"height_bands": 4, "reach_forward": 5,
		"reach_left": 2, "reach_right": 1,
		"bearing_forward": 5, "bearing_left": 2,
		"bearing_right": 1},
	{"kind_id": &"anchor.prefab.11", "width": 4, "depth": 3,
		"height_bands": 4, "reach_forward": 5,
		"reach_left": 3, "reach_right": 2,
		"bearing_forward": 5, "bearing_left": 2,
		"bearing_right": 2},
	{"kind_id": &"anchor.prefab.12", "width": 5, "depth": 3,
		"height_bands": 4, "reach_forward": 5,
		"reach_left": 4, "reach_right": 3,
		"bearing_forward": 5, "bearing_left": 3,
		"bearing_right": 3},
	{"kind_id": &"anchor.prefab.14", "width": 5, "depth": 3,
		"height_bands": 6, "reach_forward": 5,
		"reach_left": 4, "reach_right": 3,
		"bearing_forward": 5, "bearing_left": 3,
		"bearing_right": 3},
	{"kind_id": &"anchor.prefab.17", "width": 9, "depth": 6,
		"height_bands": 8, "reach_forward": 11,
		"reach_left": 8, "reach_right": 7,
		"bearing_forward": 9, "bearing_left": 5,
		"bearing_right": 3},
	{"kind_id": &"anchor.prefab.19", "width": 7, "depth": 6,
		"height_bands": 10, "reach_forward": 11,
		"reach_left": 6, "reach_right": 5,
		"bearing_forward": 8, "bearing_left": 4,
		"bearing_right": 3},
	{"kind_id": &"anchor.prefab.21", "width": 6, "depth": 5,
		"height_bands": 7, "reach_forward": 9,
		"reach_left": 5, "reach_right": 4,
		"bearing_forward": 9, "bearing_left": 5,
		"bearing_right": 3},
	{"kind_id": &"anchor.prefab.22", "width": 6, "depth": 5,
		"height_bands": 13, "reach_forward": 9,
		"reach_left": 5, "reach_right": 4,
		"bearing_forward": 9, "bearing_left": 5,
		"bearing_right": 3},
	{"kind_id": &"anchor.prefab.23", "width": 8, "depth": 8,
		"height_bands": 11, "reach_forward": 15,
		"reach_left": 7, "reach_right": 6,
		"bearing_forward": 13, "bearing_left": 6,
		"bearing_right": 5},
	{"kind_id": &"anchor.prefab.24", "width": 8, "depth": 8,
		"height_bands": 11, "reach_forward": 15,
		"reach_left": 7, "reach_right": 6,
		"bearing_forward": 13, "bearing_left": 6,
		"bearing_right": 4},
	{"kind_id": &"anchor.prefab.25", "width": 17, "depth": 13,
		"height_bands": 28, "reach_forward": 25,
		"reach_left": 16, "reach_right": 15,
		"bearing_forward": 23, "bearing_left": 13,
		"bearing_right": 12},
	{"kind_id": &"anchor.prefab.31", "width": 4, "depth": 5,
		"height_bands": 9, "reach_forward": 9,
		"reach_left": 3, "reach_right": 2,
		"bearing_forward": 8, "bearing_left": 3,
		"bearing_right": 1},
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
## Fine cells of margin the realisation mirror keeps around a prefab's whole
## measured reach, mirroring the one-cell eave halo
## `WarrenVolumetricSolver._maze_landmark_refusal` applies at the roof band.
## See `_site_realises` for why asking it of the whole box is deliberately
## conservative rather than exact.
const EAVE_HALO_CELLS := 1

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
	_grow_decks(plan, streets, blocked, outcomes)


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
		var mirror := _new_mirror_tally()
		var record := {"kind_id": &"", "site": null, "realisable": false,
			"mirror": mirror,
			"reason": "no street-fronting supportable site remains"}
		while true:
			var site := _best_asset_site(plan, streets, columns, blocked,
				refused, mirror)
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
					"realisable": bool(site.get("realisable", false)),
					"mirror": mirror, "reason": ""}
				break
			refused[_site_key(site)] = true
			record["reason"] = plan.last_rejection
		records.append(record)
	outcomes["assets"] = records


static func _new_mirror_tally() -> Dictionary:
	## Why the realisation mirror refused what it refused, over every site the
	## quota slot enumerated. When no site is realisable the fallback is taken
	## and `best` never advances, so in exactly the case worth explaining every
	## site was tested and these totals are complete.
	return {"tested": 0, "no_frontage": 0, "street_over_top": 0,
		"body_outside_plot": 0, "bearing_off_ground": 0, "realisable": 0}


static func _best_asset_site(plan: WarrenMazeSourcePlan, streets: Dictionary,
		columns: Array[Vector2i], blocked: Dictionary,
		refused: Dictionary, mirror: Dictionary = {}) -> Dictionary:
	## Minimum terrain-modification cost -- the sum over the footprint of
	## |massif.top_at(c) - datum| -- over every legal site, with the door the
	## winner faces. Ties break by (datum, anchor.x, anchor.z, orientation,
	## template); the last key is there because two templates of different sizes
	## can both cost zero on flat ground, and a total order is the whole point.
	## Two winners are tracked, not one: `best` is the cheapest site the prefab
	## really lands on, `fallback` the cheapest site full stop. A town with no
	## realisable site keeps exactly the plot it placed before this rule
	## existed -- its mass stays plot mass and `_maze_asset_landmark`'s refusal
	## stays the audited shortfall C2 designed -- so the rule can only ever add
	## a landmark, never take a town's asset away.
	var best: Dictionary = {}
	var fallback: Dictionary = {}
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
					if fallback.is_empty() or _site_less(site, fallback):
						fallback = site
					# The realisation mirror is the expensive test, so it runs
					# only on a site that would otherwise become the winner.
					if (best.is_empty() or _site_less(site, best)) \
							and _site_realises(plan, streets, template, cells,
								doors[datum], datum, mirror):
						site["realisable"] = true
						best = site
	return best if not best.is_empty() else fallback


static func _site_realises(plan: WarrenMazeSourcePlan, streets: Dictionary,
		template: Dictionary, cells: Array[Vector2i], door: Vector3i,
		datum: int, mirror: Dictionary = {}) -> bool:
	## TASK C5b RULING 3 -- the planner's mirror of
	## `WarrenVolumetricSolver._maze_asset_landmark`. A site is only a site if
	## the prefab really lands on it, and the landmark builder anchors the
	## prefab by its DOORWAY, not by the plot's centre: it takes the frontage
	## the plot addressed its street across, tries each fine lane of that 3 m
	## street cell whose inward neighbour is plot mass, and refuses the lane
	## whose body leaves the residual mass, whose bearing rests on nothing, or
	## whose measured clearance -- plus the one-cell eave halo at its own roof
	## band -- meets a neighbouring plot.
	##
	## This restates those two facts in macro columns, one per step below.
	## `reach_*` is the union of body and clearance, so "inside this plot's own
	## footprint" answers the body and the clearance together -- the footprint
	## is column-exclusive, so mass this plot owns is mass no other plot can
	## own -- and the eave halo is asked as one further fine cell of margin on
	## the same box. That margin is deliberately CONSERVATIVE: the builder
	## halos only the roof band and lets an eave overhang rock or a street,
	## while this asks the whole box to keep its margin inside the plot. The
	## mirror may refuse a site the builder would have taken; it may never
	## accept one the builder refuses, and that direction is the whole property.
	##
	## TASK C5c FIX 1, IMPORTANT 4 -- the two clauses that moved:
	##
	## - A STREET OVER THE TOP is no longer a refusal. C5b refused it because
	##   the prefab claimed a ROOF face on the boundary the route already owned
	##   and `_reserve_landmark_preplans` killed the town at the joint commit.
	##   Ruling 5 fixed that at the commit -- a maze landmark now skips a ROOF
	##   face the public realm owns -- so the mirror must stop refusing what
	##   the builder accepts. `street_over_top` stays in the tally vocabulary
	##   and reads zero.
	## - BEARING follows the builder's own relaxed rule (see
	##   `WarrenVolumetricSolver._landmark_bearing_follows_terrain`): natural
	##   ground AT the datum, or a datum ABOVE it whose band below is solid the
	##   source retains as stone. C2 kept it strict because nothing rendered
	##   that rock; Task C5b renders it. Asked of an UNSEALED plan, where a
	##   column carrying no plot yet answers its massif envelope rather than
	##   its eventual plot floor -- which can only make this stricter than the
	##   sealed builder, never looser, because `_footprint` already refuses any
	##   column another plot has taken.
	var columns := _footprint_columns(cells)
	var frontage := _frontage_direction(columns, Vector2i(door.x, door.z))
	if frontage == Vector2i.ZERO:
		return _tally(mirror, "no_frontage")
	# From the doorway into the mass, and the lateral axis the prefab's own
	# +X maps onto once its entrance faces the street. One lane is enough,
	# because the builder returns on the first lane that fits.
	var side := -frontage
	var lateral := Vector2i(-side.y, side.x)
	var body_fits := false
	for x_offset in 2:
		for z_offset in 2:
			var doorway := Vector2i(door.x * 2 + x_offset,
				door.z * 2 + z_offset) + side
			if not columns.has(_macro_column(doorway)):
				continue
			if not _fine_box_inside(columns, doorway, side, lateral,
					int(template["reach_forward"]) + EAVE_HALO_CELLS,
					int(template["reach_left"]) + EAVE_HALO_CELLS,
					int(template["reach_right"]) + EAVE_HALO_CELLS):
				continue
			body_fits = true
			if _fine_box_bears(plan, doorway, side, lateral,
					int(template["bearing_forward"]),
					int(template["bearing_left"]),
					int(template["bearing_right"]), datum):
				if not mirror.is_empty():
					mirror["tested"] = int(mirror.get("tested", 0)) + 1
					mirror["realisable"] = int(mirror.get("realisable", 0)) + 1
				return true
	return _tally(mirror,
		"bearing_off_ground" if body_fits else "body_outside_plot")


static func _footprint_columns(cells: Array[Vector2i]) -> Dictionary:
	## The site's own macro columns as a set. Column-exclusive by construction,
	## so "inside this set" is also "owned by no other plot".
	var out: Dictionary = {}
	for column: Vector2i in cells:
		out[column] = true
	return out


static func _frontage_direction(columns: Dictionary,
		door_column: Vector2i) -> Vector2i:
	## The side of the street cell this plot addresses: the first direction
	## whose opposite neighbour is the plot's own mass.
	for direction: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT,
			Vector2i.UP]:
		if columns.has(door_column - direction):
			return direction
	return Vector2i.ZERO


static func _tally(mirror: Dictionary, reason: String) -> bool:
	if mirror.is_empty():
		return false
	mirror["tested"] = int(mirror.get("tested", 0)) + 1
	mirror[reason] = int(mirror.get(reason, 0)) + 1
	return false


static func _macro_column(fine: Vector2i) -> Vector2i:
	return Vector2i(floori(float(fine.x) / 2.0), floori(float(fine.y) / 2.0))


static func _fine_box_inside(columns: Dictionary, doorway: Vector2i,
		side: Vector2i, lateral: Vector2i, forward: int, left: int,
		right: int) -> bool:
	for step in range(0, forward + 1):
		for across in range(-right, left + 1):
			if not columns.has(_macro_column(doorway + side * step \
					+ lateral * across)):
				return false
	return true


static func _fine_box_bears(plan: WarrenMazeSourcePlan, doorway: Vector2i,
		side: Vector2i, lateral: Vector2i, forward: int, left: int, right: int,
		datum: int) -> bool:
	## The builder's `_landmark_bearing_follows_terrain`, restated in macro
	## columns. Natural ground AT the datum is the original rule; a datum ABOVE
	## natural ground is accepted when the band below it is solid the source
	## calls its own, because that solid is the derived rock Task C5 retains
	## and Task C5b draws. Below natural ground is never accepted -- there the
	## heightfield owns the ground and the prefab would be buried.
	for step in range(0, forward + 1):
		for across in range(-right, left + 1):
			var column := _macro_column(doorway + side * step \
				+ lateral * across)
			if not plan.massif.has_column(column):
				return false
			var ground := plan.massif.bearing_at(column)
			if ground == datum:
				continue
			if datum < ground or not plan.solid_at(Vector3i(column.x,
					datum - 1, column.y)):
				return false
	return true


static func _no_street_left_hanging(streets: Dictionary, column: Vector2i,
		datum: int, top: int) -> bool:
	## An asset's height is fixed by its template, so unlike a house it cannot
	## rise to meet a street above it. A passage on one of its columns is legal
	## only below the datum -- the asset bears on that street's own retained
	## roof -- or exactly at its top, where the street runs across it. Anything
	## between or above would lose the rock under that street's floor, because
	## above the lowest plot floor on a column solid mass is plots and nothing
	## else.
	##
	## `_deck_column_ok` shares it with `top == datum` (a deck is flat), so
	## both P3 paths state the rule once. A house does not need it: it rises
	## to meet the street instead, which is what WarrenPlotPlanner's own
	## `_street_above` is for.
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


static func _grow_decks(plan: WarrenMazeSourcePlan, streets: Dictionary,
		blocked: Dictionary, outcomes: Dictionary) -> void:
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
		var region := _deck_region(plan, street, streets, blocked, cap)
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
		streets: Dictionary, blocked: Dictionary,
		cap: int) -> Array[Vector2i]:
	## Try each of the street's four neighbours as a root, cheapest first, and
	## keep the first region that reaches DECK_MIN. One root at a time is what
	## makes a deck connected: two opposite neighbours of the same street cell
	## are not adjacent to each other, so a frontier seeded with both can grow
	## two islands the source plan would rightly refuse as one footprint.
	var roots: Array[Vector2i] = []
	var origin := Vector2i(street.x, street.z)
	for direction: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
		var root := origin + direction
		if _deck_column_ok(plan, root, street.y, streets, blocked):
			roots.append(root)
	roots.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return WarrenPlotPlanner.closer(plan, a, b, street.y))
	for root: Vector2i in roots:
		var region := _deck_from(plan, root, street.y, streets, blocked, cap)
		if region.size() >= DECK_MIN:
			return region
	return [] as Array[Vector2i]


static func _deck_from(plan: WarrenMazeSourcePlan, root: Vector2i, datum: int,
		streets: Dictionary, blocked: Dictionary,
		cap: int) -> Array[Vector2i]:
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
						or not _deck_column_ok(plan, next, datum, streets,
							blocked):
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
		datum: int, streets: Dictionary, blocked: Dictionary) -> bool:
	## A deck column: unclaimed, on the massif, standing within a band of the
	## street's own datum, accepted by the support rule there, and leaving no
	## street on it hanging.
	##
	## The last guard is the asset path's (review finding 2026-08-23, minor
	## 10). A deck is flat -- top == floor == datum -- so the only passage it
	## can carry above its own floor is one AT the datum, which runs across
	## it; anything higher would lose the rock under that street's floor,
	## because above the lowest plot floor on a column solid mass is plots and
	## nothing else. Today the flatness test makes such a street impossible
	## (a passage at datum + 4 or above needs an envelope the |top_at - datum|
	## <= 1 test already refused), so this is belt to that brace: the rule the
	## deck actually depends on is written down where it is depended on,
	## rather than resting on another rule's incidental range.
	return not blocked.has(column) and plan.massif.has_column(column) \
		and absi(plan.massif.top_at(column) - datum) <= 1 \
		and plan.plot_support_ok(column, datum) \
		and _no_street_left_hanging(streets, column, datum, datum)
