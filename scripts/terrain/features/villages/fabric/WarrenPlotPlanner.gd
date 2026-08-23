class_name WarrenPlotPlanner
extends RefCounted

## P4 (houses, heights, bridges) of the 2026-08-21 plot-model design, plus the
## shared helpers P3 borrows. Static and program-free: the only things it ever
## changes on a plan are `add_plot` and `audit`, and support, clearance, and
## disjointness stay WarrenMazeSourcePlan's rules, never re-derived here.
## `reserve` delegates to WarrenPlotReservations.
##
## Nothing here rejects a town: a seed the join rule turns away, a roof that
## cannot reach its own minimum, a span whose clearance was eaten are all
## outcomes in `audit["plot_outcomes"]` (rules become repairs).

## Bands of solid mass a bearing plot needs directly beneath its floor.
## Identical to WarrenMazeStampPass.PLINTH_BANDS; a later task re-points
## WarrenBuildingParcel here and deletes that copy. Nothing in this planner
## reads it -- the support rule already answers "may a plot stand here" -- it
## lives here so the number ends up with one home.
const PLINTH_BANDS := 2
## Largest house footprint a scale may grow, in macro columns; each building
## rolls its own cap in [2, this], so a block is a mix of sizes rather than a
## grid of identical boxes.
const BUILDING_CAP: Dictionary = {
	&"compact": 4, &"standard": 5, &"large": 6, &"grand": 8,
}
## (min, max) storeys an untiered house may roll. The height that comes out
## follows the parcel contract exactly -- STOREY_BANDS per storey plus
## ROOF_RESERVATION_BANDS -- so compact's (1, 2) is a 4- or 6-band house.
const STOREY_BUDGET: Dictionary = {
	&"compact": Vector2i(1, 2), &"standard": Vector2i(1, 3),
	&"large": Vector2i(2, 3), &"grand": Vector2i(2, 4),
}
## The tallest a house may ever be, in bands: six storeys. It bounds three
## things at once -- how far a roof may climb to meet a street, how far it may
## climb to meet a plot claimed above it, and which streets a column may bring
## into a footprint at all. A column whose own street stands further above the
## floor than this cannot join: the house could neither reach that street nor
## stop short of it without leaving the street's floor hanging over open air,
## because above the lowest plot floor on a column, solid mass is plots only.
const MAX_TIER_BANDS := 12
## One salt per seeded roll, so two rolls on the same cell cannot agree by
## accident. Both go through WarrenPassageLatticeRules.hash_key; nothing in
## this file touches randi() or an RNG with state of its own.
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
## rather than pencils), raise each house to the street above it or to its
## storey roll, then drop a bridge onto every retained span.
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
	out["buildings"] = _raise_buildings(plan, streets, claims, buildings)
	out["bridges"] = _span_bridges(plan)
	var owned := owned_columns(plan)
	var leftover := 0
	for column: Vector2i in plan.massif.columns:
		leftover += int(not owned.has(column))
	out["leftover_columns"] = leftover
	out["street_floor_gaps"] = plan.street_floor_gaps()


# --- Seeding and growth ----------------------------------------------------


static func _seed_buildings(plan: WarrenMazeSourcePlan, streets: Dictionary,
		blocked: Dictionary, claims: Dictionary, slots: Dictionary,
		refusals: Array[Dictionary]) -> Array[Dictionary]:
	## One seed per (column, band): a street cell claims each of its four
	## neighbour columns at its own band, which is exactly what lets an upper
	## street's house stack on the roof of the lower street's tiered house. A
	## pair is visited once, from the first street cell in walk order that
	## fronts it, and a refusal there is recorded rather than retried.
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
	## to the lowest id) takes its one best adjacent column and the loop runs
	## again. That column is either free rock or a BARE SEED at the same floor
	## -- a building of one column that never grew -- which is absorbed whole:
	## its cell joins, its id retires, and its door is dropped in favour of the
	## absorber's. Without absorption a warren where nearly every column fronts
	## a street partitions into one-column pencils, because seeding claims
	## everything before growth begins.
	##
	## A building that finds no candidate is stalled for good -- columns are
	## only claimed, never released, while growth runs -- so this terminates
	## after at most one stall per building plus one step per column.
	var limit := int(BUILDING_CAP.get(plan.scale_profile.scale_id, 4))
	var caps: Array[int] = []
	var stalled: Array[bool] = []
	stalled.resize(buildings.size())
	for index in buildings.size():
		caps.append(roll(plan, FOOTPRINT_SALT,
			buildings[index]["door"] as Vector3i, index, Vector2i(2, limit)))
	while true:
		var choice := -1
		var largest := 0
		for index in buildings.size():
			var building := buildings[index]
			var size := (building["cells"] as Array).size()
			if stalled[index] or bool(building["retired"]) \
					or size >= caps[index] or size <= largest:
				continue
			largest = size
			choice = index
		if choice < 0:
			break
		var building := buildings[choice]
		var pick := _best_join(plan, building, choice, streets, blocked,
			claims, slots, buildings)
		if pick.is_empty():
			stalled[choice] = true
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
	## absorbable bare seed, ranked alike by |top_at - floor| then column order
	## -- and the tier band taking it would bind.
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


