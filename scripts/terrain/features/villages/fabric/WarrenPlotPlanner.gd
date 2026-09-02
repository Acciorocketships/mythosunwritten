class_name WarrenPlotPlanner
extends RefCounted

## P4 (houses, heights, bridges) of the 2026-08-21 plot-model design, plus the
## shared helpers P3 borrows; `reserve` delegates to WarrenPlotReservations.
## Static and program-free: it only ever touches `add_plot` and `audit`, and
## support, clearance, and disjointness stay WarrenMazeSourcePlan's rules.
## Nothing here rejects a town -- shortfalls are `audit["plot_outcomes"]` facts.

## Bands of solid mass a bearing plot needs directly beneath its floor. The
## source plan's own support rule is what the plot layer places against, so
## nothing in this file reads this: it lives here because the parcel-level
## restatement of the same rule (WarrenBuildingParcel._has_tunnel_roof_bearing)
## needs the number, and the number has exactly one home.
const PLINTH_BANDS := 2
## Largest house footprint a scale may grow, in macro columns; each building
## rolls its own cap in [2, this], so a block is a mix of sizes. Only the
## orphan sweep may pass it, and only to keep a column out of leftover rock.
const BUILDING_CAP: Dictionary = {
	&"compact": 4, &"standard": 5, &"large": 6, &"grand": 8,
}
## (min, max) storeys an untiered house may roll. The height that comes out
## follows the parcel contract exactly -- STOREY_BANDS per storey plus
## ROOF_RESERVATION_BANDS -- so compact's (1, 3) is a 4-, 6- or 8-band house.
##
## TASK E3 MEASURED FOUR WIDENINGS OF THIS TABLE AND SHIPPED NONE; TASK E3b
## SHIPS THE WIDEST OF THEM, +1 STOREY ON EVERY SCALE, AT 24/24.
##
## The reason to want one: over the 24-town flat corpus the 736 houses stood at
## only FOUR distinct heights (4 bands x 344, 5 x 66, 6 x 225, 8 x 101), and
## EIGHT of the twelve COMPACT towns had only two untiered heights -- every
## untiered house one storey or two. The odd 5s are TIERED houses whose top is
## a street's own band, so this roll is the only source of storey diversity the
## model has.
##
## E3's four measurements, each costing exactly two of the twenty-four towns:
##
##   * +1 storey on every scale -- 22/24. `2/compact` at phase selection,
##     `7/standard` at a partial-plate roof sliver.
##   * +1 storey on compact only -- 22/24. `2/compact` and `7/compact`, both
##     at phase selection.
##   * +1 for footprints of at most 2 columns -- 22/24. `5/standard` at an
##     unsupported irregular room projection, `11/compact` at a cross-lineage
##     roof sliver.
##   * +1 for footprints of one column -- 22/24. `7/standard` at a
##     modular-box partial bearing, `11/compact` at a cross-lineage sliver.
##
## E3 concluded the binding constraint was the authored roof and room
## vocabulary rather than this file, and that was right. E3b re-measured the
## first row against the fixed gates and BOTH towns came back:
##
##   * `7/standard` -- the partial-plate roof sliver. Its crown carried a
##     STREET on one cell, and that vetoed the whole crown out of the flat
##     vocabulary; a maze flat crown now TILES instead
##     (`WarrenSpatialFabricCompiler`, gate 1).
##   * `2/compact` -- `room ...house.010.part02.room00 failed measured phase
##     selection: visual envelope intersects unrelated feature
##     spatial.feature.balcony.00`. A balcony treated its whole SOURCE LINEAGE
##     as a named seam while the compiler relates it to its own room alone
##     (`WarrenSpatialFeatureSolver._feature_bounds_overlap_unrelated_room`).
##
## Measured after, on the same 24-town corpus: **24/24 sealed**, every COMPACT
## town at three or four distinct house heights (worst 3, and 3 on the untiered
## reading too, where eight of twelve stood 2), and the corpus at FIVE heights
## -- of 741 houses, 4 x 253, 5 x 66, 6 x 193, 8 x 146, 10 x 83. Every STANDARD
## town stands all five. The three narrower rows above exist only to dodge the
## cost the first one used to carry; that cost is gone, so they are superseded
## by this table rather than re-measured. The sweep's wall clock rises with the
## storeys, which is the price of them.
const STOREY_BUDGET: Dictionary = {
	&"compact": Vector2i(1, 3), &"standard": Vector2i(1, 4),
	&"large": Vector2i(2, 4), &"grand": Vector2i(2, 5),
}
## The tallest a house may ever be, in bands: six storeys. It bounds how far a
## roof climbs to meet a street or a plot claimed above it, and which streets a
## column may bring into a footprint -- one whose street stands further above
## the floor than this cannot join, since the house could neither reach it nor
## stop short without leaving that street's floor hanging.
const MAX_TIER_BANDS := 12
## One salt per seeded roll, so two rolls on the same cell cannot agree by
## accident. Both go through WarrenPassageLatticeRules.hash_key; nothing here
## touches randi().
const STOREY_SALT := 0x570e5
const FOOTPRINT_SALT := 0xf007e


## P3: catalog assets at their minimum-modification sites, then flat decks
## grown off the streets.
static func reserve(plan: WarrenMazeSourcePlan,
		profile: WarrenVillageScaleProfile) -> void:
	if plan == null or profile == null or plan.is_sealed():
		return
	WarrenPlotReservations.reserve(plan, profile)


