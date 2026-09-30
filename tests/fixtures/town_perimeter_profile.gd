extends RefCounted

## Perimeter height profile of a built town (September 29 town review, owner:
## "multi-storey buildings lining the outside of the town ... a sheer face").
##
## The town footprint is the massif. An exterior EDGE is a cardinal side of a
## massif column whose neighbour is open ground reaching the far outside (a
## flood over non-massif columns). For each edge it reads the built kit masses
## over the RIM column (the massif column on that edge) and over the INNER
## column one step inward. Wall heights are the highest storey top (walls
## only: a roof above a one-storey wall is the point) above the column's own
## ground band.
##   rim_over     rim wall > 2 storeys above ground: more than one storey on
##                at most the rim terrace's one-storey plinth
##   inner_over   inner wall > 3 storeys above ground: the ring 8 m behind the
##                rim climbs more than one further storey
##   rim_tall_house  a house (not retained terrace) on the rim with more than
##                one storey above its own floor
##   bridge_over  edges over the profile only because of a bridge-house
##                endpoint room (informational)
##   rampart      rim column showing a full storey (2 bands) of retaining
##                rock above the lawn: the stone course of photo 7
##   sheer        rim wall >= 2 storeys above ground (plinth included); an
##                informational count, not a rule
## `hist` counts edges by rim storeys above ground (ceil(bands / 2)).
const STOREY_BANDS := 2
const RIM_MAX_BANDS := 2 * STOREY_BANDS
const INNER_MAX_BANDS := 3 * STOREY_BANDS
const STRUCTURE_PREFIXES: Array[String] = ["kit.retained", "kit.tunnel"]


static func _column(cell: Vector2i) -> Vector2i:
	return Vector2i(floori(cell.x / 2.0), floori(cell.y / 2.0))


## Bridge-houses stand over a street by design: their spans, endpoint rooms
## and the endpoint houses carrying them (`bridge.NN.end.K.lower` plots) are
## reported separately (`bridge_over`), not held to the ring profile.
const BRIDGE_MARKERS: Array[String] = ["bridge", "skywalk"]


static func is_bridge(mass: BuildingMass) -> bool:
	var id := String(mass.stable_id)
	for marker: String in BRIDGE_MARKERS:
		if id.contains(marker):
			return true
	return false


static func column_wall_tops(masses: Array, bridges := true) -> Dictionary:
	## Macro column -> highest wall band over its fine cells.
	var tops: Dictionary = {}
	for mass: BuildingMass in masses:
		if not bridges and is_bridge(mass):
			continue
		for storey: Dictionary in mass.storeys:
			var top := int(storey.floor_band) + int(storey.get("bands", 2))
			for cell: Vector2i in storey.cells:
				var column := _column(cell)
				tops[column] = maxi(int(tops.get(column, -(1 << 20))), top)
	return tops


static func column_house_storeys(masses: Array) -> Dictionary:
	## Macro column -> most storeys any one house (not retained terrace) stands
	## over it, counted from that house's own lowest floor there.
	var out: Dictionary = {}
	for mass: BuildingMass in masses:
		if is_bridge(mass):
			continue
		var id := String(mass.stable_id)
		var structure := false
		for prefix: String in STRUCTURE_PREFIXES:
			structure = structure or id.begins_with(prefix)
		if structure:
			continue
		var span: Dictionary = {}
		for storey: Dictionary in mass.storeys:
			var floor := int(storey.floor_band)
			var top := floor + int(storey.get("bands", 2))
			for cell: Vector2i in storey.cells:
				var column := _column(cell)
				var range: Vector2i = span.get(column, Vector2i(floor, top))
				span[column] = Vector2i(mini(range.x, floor), maxi(range.y, top))
		for column: Vector2i in span:
			var range: Vector2i = span[column]
			out[column] = maxi(int(out.get(column, 0)),
				ceili(float(range.y - range.x) / STOREY_BANDS))
	return out


static func column_retained_tops(masses: Array) -> Dictionary:
	## Macro column -> highest band of retained (rock) courses over it.
	var tops: Dictionary = {}
	for mass: BuildingMass in masses:
		if not String(mass.stable_id).begins_with("kit.retained"):
			continue
		for storey: Dictionary in mass.storeys:
			var top := int(storey.floor_band) + int(storey.get("bands", 2))
			for cell: Vector2i in storey.cells:
				var column := _column(cell)
				tops[column] = maxi(int(tops.get(column, -(1 << 20))), top)
	return tops