static func _join(plan: WarrenMazeSourcePlan, column: Vector2i,
		floor_band: int, streets: Dictionary, blocked: Dictionary,
		claims: Dictionary, bound: int, absorb: bool) -> Dictionary:
	## May `column` carry a house at `floor_band`, and what tier band does that
	## bind? `reason` is "" when it joins; `tier` is -1 when it binds nothing,
	## otherwise the LOWEST street band the column hosts at or above the floor.
	## Only that lowest one matters: anything above it sits above the roof this
	## house will grow, so it is none of this footprint's business.
	##
	## Two strengthenings of the stated rule, both to keep the town sealable
	## rather than strict for its own sake: `blocked` holds every column an
	## asset, a deck, or a retained bridge span owns (a house under a deck
	## strands it -- a deck adds no solid mass, so everything above it floats --
	## and one under an asset strands the asset unless their bands meet), and
	## two houses may share a column only MIN_HOUSE_BANDS apart or more, so the
	## lower one's roof can always reach the upper one's floor. `absorb` waives
	## the second for the bare seed being swallowed, which claimed this very
	## band itself.
	if blocked.has(column) or not plan.massif.has_column(column):
		return {"tier": -1, "reason": "column already spoken for"}
	for other: int in claims.get(column, []) as Array:
		if absi(other - floor_band) < WarrenMazeSourcePlan.MIN_HOUSE_BANDS \
				and not (absorb and other == floor_band):
			return {"tier": -1, "reason": "claimed within MIN_HOUSE_BANDS"}
	if not plan.plot_support_ok(column, floor_band):
		return {"tier": -1, "reason": "support rule refuses this floor"}
	var tier := -1
	for band: int in streets.get(column, []) as Array:
		if band >= floor_band and (tier < 0 or band < tier):
			tier = band
	if tier < 0:
		return {"tier": -1, "reason": ""}
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
	## already standing when the house stacked on its roof asks the support rule
	## whether the band below it is solid. A building that does not stand gives
	## its claims back, so nothing above it is still capped by a roof that never
	## got built.
	var records: Array[Dictionary] = []
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
		var roof := _building_top(plan, streets, claims, building, index)
		var id := StringName(building["id"])
		var cells := building["cells"] as Array[Vector2i]
		cells.sort_custom(Callable(WarrenPlotPlanner, "column_less"))
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
		if String(record["reason"]) != "":
			for column: Vector2i in cells:
				_release(claims, column, floor_band)
		records.append(record)
	return records


static func _building_top(plan: WarrenMazeSourcePlan, streets: Dictionary,
		claims: Dictionary, building: Dictionary, index: int) -> Dictionary:
	## A roof is, in order of preference, the street running through this
	## footprint (the tier the whole model exists for), the lowest street past
	## its one-column apron, or the scale's seeded storey budget. It then has to
	## agree with whatever else is claimed above this floor on the same columns,
	## and a column it cannot agree with leaves the footprint -- hence the loop:
	## a smaller footprint sees a different street and a different ceiling.
	var floor_band := int(building["floor"])
	var minimum := floor_band + WarrenMazeSourcePlan.MIN_HOUSE_BANDS
	var reach := floor_band + MAX_TIER_BANDS
	# The parcel contract exactly: whole storeys plus the roof reservation, so
	# a house the translator receives already has a legal envelope. `index` is
	# in the hash, or the four houses around one street cell would be clones.
	var rolled := floor_band + WarrenBuildingParcel.ROOF_RESERVATION_BANDS \
		+ WarrenBuildingParcel.STOREY_BANDS * roll(plan, STOREY_SALT,
			building["door"] as Vector3i, index, STOREY_BUDGET.get(
				plan.scale_profile.scale_id, Vector2i(1, 2)))
	var cells := building["cells"] as Array[Vector2i]
	var street_top := -1
	var top := floor_band
	while true:
		# Re-derived from the columns that survived, never from the flag growth
		# bound: a shrunken footprint may have lost the street it meant to meet.
		street_top = _lowest_street(streets, cells, minimum, reach, false)
		if street_top < 0:
			street_top = _lowest_street(streets, cells, minimum, reach, true)
		top = street_top if street_top >= 0 else rolled
		# Something is claimed above this floor on one of these columns. Meet
		# it: a roof that stops short of the house stacked on it strands that
		# house, and the stack invariant fails the whole town for it. Two things
		# stop the climb -- a street carved through the gap, and MAX_TIER_BANDS.
		# Where a street stops it the mismatching column leaves the footprint;
		# where MAX_TIER_BANDS stops it this house keeps its own height and the
		# claim above is the one that gives way, refused at its own commit.
		var cap := _lowest_above(claims, cells, floor_band)
		if cap >= 0:
			top = cap if cap <= reach and _uncarved(plan, cells, floor_band,
				cap) else mini(top, cap)
		var dropped: Dictionary = {}
		for column: Vector2i in cells:
			var one := [column] as Array[Vector2i]
			var ceiling := _lowest_above(claims, one, floor_band)
			# A column whose own street stands above this roof has to go too:
			# the house would take the rock out from under that street and
			# leave its floor hanging, because above the lowest plot floor on a
			# column solid mass is plots and nothing else. Off the footprint,
			# the sealed rock shoulder keeps the street its ground.
			var street := _lowest_street(streets, one, minimum, reach, false)
			if ceiling >= 0 and (ceiling < minimum \
					or ceiling > top and ceiling <= reach) \
					or street > top:
				dropped[column] = true
		if dropped.is_empty() or cells.size() <= 1:
			break
		for column: Vector2i in dropped:
			_release(claims, column, floor_band)
		cells = _keep_component(cells, dropped, building["seed"] as Vector2i)
		building["cells"] = cells
	return {"top": top, "tiered": street_top >= 0 and top == street_top}


