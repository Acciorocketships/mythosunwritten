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
## A later modular house is not confined to its macro column: its authored roof
## can project from the far side of the fronting street back into the prefab's
## street-facing eave halo. The landmark builder sees only already-claimed grid
## cells, so reserving the prefab's own envelope alone is one phase too late to
## prevent that future visual overlap. One macro column is two fine cells; add
## that exact reach behind the entrance while selecting the site. The inward
## and lateral sides already carry the prefab reach plus its own eave halo and
## need no blanket extra ring (which would erase viable edge sites).
const FUTURE_HOUSE_CLEARANCE_CELLS := 2

const ASSET_QUOTA_SALT := 0x51071
const DECK_QUOTA_SALT := 0x4dec5

## TASK I4 ROUND 3 -- THE PLAZA DECK, and the whole of it is a SITING POLICY.
##
## The village green reads as a CORRIDOR and task I4 round 2 photographed why:
## a square needs (1) two plan extents within some ratio of each other, (2)
## enclosure on three or four sides, (3) a street arriving at it head-on -- and
## all three are questions about the PLOT MODEL, which is here. `_grow_decks`
## below grows the flattest connected region off each street cheapest-first
## with no shape rule at all, and measured on the four planner towns that walk
## produces 4x1, 6x1, 1x3 and 3x4 columns: a lane, not a room. So the town's
## one deliberate open place is grown by SHAPE instead, before the ordinary
## quota walks, and the ordinary decks take what is left.
##
## THE SITE IS A RECTANGLE, which is the cheapest honest way to say "aspect
## bounded": at least PLAZA_MIN_SIDE columns on the short side and no longer
## than PLAZA_MAX_ASPECT times it on the long one. Its area is bounded by the
## scale's own DECK_MAX -- a plaza is a deck and the reason that bound exists
## ("past this it reads as missing town") is the same reason here -- so a
## compact town's square is 2 x 2 macro columns (6 x 6 m) and a grand one's is
## 3 x 4 (9 x 12 m).
##
## STREET-ADJACENT is a REQUIREMENT and NEAR THE HEART is a preference: the
## datum is a fronting street's own band, exactly as an ordinary deck's is, so a
## square nobody can walk into is not a site at all; and among sites that
## qualify the order is CHEAPEST FIRST, then nearest `plan.summit_cell`'s column
## (the massif's own centre, which every other seeded roll in this file already
## keys off), then biggest, then squarest. Cost leads because it is what the
## corpus paid for -- see `_plaza_site_less`, which carries the seals.
##
## WHY THE SQUARE IS NOT ITSELF THE TURF, which is the part worth reading twice.
## A deck plot is PAVED public floor (`WarrenVolumetricSolver._pave_maze_decks`),
## so the plaza's own surface is stone. What it does for the green is give it a
## WAY IN: `SettlementFabricAssembler.maze_plaza_entries` calls a garden cell
## entered when a walked cell stands one band up and one cell across, and the
## village-green designation prefers an entered run over a bigger unentered one.
## Measured on 12/compact, the town's largest garden run was 36 cells in a 6 x 6
## box with ZERO streets into it -- a rooftop shoulder nobody could reach -- so
## the designation fell back to a 7-cell 2 x 4 ribbon. A 2 x 2 plaza beside that
## shoulder gives it four entrances, and the designation names the 6 x 6 square
## with a tree in the middle of it and paved thresholds at its mouths.
##
## The fallback is deliberate: a town with no rectangle that fits keeps exactly
## the plots it had before this rule existed, its ordinary decks grow off the
## same streets in the same order, and its green is designated by the same
## corridor rule. `outcomes["plaza"]` is written only when a site is CLAIMED,
## so a town without one is byte-identical to its pre-round record.


