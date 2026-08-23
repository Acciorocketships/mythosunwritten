class_name WarrenMazeBlockPartitioner
extends RefCounted

## Translator from a sealed WarrenMazeSourcePlan's PLOTS into the parcel
## contract construction already consumes. The maze decided the public graph,
## the plot planner decided the town; nothing here enumerates, scores, or
## grows an alternative partition.
##
## One HOUSE plot becomes ONE sealed WarrenBuildingParcel -- the largest
## rectangle inside that plot which can carry its own door -- and the cells
## the rectangle leaves over are that building's back rooms, recorded on the
## parcel plan for composition's residual-room machinery. Decks, bridges and
## assets are typed records, never parcels: a deck has no height to build, a
## bridge's door is a covered passage cell, and an ASSET is a complete
## authored building the planner already chose a recipe for (controller
## ruling, 2026-08-23). Parcelling an asset would ask the room grammar to
## invent walls for a prefab that ships with its own; composition instead
## reserves it as a prefab landmark from `maze_assets`.
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
	var assets: Array[Dictionary] = []
	var buildings: Dictionary = {}
	var untranslated: Array[Dictionary] = []
	var shrunk: Dictionary = {}
	var recipe_by_asset := _recipe_by_asset(source)
	# A plot standing on another plot's top band is a building ON a building,
	# and the parcel has to SAY so before it seals: left undeclared it claims
	# terrain bearing and `WarrenParcelConstruction` descends its whole room
	# stack straight through the house underneath. Houses are therefore built
	# in FLOOR order, so a parent parcel (and its own storey count) always
	# exists before the child that names it. Only the build order moves: every
	# array below is still emitted in the source's own plot order.
	var stacking := stack_parents(source)
	var stack_refusals: Dictionary = {}
	var house_outcomes := _translate_houses(source, volume,
		stacking["parents"] as Dictionary, stack_refusals)
	for plot: Dictionary in source.plots:
		match StringName(plot["kind"]):
			WarrenMazeSourcePlan.PLOT_DECK:
				decks.append(_deck_record(plot))
			WarrenMazeSourcePlan.PLOT_BRIDGE:
				bridges.append(_bridge_record(plot))
			WarrenMazeSourcePlan.PLOT_ASSET:
				var kind_id := StringName(recipe_by_asset.get(
					StringName(plot["id"]), &""))
				if kind_id.is_empty():
					untranslated.append({"id": StringName(plot["id"]),
						"kind": StringName(plot["kind"]),
						"reason": "asset plot names no catalog recipe"})
					continue
				assets.append(_asset_record(plot, kind_id))
			WarrenMazeSourcePlan.PLOT_HOUSE:
				var outcome := house_outcomes[
					StringName(plot["id"])] as Dictionary
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
		"asset_count": assets.size(),
		"shrunk_parcel_count": shrunk.size(),
		"stacked_parcel_count": (stacking["parents"] as Dictionary).size() \
			- stack_refusals.size(),
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
	plan.audit["maze_assets"] = assets
	plan.audit["maze_buildings"] = buildings
	plan.audit["maze_untranslated"] = untranslated
	plan.audit["maze_shrunk_parcel_count"] = shrunk.size()
	plan.audit["maze_shrunk_parcels"] = shrunk
	plan.audit["maze_stacked_parcel_count"] = \
		(stacking["parents"] as Dictionary).size() - stack_refusals.size()
	# The same two facts under names that cannot be misread: how many plots
	# the PLANNER stacked, and how many of those seams the translation really
	# declared. The pair is what a reader needs to tell "the planner grew no
	# stacks" from "every stack was refused".
	plan.audit["maze_stacked_plot_count"] = \
		(stacking["parents"] as Dictionary).size()
	plan.audit["maze_declared_stack_count"] = \
		(stacking["parents"] as Dictionary).size() - stack_refusals.size()
	plan.audit["maze_partial_stack_count"] = int(stacking["partial_count"])
	plan.audit["maze_stack_refusal_count"] = stack_refusals.size()
	plan.audit["maze_stack_slab_gap_count"] = _slab_gap_count(stack_refusals)
	plan.audit["maze_stack_refusals"] = stack_refusals
	# Child parcel id -> the parcel it stands on, published so the seam can be
	# checked against the sealed plan itself rather than trusted: every value
	# here must name a house parcel the translation really emitted.
	plan.audit["maze_stack_parents"] = _stack_parcel_ids(
		stacking["parents"] as Dictionary)
	# TASK C5 RULING 4 -- the plot's own bearing fact, per parcel. A house
	# whose every column has solid under its floor and no other plot occupying
	# that band stands on ROCK or terrain and wears the stone base; a house
	# standing on another house does not, because what carries it is that
	# house's slab. Composition reads this where it decides a stamp's
	# `terrain_bearing`; nothing here re-derives the rule.
	plan.audit["maze_parcel_bears_on_rock"] = _bears_on_rock_by_parcel(source)
	var ownership := _ownership(source, parcels, back_rooms, assets)
	plan.audit.merge(ownership, true)
	last_diagnostic.merge(ownership, true)
	return plan