## P4: seed a house at every street-fronting column, grow the partition
## largest-first (absorbing bare neighbouring seeds so a block is buildings
## rather than pencils), sweep up the orphan columns, raise each house to the
## street above it or to its storey roll, then bridge every retained span.
static func partition(plan: WarrenMazeSourcePlan,
		profile: WarrenVillageScaleProfile) -> void:
	if plan == null or profile == null or plan.is_sealed():
		return
	var out := outcomes(plan)
	var streets := street_bands(plan)
	var blocked := blocked_columns(plan)
	var claims: Dictionary = {}
	var slots: Dictionary = {}
	var refusals: Array[Dictionary] = []
	var buildings := _seed_buildings(plan, streets, blocked, claims, slots,
		refusals)
	out["seed_refusals"] = refusals
	_grow_buildings(plan, buildings, streets, blocked, claims, slots)
	out["orphan_sweep_joined"] = _orphan_sweep(plan, buildings, streets,
		blocked, claims, slots)
	out["buildings"] = _raise_buildings(plan, streets, claims, buildings)
	out["bridges"] = _span_bridges(plan)
	out["leftover_columns"] = plan.massif.columns.size() \
		- owned_columns(plan).size()
	out["street_floor_gaps"] = plan.street_floor_gaps()


# --- Seeding and growth ----------------------------------------------------


static func _seed_buildings(plan: WarrenMazeSourcePlan, streets: Dictionary,
		blocked: Dictionary, claims: Dictionary, slots: Dictionary,
		refusals: Array[Dictionary]) -> Array[Dictionary]:
	## One seed per (column, band): a street cell claims each of its four
	## neighbour columns at its own band, which is what lets an upper street's
	## house stack on the roof of the lower one's tiered house. A pair is seen
	## once, from the first street that fronts it, and a refusal is recorded.
	var out: Array[Dictionary] = []
	var visited: Dictionary = {}
	for street: Vector3i in walk_order(plan):
		for direction: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
			var column := Vector2i(street.x, street.z) + direction
			var slot := _slot(column, street.y)
			if visited.has(slot):
				continue
			visited[slot] = true
			var join := _join(plan, column, street.y, streets, blocked, claims,
				-1, false)
			if String(join["reason"]) != "":
				refusals.append({"column": column, "band": street.y,
					"reason": join["reason"]})
				continue
			claims[column] = (claims.get(column, []) as Array) + [street.y]
			slots[slot] = out.size()
			out.append({"id": StringName("house.%03d" % out.size()),
				"seed": column, "cells": [column] as Array[Vector2i],
				"floor": street.y, "door": street, "tier": int(join["tier"]),
				"retired": false})
	return out


static func _grow_buildings(plan: WarrenMazeSourcePlan,
		buildings: Array[Dictionary], streets: Dictionary,
		blocked: Dictionary, claims: Dictionary, slots: Dictionary) -> void:
	## The single priority loop: the largest building that can still grow (ties
	## to the lowest id) takes its one best adjacent column, and the loop runs
	## again. That column is free rock or a BARE SEED at the same floor -- a
	## building of one column that never grew -- absorbed whole: its cell joins,
	## its id retires, its door gives way to the absorber's. Without it a warren
	## where nearly every column fronts a street partitions into pencils. A
	## building with no candidate stalls for good, so this ends after one stall
	## each plus one step per column.
	var limit := int(BUILDING_CAP.get(plan.scale_profile.scale_id, 4))
	for index in buildings.size():
		buildings[index]["cap"] = roll(plan, FOOTPRINT_SALT,
			buildings[index]["door"] as Vector3i, index, Vector2i(2, limit))
		buildings[index]["stalled"] = false
	while true:
		var choice := -1
		var largest := 0
		for index in buildings.size():
			var building := buildings[index]
			var size := (building["cells"] as Array).size()
			if bool(building["stalled"]) or bool(building["retired"]) \
					or size >= int(building["cap"]) or size <= largest:
				continue
			largest = size
			choice = index
		if choice < 0:
			break
		var building := buildings[choice]
		var pick := _best_join(plan, building, choice, streets, blocked,
			claims, slots, buildings)
		if pick.is_empty():
			building["stalled"] = true
			continue
		var column := pick["column"] as Vector2i
		var floor_band := int(building["floor"])
		(building["cells"] as Array[Vector2i]).append(column)
		if int(pick["tier"]) >= 0:
			building["tier"] = int(pick["tier"])
		var absorbed := int(pick["absorb"])
		if absorbed < 0:
			claims[column] = (claims.get(column, []) as Array) + [floor_band]
		else:
			buildings[absorbed]["retired"] = true
			buildings[absorbed]["cells"] = [] as Array[Vector2i]
		slots[_slot(column, floor_band)] = choice


static func _best_join(plan: WarrenMazeSourcePlan, building: Dictionary,
		self_index: int, streets: Dictionary, blocked: Dictionary,
		claims: Dictionary, slots: Dictionary,
		buildings: Array[Dictionary]) -> Dictionary:
	## The adjacent column this building would rather have -- free rock or an
	## absorbable bare seed, ranked alike by |top_at - floor| then column order.
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
			members[next] = true
			var owner := int(slots.get(_slot(next, floor_band), -1))
			var absorb := owner >= 0 and owner != self_index \
				and not bool(buildings[owner]["retired"]) \
				and (buildings[owner]["cells"] as Array).size() == 1
			if owner >= 0 and not absorb:
				continue
			var join := _join(plan, next, floor_band, streets, blocked, claims,
				int(building["tier"]), absorb)
			if String(join["reason"]) != "":
				continue
			if best.is_empty() \
					or closer(plan, next, best["column"], floor_band):
				best = {"column": next, "tier": int(join["tier"]),
					"absorb": owner if absorb else -1}
	return best