## The plaza's own plot id, and what tells the town's one shaped square from the
## quota's ordinary courtyards everywhere downstream. Deliberately NOT
## `deck.%02d`: an id in that family would renumber the ordinary decks and make
## "which deck is this" a question about placement order.
const PLAZA_PLOT_ID := &"plaza.00"
const PLAZA_MIN_SIDE := 2
const PLAZA_MAX_ASPECT := 2
## How deep the square may cut. The ordinary deck asks its columns to stand
## within ONE band of the street's datum, and on a stepped cone that is a
## CONTOUR -- one column wide, which is exactly the corridor round 2
## photographed. A square is a terrace cut into a slope, so the plaza is allowed
## to take the hill down to its own floor. The bound is a cut and never a fill:
## `plot_support_ok` needs solid at `datum - 1`, and on a column carrying no
## plot that solid stops at the massif's own top.
##
## FOUR IS MEASURED, not chosen. A compact massif's own tops stand at bands
## 2-12 while its streets run at 0-5, so "within one band of the street" is a
## contour and a contour is one column wide. Qualifying 2 x 2 sites per compact
## town, over the twelve-seed corpus, by how deep the cut is allowed to be:
##
## | bands | 1 | 2 | 3 | 4 | 6 | 8 |
## | towns with none | 11 | 9 | 4 | **0** | 0 | 0 |
## | sites, worst town | 0 | 0 | 0 | **1** | 2 | 6 |
##
## Four is the first bound every town in the corpus offers a site at, and
## stopping there keeps the excavation to two storeys of retained face around the
## square -- which is what dresses its enclosure -- rather than the four or six a
## looser bound would cut. (The budget below then spends fewer of those sites
## than this table offers; the two bounds are different questions.)
const PLAZA_LEVEL_BANDS := 4
## And how much hill the square may take ALTOGETHER, as bands per column.
## PLAZA_LEVEL_BANDS bounds the WORST column; this bounds the mean, so the site
## is a levelled terrace rather than a quarry with one shallow corner. Two is
## half the per-column bound: a 2 x 2 site standing on a single step -- two
## columns at the datum and two a step above it -- still qualifies, and a site
## cut out of a real slope does not.
##
## IT IS ALSO WHAT THE CORPUS PAID FOR, and the honest reason it exists. Without
## it the 48-town matrix sealed 41 (grand 7/12 against a 10/12 baseline): the
## deepest sites take four columns out of the middle of a hill and the elevated
## court, the interstitial joins and the route graph are what fall over. With it,
## 11/grand's 12-band site is refused, that town keeps the corridor fallback --
## and it already had a 35-cell green with ten entrances, so it lost nothing --
## and the scale comes back inside the round's stop condition.
const PLAZA_CUT_BUDGET_BANDS := 2
## How many refused sites the plaza will walk past before giving up. The source
## plan can still refuse a rectangle every column of `_deck_column_ok` accepted
## -- disjointness and the seal's own placement rules are its business, not
## this file's -- and one square a town is worth a few tries. Bounded because
## each retry is a full rescan.
const PLAZA_SITE_ATTEMPTS := 4


## P3: assets first, then the town's one plaza, then ordinary decks on what is
## left. All three write their outcomes into `plan.audit["plot_outcomes"]`.
static func reserve(plan: WarrenMazeSourcePlan,
		profile: WarrenVillageScaleProfile) -> void:
	var outcomes := WarrenPlotPlanner.outcomes(plan)
	var streets := WarrenPlotPlanner.street_bands(plan)
	var blocked := WarrenPlotPlanner.blocked_columns(plan)
	_place_assets(plan, profile, streets, blocked, outcomes)
	# The extra measured prefab reach is a height-bounded construction
	# reservation, not ownership of every band in a column. Rebuild the ordinary
	# source-plan set here; `_deck_column_ok` and P4 both consult the published
	# vertical reservation, so a plaza/house above the measured roof remains
	# legal while neither can excavate the retained support or visual envelope
	# below it. Treating this as a flat blocked-column set erased valid upper
	# courts; forgetting it entirely let a later deck remove rock under an
	# authored prefab footing.
	blocked = WarrenPlotPlanner.blocked_columns(plan)
	var plaza := _place_plaza(plan, streets, blocked, outcomes)
	_grow_decks(plan, streets, blocked, outcomes, plaza)