static func exterior_columns(massif: WarrenMassif) -> Dictionary:
	var lo := Vector2i(1 << 20, 1 << 20)
	var hi := -lo
	for column: Vector2i in massif.columns:
		lo = Vector2i(mini(lo.x, column.x), mini(lo.y, column.y))
		hi = Vector2i(maxi(hi.x, column.x), maxi(hi.y, column.y))
	lo -= Vector2i.ONE
	hi += Vector2i.ONE
	var out: Dictionary = {lo: true}
	var frontier: Array[Vector2i] = [lo]
	while not frontier.is_empty():
		var column: Vector2i = frontier.pop_back()
		for direction: Vector2i in BuildingMass.DIRS:
			var next := column + direction
			if next.x < lo.x or next.y < lo.y or next.x > hi.x or next.y > hi.y \
					or out.has(next) or massif.has_column(next):
				continue
			out[next] = true
			frontier.append(next)
	return out


static func measure(source: WarrenMazeSourcePlan, masses: Array) -> Dictionary:
	var massif := source.massif
	var tops := column_wall_tops(masses, false)
	var all_tops := column_wall_tops(masses)
	var house_storeys := column_house_storeys(masses)
	var retained_tops := column_retained_tops(masses)
	var rampart := 0
	var outside := exterior_columns(massif)
	var edges := 0
	var sheer := 0
	var rim_over := 0
	var inner_over := 0
	var rim_tall_house := 0
	var bridge_over := 0
	var storeys_sum := 0
	var hist: Dictionary = {}
	var offenders: Array[Vector2i] = []
	for column: Vector2i in massif.columns:
		var ground := massif.base_at(column)
		for direction: Vector2i in BuildingMass.DIRS:
			if not outside.has(column + direction):
				continue
			edges += 1
			var bands := maxi(0, int(tops.get(column, ground)) - ground)
			var storeys := ceili(float(bands) / STOREY_BANDS)
			hist[storeys] = int(hist.get(storeys, 0)) + 1
			storeys_sum += storeys
			sheer += int(bands >= 2 * STOREY_BANDS)
			# A full storey of retaining rock on the lawn: the stone rampart.
			rampart += int(int(retained_tops.get(column, ground)) - ground >= STOREY_BANDS)
			var bad := false
			if bands > RIM_MAX_BANDS:
				rim_over += 1
				bad = true
			if int(house_storeys.get(column, 0)) > 1:
				rim_tall_house += 1
				bad = true
			var inner := column - direction
			if massif.has_column(inner):
				var inner_ground := massif.base_at(inner)
				if int(tops.get(inner, inner_ground)) - inner_ground > INNER_MAX_BANDS:
					inner_over += 1
					bad = true
				elif int(all_tops.get(inner, inner_ground)) - inner_ground > INNER_MAX_BANDS:
					bridge_over += 1
			if int(all_tops.get(column, ground)) - ground > RIM_MAX_BANDS \
					and bands <= RIM_MAX_BANDS:
				bridge_over += 1
			if bad and not offenders.has(column):
				offenders.append(column)
	var keys := hist.keys()
	keys.sort()
	var sorted_hist: Dictionary = {}
	for k: int in keys:
		sorted_hist[k] = hist[k]
	# Town-wide context, so a lower rim cannot be bought by deleting houses.
	var houses := 0
	var house_columns := 0
	var decks := 0
	var assets := 0
	for plot: Dictionary in source.plots:
		if plot.kind == WarrenMazeSourcePlan.PLOT_HOUSE:
			houses += 1
			house_columns += (plot.cells as Array).size()
		decks += int(plot.kind == WarrenMazeSourcePlan.PLOT_DECK)
		assets += int(plot.kind == WarrenMazeSourcePlan.PLOT_ASSET)
	var lane_cells := 0
	for lane: Dictionary in source.excavation.lanes:
		if StringName(lane.get("feature_kind", &"")) == &"perimeter":
			lane_cells += (lane.cells as Array).size()
	return {"edges": edges, "perimeter_lane_cells": lane_cells, "rim_over": rim_over, "inner_over": inner_over,
		"rim_tall_house": rim_tall_house, "bridge_over": bridge_over,
		"rampart": rampart,
		"sheer": sheer,
		"houses": houses, "house_columns": house_columns, "decks": decks,
		"assets": assets,
		"rim_storeys_sum": storeys_sum, "hist": sorted_hist,
		"offenders": offenders}
