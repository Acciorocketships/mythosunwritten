class_name WarrenMazeSourcePlan
extends RefCounted

## Sealed, resource-free authority for the solid-first maze front end. It
## records what the carver constructed; downstream adapters may translate it,
## but may not infer or repair its topology.
enum CellState { SOLID, PASSAGE, AIR }

const PASSAGE_SPINE := &"spine"
const PASSAGE_ALLEY := &"alley"
const PASSAGE_MARKET := &"market"
const PASSAGE_KINDS: Array[StringName] = [
	PASSAGE_SPINE, PASSAGE_ALLEY, PASSAGE_MARKET,
]
const MIN_HOUSE_BANDS := 4
const MAX_SPINE_STRAIGHT_RUN := 6
const MAX_ALLEY_STRAIGHT_RUN := 4

## The four things a plot can be (2026-08-21 plot-model design). A deck is a
## plot with zero height, a bridge is a plot whose floor is a street's own
## headroom top, an asset is a plot with a catalog footprint, and a house is
## anything the partition grows.
const PLOT_HOUSE := &"house"
const PLOT_ASSET := &"asset"
const PLOT_DECK := &"deck"
const PLOT_BRIDGE := &"bridge"
const PLOT_KINDS: Array[StringName] = [
	PLOT_HOUSE, PLOT_ASSET, PLOT_DECK, PLOT_BRIDGE,
]
## The minimum slab a COVERED passage keeps overhead: one band of retained
## mass between a tunnel's own headroom and whatever stands on it. A sealed
## rock shoulder never cuts below it, and a plot bearing on a tunnel roof
## sits exactly this far above that passage's headroom top. The one copy in
## the codebase: WarrenPlotPlanner and WarrenBuildingParcel both read it here.
const TUNNEL_ROOF_BANDS := 1

var world_seed: int
var scale_profile: WarrenVillageScaleProfile
var massif: WarrenMassif
var excavation: WarrenExcavation
var passage_kinds: Dictionary = {}
var market_zone: Array[Vector3i] = []
## One deliberately broad 2x2 public floor. Unlike an accidental plaza, every
## cell is named before the source seals and the common volume adapter carries
## the same typed exception into its breadth audit.
var market_square_cells: Array[Vector3i] = []
var feature_stamps: Array[Dictionary] = []
var summit_cell := Vector3i.ZERO
var block_thickness: Dictionary = {}
var audit: Dictionary = {}
var last_rejection := ""
var _sealed := false

## The town as plots (2026-08-21 plot-model design): {id: StringName, kind:
## StringName, cells: Array[Vector2i], floor: int, top: int, door_walk:
## Vector3i, building_id: StringName}. ROCK IS NEVER STORED -- solid_at
## derives it from these plus the massif, so this array plus the excavation is
## the whole town. Append through add_plot, which is the only thing that
## checks the support rule.
var plots: Array[Dictionary] = []
## Vector2i column -> Array[int] of indices into `plots`. Keeps solid_at O(the
## plots standing on one column) rather than O(the whole town).
var _plot_columns: Dictionary = {}
## Vector2i column -> int: the derived rock top of a column carrying NO plot,
## computed once at seal (see rock_shoulder). Empty while the plan is
## unsealed, where the massif envelope answers instead.
var _rock_shoulders: Dictionary = {}


func _init(p_world_seed: int, p_profile: WarrenVillageScaleProfile,
		p_massif: WarrenMassif, p_excavation: WarrenExcavation) -> void:
	world_seed = p_world_seed
	scale_profile = p_profile
	massif = p_massif
	excavation = p_excavation


func mark_passage(cell: Vector3i, kind: StringName) -> bool:
	if _sealed or kind not in PASSAGE_KINDS:
		return false
	if passage_kinds.has(cell) and passage_kinds[cell] != kind:
		return false
	passage_kinds[cell] = kind
	return true


## The real, per-cell top of a passage cell's own carved headroom slot --
## cell.y + excavation.slot_bands(cell) -- controller ruling (2026-08-22):
## NOT cell.y + WarrenExcavation.HEADROOM_BANDS, which undercounts a
## stair/ramp intermediate stride cell's own taller carved slot (it carries
## both treads, one band more than a plain LEVEL cell -- see
## WarrenExcavation.slot_bands' own header). This is the ONE source of truth
## every headroom-measuring rule in this file and in WarrenPlotPlanner must
## use instead of re-deriving the constant-based approximation that used to
## certify a plot as bearing on what a stair-adjacent column's real carved
## slot still shows as open air.
## HEADROOM_BANDS itself stays meaningful only where it genuinely names a
## MINIMUM (e.g. the carver's own span-legality mass check) -- never as a
## stand-in for a specific cell's own real headroom.
func passage_headroom_top(cell: Vector3i) -> int:
	return cell.y + excavation.slot_bands(cell)