static func _orphan_sweep(plan: WarrenMazeSourcePlan,
		buildings: Array[Dictionary], streets: Dictionary,
		blocked: Dictionary, claims: Dictionary, slots: Dictionary) -> int:
	## Coverage beats size variation: once the capped loop is done, every free
	## supportable column that can still join a building does, cap or no cap. It
	## goes to the SMALLEST adjacent building, so a block evens out instead of
	## fattening whichever came first, and it repeats because a column with no
	## neighbour to join can gain one as the sweep fills the gap beside it.
	var limit := int(BUILDING_CAP.get(plan.scale_profile.scale_id, 4))
	var columns: Array[Vector2i] = []
	columns.assign(plan.massif.columns.keys())
	columns.sort_custom(Callable(WarrenPlotPlanner, "column_less"))
	var joined := 0
	var moved := true
	while moved:
		moved = false
		for column: Vector2i in columns:
			if blocked.has(column) \
					or not (claims.get(column, []) as Array).is_empty():
				continue
			var host := _orphan_host(plan, column, buildings, streets, blocked,
				claims, slots, limit)
			if host.is_empty():
				continue
			var owner := int(host["owner"])
			var building := buildings[owner]
			var floor_band := int(building["floor"])
			(building["cells"] as Array[Vector2i]).append(column)
			if int(host["tier"]) >= 0:
				building["tier"] = int(host["tier"])
			claims[column] = [floor_band]
			slots[_slot(column, floor_band)] = owner
			joined += 1
			moved = true
	return joined


static func _orphan_host(plan: WarrenMazeSourcePlan, column: Vector2i,
		buildings: Array[Dictionary], streets: Dictionary,
		blocked: Dictionary, claims: Dictionary, slots: Dictionary,
		limit: int) -> Dictionary:
	## The building this orphan should join: the smallest adjacent one the join
	## rule accepts at its own floor, ties to the lowest id. One under
	## BUILDING_CAP always wins; only when every candidate sits at that ceiling
	## is a building pushed past it, rock being the costlier outcome.
	var best: Dictionary = {}
	var under: Dictionary = {}
	for direction: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
		var next := column + direction
		for band: int in claims.get(next, []) as Array:
			var owner := int(slots.get(_slot(next, band), -1))
			if owner < 0 or bool(buildings[owner]["retired"]):
				continue
			var join := _join(plan, column, band, streets, blocked, claims,
				int(buildings[owner]["tier"]), false)
			if String(join["reason"]) != "":
				continue
			var size := (buildings[owner]["cells"] as Array).size()
			var candidate := {"owner": owner, "size": size,
				"tier": int(join["tier"])}
			var rank := Vector2i(size, owner)
			if best.is_empty() or rank < Vector2i(int(best["size"]),
					int(best["owner"])):
				best = candidate
			if size < limit and (under.is_empty() or rank \
					< Vector2i(int(under["size"]), int(under["owner"]))):
				under = candidate
	return best if under.is_empty() else under


static func _join(plan: WarrenMazeSourcePlan, column: Vector2i,
		floor_band: int, streets: Dictionary, blocked: Dictionary,
		claims: Dictionary, bound: int, absorb: bool) -> Dictionary:
	## May `column` carry a house at `floor_band`, and what tier band does that
	## bind? `reason` is "" when it joins; `tier` is -1 when it binds nothing,
	## otherwise the LOWEST street band the column hosts at or above the floor.
	## Only that lowest one matters: anything above it sits above the roof this
	## house will grow, so it is none of this footprint's business.
	##
	## Two strengthenings, both to keep the town sealable: `blocked` holds every
	## column an asset, a deck, or a retained bridge span owns (a house under a
	## deck strands it -- a deck adds no solid mass), and two houses share a
	## column only MIN_HOUSE_BANDS apart or more, so the lower roof can always
	## reach the upper floor. `absorb` waives the second for the bare seed being
	## swallowed, which claimed this band itself.
	if blocked.has(column) \
			or _asset_clearance_blocks(plan, column, floor_band) \
			or not plan.massif.has_column(column):
		return {"tier": -1, "reason": "column already spoken for"}
	for other: int in claims.get(column, []) as Array:
		if absi(other - floor_band) < WarrenMazeSourcePlan.MIN_HOUSE_BANDS \
				and not (absorb and other == floor_band):
			return {"tier": -1, "reason": "claimed within MIN_HOUSE_BANDS"}
	if not plan.plot_support_ok(column, floor_band):
		return {"tier": -1, "reason": "support rule refuses this floor"}
	var tier := -1
	var above := 0
	for band: int in streets.get(column, []) as Array:
		if band < floor_band:
			continue
		above += 1
		tier = band if tier < 0 else mini(tier, band)
	if tier < 0:
		return {"tier": -1, "reason": ""}
	# A roof can carry exactly one street: its own. The footprint's top is the
	# LOWEST street across its columns, so a column hosting a second one above
	# that lands it over open air -- on a column carrying a plot there is
	# nothing above the plot's top but sky.
	if above > 1:
		return {"tier": tier, "reason": "second street above the tier"}
	if tier < floor_band + WarrenMazeSourcePlan.MIN_HOUSE_BANDS:
		return {"tier": tier, "reason": "tier below MIN_HOUSE_BANDS"}
	if tier > floor_band + MAX_TIER_BANDS:
		return {"tier": tier, "reason": "tier beyond MAX_TIER_BANDS"}
	if bound >= 0 and tier != bound:
		return {"tier": tier, "reason": "tier disagrees with the footprint"}
	return {"tier": tier, "reason": ""}


