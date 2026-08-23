class_name WarrenMazeBlockPartitioner
extends RefCounted

## Translator from a sealed WarrenMazeSourcePlan's PLOTS into the parcel
## contract construction already consumes. The maze decided the public graph,
## the plot planner decided the town; nothing here enumerates, scores, or
## grows an alternative partition.
##
## One house or asset plot becomes ONE sealed WarrenBuildingParcel -- the
## largest rectangle inside that plot which can carry its own door -- and the
## cells the rectangle leaves over are that building's back rooms, recorded on
## the parcel plan for composition's residual-room machinery. Decks and
## bridges are typed records, never parcels: a deck has no height to build and
## a bridge's door is a covered passage cell.
##
## A plot whose door rectangle cannot seal is a GENERATOR bug -- a plot the
## planner should never have placed -- not a shape this stage may silently
## substitute or drop, so one untranslated plot fails the whole translation
## with its reason in `last_failure`.
const CARDINALS: Array[Vector2i] = [
	Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP,
]

static var last_failure := ""
static var last_diagnostic: Dictionary = {}


## Translates every plot of `source` against the volume adapted from it.
## Returns the sealed parcel plan, or null with `last_failure` set.
static func partition(source: WarrenMazeSourcePlan,
		volume: WarrenVolumePlan) -> WarrenParcelPlan:
	last_failure = ""
	last_diagnostic = {}
	if source == null or not source.is_sealed() or volume == null \
			or not volume.is_sealed() \
			or volume.mass_context.get(&"maze_source_plan") != source:
		last_failure = "missing or mismatched sealed maze source and volume"
		return null
	if source.plots.is_empty():
		last_failure = "sealed maze source carries no plots to translate"
		return null
	var parcels: Array[WarrenBuildingParcel] = []
	var back_rooms: Array[Dictionary] = []
	var decks: Array[Dictionary] = []
	var bridges: Array[Dictionary] = []
	var buildings: Dictionary = {}
	var untranslated: Array[Dictionary] = []
	var shrunk: Dictionary = {}
	for plot: Dictionary in source.plots:
		match StringName(plot["kind"]):
			WarrenMazeSourcePlan.PLOT_DECK:
				decks.append(_deck_record(plot))
			WarrenMazeSourcePlan.PLOT_BRIDGE:
				bridges.append(_bridge_record(plot))
			WarrenMazeSourcePlan.PLOT_HOUSE, WarrenMazeSourcePlan.PLOT_ASSET:
				var outcome := _parcel_for_plot(source, volume, plot)
				var parcel := outcome["parcel"] as WarrenBuildingParcel
				if parcel == null:
					untranslated.append({"id": StringName(plot["id"]),
						"kind": StringName(plot["kind"]),
						"reason": String(outcome["reason"])})
					continue
				# A plot whose winner was not its own largest rectangle gave
				# mass up, and giving mass up silently is how an ownership
				# regression hides: name it and why.
				if int(outcome["skipped"]) > 0:
					shrunk[String(plot["id"])] = outcome["reason"]
				parcels.append(parcel)
				var group := StringName(plot["building_id"])
				var members: Array = buildings.get(group,
					[] as Array[StringName])
				members.append(parcel.stable_id)
				buildings[group] = members
				var back := _back_room_record(plot, parcel)
				if not back.is_empty():
					back_rooms.append(back)
			_:
				untranslated.append({"id": StringName(plot["id"]),
					"kind": StringName(plot["kind"]),
					"reason": "unknown plot kind %s" % plot["kind"]})
	last_diagnostic = {
		"plot_count": source.plots.size(),
		"parcel_count": parcels.size(),
		"back_room_count": back_rooms.size(),
		"deck_count": decks.size(),
		"bridge_count": bridges.size(),
		"shrunk_parcel_count": shrunk.size(),
		"untranslated": untranslated,
	}
	if not untranslated.is_empty():
		var reasons := PackedStringArray()
		for record: Dictionary in untranslated:
			reasons.append("%s: %s" % [record["id"], record["reason"]])
		last_failure = "%d of %d plots did not translate (generator bug): %s" \
			% [untranslated.size(), source.plots.size(), "; ".join(reasons)]
		return null
	var plan := WarrenParcelPlan.new(
		StringName("%s.maze_parcels" % volume.stable_id), volume)
	if not plan.seal(parcels):
		last_failure = "maze parcel plan rejected: %s" % plan.last_rejection
		return null
	# WarrenParcelPlan.seal builds `audit` itself, so every plot fact lands
	# after it: composition reads the two through one dictionary.
	plan.audit["maze_back_rooms"] = back_rooms
	plan.audit["maze_decks"] = decks
	plan.audit["maze_bridges"] = bridges
	plan.audit["maze_buildings"] = buildings
	plan.audit["maze_untranslated"] = untranslated
	plan.audit["maze_shrunk_parcel_count"] = shrunk.size()
	plan.audit["maze_shrunk_parcels"] = shrunk
	var ownership := _ownership(source, parcels, back_rooms)
	plan.audit.merge(ownership, true)
	last_diagnostic.merge(ownership, true)
	return plan