func seal() -> bool:
	last_rejection = ""
	if _sealed or scale_profile == null or not scale_profile.validate() \
			or massif == null or not massif.is_sealed() or excavation == null \
			or not excavation.is_sealed():
		return _reject("missing sealed profile, massif, or excavation")
	var public := excavation.public_cells()
	if public.size() != passage_kinds.size():
		return _reject("%d public cells disagree with %d passage claims" % [
			public.size(), passage_kinds.size()])
	for cell: Vector3i in public:
		if not passage_kinds.has(cell):
			return _reject("public cell %s has no passage kind" % cell)
	if market_zone.is_empty() or market_zone.size() > excavation.route.size():
		return _reject("market zone is empty or longer than the spine")
	if not _has_typed_square(market_square_cells):
		return _reject("universal market is not one typed 2x2 square")
	if excavation.portals.size() != 1 \
			or excavation.portals[0] != excavation.route[0] \
			or not WarrenPassageLatticeRules.opens_to_exterior(
				massif, excavation.route[0]):
		return _reject("v1 requires one exterior entrance at the spine mouth")
	for index in market_zone.size():
		var cell := market_zone[index]
		if excavation.route[index] != cell \
				or passage_kinds.get(cell, &"") != PASSAGE_SPINE \
				or not WarrenPassageLatticeRules.is_at_grade(massif, cell):
			return _reject("market cell %s is not the spine's ground prefix" % cell)
	var market_touches_approach := false
	for cell: Vector3i in market_square_cells:
		if passage_kinds.get(cell, &"") not in [PASSAGE_SPINE, PASSAGE_MARKET]:
			return _reject("market square cell %s has no market passage claim" % cell)
		market_touches_approach = market_touches_approach or cell in market_zone
	if not market_touches_approach:
		return _reject("market square is detached from its spine approach")
	if summit_cell != excavation.route.back():
		return _reject("summit arrival is not the spine terminus")
	if excavation.loop_edges.is_empty():
		return _reject("public passage graph is a branch tree without a loop join")
	for column: Vector2i in massif.columns:
		if not block_thickness.has(column):
			return _reject("column %s has no block-thickness classification" % column)
	# The plot phases already wrote audit facts before seal runs (the plot
	# planner's own `plot_outcomes`); seal contributes its own freshly
	# computed keys, it never destroys theirs.
	var built := _build_audit()
	audit.merge(built, true)
	if int(audit.get("max_spine_straight_run", 0)) \
			> MAX_SPINE_STRAIGHT_RUN \
			or int(audit.get("max_alley_straight_run", 0)) \
				> MAX_ALLEY_STRAIGHT_RUN:
		return _reject("a passage exceeds its straight-run cap")
	if float(audit.get("frontage_ratio", 0.0)) < 0.90:
		return _reject("frontage %.3f is below the 0.900 source floor" \
			% float(audit.frontage_ratio))
	# The plot model's own invariants (2026-08-21 design): solids contiguous
	# from terrain on every column, every plot still supported, no plot
	# standing in a carved street's headroom, plots pairwise disjoint. A town
	# with no plots satisfies all four trivially. Deliberately the LAST check:
	# it is the only one that leaves a cache behind (the sealed rock
	# shoulders), so this is the only rejecting return that has to throw one
	# away, and a rejected seal always leaves the plan as open as it found it.
	var plot_failure := _plot_rejection()
	if plot_failure != "":
		_rock_shoulders.clear()
		return _reject(plot_failure)
	# Rules become repairs: a street whose own floor is not solid is an audit
	# fact here, never a rejection. Both facts are measured AFTER the plot
	# checks, which is what builds the sealed rock shoulders they read.
	audit["street_floor_gaps"] = _street_floor_gaps()
	audit["exterior_rock_ratio"] = exterior_rock_ratio()
	_sealed = true
	return true


func is_sealed() -> bool:
	return _sealed


## The three-state reading of one cell, for the two review harnesses that
## paint a town: a carved street cell is PASSAGE, anything `solid_at` calls
## mass is SOLID, and everything else -- carved headroom, the air above a
## roof, a column outside the massif -- is AIR. A thin wrapper over the
## derivation and nothing more: the plot model answers "is there mass here",
## and this only names the answer in the vocabulary a renderer wants.
func state_at(cell: Vector3i) -> CellState:
	if passage_kinds.has(cell):
		return CellState.PASSAGE
	if solid_at(cell):
		return CellState.SOLID
	return CellState.AIR


# --- Plot model ------------------------------------------------------------
# The 2026-08-21 plot-model design: one plot concept, rock derived rather than
# stored, and one support rule that replaces bearing, plinth, flush-stack,
# tunnel-roof, and per-cell headroom. This is the whole town: the reservation
# pass, the stamp pass, and the edit ledger they shared are gone (task B4).


## Adds one plot, after checking everything the model can check about it: its
## shape (every key present and typed, a non-empty 4-connected footprint of
## unique columns, top >= floor, a deck exactly flat, an unused id), the one
## support rule on every column, that no carved cell stands inside the band
## interval it occupies, and that it stays disjoint from the plots already on
## those columns. Stores a COPY, so a caller may reuse and mutate its own
## dictionary. False with `last_rejection` naming the failed rule otherwise;
## a sealed plan accepts nothing.
##
## `top` is NOT clamped to the massif: the envelope is a planning reference
## and the rock of a column with no plot, never a ceiling.
func add_plot(plot: Dictionary) -> bool:
	# FIRST, before anything below touches state: a sealed plan is finished,
	# and a refused plot may not move so much as a cached band of it. The
	# shoulders below it are the sealed town's own derivation and nothing
	# rebuilds them once _sealed is true.
	if _sealed:
		return _reject("plan is sealed; no plot may be added")
	last_rejection = ""
	# Sealed shoulders describe a FINISHED town. seal() already throws its
	# own cache away on the one path that can leave one behind (its plot
	# checks run last for exactly that reason), so this is the belt to that
	# brace: however seal's checks are ever reordered, a plot on an OPEN plan
	# is judged against the envelope that is really standing, never against
	# the shoulders of an attempt that failed.
	_rock_shoulders.clear()
	var shape := _plot_shape_rejection(plot)
	if shape != "":
		return _reject(shape)
	var placement := _plot_placement_rejection(plot, -1)
	if placement != "":
		return _reject(placement)
	var cells: Array[Vector2i] = []
	cells.assign(plot["cells"])
	plots.append({
		"id": StringName(plot["id"]),
		"kind": StringName(plot["kind"]),
		"cells": cells,
		"floor": int(plot["floor"]),
		"top": int(plot["top"]),
		"door_walk": plot["door_walk"] as Vector3i,
		"building_id": StringName(plot["building_id"]),
	})
	for column: Vector2i in cells:
		var indices: Array = _plot_columns.get(column, [])
		indices.append(plots.size() - 1)
		_plot_columns[column] = indices
	return true