# --- Heights ---------------------------------------------------------------


static func _raise_buildings(plan: WarrenMazeSourcePlan, streets: Dictionary,
		claims: Dictionary, buildings: Array[Dictionary]) -> Array[Dictionary]:
	## Heights, then commit, in ascending floor order -- so a tiered house is
	## standing when the house stacked on its roof asks whether the band below
	## is solid. One that does not stand gives its claims back, so nothing above
	## it is capped by a roof that never got built.
	var records: Array[Dictionary] = []
	var skyline_peaks := _skyline_peak_indices(plan, buildings)
	var order: Array[int] = []
	order.assign(range(buildings.size()))
	order.sort_custom(func(a: int, b: int) -> bool:
		var floor_a := int(buildings[a]["floor"])
		var floor_b := int(buildings[b]["floor"])
		return floor_a < floor_b if floor_a != floor_b else a < b)
	for index: int in order:
		var building := buildings[index]
		if bool(building["retired"]):
			continue
		var floor_band := int(building["floor"])
		var roof := _building_top(plan, streets, claims, building, index,
			skyline_peaks.has(index))
		var id := StringName(building["id"])
		var cells := building["cells"] as Array[Vector2i]
		cells.sort_custom(Callable(WarrenPlotPlanner, "column_less"))
		var top := int(roof["top"])
		var record := {"id": id, "cells": cells.size(), "floor": floor_band,
			"top": top, "tiered": bool(roof["tiered"]),
			"skyline_peak": bool(roof["skyline_peak"]), "reason": ""}
		# The last word on the hard rule, checked here rather than trusted
		# from the height fixpoint (review finding 2026-08-23, Important 1).
		# `_building_top` exits its loop on `cells.size() <= 1` as well as on
		# an empty `dropped`, so a single-column house can come back with the
		# very street it could not carry still on it -- reachable through the
		# `cap` override, where a house claimed above forces `top = cap` below
		# the tier and the upper house then fails its own add_plot and
		# releases, after this one has already committed. A refused house is a
		# coverage fact this record publishes; a floating street is a broken
		# hard rule, so the house gives way.
		var stranding := _stranding_refusal(streets, cells, floor_band, top)
		if top < floor_band + WarrenMazeSourcePlan.MIN_HOUSE_BANDS:
			record["reason"] = "no footprint here reaches MIN_HOUSE_BANDS"
		elif stranding != "":
			record["reason"] = stranding
		elif not plan.add_plot({"id": id,
				"kind": WarrenMazeSourcePlan.PLOT_HOUSE, "cells": cells,
				"floor": floor_band, "top": top,
				"door_walk": building["door"], "building_id": id}):
			record["reason"] = plan.last_rejection
		if String(record["reason"]) != "":
			for column: Vector2i in cells:
				_release(claims, column, floor_band)
		records.append(record)
	return records


static func _building_top(plan: WarrenMazeSourcePlan, streets: Dictionary,
		claims: Dictionary, building: Dictionary, index: int,
		skyline_peak: bool = false) -> Dictionary:
	## A roof is, in preference order, the street through this footprint (the
	## tier the whole model exists for), the lowest street past its one-column
	## apron, or the scale's seeded storey budget. It then has to agree with
	## whatever else is claimed above this floor on the same columns, and a
	## column it cannot agree with leaves the footprint -- hence the loop.
	var floor_band := int(building["floor"])
	var minimum := floor_band + WarrenMazeSourcePlan.MIN_HOUSE_BANDS
	var reach := floor_band + MAX_TIER_BANDS
	# The parcel contract exactly -- whole storeys plus the roof reservation --
	# so the translator receives a legal envelope. `index` is in the hash, or
	# the four houses around one street cell would be clones.
	var rolled_seed_top := _rolled_seed_top(plan, building, index)
	var cells := building["cells"] as Array[Vector2i]
	var street_top := -1
	var top := floor_band
	while true:
		# The massif already descends toward its boundary, but the former free
		# storey roll could put a three-storey shell back on its last column and
		# recreate a sheer white/timber face after the natural mass had stepped
		# down.  A parcel may rise by at most one storey per complete ring of
		# surrounding massif: boundary houses are one storey, the next ring at
		# most two, and only deeper houses receive the full seeded roll.  A roof
		# meeting an upper public street remains authoritative below; shortening
		# it would strand that street rather than make a terrace.
		var rolled := rolled_seed_top if skyline_peak else mini(
			rolled_seed_top, _outer_terrace_top(plan, cells, floor_band))
		# Re-derived from the columns that survived, never from the flag growth
		# bound: a shrunken footprint may have lost the street it meant to meet.
		street_top = _lowest_street(streets, cells, minimum, reach, false)
		if street_top < 0:
			street_top = _lowest_street(streets, cells, minimum, reach, true)
		top = street_top if street_top >= 0 else rolled
		# Something is claimed above this floor here. Meet it: a roof stopping
		# short of the house stacked on it strands that house, and the stack
		# invariant fails the whole town for it. A street in the gap stops the
		# climb (the mismatching column then leaves the footprint), and so does
		# MAX_TIER_BANDS -- there this house keeps its height and the claim
		# above gives way at its own commit.
		var cap := _lowest_above(claims, cells, floor_band)
		if cap >= 0:
			var clear := cap <= reach
			for column: Vector2i in cells:
				clear = clear and plan.first_carved_band(column, floor_band,
					cap) < 0
			top = cap if clear else mini(top, cap)
		var dropped: Dictionary = {}
		for column: Vector2i in cells:
			var ceiling := _lowest_above(claims, [column] as Array[Vector2i],
				floor_band)
			# Every street this roof cannot carry sends its column away, not
			# just the lowest one: the house would take the rock out from under
			# that street and leave its floor hanging, since above the lowest
			# plot floor on a column solid mass is plots only. Off the footprint
			# the sealed rock shoulder keeps the street its ground.
			if ceiling >= 0 and (ceiling < minimum \
					or ceiling > top and ceiling <= reach) \
					or _street_above(streets, column, floor_band, top):
				dropped[column] = true
		# The second disjunct exits with `dropped` STILL non-empty: a
		# one-column house has nothing left to shed, so it returns the height
		# it has and the offending street with it. That is why
		# `_raise_buildings` re-asks `_stranding_refusal` before it commits --
		# this loop settles a shape, it does not certify one.
		if dropped.is_empty() or cells.size() <= 1:
			break
		# The component walk, not `dropped`, decides who really leaves: it keeps
		# a dropped SEED and it strands columns the drop disconnected. Claims
		# are handed back for exactly the difference, or a phantom claim keeps
		# capping the roofs beneath a column nobody owns.
		var before := cells
		cells = _keep_component(cells, dropped, building["seed"] as Vector2i)
		var kept: Dictionary = {}
		for column: Vector2i in cells:
			kept[column] = true
		for column: Vector2i in before:
			if not kept.has(column):
				_release(claims, column, floor_band)
		building["cells"] = cells
	return {"top": top, "tiered": street_top >= 0 and top == street_top,
		"skyline_peak": skyline_peak and street_top < 0 \
			and top == rolled_seed_top}