## Does something STAND ON this plot's roof, so that the roof is a slab and
## owes the storey grid nothing? Either an upper street meets it (`tiered`, the
## case the tier model exists for) or another plot occupies its own columns at
## its top band (`not roofed` -- a stacked house, or a roof deck).
##
## THE ONE OWNER OF THE RULE. The translator decides a parcel's `flat_roof`
## with it, and `WarrenVolumetricSolver` asks it twice more -- once to retain a
## stack parent's slab before composition, once to decide whether a bridge's
## flank presents a flat surface -- so three readings of "tiered or not roofed"
## can never drift apart.
static func plot_is_flat_roofed(source: WarrenMazeSourcePlan,
		plot: Dictionary) -> bool:
	if source == null or plot.is_empty():
		return false
	var facts := source.plot_facts(plot)
	return bool(facts.get("tiered", false)) \
		or not bool(facts.get("roofed", true))


static func _bears_on_rock_by_parcel(
		source: WarrenMazeSourcePlan) -> Dictionary:
	## Parcel id -> `plot_facts(plot).bears_on_rock`, for every house plot the
	## translation could name a parcel for. Published rather than recomputed
	## downstream: the fact belongs to the source plan and this is the one
	## place that reads it into parcel vocabulary.
	var out: Dictionary = {}
	for plot: Dictionary in source.plots:
		if StringName(plot["kind"]) != WarrenMazeSourcePlan.PLOT_HOUSE:
			continue
		out[StringName("parcel.maze.%s" % String(plot["id"]))] = bool(
			source.plot_facts(plot).get("bears_on_rock", false))
	return out


static func stack_parents(source: WarrenMazeSourcePlan) -> Dictionary:
	## `{parents: {house plot id -> the house plot it stands ON},
	## partial_count: int}`.
	##
	## A house plot is STACKED when one other plot's `[floor, top)` contains
	## `floor - 1` on EVERY one of its columns. Partial stacking -- some
	## columns over a plot, or columns over two different plots -- is NOT a
	## seam: there is no single parent to name and no single top storey to bear
	## on, so those plots stay exactly as they are today (terrain-borne) and
	## are counted instead of guessed at.
	##
	## ONLY A HOUSE CAN BE A PARENT. A bridge and an asset both translate to
	## typed records and never to parcels, so naming one as a support parent
	## would name a `parcel.maze.<id>` that does not exist: the child would
	## find nothing, fall through terrain-borne with no refusal published, and
	## the stacked count would be an overcount of plots that never declared
	## anything (review finding 2026-08-23, Important 1). A deck has no height
	## to stand on in the first place.
	var parents: Dictionary = {}
	var partial := 0
	for plot: Dictionary in source.plots:
		if StringName(plot["kind"]) != WarrenMazeSourcePlan.PLOT_HOUSE:
			continue
		var floor_band := int(plot["floor"])
		var lower: Dictionary = {}
		var uncovered := false
		for cell_value: Variant in plot["cells"] as Array:
			var column := cell_value as Vector2i
			var covered := false
			for other: Dictionary in source.plots:
				if StringName(other["id"]) == StringName(plot["id"]) \
						or StringName(other["kind"]) \
							!= WarrenMazeSourcePlan.PLOT_HOUSE \
						or not (other["cells"] as Array).has(column) \
						or floor_band - 1 < int(other["floor"]) \
						or floor_band - 1 >= int(other["top"]):
					continue
				lower[StringName(other["id"])] = true
				covered = true
			uncovered = uncovered or not covered
		if lower.is_empty():
			continue
		if uncovered or lower.size() != 1:
			partial += 1
			continue
		parents[StringName(plot["id"])] = StringName(lower.keys()[0])
	return {"parents": parents, "partial_count": partial}