static func _place_assets(plan: WarrenMazeSourcePlan,
		profile: WarrenVillageScaleProfile, streets: Dictionary,
		blocked: Dictionary, outcomes: Dictionary) -> void:
	## One pass per quota slot: enumerate every (template, orientation, anchor,
	## datum) site the massif, the support rule, and the streets already carved
	## through the template's own height allow; take the cheapest; commit it. A
	## site the source plan still refuses is set aside and the next-cheapest
	## tried, so a refusal never silently costs the town a landmark.
	var records: Array[Dictionary] = []
	var clearance_reservations: Array[Dictionary] = []
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
				var clearance_columns: Array[Vector2i] = []
				clearance_columns.assign(site.get("reserved_columns", []) as Array)
				var support_columns: Array[Vector2i] = []
				support_columns.assign(site.get("support_columns", []) as Array)
				for column: Vector2i in clearance_columns:
					blocked[column] = true
				if not clearance_columns.is_empty() \
						or not support_columns.is_empty():
					clearance_reservations.append({"id": id,
						"columns": clearance_columns.duplicate(),
						"support_columns": support_columns.duplicate(),
						"floor": datum,
						"top": datum + int(template["height_bands"])})
				record = {"kind_id": StringName(template["kind_id"]),
					"site": {"id": id, "anchor": site["anchor"],
						"datum": datum, "cost": int(site["cost"]),
						"orientation": int(site["orientation"]),
						"clearance_column_count": clearance_columns.size()},
					"realisable": bool(site.get("realisable", false)),
					"mirror": mirror, "reason": ""}
				break
			refused[_site_key(site)] = true
			record["reason"] = plan.last_rejection
		records.append(record)
	outcomes["assets"] = records
	# P4 rebuilds its blocked-column set after this function returns. Publish
	# the exact extra columns here so the reservation survives that phase
	# boundary; they remain residual massif (rendered as stone), not a second
	# asset plot, and the prefab builder can claim their still-allocatable fine
	# cells before residual packing begins.
	outcomes["asset_clearance_reservations"] = clearance_reservations


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
					var realisation: Dictionary = {}
					if (best.is_empty() or _site_less(site, best)) \
							and _site_realises(plan, streets, template, cells,
								doors[datum], datum, mirror, blocked,
								realisation):
						site["realisable"] = true
						site["reserved_columns"] = realisation.get(
							"reserved_columns", [])
						site["support_columns"] = realisation.get(
							"support_columns", [])
						best = site
	return best if not best.is_empty() else fallback


static func _site_realises(plan: WarrenMazeSourcePlan, streets: Dictionary,
		template: Dictionary, cells: Array[Vector2i], door: Vector3i,
		datum: int, mirror: Dictionary = {}, blocked: Dictionary = {},
		realisation: Dictionary = {}) -> bool:
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
	## `reach_*` is the union of body and clearance, so one box answers the body
	## and the clearance together -- the footprint is column-exclusive, so mass
	## this plot owns is mass no other plot can own -- and the eave halo is
	## asked as one further fine cell of margin on the same box.
	##
	## TASK E3 RULING 4 -- the box must stay inside this plot's own footprint OR
	## just off the massif, where no plot can ever stand (`_fine_box_inside`,
	## which states the bound and the two builder refusals it does not model).
	## What remains CONSERVATIVE is the halo: the builder halos only the roof
	## band and lets an eave overhang rock or a street, while this asks the
	## whole box for its cell of margin. The mirror may refuse a site the
	## builder would have taken; it may never accept one the builder refuses,
	## and that direction is the whole property.
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
			var reservation := _fine_box_reservation(plan, columns, blocked,
				doorway, side, lateral,
				int(template["reach_forward"]) + EAVE_HALO_CELLS,
				int(template["reach_left"]) + EAVE_HALO_CELLS,
				int(template["reach_right"]) + EAVE_HALO_CELLS,
				EAVE_HALO_CELLS + FUTURE_HOUSE_CLEARANCE_CELLS)
			if not bool(reservation.get("fits", false)):
				continue
			body_fits = true
			var support_columns: Dictionary = {}
			if _fine_box_bears(plan, doorway, side, lateral,
					int(template["bearing_forward"]),
					int(template["bearing_left"]),
					int(template["bearing_right"]), datum, support_columns):
				if not mirror.is_empty():
					mirror["tested"] = int(mirror.get("tested", 0)) + 1
					mirror["realisable"] = int(mirror.get("realisable", 0)) + 1
				realisation["reserved_columns"] = reservation.get("columns", [])
				var ordered_supports: Array[Vector2i] = []
				ordered_supports.assign(support_columns.keys())
				ordered_supports.sort_custom(Callable(WarrenPlotPlanner,
					"column_less"))
				realisation["support_columns"] = ordered_supports
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