## The one support rule. A plot may occupy `cell` at `floor` when
##
##   1. the band below the floor is solid -- rock, a retained tunnel-roof
##      slab, or another plot's top (solid_at answers all three), and
##   2. no carved air stands in the MIN_HOUSE_BANDS of clearance above it.
##
## Rule 2 is CLEARANCE, not "above every passage in this column" (controller
## ruling, 2026-08-22): a house tiered under an upper street has that street's
## own band as its top and must stay legal. Its consequence at the bottom end
## is that a plot can never sit AT a passage's headroom top -- the band below
## it would be carved -- so a tunnel-roof or bridge plot sits one band higher,
## on the retained roof slab that is its rock.
func plot_support_ok(cell: Vector2i, floor: int) -> bool:
	if not solid_at(Vector3i(cell.x, floor - 1, cell.y)):
		return false
	return _first_carved_band(cell, floor, floor + MIN_HOUSE_BANDS) < 0


## Derived solid mass; rock is never stored. A carved street cell or its
## headroom is air, a band inside some plot's [floor, top) is that plot's own
## mass, everything below the lowest plot floor on the column is rock down to
## the terrain, and a column carrying no plot is rock up to its shoulder.
## Everything else is air -- including the envelope standing above a plot's
## top, which is exactly the mass the old skyline trim used to have to remove.
##
## Terrain is solid (controller ruling, 2026-08-22): below massif.base_at the
## ground is untouched sample, which is what lets a house fronting a grade
## street stand at floor == base_at. A column outside the massif is air
## everywhere. A deck contributes nothing here: its [floor, top) is empty.
func solid_at(cell: Vector3i) -> bool:
	if passage_kinds.has(cell):
		return false
	if excavation != null and excavation.carved.has(cell):
		return false
	var column := Vector2i(cell.x, cell.z)
	if massif == null or not massif.has_column(column):
		return false
	if cell.y < massif.base_at(column):
		return true
	var indices: Array = _plot_columns.get(column, [])
	if indices.is_empty():
		return cell.y < rock_shoulder(column)
	for index: int in indices:
		var plot := plots[index] as Dictionary
		if cell.y >= int(plot["floor"]) and cell.y < int(plot["top"]):
			return true
	return cell.y < _lowest_plot_floor(column)


## The top of derived rock on `column`.
##
## A column that carries plots of its own answers with its lowest plot floor:
## rock fills the column from terrain up to the building standing on it.
##
## A column with no plot answers the massif envelope while the plan is
## UNSEALED -- the envelope stands during planning, or nothing could ever be
## placed on it -- and, once SEALED, the lowest plot floor bordering the
## connected no-plot region this column belongs to, so leftover rock steps
## down to meet the town instead of towering over it. A region that touches no
## plot at all keeps its envelope. A column outside the massif carries no rock
## at all.
func rock_shoulder(column: Vector2i) -> int:
	if massif == null or not massif.has_column(column):
		return 0
	if _plot_columns.has(column):
		return _lowest_plot_floor(column)
	if _rock_shoulders.has(column):
		return int(_rock_shoulders[column])
	return massif.top_at(column)


## Instrumentation for the unclamped shoulder (review finding 2026-08-23,
## minor 5): the columns carrying NO plot whose sealed `rock_shoulder` stands
## ABOVE their own massif envelope, in column order. `rock_shoulder` has no
## upper clamp -- a no-plot region takes the LOWEST floor of the plots
## bordering it, and `_street_rock_floors` can raise it further so a passage
## keeps its ground -- so leftover rock may legitimately grow past the terrace
## it started from. Nothing rejects that; the `--constructive` sweep reports
## this count per town, so a clamp can be argued from measurement rather than
## from suspicion. Empty on an unsealed plan, where every no-plot column
## answers its envelope by definition.
func raised_shoulder_columns() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if massif == null:
		return out
	var columns: Array[Vector2i] = []
	columns.assign(massif.columns.keys())
	columns.sort_custom(Callable(WarrenMazeSourcePlan, "_column_less"))
	for column: Vector2i in columns:
		if _plot_columns.has(column):
			continue
		if rock_shoulder(column) > massif.top_at(column):
			out.append(column)
	return out


## The highest band anything on `column` can reach: its massif envelope, the
## rock shoulder a taller neighbour left it, or the tallest plot top standing
## on it -- whichever is highest. A plot is NOT clamped to the massif and a
## no-plot column's shoulder can stand above its own envelope, so this is the
## one reach rule every consumer scanning a column bottom-to-top shares
## (WarrenMazeVolumeAdapter's derived top, the translator's ownership sweep,
## and the tests that falsify both). Zero outside the massif.
func column_ceiling(column: Vector2i) -> int:
	if massif == null or not massif.has_column(column):
		return 0
	var out := maxi(massif.top_at(column), rock_shoulder(column))
	for index: int in _plot_columns.get(column, []) as Array:
		out = maxi(out, int((plots[index] as Dictionary)["top"]))
	return out