static func _rolled_seed_top(plan: WarrenMazeSourcePlan,
		building: Dictionary, index: int) -> int:
	var floor_band := int(building["floor"])
	return floor_band + WarrenBuildingParcel.ROOF_RESERVATION_BANDS \
		+ WarrenBuildingParcel.STOREY_BANDS * roll(plan, STOREY_SALT,
			building["door"] as Vector3i, index, STOREY_BUDGET.get(
				plan.scale_profile.scale_id, Vector2i(1, 2)))


static func _skyline_peak_indices(plan: WarrenMazeSourcePlan,
		buildings: Array[Dictionary]) -> Dictionary:
	## Towers are local maxima of the parcel field, not a globally selected hero.
	## Every narrow, grounded parcel whose seeded height would be shortened by the
	## terrace profile competes only with parcels touching its footprint. A strict
	## local maximum keeps its complete seeded stack; the others follow the same
	## descending terrace profile as broad buildings. This admits zero, one, or
	## several peaks as a consequence of topology and height noise, with no town-
	## wide quota and no privileged seed or coordinate.
	var eligible: Dictionary = {}
	var owners: Dictionary = {}
	for index in buildings.size():
		var building := buildings[index]
		if bool(building["retired"]):
			continue
		var cells := building["cells"] as Array[Vector2i]
		for cell: Vector2i in cells:
			var at_cell: Array = owners.get(cell, [])
			at_cell.append(index)
			owners[cell] = at_cell
		if cells.is_empty() or cells.size() > 2:
			continue
		var floor_band := int(building["floor"])
		var seeded_top := _rolled_seed_top(plan, building, index)
		if seeded_top <= _outer_terrace_top(plan, cells, floor_band):
			continue
		eligible[index] = seeded_top - floor_band
	var out: Dictionary = {}
	for index_value: Variant in eligible.keys():
		var index := int(index_value)
		var building := buildings[index]
		var neighbors: Dictionary = {}
		for cell: Vector2i in building["cells"] as Array[Vector2i]:
			for probe: Vector2i in [cell, cell + Vector2i.LEFT,
					cell + Vector2i.RIGHT, cell + Vector2i.UP,
					cell + Vector2i.DOWN]:
				for other_value: Variant in owners.get(probe, []):
					var other := int(other_value)
					if other != index:
						neighbors[other] = true
		var is_peak := true
		for other_value: Variant in neighbors.keys():
			var other := int(other_value)
			if not eligible.has(other):
				continue
			var other_height := int(eligible[other])
			if other_height > int(eligible[index]) \
					or other_height == int(eligible[index]) and other < index:
				is_peak = false
				break
		if is_peak:
			out[index] = true
	return out


static func _outer_terrace_top(plan: WarrenMazeSourcePlan,
		cells: Array[Vector2i], floor_band: int) -> int:
	## Highest untiered roof admitted when this parcel is the lower foreground
	## of an actual terrace. Depth is counted in complete cardinal massif rings;
	## a boundary parcel is shortened only when a deeper neighbouring column
	## belongs to another parcel, so the lost storey reveals a roofed layer
	## behind it rather than merely deleting an isolated edge house.
	var depth := 2147483647
	var members: Dictionary = {}
	for column: Vector2i in cells:
		members[column] = true
		depth = mini(depth, _massif_boundary_depth(plan.massif, column))
	if depth == 2147483647:
		return 2147483647
	var fronts_deeper_mass := false
	for column: Vector2i in cells:
		if _massif_boundary_depth(plan.massif, column) != depth:
			continue
		for direction: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
			var neighbor := column + direction
			if members.has(neighbor) or not plan.massif.has_column(neighbor):
				continue
			if _massif_boundary_depth(plan.massif, neighbor) > depth:
				fronts_deeper_mass = true
				break
		if fronts_deeper_mass:
			break
	if not fronts_deeper_mass:
		return 2147483647
	return floor_band + WarrenBuildingParcel.ROOF_RESERVATION_BANDS \
		+ WarrenBuildingParcel.STOREY_BANDS * maxi(1, depth)