static func _parcel_for_plot(source: WarrenMazeSourcePlan,
		volume: WarrenVolumePlan, plot: Dictionary) -> Dictionary:
	## The plot's own door, floor and top; the only open question is which
	## rectangle of its footprint carries the facade. Candidates come in
	## largest-first order and the first one whose real authored doorway opens
	## onto the plot's own street cell wins, so a plot always yields the
	## biggest buildable street-facing rectangle it can.
	##
	## Returns `{parcel, skipped, reason}`: `skipped` counts the LARGER
	## rectangles refused before the winner and `reason` names why the first
	## of them was refused, so shrinking is a published fact rather than a
	## silent substitution. A null parcel means every candidate was refused
	## and `reason` is the whole plot's refusal.
	var floor_band := int(plot["floor"])
	var top_band := int(plot["top"])
	var door_walk := plot["door_walk"] as Vector3i
	var stable_id := StringName("parcel.maze.%s" % String(plot["id"]))
	# Something stands ON this plot's roof, so the roof is a slab and owes the
	# storey grid nothing: either an upper street meets it (`tiered`, the case
	# the tier model exists for) or another plot occupies its own columns at
	# its top band (`not roofed` -- a stacked house, or a roof deck). The
	# planner produces both: `_building_top` sets a house's top to the street
	# it meets OR to the floor of whatever is claimed above it, and only the
	# first of those lands on the storey grid by construction. A plot with a
	# real roof of its own is untouched and still owes whole storeys plus its
	# roof reservation.
	var facts := source.plot_facts(plot)
	var flat_roof := bool(facts.get("tiered", false)) \
		or not bool(facts.get("roofed", true))
	var candidates := _rectangles(plot, door_walk)
	if candidates.is_empty():
		return {"parcel": null, "skipped": 0,
			"reason": "no street-facing rectangle inside the plot"}
	var first_refusal := ""
	for index in candidates.size():
		var candidate := candidates[index]
		var refusal := "footprint has no mass, no bearing, or an illegal " \
			+ "height here"
		for door_phase in 2:
			var parcel := WarrenBuildingParcel.new(stable_id,
				candidate["footprint"] as Array[Vector2i], floor_band,
				top_band, door_walk, candidate["threshold"] as Vector2i,
				candidate["frontage"] as Vector2i, door_phase, flat_roof)
			if not parcel.seal(volume):
				continue
			if WarrenParcelConstruction.door_serves_address(parcel):
				return {"parcel": parcel, "skipped": index,
					"reason": first_refusal}
			refusal = "no authored door module serves the address"
		if first_refusal == "":
			first_refusal = "%d columns at %s: %s" % [
				int(candidate["area"]), candidate["minimum"], refusal]
	return {"parcel": null, "skipped": candidates.size(),
		"reason": ("none of %d rectangles sealed on either door phase " \
			+ "(floor %d, top %d, flat_roof %s); largest: %s") % [
				candidates.size(), floor_band, top_band, flat_roof,
				first_refusal]}