## The derived facts composition reads off a plot: `roofed` (no plot stands on
## any of its columns at its own top -- a roof deck up there means this plot
## has no roof of its own), `bears_on_rock` (every column's floor - 1 is rock
## rather than another plot, which is the existing terrain_bearing ->
## .base.rock composition rule stated at the source), and `tiered` (its top is
## an upper street's own band, within the footprint or its 1-column apron).
func plot_facts(plot: Dictionary) -> Dictionary:
	var id := StringName(plot.get("id", &""))
	var floor_band := int(plot.get("floor", 0))
	var top_band := int(plot.get("top", 0))
	var roofed := true
	var bears_on_rock := not (plot.get("cells", []) as Array).is_empty()
	var apron: Dictionary = {}
	for cell_value: Variant in plot.get("cells", []) as Array:
		var column := cell_value as Vector2i
		apron[column] = true
		for direction: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
			apron[column + direction] = true
		if not solid_at(Vector3i(column.x, floor_band - 1, column.y)):
			bears_on_rock = false
		for index: int in _plot_columns.get(column, []) as Array:
			var other := plots[index] as Dictionary
			if StringName(other["id"]) == id:
				continue
			var other_floor := int(other["floor"])
			var other_top := _plot_reserved_top(other)
			if top_band >= other_floor and top_band < other_top:
				roofed = false
			if floor_band - 1 >= other_floor and floor_band - 1 < other_top:
				bears_on_rock = false
	var tiered := false
	for cell: Vector3i in passage_kinds.keys():
		if cell.y == top_band and apron.has(Vector2i(cell.x, cell.z)):
			tiered = true
			break
	return {"roofed": roofed, "bears_on_rock": bears_on_rock,
		"tiered": tiered}


func _lowest_plot_floor(column: Vector2i) -> int:
	var out := 0
	var found := false
	for index: int in _plot_columns.get(column, []) as Array:
		var floor_band := int((plots[index] as Dictionary)["floor"])
		out = floor_band if not found else mini(out, floor_band)
		found = true
	return out


static func _plot_reserved_top(plot: Dictionary) -> int:
	## The band interval a plot RESERVES on its columns is [floor, this),
	## which is [floor, top) for anything with height and the single floor
	## band for a deck. A deck adds no solid mass (solid_at reads [floor,
	## top), which is empty for it) but two decks may still not share a band.
	return maxi(int(plot["top"]), int(plot["floor"]) + 1)


## The lowest carved band in [from_band, to_band) on `column`, -1 when the
## range is clear -- the public form of the reading the support rule, add_plot,
## and seal all share, so a planner asking "is a street in the way of this
## mass" never has to walk `excavation.carved` for itself.
func first_carved_band(column: Vector2i, from_band: int,
		to_band: int) -> int:
	return _first_carved_band(column, from_band, to_band)


## How many passage cells have nothing solid under the band they walk on. An
## audit fact, never a gate; seal records the same number under
## `audit["street_floor_gaps"]` once the town is finished.
func street_floor_gaps() -> int:
	return _street_floor_gaps()


## Phase B's exit metric: how much of the town's own SKIN is bare rock rather
## than building. An EXTERIOR cell is a solid cell in the massif's own band
## range with at least one exposed face: a 4-neighbour at the same band that
## is not solid -- air, carved street, or off the massif entirely -- or
## nothing solid directly above it. Each one is `plot` when a plot's own
## [floor, top) covers it and `rock` otherwise.
##
## REDEFINED (review finding 2026-08-23, minor 6): this used to scan
## `range(base_at + 1, ceiling)` and side faces only, which dropped band
## `base_at` -- massif mass that `_build_audit` itself counts from `base_at`
## -- and never charged a bare rock TOP for being the thing you look down on.
## Both are skin, so both are counted now; the pinned ceiling was re-measured
## against this definition and the two numbers are not comparable.
##
## `{exterior_cells, rock_cells, plot_cells, ratio}` with ratio =
## rock/exterior (0.0 for a town with no skin at all). The goal is near zero
## above street level: rock should be the town's interior structure, not its
## outside. Seal records this whole dictionary under
## `audit["exterior_rock_ratio"]`; a plan is only worth measuring once the
## sealed rock shoulders exist, so an unsealed plan answers against the raw
## massif envelope instead and reads too rocky.
func exterior_rock_ratio() -> Dictionary:
	var exterior_cells := 0
	var rock_cells := 0
	var plot_cells := 0
	if massif == null:
		return {"exterior_cells": 0, "rock_cells": 0, "plot_cells": 0,
			"ratio": 0.0}
	var columns: Array[Vector2i] = []
	columns.assign(massif.columns.keys())
	columns.sort_custom(Callable(WarrenMazeSourcePlan, "_column_less"))
	for column: Vector2i in columns:
		for band in range(massif.base_at(column), column_ceiling(column)):
			var cell := Vector3i(column.x, band, column.y)
			if not solid_at(cell):
				continue
			var exposed := not solid_at(Vector3i(column.x, band + 1, column.y))
			for direction: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
				if exposed:
					break
				exposed = not solid_at(Vector3i(column.x + direction.x, band,
					column.y + direction.y))
			if not exposed:
				continue
			exterior_cells += 1
			var in_plot := false
			for index: int in _plot_columns.get(column, []) as Array:
				var plot := plots[index] as Dictionary
				if band >= int(plot["floor"]) and band < int(plot["top"]):
					in_plot = true
					break
			plot_cells += int(in_plot)
			rock_cells += int(not in_plot)
	return {
		"exterior_cells": exterior_cells,
		"rock_cells": rock_cells,
		"plot_cells": plot_cells,
		"ratio": float(rock_cells) / float(maxi(1, exterior_cells)),
	}