static func _fine_box_inside(plan: WarrenMazeSourcePlan, columns: Dictionary,
		doorway: Vector2i, side: Vector2i, lateral: Vector2i, forward: int,
		left: int, right: int) -> bool:
	return bool(_fine_box_reservation(plan, columns, {}, doorway, side,
		lateral, forward, left, right).get("fits", false))


static func _fine_box_reservation(plan: WarrenMazeSourcePlan,
		columns: Dictionary, blocked: Dictionary, doorway: Vector2i,
		side: Vector2i, lateral: Vector2i, forward: int, left: int,
		right: int, backward: int = 0) -> Dictionary:
	## TASK E3 RULING 4. A column just OFF THE MASSIF is as good as one this
	## plot owns, and that is the whole of the alignment.
	##
	## The property this test exists for is the builder's: a prefab's measured
	## envelope, plus the eave halo at its roof band, may not meet a
	## NEIGHBOURING PLOT (`WarrenVolumetricSolver._maze_landmark_refusal`'s
	## blocker list). At source stage the houses do not exist yet, so "inside my
	## own footprint" was the only sound way to say "owned by nobody else" --
	## P4 gives essentially every remaining massif column to a house. But a
	## column the MASSIF does not have can never carry a plot at all: there is
	## no mass there for one to stand on and `_footprint` refuses it outright.
	## An eave that overhangs the edge of the hill therefore meets nothing, and
	## refusing it was pessimism with no property behind it.
	##
	## FIX 1, IMPORTANT 1 -- BUT ONLY AS FAR AS THE GRID REACHES. Plot ownership
	## is not the builder's only spatial refusal: `_skywalk_body_fits_grid`
	## demands `grid.contains(cell)` first, and the fine grid is the massif's
	## own fine bounding box grown by
	## `WarrenVolumetricSolver.GRID_PADDING_CELLS` (2) fine cells to each side.
	## An envelope reaching three fine cells past the edge leaves the grid, the
	## builder refuses it, and an unbounded exemption would have made the mirror
	## OPTIMISTIC -- which with `realisable == realised == 2` has no slack left
	## to absorb it. The exemption is therefore bounded to macro columns that
	## touch the massif (Chebyshev 1): an adjacent macro column's far fine edge
	## is exactly 2 fine cells past the massif's last fine cell on that axis,
	## and the padding applies to x and z independently, so touching-adjacency
	## is precisely the padded bound and never past it.
	##
	## WHAT THIS STILL DOES NOT MODEL, stated rather than assumed: the builder
	## also refuses on `protected_owners` -- the market, skywalk, courtyard and
	## gateway reservations committed before the landmark preplan, whose visual
	## clearances this source-stage predicate cannot see -- and on the grid's
	## VERTICAL extent, which no part of the mirror reads. Both are directions
	## in which the builder can still refuse a site the mirror accepted, so the
	## mirror's soundness is an empirical claim on this corpus rather than a
	## proof. That is exactly what `test_assets_land`'s per-town
	## `landmarks >= realisable` assertion is for, and why its accepted count is
	## pinned two-sidedly: the day either of those bites, the pin is red.
	##
	## TASK I6 closes the remaining gap without enlarging the plot itself. A
	## measured envelope may cross an unclaimed massif column; P4 used to place
	## an ordinary house there after this mirror ran, so a source-stage "yes"
	## became a builder-stage clearance collision. Such columns are now returned
	## as an exact reservation. They stay allocatable residual mass until the
	## landmark transaction claims them, but P4 cannot turn them into a house.
	## The one-cell backward reach is the roof halo on the street-facing side;
	## the previous one-way box omitted it even though the builder expands the
	## roof band in all four horizontal directions.
	var reserved: Dictionary = {}
	for step in range(-backward, forward + 1):
		for across in range(-right, left + 1):
			var column := _macro_column(doorway + side * step \
				+ lateral * across)
			if columns.has(column):
				continue
			if plan.massif.has_column(column):
				# A typed bridge/passages reservation is already unavailable to P4.
				# Do not mistake it for a future generic house; the exact volumetric
				# feature pass arbitrates the two authored envelopes later.
				if blocked.has(column):
					continue
				reserved[column] = true
			elif not _touches_the_massif(plan, column):
				return {"fits": false, "columns": [] as Array[Vector2i]}
	var ordered: Array[Vector2i] = []
	ordered.assign(reserved.keys())
	ordered.sort_custom(Callable(WarrenPlotPlanner, "column_less"))
	return {"fits": true, "columns": ordered}