static func _rectangles(plot: Dictionary,
		door_walk: Vector3i) -> Array[Dictionary]:
	## Every axis-aligned rectangle of plot cells that contains a threshold
	## column (a plot cell 4-adjacent to the door's own street cell) and obeys
	## the parcel shape rule -- deeper than it is wide, or the one authored
	## 2-wide by 1-deep rowhouse. Largest first, then deepest, then by
	## threshold and minimum corner, so the choice is a pure function of the
	## plot.
	var cells: Dictionary = {}
	var minimum := Vector2i(2147483647, 2147483647)
	var maximum := Vector2i(-2147483648, -2147483648)
	for cell_value: Variant in plot["cells"] as Array:
		var column := cell_value as Vector2i
		cells[column] = true
		minimum = minimum.min(column)
		maximum = maximum.max(column)
	var door_column := Vector2i(door_walk.x, door_walk.z)
	var out: Array[Dictionary] = []
	for direction: Vector2i in CARDINALS:
		var threshold := door_column - direction
		if not cells.has(threshold):
			continue
		for x0 in range(minimum.x, threshold.x + 1):
			for x1 in range(threshold.x, maximum.x + 1):
				for z0 in range(minimum.y, threshold.y + 1):
					for z1 in range(threshold.y, maximum.y + 1):
						var span := Vector2i(x1 - x0 + 1, z1 - z0 + 1)
						var depth := span.x if direction.x != 0 else span.y
						var width := span.y if direction.x != 0 else span.x
						if depth < width \
								and not (width == 2 and depth == 1):
							continue
						var footprint := _footprint(cells, Vector2i(x0, z0),
							Vector2i(x1, z1))
						if footprint.is_empty():
							continue
						out.append({"footprint": footprint,
							"threshold": threshold, "frontage": direction,
							"area": footprint.size(), "depth": depth,
							"minimum": Vector2i(x0, z0)})
	out.sort_custom(Callable(WarrenMazeBlockPartitioner,
		"_candidate_less"))
	return out


static func _footprint(cells: Dictionary, from_column: Vector2i,
		to_column: Vector2i) -> Array[Vector2i]:
	## The complete rectangle, or nothing at all when one of its columns is
	## not the plot's own.
	var out: Array[Vector2i] = []
	for x in range(from_column.x, to_column.x + 1):
		for z in range(from_column.y, to_column.y + 1):
			var column := Vector2i(x, z)
			if not cells.has(column):
				return []
			out.append(column)
	return out


static func _candidate_less(left: Dictionary, right: Dictionary) -> bool:
	if int(left["area"]) != int(right["area"]):
		return int(left["area"]) > int(right["area"])
	if int(left["depth"]) != int(right["depth"]):
		return int(left["depth"]) > int(right["depth"])
	if left["threshold"] != right["threshold"]:
		return _column_less(left["threshold"] as Vector2i,
			right["threshold"] as Vector2i)
	return _column_less(left["minimum"] as Vector2i,
		right["minimum"] as Vector2i)


static func _column_less(a: Vector2i, b: Vector2i) -> bool:
	return a.x < b.x if a.y == b.y else a.y < b.y


static func _back_room_record(plot: Dictionary,
		parcel: WarrenBuildingParcel) -> Dictionary:
	## The plot cells the facade rectangle did not take. Composition builds
	## them as rooms behind the addressed one; they are the same building, at
	## the same floor and top, without a street of their own.
	var cells: Array[Vector2i] = []
	for cell_value: Variant in plot["cells"] as Array:
		var column := cell_value as Vector2i
		if not parcel.footprint.has(column):
			cells.append(column)
	if cells.is_empty():
		return {}
	return {
		"building_id": StringName(plot["building_id"]),
		"parcel_id": parcel.stable_id,
		"cells": cells,
		"floor": int(plot["floor"]),
		"top": int(plot["top"]),
	}


static func _deck_record(plot: Dictionary) -> Dictionary:
	## A deck has no height, so it has nothing to parcel: composition lays a
	## courtyard, plaza or roof terrace on its floor band.
	return {
		"id": StringName(plot["id"]),
		"cells": (plot["cells"] as Array[Vector2i]).duplicate(),
		"floor": int(plot["floor"]),
		"door_walk": plot["door_walk"] as Vector3i,
	}