func _first_carved_band(column: Vector2i, from_band: int,
		to_band: int) -> int:
	## The lowest carved band in [from_band, to_band) on `column`, -1 when the
	## range is clear. `excavation.carved` is every cell the bore removed --
	## each walk cell plus the void above it -- so this is the ONE reading of
	## "a street or its headroom is in the way" the support rule, add_plot,
	## and seal all share.
	if excavation == null:
		return -1
	for band in range(from_band, to_band):
		if excavation.carved.has(Vector3i(column.x, band, column.y)):
			return band
	return -1


func _plot_shape_rejection(plot: Dictionary, self_index: int = -1) -> String:
	## "" when the dictionary really is a plot, else why it is not. Shape
	## alone: nothing here looks at the town around it, except the one thing
	## shape cannot answer on its own -- that no OTHER plot already carries
	## this id. `self_index` is the plot's own slot in `plots` when it is
	## already stored (seal re-checking a finished town) and -1 when it is not
	## (add_plot vetting a newcomer), exactly as _plot_placement_rejection
	## uses it, so the two readings of "already taken" cannot disagree.
	for key: String in ["id", "kind", "cells", "floor", "top", "door_walk",
			"building_id"]:
		if not plot.has(key):
			return "plot is missing the %s key" % key
	if typeof(plot["id"]) != TYPE_STRING_NAME \
			or typeof(plot["kind"]) != TYPE_STRING_NAME \
			or typeof(plot["building_id"]) != TYPE_STRING_NAME:
		return "plot id, kind, and building_id must be StringNames"
	if typeof(plot["cells"]) != TYPE_ARRAY or typeof(plot["floor"]) != TYPE_INT \
			or typeof(plot["top"]) != TYPE_INT \
			or typeof(plot["door_walk"]) != TYPE_VECTOR3I:
		return "plot cells, floor, top, or door_walk has the wrong type"
	var id := StringName(plot["id"])
	var kind := StringName(plot["kind"])
	if kind not in PLOT_KINDS:
		return "plot %s has unknown kind %s" % [id, kind]
	for existing_index in plots.size():
		if existing_index == self_index:
			continue
		if StringName((plots[existing_index] as Dictionary)["id"]) == id:
			return "plot id %s is already taken" % id
	var cells: Array = plot["cells"]
	if cells.is_empty():
		return "plot %s has an empty footprint" % id
	var members: Dictionary = {}
	for cell_value: Variant in cells:
		if typeof(cell_value) != TYPE_VECTOR2I:
			return "plot %s has a footprint member that is not a column" % id
		var column := cell_value as Vector2i
		if members.has(column):
			return "plot %s repeats column %s" % [id, column]
		members[column] = true
	if not _footprint_is_connected(members, cells[0] as Vector2i):
		return "plot %s has a disconnected footprint" % id
	if int(plot["top"]) < int(plot["floor"]):
		return "plot %s has a top below its floor" % id
	if kind == PLOT_DECK and int(plot["top"]) != int(plot["floor"]):
		return "deck %s must be flat: top must equal floor" % id
	if kind != PLOT_DECK and int(plot["top"]) == int(plot["floor"]):
		return "plot %s has no height: only a deck may be flat" % id
	return ""


static func _footprint_is_connected(members: Dictionary,
		start: Vector2i) -> bool:
	var frontier: Array[Vector2i] = [start]
	var seen: Dictionary = {start: true}
	var head := 0
	while head < frontier.size():
		var column := frontier[head]
		head += 1
		for direction: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
			var next := column + direction
			if members.has(next) and not seen.has(next):
				seen[next] = true
				frontier.append(next)
	return seen.size() == members.size()


func _rebuild_plot_columns() -> void:
	## Seal re-derives the per-column index from `plots` themselves rather
	## than trusting add_plot's own running bookkeeping, so a plot appended
	## straight onto the public array -- or an index left stale by a refused
	## seal -- still faces the PLACEMENT checks that read this.
	##
	## Rebuilding the index is only half of that guarantee and never claimed
	## the other half (review finding 2026-08-23, minor 7): shape is invisible
	## from here, so _plot_rejection re-runs _plot_shape_rejection over the
	## stored plots before calling this.
	_plot_columns.clear()
	for index in plots.size():
		for cell_value: Variant in (plots[index] as Dictionary)["cells"] \
				as Array:
			var column := cell_value as Vector2i
			var indices: Array = _plot_columns.get(column, [])
			indices.append(index)
			_plot_columns[column] = indices


func _rebuild_rock_shoulders() -> void:
	## One shoulder per no-plot column, computed once at seal: flood the
	## 4-neighbour regions of columns that carry no plot and give every member
	## of a region the lowest floor of the plots bordering it, or the massif
	## envelope where a region borders no plot at all. Region membership and a
	## minimum are both order-free, so the sorted seed walk is belt and braces.
	##
	## A region shoulder may never cut the ground out from under a street
	## (controller ruling, 2026-08-22): a column hosting passages keeps at
	## least what _street_rock_floors says those passages need, so an
	## un-built tunnel keeps its roof slab and a street keeps the rock it
	## stands on even where the town around it stepped down.
	_rock_shoulders.clear()
	if massif == null:
		return
	var street_floors := _street_rock_floors()
	var columns: Array[Vector2i] = []
	columns.assign(massif.columns.keys())
	columns.sort_custom(Callable(WarrenMazeSourcePlan, "_column_less"))
	var seen: Dictionary = {}
	for column: Vector2i in columns:
		if _plot_columns.has(column) or seen.has(column):
			continue
		var region: Array[Vector2i] = [column]
		seen[column] = true
		var shoulder := -1
		var head := 0
		while head < region.size():
			var current := region[head]
			head += 1
			for direction: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
				var next := current + direction
				if not massif.has_column(next):
					continue
				if _plot_columns.has(next):
					var floor_band := _lowest_plot_floor(next)
					shoulder = floor_band if shoulder < 0 \
						else mini(shoulder, floor_band)
				elif not seen.has(next):
					seen[next] = true
					region.append(next)
		for member: Vector2i in region:
			var derived := shoulder if shoulder >= 0 \
				else massif.top_at(member)
			_rock_shoulders[member] = maxi(derived,
				int(street_floors.get(member, derived)))