static func _lowest_street(streets: Dictionary, cells: Array[Vector2i],
		minimum: int, reach: int, apron: bool) -> int:
	## The lowest street band in [minimum, reach] running through these columns,
	## or -1. `apron` looks one column further out -- the difference between a
	## street crossing this roof and one running past it.
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


static func _uncarved(plan: WarrenMazeSourcePlan, cells: Array[Vector2i],
		from_band: int, to_band: int) -> bool:
	## Could a plot fill [from_band, to_band) on these columns at all, or does a
	## street run through it? Streets are immutable, so this is the one thing
	## that stops a roof from rising to meet the plot above it.
	for column: Vector2i in cells:
		if plan.first_carved_band(column, from_band, to_band) >= 0:
			return false
	return true


static func _lowest_above(claims: Dictionary, cells: Array[Vector2i],
		floor_band: int) -> int:
	## The lowest floor another house claims above this one on these columns, or
	## -1 when the sky is clear. Assets and decks never share a column with a
	## house (see _join), so houses are the whole story.
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


static func _release(claims: Dictionary, column: Vector2i, band: int) -> void:
	## Hand one claim back. A column a footprint dropped, or a building that
	## never stood, must stop capping the roofs beneath it.
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
	## Placed last, so an adjacent house sharing the bridge's own floor is
	## already standing and can lend it a building id.
	var records: Array[Dictionary] = []
	for index in plan.excavation.bridge_spans.size():
		var span: Array = plan.excavation.bridge_spans[index]
		var cells: Array[Vector2i] = []
		var floor_band := plan.passage_headroom_top(span[0] as Vector3i) \
			+ WarrenMazeSourcePlan.TUNNEL_ROOF_BANDS
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
		var record := {"id": id, "span": index, "cells": cells.size(),
			"floor": floor_band, "top": top, "building_id": owner,
			"reason": ""}
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


## The single audit record every phase writes into. Seal merges its own keys
## over the top without destroying this one.
static func outcomes(plan: WarrenMazeSourcePlan) -> Dictionary:
	if not plan.audit.has("plot_outcomes"):
		plan.audit["plot_outcomes"] = {"assets": [], "decks": [],
			"decks_short": 0, "seed_refusals": [], "buildings": [],
			"bridges": [], "leftover_columns": 0, "street_floor_gaps": 0}
	return plan.audit["plot_outcomes"] as Dictionary


## Street cells in the order the town is walked: the spine, then each lane from
## its anchor outward, then -- so nothing is ever missed -- whatever passage
## cells that walk did not reach, in sorted order.
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


## Columns nothing new may claim: whatever already carries a plot, plus the
## retained bridge spans. The carver kept that overhead mass precisely so a
## bridge could stand on it, so no earlier phase may build the column out from
## under it.
static func blocked_columns(plan: WarrenMazeSourcePlan) -> Dictionary:
	var out := owned_columns(plan)
	for span_value: Variant in plan.excavation.bridge_spans:
		for cell_value: Variant in span_value as Array:
			var cell := cell_value as Vector3i
			out[Vector2i(cell.x, cell.z)] = true
	return out


## One seeded integer in the inclusive range, from the lattice's own hash.
static func roll(plan: WarrenMazeSourcePlan, salt: int, cell: Vector3i,
		extra: int, range_value: Vector2i) -> int:
	return range_value.x + posmod(WarrenPassageLatticeRules.hash_key(
		plan.world_seed, salt, cell, extra),
		maxi(1, range_value.y - range_value.x + 1))


## Which column a growth step would rather have: the one whose envelope stands
## nearest the datum, then the one that sorts first.
static func closer(plan: WarrenMazeSourcePlan, a: Vector2i, b: Vector2i,
		datum: int) -> bool:
	var cost_a := absi(plan.massif.top_at(a) - datum)
	var cost_b := absi(plan.massif.top_at(b) - datum)
	return cost_a < cost_b if cost_a != cost_b else column_less(a, b)


## The lattice's column order: by z, then x.
static func column_less(a: Vector2i, b: Vector2i) -> bool:
	return a.x < b.x if a.y == b.y else a.y < b.y


static func _slot(column: Vector2i, band: int) -> Vector3i:
	## A (column, band) key -- one house per column per band, which is what
	## makes seeding and absorption agree about who owns what.
	return Vector3i(column.x, band, column.y)