static func _touches_the_massif(plan: WarrenMazeSourcePlan,
		column: Vector2i) -> bool:
	## Does this macro column share an edge or a corner with one the massif
	## has? See `_fine_box_inside`: that is exactly the fine grid's own padding.
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			if plan.massif.has_column(column + Vector2i(dx, dz)):
				return true
	return false


static func _fine_box_bears(plan: WarrenMazeSourcePlan, doorway: Vector2i,
		side: Vector2i, lateral: Vector2i, forward: int, left: int, right: int,
		datum: int, support_columns: Dictionary = {}) -> bool:
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
			support_columns[column] = true
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


static func _place_plaza(plan: WarrenMazeSourcePlan, streets: Dictionary,
		blocked: Dictionary, outcomes: Dictionary) -> int:
	## ONE aspect-bounded, street-fronted deck per town, claimed before the
	## ordinary quota walks. See the PLAZA_MIN_SIDE block above for the policy
	## and for why the no-site case has to leave no trace.
	##
	## Returns 1 when the square stands, and the ordinary quota is then one
	## shorter: THE PLAZA IS A DECK, not a deck plus a plaza. A scale's quota is
	## how many breathing spaces its town wants -- a compact town asks for one --
	## and spending the first of them on a shaped, central, street-fronted site
	## rather than on the first ribbon in walk order is the entire policy. Adding
	## the square ON TOP would give every town more open floor than its scale was
	## measured for, which is a different change and one the corpus would pay for
	## in seals.
	var refused: Dictionary = {}
	for attempt in PLAZA_SITE_ATTEMPTS:
		var site := _best_plaza_site(plan, streets, blocked, refused)
		if site.is_empty():
			return 0
		var id := PLAZA_PLOT_ID
		var datum := int(site["datum"])
		var cells := site["cells"] as Array[Vector2i]
		if plan.add_plot({"id": id, "kind": WarrenMazeSourcePlan.PLOT_DECK,
				"cells": cells, "floor": datum, "top": datum,
				"door_walk": site["door"], "building_id": id}):
			for column: Vector2i in cells:
				blocked[column] = true
			outcomes["plaza"] = {"id": id, "size": cells.size(),
				"datum": datum, "width": int(site["width"]),
				"depth": int(site["depth"]), "anchor": site["anchor"],
				"cost": int(site["cost"]), "reason": ""}
			return 1
		refused[_plaza_site_key(site)] = true
	# Every site the scan offered was refused by the source plan itself. The
	# town keeps the corridor fallback and says so.
	outcomes["plaza"] = {"id": &"", "size": 0, "datum": 0, "width": 0,
		"depth": 0, "anchor": Vector2i.ZERO, "cost": 0,
		"reason": plan.last_rejection}
	return 0