func _street_rock_floors() -> Dictionary:
	## Vector2i column -> the rock top the passages it hosts need under and
	## over them: the highest hosted passage's own headroom top, plus
	## TUNNEL_ROOF_BANDS where the carver left that passage COVERED (the
	## retained slab is the tunnel's roof; an open passage is carved to the
	## envelope, so its headroom top already is that envelope). One pass over
	## the passages, so a shoulder walk stays a column lookup. Columns hosting
	## no passage at all are absent.
	var out: Dictionary = {}
	for cell: Vector3i in passage_kinds.keys():
		var column := Vector2i(cell.x, cell.z)
		var need := passage_headroom_top(cell)
		if excavation != null and bool(excavation.covered.get(cell, false)):
			need += TUNNEL_ROOF_BANDS
		out[column] = maxi(int(out.get(column, need)), need)
	return out


func _street_floor_gaps() -> int:
	## Audit fact, never a gate (rules become repairs): how many passage cells
	## have nothing solid under the band they walk on. A cell at its own
	## terrain band counts as grounded -- solid_at answers true for the
	## untouched ground below massif.base_at -- so this counts real holes: a
	## street left hanging where a lower passage's headroom eats its floor, or
	## where the plot layer has yet to build the mass it stands on.
	var out := 0
	for cell: Vector3i in passage_cells():
		if not solid_at(Vector3i(cell.x, cell.y - 1, cell.z)):
			out += 1
	return out


func _plot_rejection() -> String:
	## Seal's plot half: every stored plot re-checked for SHAPE, then the
	## stack invariant on every column, then every plot re-checked for
	## PLACEMENT against the finished town. "" when the town is sound.
	##
	## The shape sweep is not redundant with add_plot's (review finding
	## 2026-08-23, minor 7): `plots` is public, so a caller can append a
	## dictionary straight onto it -- a disconnected footprint, a duplicate
	## id, a deck with height -- and, before this, seal judged it on placement
	## alone and let it through. It runs FIRST because the column index and
	## the shoulders below are built from `cells`, and a malformed footprint
	## has no business seeding either.
	for index in plots.size():
		var shape := _plot_shape_rejection(plots[index], index)
		if shape != "":
			return shape
	_rebuild_plot_columns()
	_rebuild_rock_shoulders()
	var columns: Array[Vector2i] = []
	columns.assign(massif.columns.keys())
	columns.sort_custom(Callable(WarrenMazeSourcePlan, "_column_less"))
	for column: Vector2i in columns:
		# Solids must be contiguous from terrain: rock, then plots in floor
		# order. A carved band is a permitted gap (a street runs through the
		# block, and the mass above it is a real roof); any OTHER air band
		# with solid mass above it means something floats.
		var scan_top := massif.top_at(column)
		for index: int in _plot_columns.get(column, []) as Array:
			scan_top = maxi(scan_top, _plot_reserved_top(plots[index]))
		var air_band := -1
		for band in range(massif.base_at(column), scan_top):
			var cell := Vector3i(column.x, band, column.y)
			if solid_at(cell):
				if air_band >= 0:
					return ("column %s floats: solid mass at band %d stands " \
						+ "over open air at band %d") % [column, band, air_band]
			elif air_band < 0 and not excavation.carved.has(cell):
				air_band = band
	for index in plots.size():
		var placement := _plot_placement_rejection(plots[index], index)
		if placement != "":
			return placement
	return ""