static func _massif_boundary_depth(massif: WarrenMassif,
		column: Vector2i) -> int:
	## 1 for a boundary column, 2 for its first complete inner ring, and so on.
	## The largest production massif is only 17 columns across; this bounded
	## breadth-first walk is clearer and cheaper than keeping a second field in
	## the source plan.
	if massif == null or not massif.has_column(column):
		return 1
	var frontier: Array[Vector2i] = [column]
	var visited: Dictionary = {column: true}
	var depth := 1
	while not frontier.is_empty():
		var next: Array[Vector2i] = []
		for current: Vector2i in frontier:
			for direction: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
				var neighbor := current + direction
				if not massif.has_column(neighbor):
					return depth
				if not visited.has(neighbor):
					visited[neighbor] = true
					next.append(neighbor)
		frontier = next
		depth += 1
	return depth


static func _stranding_refusal(streets: Dictionary, cells: Array[Vector2i],
		floor_band: int, top: int) -> String:
	## "" when a roof at `top` carries every street standing on this
	## footprint, else the reason naming the first column it would leave
	## hanging. `_raise_buildings` asks before it commits, so the fixpoint in
	## `_building_top` decides the SHAPE and this decides whether the shape it
	## settled on may stand at all.
	for column: Vector2i in cells:
		if _street_above(streets, column, floor_band, top):
			return "would strand a street on column %s" % column
	return ""


static func _street_above(streets: Dictionary, column: Vector2i,
		floor_band: int, top: int) -> bool:
	## Does this column host a street the roof at `top` cannot carry? Only a
	## street exactly at `top` is carried (it runs across the roof); one below
	## the floor is this house's own bearing, and anything else is a floor left
	## hanging. Mirrors the asset path's check in WarrenPlotReservations.
	for band: int in streets.get(column, []) as Array:
		if band >= floor_band and band != top:
			return true
	return false


static func _lowest_street(streets: Dictionary, cells: Array[Vector2i],
		minimum: int, reach: int, apron: bool) -> int:
	## The lowest street band in [minimum, reach] through these columns, or -1.
	## `apron` looks one column further out -- the difference between a street
	## crossing this roof and one running past it.
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
			if band >= minimum and band <= reach:
				out = band if out < 0 else mini(out, band)
	return out


static func _lowest_above(claims: Dictionary, cells: Array[Vector2i],
		floor_band: int) -> int:
	## The lowest floor another house claims above this one on these columns, or
	## -1 when the sky is clear. Assets and decks never share a column with a
	## house (see _join).
	var out := -1
	for column: Vector2i in cells:
		for band: int in claims.get(column, []) as Array:
			if band > floor_band:
				out = band if out < 0 else mini(out, band)
	return out


static func _keep_component(cells: Array[Vector2i], dropped: Dictionary,
		seed_column: Vector2i) -> Array[Vector2i]:
	## The seed's connected component once the offenders leave, so a shrunken
	## footprint is still the 4-connected footprint add_plot demands.
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


static func _release(claims: Dictionary, column: Vector2i, band: int) -> void:
	## Hand one claim back: a dropped column, or a building that never stood,
	## must stop capping the roofs beneath it.
	var bands: Array = claims.get(column, [])
	var at := bands.find(band)
	if at < 0:
		return
	bands.remove_at(at)
	claims[column] = bands


# --- Bridges ---------------------------------------------------------------