static func _translate_houses(source: WarrenMazeSourcePlan,
		volume: WarrenVolumePlan, parents: Dictionary,
		refusals: Dictionary) -> Dictionary:
	## Every house plot's translation outcome, keyed by plot id, built in FLOOR
	## order so a stacked child always finds its parent already sealed.
	##
	## A child that cannot seal WITH its declared parent falls back to the
	## terrain-borne parcel it is today rather than failing the whole town, and
	## the fall-back is named in `refusals`. Silent substitution is what this
	## translator refuses everywhere else, so it is recorded here too.
	var order: Array[Dictionary] = []
	for plot: Dictionary in source.plots:
		if StringName(plot["kind"]) == WarrenMazeSourcePlan.PLOT_HOUSE:
			order.append(plot)
	order.sort_custom(Callable(WarrenMazeBlockPartitioner, "_floor_less"))
	var parcel_by_id: Dictionary = {}
	var out: Dictionary = {}
	for plot: Dictionary in order:
		var plot_id := StringName(plot["id"])
		var parent := parcel_by_id.get(StringName("parcel.maze.%s" \
			% String(parents.get(plot_id, &"")))) as WarrenBuildingParcel
		var child_floor := int(plot["floor"])
		var seam_is_legible := parent != null \
			and (child_floor == parent.roof_base_band() \
				or parent.flat_roof and child_floor == parent.top_band)
		if parent != null and not seam_is_legible:
			# THE SLAB IS CONSTRUCTION SINCE TASK C5, but only where the plot
			# model really built it. A flat-roofed parent fills its plot: its
			# rooms reach `roof_base_band()`, the authored one-band
			# `roof.flat.*` unit sits on them, and any remaining band is the
			# retained stone parapet `WarrenVolumetricSolver
			# ._retain_maze_slab_courses` marks STRUCTURAL_VOLUME before
			# composition. A child standing on `top_band` therefore stands on
			# something, and `WarrenRoomCompositionPlanner` can see it.
			#
			# A child at any OTHER band still rests on nothing -- there is no
			# slab there to bear on -- so it stays terrain-borne exactly as it
			# was, and the gap is published rather than guessed at.
			refusals[String(plot_id)] = ("%s leaves a %d-band unbuilt slab " \
				+ "gap between its own construction and this floor") % [
					parent.stable_id, child_floor - parent.top_band \
						if parent.flat_roof \
						else child_floor - parent.roof_base_band()]
			parent = null
		if parent != null and not _parent_owns_its_top_storey(parent):
			# `WarrenParcelPlan._building_support_is_valid` measures the
			# parent's top storey through `WarrenParcelConstruction.proposal`,
			# which counts the storeys a fully borne parcel DESCENDS through as
			# well as its own. Where those two disagree the seam the ruling
			# names (`storey_count() - 1`) is not the storey the plan would
			# accept, and declaring it anyway would reject the town.
			refusals[String(plot_id)] = ("parent %s descends below its own " \
				+ "floor, so its top storey is not storey_count() - 1") \
				% parent.stable_id
			parent = null
		var outcome := _parcel_for_plot(source, volume, plot, parent)
		if parent != null and outcome["parcel"] == null:
			refusals[String(plot_id)] = "stacked on %s: %s" % [
				parent.stable_id, outcome["reason"]]
			outcome = _parcel_for_plot(source, volume, plot, null)
		out[plot_id] = outcome
		var parcel := outcome["parcel"] as WarrenBuildingParcel
		if parcel != null:
			parcel_by_id[parcel.stable_id] = parcel
	return out


static func _stack_parcel_ids(parents: Dictionary) -> Dictionary:
	## The plot-id stacking map restated in parcel ids, which is the vocabulary
	## every consumer of the seam speaks.
	var out: Dictionary = {}
	for child_value: Variant in parents.keys():
		out[StringName("parcel.maze.%s" % String(child_value))] = StringName(
			"parcel.maze.%s" % String(parents[child_value]))
	return out


static func _slab_gap_count(refusals: Dictionary) -> int:
	## How many stacked plots stayed terrain-borne because their parent builds
	## nothing at the band they stand on. A separate count from the whole
	## refusal set: before Task C5 made the flat slab real construction this
	## was every stack in the corpus, and it is the number that says whether
	## the plot model and the composition still disagree about where a
	## building stops.
	var out := 0
	for reason_value: Variant in refusals.values():
		out += int(String(reason_value).contains("unbuilt slab gap"))
	return out


static func _parent_owns_its_top_storey(parent: WarrenBuildingParcel) -> bool:
	var proposal := WarrenParcelConstruction.proposal(parent)
	return not proposal.is_empty() \
		and int(proposal["storeys"]) == parent.storey_count()


static func _floor_less(left: Dictionary, right: Dictionary) -> bool:
	if int(left["floor"]) != int(right["floor"]):
		return int(left["floor"]) < int(right["floor"])
	return String(left["id"]) < String(right["id"])