func _plot_placement_rejection(plot: Dictionary, self_index: int) -> String:
	## Why this plot may not stand where it says it does -- the one support
	## rule, a carved cell inside the band interval it occupies, or an overlap
	## with a plot already standing on one of its columns -- and "" when it
	## may. `self_index` is the plot's own slot in `plots` when it is already
	## stored (seal re-checking a finished town) and -1 when it is not
	## (add_plot vetting a newcomer), so add_plot's own gate and seal's mirror
	## of it can never disagree about what a legal plot is.
	##
	## The carved check is where "every passage cell and its carved headroom
	## stays air" actually lives: solid_at answers air for a carved cell
	## whatever a plot claims, so the invariant that can really fail is the
	## one stated from the plot's side -- no plot claims a carved band.
	##
	## The `door_walk` check (review finding 2026-08-23, minor 8) is the same
	## kind of rule: composition places the door module at that cell, so a
	## house or an asset has to address a real passage cell 4-adjacent to its
	## own footprint. A DECK's door_walk is the street it grew off and a
	## BRIDGE's is the span cell it stands over -- neither is beside its
	## footprint, both are exempt, and the model says so rather than leaving
	## the field unchecked for all four kinds.
	var id := StringName(plot["id"])
	var kind := StringName(plot["kind"])
	var floor_band := int(plot["floor"])
	var reserved_top := _plot_reserved_top(plot)
	if kind in [PLOT_HOUSE, PLOT_ASSET]:
		var door := plot["door_walk"] as Vector3i
		if not passage_kinds.has(door):
			return "plot %s has a door_walk at %s that is not a passage cell" \
				% [id, door]
		var addressed := false
		for cell_value: Variant in plot["cells"] as Array:
			var column := cell_value as Vector2i
			if absi(column.x - door.x) + absi(column.y - door.z) == 1:
				addressed = true
				break
		if not addressed:
			return ("plot %s has a door_walk at %s that no footprint column " \
				+ "touches") % [id, door]
	for cell_value: Variant in plot["cells"] as Array:
		var column := cell_value as Vector2i
		if not plot_support_ok(column, floor_band):
			if not solid_at(Vector3i(column.x, floor_band - 1, column.y)):
				return ("plot %s breaks support rule 1 at column %s: band %d " \
					+ "below its floor is not solid") \
					% [id, column, floor_band - 1]
			return ("plot %s breaks support rule 2 at column %s: carved air " \
				+ "stands inside its clearance [%d, %d)") \
				% [id, column, floor_band, floor_band + MIN_HOUSE_BANDS]
		var carved := _first_carved_band(column, floor_band, reserved_top)
		if carved >= 0:
			return ("plot %s covers carved band %d at column %s -- a street " \
				+ "and its headroom are immutable") % [id, carved, column]
		for index: int in _plot_columns.get(column, []) as Array:
			if index == self_index:
				continue
			var other := plots[index] as Dictionary
			if floor_band < _plot_reserved_top(other) \
					and reserved_top > int(other["floor"]):
				return "plot %s overlaps plot %s at column %s" \
					% [id, StringName(other["id"]), column]
	return ""


# --- End plot model --------------------------------------------------------


func passage_cells() -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	out.assign(passage_kinds.keys())
	out.sort_custom(Callable(WarrenMazeSourcePlan, "_cell_less"))
	return out


func deterministic_signature() -> String:
	var parts := PackedStringArray([
		String(scale_profile.deterministic_signature()),
		"summit:%d,%d,%d" % [summit_cell.x, summit_cell.y, summit_cell.z],
	])
	for cell: Vector3i in passage_cells():
		parts.append("p:%d,%d,%d:%s" % [cell.x, cell.y, cell.z,
			String(passage_kinds[cell])])
	for cell: Vector3i in market_zone:
		parts.append("m:%d,%d,%d" % [cell.x, cell.y, cell.z])
	for cell: Vector3i in market_square_cells:
		parts.append("ms:%d,%d,%d" % [cell.x, cell.y, cell.z])
	for stamp: Dictionary in feature_stamps:
		parts.append("stamp:%s:%s" % [String(stamp.get("kind", &"")),
			str(stamp.get("cells", []))])
	for cell: Vector3i in excavation.route:
		parts.append("r:%d,%d,%d" % [cell.x, cell.y, cell.z])
	for transition: Dictionary in excavation.transitions:
		parts.append("rt:%s>%s:%d" % [str(transition.from),
			str(transition.to), int(transition.kind)])
	for lane_index in excavation.lanes.size():
		var lane := excavation.lanes[lane_index]
		parts.append("l%d@%s" % [lane_index, str(lane.anchor)])
		for cell: Vector3i in lane.cells as Array[Vector3i]:
			parts.append("lc:%d,%d,%d" % [cell.x, cell.y, cell.z])
		for transition: Dictionary in lane.transitions as Array[Dictionary]:
			parts.append("lt:%s>%s:%d" % [str(transition.from),
				str(transition.to), int(transition.kind)])
	for edge: Dictionary in excavation.loop_edges:
		parts.append("loop:%s>%s:%d" % [str(edge.from), str(edge.to),
			int(edge.kind)])
	for span_index in excavation.bridge_spans.size():
		var span := excavation.bridge_spans[span_index] as Array[Vector3i]
		for cell: Vector3i in span:
			parts.append("b:%d:%d,%d,%d" % [span_index, cell.x, cell.y, cell.z])
	var air: Array[Vector3i] = []
	air.assign(excavation.carved.keys())
	air.sort_custom(Callable(WarrenMazeSourcePlan, "_cell_less"))
	for cell: Vector3i in air:
		parts.append("a:%d,%d,%d" % [cell.x, cell.y, cell.z])
	var columns: Array[Vector2i] = []
	columns.assign(block_thickness.keys())
	columns.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or a.y == b.y and a.x < b.x)
	for column: Vector2i in columns:
		parts.append("t:%d,%d:%d" % [column.x, column.y,
			int(block_thickness[column])])
	# `plot:`, not `p:` -- that prefix already belongs to the passage cells
	# above. Ids are unique, so sorting the whole line sorts by id and the
	# order plots were added can never show in the signature.
	var plot_lines := PackedStringArray()
	for plot: Dictionary in plots:
		var plot_cells: Array[Vector2i] = []
		plot_cells.assign(plot["cells"])
		plot_cells.sort_custom(Callable(WarrenMazeSourcePlan, "_column_less"))
		var plot_text := PackedStringArray()
		for cell: Vector2i in plot_cells:
			plot_text.append("%d,%d" % [cell.x, cell.y])
		var door: Vector3i = plot["door_walk"]
		plot_lines.append("plot:%s:%s:%s:%d,%d:%d,%d,%d:%s" % [
			String(plot["id"]), String(plot["kind"]),
			"+".join(plot_text), int(plot["floor"]), int(plot["top"]),
			door.x, door.y, door.z, String(plot["building_id"])])
	plot_lines.sort()
	for line: String in plot_lines:
		parts.append(line)
	return "|".join(parts)