static func _span_bridges(plan: WarrenMazeSourcePlan) -> Array[Dictionary]:
	## Every span whose overhead mass the carver retained becomes a one-storey
	## plot on that slab, one band above the highest headroom the span owns.
	## Placed last, so an adjacent house sharing the bridge's floor is already
	## standing and can lend it a building id.
	var records: Array[Dictionary] = []
	var seeded := plan.excavation.bridge_span_audit.get("seeded", []) as Array
	for index in plan.excavation.bridge_spans.size():
		var span: Array = plan.excavation.bridge_spans[index]
		var cells: Array[Vector2i] = []
		# The carver records the occupied floor before it opens the selected bore
		# through the former rock slab. Recomputing from that enlarged carved set
		# would move the floor upward one band on every read and recreate a gap.
		var proof := seeded[index] as Dictionary if index < seeded.size() else {}
		var floor_band := int(proof.get("floor",
			plan.passage_headroom_top(span[0] as Vector3i) \
			+ WarrenMazeSourcePlan.TUNNEL_ROOF_BANDS))
		for cell_value: Variant in span:
			var cell := cell_value as Vector3i
			var column := Vector2i(cell.x, cell.z)
			if not cells.has(column):
				cells.append(column)
			if proof.is_empty():
				floor_band = maxi(floor_band, plan.passage_headroom_top(cell)
					+ WarrenMazeSourcePlan.TUNNEL_ROOF_BANDS)
		var id := StringName("bridge.%02d" % index)
		var top := floor_band + WarrenBuildingParcel.STOREY_BANDS
		# The source selector owns the whole three-part composition: two widened
		# lower houses and the occupied span. The narrower upper endpoint rooms
		# are compiled from the sealed bridge compound after these ordinary house
		# plots exist, so they inherit real ground access without requiring an
		# impossible second public door at bridge height. A bridge no longer hopes
		# generic infill will happen to place the houses it needs.
		var endpoint_reason := ""
		var endpoint_groups: Array = proof.get("endpoint_groups", []) as Array
		var foundation_groups: Array = proof.get(
			"endpoint_foundation_groups", []) as Array
		var support_modes: Array = proof.get("endpoint_support_modes", []) as Array
		if endpoint_groups.size() != 2 or foundation_groups.size() != 2 \
				or support_modes.size() != 2:
			endpoint_reason = "source bridge carries no complete endpoint-house plan"
		for endpoint_index in 2:
			if endpoint_reason != "":
				break
			# A terrain arcade is itself the endpoint's complete load path and is
			# compiled with the upper room. Only the direct-house form needs a lower
			# plot here; forcing both forms through a vertically-supported house plot
			# recreated the stone plug underneath every bridge.
			if StringName(support_modes[endpoint_index]) == &"terrain_arcade":
				continue
			var endpoint_cells: Array[Vector2i] = []
			endpoint_cells.assign(endpoint_groups[endpoint_index] as Array)
			var foundation_cells: Array[Vector2i] = []
			foundation_cells.assign(foundation_groups[endpoint_index] as Array)
			var door_walk := _bridge_endpoint_door(span, endpoint_cells)
			var building_id := StringName("%s.end.%d" % [String(id),
				endpoint_index])
			var lower_id := StringName("%s.lower" % String(building_id))
			if door_walk.x == 2147483647 \
					or not plan.add_plot({"id": lower_id,
						"kind": WarrenMazeSourcePlan.PLOT_HOUSE,
						"cells": foundation_cells,
						"floor": door_walk.y, "top": floor_band,
						"door_walk": door_walk,
						"building_id": building_id}):
				endpoint_reason = "lower endpoint house %d: %s" % [
					endpoint_index, plan.last_rejection]
				break
		var owner := _bridge_owner(plan, cells, floor_band, id)
		var record := {"id": id, "span": index, "cells": cells.size(),
			"columns": cells.duplicate(), "door_walk": span[0] as Vector3i,
			"floor": floor_band, "top": top, "building_id": owner,
			"reason": ""}
		if endpoint_reason != "":
			record["reason"] = endpoint_reason
		elif not plan.add_plot({"id": id,
				"kind": WarrenMazeSourcePlan.PLOT_BRIDGE, "cells": cells,
				"floor": floor_band, "top": top,
				"door_walk": span[0] as Vector3i, "building_id": owner}):
			record["reason"] = plan.last_rejection
		records.append(record)
	return records


static func _bridge_endpoint_door(span: Array,
		endpoint_cells: Array[Vector2i]) -> Vector3i:
	## The endpoint's lower house opens onto the same canonical route bay the
	## bridge crosses. Find the exact adjacent span cell; no nearest-distance
	## fallback can invent a door disconnected from the route.
	for span_value: Variant in span:
		var walk := span_value as Vector3i
		for column: Vector2i in endpoint_cells:
			if absi(column.x - walk.x) + absi(column.y - walk.z) == 1:
				return walk
	return Vector3i(2147483647, 2147483647, 2147483647)


static func _bridge_owner(plan: WarrenMazeSourcePlan, cells: Array[Vector2i],
		floor_band: int, own_id: StringName) -> StringName:
	## The house a bridge belongs to: one with an occupied storey crossing the
	## bridge floor beside the span, lowest id where several qualify. A tall
	## house usually begins below this band; requiring its plot floor to equal
	## the bridge floor discarded that valid upper room even though the later
	## access resolver correctly accepts the same [floor, top) containment.
	var members: Dictionary = {}
	for column: Vector2i in cells:
		members[column] = true
	var out := own_id
	for plot: Dictionary in plan.plots:
		if StringName(plot["kind"]) != WarrenMazeSourcePlan.PLOT_HOUSE \
				or floor_band < int(plot["floor"]) \
				or floor_band >= int(plot["top"]):
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


## The single audit record every phase writes into. Seal merges its own keys
## over the top without destroying this one.
static func outcomes(plan: WarrenMazeSourcePlan) -> Dictionary:
	if not plan.audit.has("plot_outcomes"):
		plan.audit["plot_outcomes"] = {"assets": [], "decks": [],
			"decks_short": 0, "seed_refusals": [], "buildings": [],
			"bridges": [], "orphan_sweep_joined": 0, "leftover_columns": 0,
			"street_floor_gaps": 0}
	return plan.audit["plot_outcomes"] as Dictionary


## Street cells in the order the town is walked: the spine, then each lane from
## its anchor outward, then -- so nothing is missed -- whatever passage cells
## that walk did not reach, in sorted order.
static func walk_order(plan: WarrenMazeSourcePlan) -> Array[Vector3i]:
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


## Vector2i column -> sorted Array[int] of the bands a passage walks there.
static func street_bands(plan: WarrenMazeSourcePlan) -> Dictionary:
	var out: Dictionary = {}
	for cell: Vector3i in plan.passage_cells():
		var column := Vector2i(cell.x, cell.z)
		var bands: Array = out.get(column, [])
		if not bands.has(cell.y):
			bands.append(cell.y)
			bands.sort()
		out[column] = bands
	return out


## Every column carrying a plot, as a set.
static func owned_columns(plan: WarrenMazeSourcePlan) -> Dictionary:
	var out: Dictionary = {}
	for plot: Dictionary in plan.plots:
		for cell_value: Variant in plot["cells"] as Array:
			out[cell_value as Vector2i] = true
	return out