static func _best_plaza_site(plan: WarrenMazeSourcePlan, streets: Dictionary,
		blocked: Dictionary, refused: Dictionary) -> Dictionary:
	## The best rectangle of unclaimed deck columns, over every aspect-legal
	## shape the scale's own DECK_MAX admits and every band a street runs
	## beside it. `_deck_column_ok` is asked of each member, so a plaza column
	## is a deck column in exactly the sense the ordinary quota means -- the
	## shape rule is the only thing this adds.
	var cap := int(DECK_MAX.get(plan.scale_profile.scale_id, DECK_MIN))
	var heart := Vector2i(plan.summit_cell.x, plan.summit_cell.z)
	var columns: Array[Vector2i] = []
	columns.assign(plan.massif.columns.keys())
	columns.sort_custom(Callable(WarrenPlotPlanner, "column_less"))
	var best: Dictionary = {}
	for shape: Vector2i in _plaza_shapes(cap):
		for anchor: Vector2i in columns:
			var cells := _plaza_footprint(plan, anchor, shape, blocked)
			if cells.is_empty():
				continue
			var doors := _fronting_doors(cells, streets)
			var bands: Array = doors.keys()
			bands.sort()
			for datum: int in bands:
				var cost := 0
				var fits := true
				for member: Vector2i in cells:
					if not _deck_column_ok(plan, member, datum, streets,
							blocked, PLAZA_LEVEL_BANDS):
						fits = false
						break
					cost += absi(plan.massif.top_at(member) - datum)
				if not fits \
						or cost > cells.size() * PLAZA_CUT_BUDGET_BANDS:
					continue
				# Doubled column units, so an even side's centre is exact.
				var offset := Vector2i(anchor.x * 2 + shape.x - 1 - heart.x * 2,
					anchor.y * 2 + shape.y - 1 - heart.y * 2)
				var site := {"anchor": anchor, "width": shape.x,
					"depth": shape.y, "datum": datum, "cost": cost,
					"area": shape.x * shape.y,
					"long": maxi(shape.x, shape.y),
					"short": mini(shape.x, shape.y),
					"heart": offset.x * offset.x + offset.y * offset.y,
					"cells": cells, "door": doors[datum]}
				if refused.has(_plaza_site_key(site)):
					continue
				if best.is_empty() or _plaza_site_less(site, best):
					best = site
	return best


static func _plaza_shapes(cap: int) -> Array[Vector2i]:
	## Every (width, depth) a plaza may take at this scale, in a fixed order.
	## Both sides at least PLAZA_MIN_SIDE, the long one at most
	## PLAZA_MAX_ASPECT times the short one, and the area within the scale's
	## own deck bound. Both orientations, because a 2 x 3 and a 3 x 2 are
	## different sites on a hill.
	var out: Array[Vector2i] = []
	for width in range(PLAZA_MIN_SIDE, cap + 1):
		for depth in range(PLAZA_MIN_SIDE, cap + 1):
			if width * depth > cap \
					or maxi(width, depth) > mini(width, depth) * PLAZA_MAX_ASPECT:
				continue
			out.append(Vector2i(width, depth))
	return out


static func _plaza_footprint(plan: WarrenMazeSourcePlan, anchor: Vector2i,
		shape: Vector2i, blocked: Dictionary) -> Array[Vector2i]:
	## The rectangle at `anchor`, or empty when a member is off the massif or
	## already spoken for. `_footprint`'s own body, kept separate only because
	## the plaza names its extents (width, depth) rather than (width, depth)
	## derived from a template row.
	return _footprint(plan, anchor, shape.x, shape.y, blocked)


static func _plaza_site_less(a: Dictionary, b: Dictionary) -> bool:
	## CHEAPEST FIRST, then nearest the heart, then biggest, then squarest.
	##
	## The aspect bound has already thrown out everything that is not a room, so
	## what is left to choose between are rooms -- and the choice is made by how
	## much hill each one takes, because that is what the corpus's seals turned
	## out to be a function of. Ordering by the heart first sealed 41 of 48 (grand
	## 7/12 against 10/12) and ordering by cost first seals 44 with the SAME
	## squares on the towns that matter: 12/compact and 4/compact keep the site
	## the heart order chose, because on those towns nothing cheaper exists and
	## the heart is the tie-break that picks it.
	##
	## Heart before size for the reason the direction gives -- "a grass plaza in
	## the center" -- and size before squareness because the aspect bound has
	## already made every candidate square enough. The last two keys exist so the
	## order is total.
	if int(a["cost"]) != int(b["cost"]):
		return int(a["cost"]) < int(b["cost"])
	if int(a["heart"]) != int(b["heart"]):
		return int(a["heart"]) < int(b["heart"])
	if int(a["area"]) != int(b["area"]):
		return int(a["area"]) > int(b["area"])
	var aspect_a := int(a["long"]) * int(b["short"])
	var aspect_b := int(b["long"]) * int(a["short"])
	if aspect_a != aspect_b:
		return aspect_a < aspect_b
	for key: String in ["datum"]:
		if int(a[key]) != int(b[key]):
			return int(a[key]) < int(b[key])
	var anchor_a := a["anchor"] as Vector2i
	var anchor_b := b["anchor"] as Vector2i
	if anchor_a != anchor_b:
		return WarrenPlotPlanner.column_less(anchor_a, anchor_b)
	return int(a["width"]) < int(b["width"])