func _build_audit() -> Dictionary:
	var total_mass := 0
	var retained_mass := 0
	var house_capable := 0
	var addressed_columns: Dictionary = {}
	var public := passage_cells()
	for column: Vector2i in massif.columns:
		var longest := 0
		var current := 0
		for band in range(massif.base_at(column), massif.top_at(column)):
			total_mass += 1
			var solid := not excavation.carved.has(
				Vector3i(column.x, band, column.y))
			retained_mass += int(solid)
			current = current + 1 if solid else 0
			longest = maxi(longest, current)
		house_capable += int(longest >= MIN_HOUSE_BANDS)
	var two_sided := 0
	var fronted_passages := 0
	var covered := 0
	var thickness_histogram: Dictionary = {}
	for cell: Vector3i in public:
		var sides := 0
		for direction: Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
			var column := Vector2i(cell.x + direction.x,
				cell.z + direction.y)
			if _column_carries_house_at(column, cell.y):
				sides += 1
				addressed_columns[column] = true
		fronted_passages += int(sides >= 1)
		two_sided += int(sides >= 2)
		var column := Vector2i(cell.x, cell.z)
		var roof := Vector3i(cell.x,
			cell.y + excavation.slot_bands(cell), cell.z)
		covered += int(massif.top_at(column) > roof.y \
			and not excavation.carved.has(roof))
		var thickness := int(block_thickness.get(column, 0))
		thickness_histogram[thickness] = int(
			thickness_histogram.get(thickness, 0)) + 1
	return {
		"passage_cell_count": public.size(),
		"spine_cell_count": excavation.route.size(),
		"alley_cell_count": excavation.lane_cells().size(),
		"market_cell_count": _market_cell_count(),
		"market_approach_cell_count": market_zone.size(),
		"market_square_cell_count": market_square_cells.size(),
		"loop_join_count": excavation.loop_edges.size(),
		"house_capable_column_count": house_capable,
		"fronted_house_column_count": addressed_columns.size(),
		# The sealed source invariant is path-centric: almost every public cell
		# must run beside inhabitable mass. Thick-block interior columns are
		# deliberately attached as the backs/upper mass of those front buildings
		# and are therefore reported separately rather than making a four-deep
		# house look 25% fronted.
		"frontage_ratio": float(fronted_passages) \
			/ float(maxi(1, public.size())),
		"addressed_column_ratio": float(addressed_columns.size()) \
			/ float(maxi(1, house_capable)),
		"two_sided_passage_ratio": float(two_sided) \
			/ float(maxi(1, public.size())),
		"covered_passage_ratio": float(covered) \
			/ float(maxi(1, public.size())),
		# Raw source-solid survival is useful topology guidance, but it is not the
		# design's 0.85 mass-assignment gate. That gate measures how much of the
		# SOLID LEFT AFTER CARVING becomes owned building parcels and can only be
		# sealed by the partition stage.
		"source_solid_retention_ratio": float(retained_mass) \
			/ float(maxi(1, total_mass)),
		"block_thickness_histogram": thickness_histogram,
		"route_span_bands": excavation.route_span_bands(),
		"max_spine_straight_run": _max_straight_run(excavation.route),
		"max_alley_straight_run": _max_alley_straight_run(),
	}


func _market_cell_count() -> int:
	var cells: Dictionary = {}
	for cell: Vector3i in market_zone:
		cells[cell] = true
	for cell: Vector3i in market_square_cells:
		cells[cell] = true
	return cells.size()


func _max_alley_straight_run() -> int:
	var out := 0
	for lane: Dictionary in excavation.lanes:
		var walk: Array[Vector3i] = [lane.anchor as Vector3i]
		walk.append_array(lane.cells as Array[Vector3i])
		out = maxi(out, _max_straight_run(walk))
	return out


static func _max_straight_run(walk: Array[Vector3i]) -> int:
	var longest := 0
	var current := 0
	var previous := Vector2i.ZERO
	for index in range(1, walk.size()):
		var delta := walk[index] - walk[index - 1]
		var direction := Vector2i(delta.x, delta.z)
		current = current + 1 if direction == previous else 1
		previous = direction
		longest = maxi(longest, current)
	return longest


func _column_carries_house_at(column: Vector2i, street_band: int) -> bool:
	if not massif.has_column(column) or street_band < massif.base_at(column) \
			or street_band + MIN_HOUSE_BANDS > massif.top_at(column):
		return false
	for band in range(street_band, street_band + MIN_HOUSE_BANDS):
		if excavation.carved.has(Vector3i(column.x, band, column.y)):
			return false
	return true


static func _has_typed_square(cells: Array[Vector3i]) -> bool:
	if cells.size() != 4:
		return false
	var claimed: Dictionary = {}
	for cell: Vector3i in cells:
		claimed[cell] = true
	for cell: Vector3i in cells:
		if claimed.has(cell + Vector3i.RIGHT) \
				and claimed.has(cell + Vector3i.BACK) \
				and claimed.has(cell + Vector3i(1, 0, 1)):
			return true
	return false


func _reject(reason: String) -> bool:
	last_rejection = reason
	return false


static func _cell_less(a: Vector3i, b: Vector3i) -> bool:
	if a.y != b.y:
		return a.y < b.y
	if a.z != b.z:
		return a.z < b.z
	return a.x < b.x


static func _column_less(a: Vector2i, b: Vector2i) -> bool:
	if a.y != b.y:
		return a.y < b.y
	return a.x < b.x