## Columns nothing new may claim: whatever already carries a plot, plus each
## retained bridge compound's span and its two source-proved endpoint footprints.
## The bridge is one topology fact, so generic parcel growth cannot spend an
## endpoint and force a downstream compiler to reconstruct or patch the missing
## half. The dedicated bridge transaction later claims all three pieces together.
##
## TASK E3 RULING 2 MEASURED THE RELAXATION HERE AND SHIPPED NONE. Every one of
## the 24-town corpus's 214 unfilled street-fronting (column, band) slots was
## attributed, and NOT ONE of them is the alley/block-thickness shadow Task E2
## named: 101 are columns an ASSET holds and 25 a DECK holds -- this rule -- 83
## are a second street on a column another house already claims within
## MIN_HOUSE_BANDS, and 5 are unrecorded. Letting a house stand UNDER a
## reserved plot where MIN_HOUSE_BANDS of clearance really exists (with the
## reserved floors seeded into the partition's own `claims`, so the roof has to
## rise to meet them exactly) recovers the fronting share 0.865 -> 0.909,
## buildable coverage 0.946 -> 0.951, and 28 more houses -- and costs FIVE
## towns (`2/standard`, `3/compact`, `9/compact`, `9/standard`, `12/compact`,
## at roofless-house and partial-bearing modular-box contracts, a balcony
## visual envelope, and two phase selections). Narrowed to DECKS alone it still
## costs one (`10/standard`, roofless house). The recoverable slots are real
## and the lever is here; what refuses them is the same room/roof vocabulary
## that refuses a taller house (see STOREY_BUDGET).
##
## TASK E3b DECLINED THIS, AND IT IS A DECLINE RATHER THAN AN OVERSIGHT.
## E3b was funded to fix the two vocabulary gates and then re-apply E3's
## measured attempts one at a time; it shipped the storey widening and stopped
## the outcropping one, and it did NOT attempt this. Three reasons, in order:
## the lever is a four-part change (narrowing this function, seeding reserved
## floors into `claims`, a `_join` clause and `_reserved_gap_refusal`), neither
## of E3b's exit targets depends on it, and the gates E3b actually fixed are
## not the gates it died at -- of the five towns above, only `3/compact`'s
## balcony envelope is in a family E3b touched (the lineage narrowing and the
## accepted-balcony envelope, both maze-only).
##
## SO THE NUMBERS ABOVE ARE STALE IN ONE DIRECTION: they were measured before
## those two balcony fixes and before every house grew a storey, and both move
## this experiment. Whoever picks it up should RE-MEASURE from HEAD rather than
## trust the five-town cost, and should expect the storey widening to have made
## it harder (more rooms per plot, more chances at the room gate) and the
## balcony fixes to have made it easier.
static func blocked_columns(plan: WarrenMazeSourcePlan) -> Dictionary:
	var out := owned_columns(plan)
	for span_value: Variant in plan.excavation.bridge_spans:
		for cell_value: Variant in span_value as Array:
			var cell := cell_value as Vector3i
			out[Vector2i(cell.x, cell.z)] = true
	for proof_value: Variant in plan.excavation.bridge_span_audit.get(
			"seeded", []) as Array:
		var proof := proof_value as Dictionary
		for group_value: Variant in proof.get(
				"endpoint_foundation_groups", []) as Array:
			for column_value: Variant in group_value as Array:
				out[column_value as Vector2i] = true
	return out


static func _asset_clearance_blocks(plan: WarrenMazeSourcePlan,
		column: Vector2i, floor_band: int) -> bool:
	## A prefab's neighbouring reservation is VOLUMETRIC, not ownership of the
	## column forever. Houses below its measured top would intersect its body or
	## eaves; a house whose floor is at/above that top can form the next terrace
	## without touching it. Keeping the band here prevents the clearance fix
	## from erasing legitimate upper houses and the roofs that articulate them.
	for record_value: Variant in outcomes(plan).get(
			"asset_clearance_reservations", []) as Array:
		var record := record_value as Dictionary
		if floor_band >= int(record.get("top", 2147483647)):
			continue
		for column_value: Variant in record.get("columns", []) as Array:
			if column_value as Vector2i == column:
				return true
	return false


## One seeded integer in the inclusive range, from the lattice's own hash.
static func roll(plan: WarrenMazeSourcePlan, salt: int, cell: Vector3i,
		extra: int, range_value: Vector2i) -> int:
	return range_value.x + posmod(WarrenPassageLatticeRules.hash_key(
		plan.world_seed, salt, cell, extra),
		maxi(1, range_value.y - range_value.x + 1))


## Which column a growth step would rather have: envelope nearest the datum,
## then column order.
static func closer(plan: WarrenMazeSourcePlan, a: Vector2i, b: Vector2i,
		datum: int) -> bool:
	var cost_a := absi(plan.massif.top_at(a) - datum)
	var cost_b := absi(plan.massif.top_at(b) - datum)
	return cost_a < cost_b if cost_a != cost_b else column_less(a, b)


## The lattice's column order: by z, then x.
static func column_less(a: Vector2i, b: Vector2i) -> bool:
	return a.x < b.x if a.y == b.y else a.y < b.y


static func _slot(column: Vector2i, band: int) -> Vector3i:
	## A (column, band) key: one house per column per band, which is what makes
	## seeding, absorption, and the sweep agree about who owns what.
	return Vector3i(column.x, band, column.y)