static func _plaza_site_key(site: Dictionary) -> String:
	var anchor := site["anchor"] as Vector2i
	return "%d,%d/%dx%d/%d" % [anchor.x, anchor.y, int(site["width"]),
		int(site["depth"]), int(site["datum"])]


static func _grow_decks(plan: WarrenMazeSourcePlan, streets: Dictionary,
		blocked: Dictionary, outcomes: Dictionary, claimed: int = 0) -> void:
	## Every public open room uses the same aspect-bounded rectangle transaction
	## as the primary plaza. The former second algorithm grew cheapest-first
	## tendrils from individual street cells; although connected, those regions
	## could be 1-column ledges and therefore created the small platform vocabulary
	## the visual adapter was later asked to disguise. One siting grammar now owns
	## all plazas and courts: complete rectangles, bounded aspect, exact support,
	## and an explicit same-band street threshold. A refused rectangle leaves no
	## partial floor and the next complete site is considered.
	var records: Array[Dictionary] = []
	var scale := plan.scale_profile.scale_id
	var quota := WarrenPlotPlanner.roll(plan, DECK_QUOTA_SALT,
		plan.summit_cell, 0, DECK_QUOTA.get(scale, Vector2i(1, 1)))
	var accepted := claimed
	var refused: Dictionary = {}
	while accepted < quota:
		var site := _best_plaza_site(plan, streets, blocked, refused)
		if site.is_empty():
			break
		var id := StringName("deck.%02d" % records.size())
		var region := site["cells"] as Array[Vector2i]
		var datum := int(site["datum"])
		var record := {"id": id, "size": region.size(), "datum": datum,
			"width": int(site["width"]), "depth": int(site["depth"]),
			"reason": ""}
		if plan.add_plot({"id": id, "kind": WarrenMazeSourcePlan.PLOT_DECK,
				"cells": region, "floor": datum, "top": datum,
				"door_walk": site["door"], "building_id": id}):
			for column: Vector2i in region:
				blocked[column] = true
			accepted += 1
		else:
			record["reason"] = plan.last_rejection
			refused[_plaza_site_key(site)] = true
		records.append(record)
	outcomes["decks"] = records
	outcomes["decks_short"] = quota - accepted


static func _deck_column_ok(plan: WarrenMazeSourcePlan, column: Vector2i,
		datum: int, streets: Dictionary, blocked: Dictionary,
		level_bands: int = 1) -> bool:
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
	##
	## `level_bands` is how deep the floor may cut. Every court passes the shared
	## plaza bound. The bound is only ever
	## a CUT: `plot_support_ok` asks for solid at `datum - 1`, and on a column
	## carrying no plot yet that solid runs out at the massif's own top, so a
	## datum above the terrain is already impossible and `absi` was symmetric
	## about a case that cannot happen. A plaza/court is a terrace cut into a
	## slope, so its complete footprint is evaluated as one transaction.
	return not blocked.has(column) \
		and not WarrenPlotPlanner._asset_clearance_blocks(plan, column, datum) \
		and plan.massif.has_column(column) \
		and absi(plan.massif.top_at(column) - datum) <= level_bands \
		and plan.plot_support_ok(column, datum) \
		and _no_street_left_hanging(streets, column, datum, datum)