static func _parcel_for_plot(source: WarrenMazeSourcePlan,
		volume: WarrenVolumePlan, plot: Dictionary,
		support_parent: WarrenBuildingParcel = null) -> Dictionary:
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
	var flat_roof := plot_is_flat_roofed(source, plot)
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
			# The seam is declared BEFORE the seal: it decides the support
			# mode, and `WarrenParcelConstruction._support_base_band` reads it
			# to keep the room stack at this plot's own floor instead of
			# descending it through the house underneath.
			if support_parent != null and not parcel.set_building_support(
					support_parent.stable_id,
					support_parent.storey_count() - 1):
				continue
			if not parcel.seal(volume):
				continue
			# The plot below is what this plot STANDS on, but the parcel below
			# is only that plot's own door rectangle. Ask the plan's own seam
			# rule whether this rectangle really bears on it -- a rectangle
			# that overhangs the parent's footprint is not a stacked house,
			# and declaring it would make `WarrenParcelPlan.seal` refuse the
			# whole town. Largest-first order means this picks the biggest
			# rectangle that CAN bear.
			if support_parent != null \
					and not WarrenParcelPlan.building_support_is_valid(parcel,
						support_parent):
				refusal = "no rectangle bears on the parent's own footprint"
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


static func _recipe_by_asset(source: WarrenMazeSourcePlan) -> Dictionary:
	## plot id -> the `prefab_anchor` recipe the reservation pass chose for it.
	## The plot itself carries only the macro footprint the template implied;
	## which recipe that template stands for lives in the planner's own
	## outcome record, and composition needs the recipe, not the template.
	var out: Dictionary = {}
	var outcomes := source.audit.get("plot_outcomes", {}) as Dictionary
	for record_value: Variant in outcomes.get("assets", []) as Array:
		# A quota slot with no site left is a null record, not a plot: it
		# never reached `add_plot`, so there is nothing here to name.
		var record := record_value as Dictionary
		if record.get("site", null) == null:
			continue
		var site := record["site"] as Dictionary
		out[StringName(site["id"])] = StringName(record["kind_id"])
	return out


static func _asset_record(plot: Dictionary, kind_id: StringName) -> Dictionary:
	## A complete authored building at the site the planner costed for it.
	## `kind_id` is the catalog recipe composition must realise; `door_walk`
	## is the street cell its entrance has to open onto, at `floor`.
	return {
		"id": StringName(plot["id"]),
		"kind_id": kind_id,
		"cells": (plot["cells"] as Array[Vector2i]).duplicate(),
		"floor": int(plot["floor"]),
		"top": int(plot["top"]),
		"door_walk": plot["door_walk"] as Vector3i,
		"building_id": StringName(plot["building_id"]),
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
		back_rooms: Array[Dictionary],
		assets: Array[Dictionary]) -> Dictionary:
	## How much of the town above terrain the translation actually owns:
	## parcel cells plus back-room cells plus ASSET cells over every solid
	## cell in [massif.base_at, the column's own top). `rock_cells` is the
	## rest of that solid which no plot stands in -- interior structure and
	## the rock shoulders, which are derived mass rather than construction.
	## Deck plots are in neither bucket by design: they are typed records with
	## no mass at all ([floor, top) is empty for them).
	##
	## An asset is a typed record rather than a parcel, but unlike a deck or a
	## bridge it is real occupied mass the translation DID dispose of, so it
	## belongs in the numerator exactly as a back room does. Leaving it out
	## would charge the ratio for a landmark the town actually builds.
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
	# Through solid_at, the same predicate the denominator counts: a back room
	# or an asset owns the mass that is really there, never a band of its own
	# plot that a street was bored through.
	var back_room_cells := _record_solid_cells(source, back_rooms)
	var asset_cells := _record_solid_cells(source, assets)
	var owned_cells := parcel_cells + back_room_cells + asset_cells
	return {
		"maze_ownership_ratio": float(owned_cells) \
			/ float(maxi(1, solid_cells)),
		"maze_owned_cells": owned_cells,
		"maze_solid_cells": solid_cells,
		"maze_rock_cells": rock_cells,
		"maze_parcel_cells": parcel_cells,
		"maze_back_room_cells": back_room_cells,
		"maze_asset_cells": asset_cells,
	}


static func _record_solid_cells(source: WarrenMazeSourcePlan,
		records: Array[Dictionary]) -> int:
	## Solid bands inside every record's own [floor, top) span.
	var out := 0
	for record: Dictionary in records:
		for cell_value: Variant in record["cells"] as Array:
			var column := cell_value as Vector2i
			for band in range(int(record["floor"]), int(record["top"])):
				out += int(source.solid_at(
					Vector3i(column.x, band, column.y)))
	return out


static func _band_inside(spans: Array, band: int) -> bool:
	## Does `band` fall in any [x, y) span? One reading for both the bridge
	## exclusion and the rock split, so the two can never drift apart.
	for span: Vector2i in spans:
		if band >= span.x and band < span.y:
			return true
	return false