static func _bridge_record(plot: Dictionary) -> Dictionary:
	## A bridge spans a retained street; its `door_walk` is that covered
	## passage cell, which is public realm rather than an address, so it can
	## never be a parcel's own frontage.
	return {
		"id": StringName(plot["id"]),
		"cells": (plot["cells"] as Array[Vector2i]).duplicate(),
		"floor": int(plot["floor"]),
		"top": int(plot["top"]),
		"door_walk": plot["door_walk"] as Vector3i,
		"building_id": StringName(plot["building_id"]),
	}


static func _ownership(source: WarrenMazeSourcePlan,
		parcels: Array[WarrenBuildingParcel],
		back_rooms: Array[Dictionary]) -> Dictionary:
	## How much of the town above terrain the translation actually owns:
	## parcel cells plus back-room cells over every solid cell in
	## [massif.base_at, the column's own top). `rock_cells` is the rest of
	## that solid which no plot stands in -- interior structure and the rock
	## shoulders, which are derived mass rather than construction. Deck plots
	## are in neither bucket by design: they are typed records with no mass at
	## all ([floor, top) is empty for them).
	##
	## BRIDGE mass leaves the DENOMINATOR too (review finding 2026-08-23,
	## minor 15). A bridge is also a typed record -- it translates to an
	## occupied-link reservation, never to a parcel -- so no parcel or back
	## room can ever own its bands, and counting them as solid the
	## translation failed to own charged the ratio for mass nothing was ever
	## going to claim. A town with more skywalks scored worse for having
	## them. Bridge bands are now outside both buckets, exactly like decks.
	##
	## An audit fact, pinned nowhere here (the phase sweep and the plots suite
	## read it).
	var plot_bands: Dictionary = {}
	var bridge_bands: Dictionary = {}
	for plot: Dictionary in source.plots:
		var bridge := StringName(plot["kind"]) \
			== WarrenMazeSourcePlan.PLOT_BRIDGE
		for cell_value: Variant in plot["cells"] as Array:
			var column := cell_value as Vector2i
			var into := bridge_bands if bridge else plot_bands
			var spans: Array = into.get(column, [])
			spans.append(Vector2i(int(plot["floor"]), int(plot["top"])))
			into[column] = spans
	var solid_cells := 0
	var rock_cells := 0
	for column: Vector2i in source.massif.columns:
		var spans := plot_bands.get(column, []) as Array
		var bridges := bridge_bands.get(column, []) as Array
		for band in range(source.massif.base_at(column),
				source.column_ceiling(column)):
			if not source.solid_at(Vector3i(column.x, band, column.y)):
				continue
			if _band_inside(bridges, band):
				continue
			solid_cells += 1
			rock_cells += int(not _band_inside(spans, band))
	var parcel_cells := 0
	for parcel: WarrenBuildingParcel in parcels:
		parcel_cells += parcel.occupied_cells().size()
	var back_room_cells := 0
	for record: Dictionary in back_rooms:
		# Through solid_at, the same predicate the denominator counts: a
		# back room owns the mass that is really there, never a band of its
		# own plot that a street was bored through.
		for cell_value: Variant in record["cells"] as Array:
			var column := cell_value as Vector2i
			for band in range(int(record["floor"]), int(record["top"])):
				back_room_cells += int(source.solid_at(
					Vector3i(column.x, band, column.y)))
	var owned_cells := parcel_cells + back_room_cells
	return {
		"maze_ownership_ratio": float(owned_cells) \
			/ float(maxi(1, solid_cells)),
		"maze_owned_cells": owned_cells,
		"maze_solid_cells": solid_cells,
		"maze_rock_cells": rock_cells,
		"maze_parcel_cells": parcel_cells,
		"maze_back_room_cells": back_room_cells,
	}


static func _band_inside(spans: Array, band: int) -> bool:
	## Does `band` fall in any [x, y) span? One reading for both the bridge
	## exclusion and the rock split, so the two can never drift apart.
	for span: Vector2i in spans:
		if band >= span.x and band < span.y:
			return true
	return false
