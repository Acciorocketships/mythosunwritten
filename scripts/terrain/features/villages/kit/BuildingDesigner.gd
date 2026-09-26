class_name BuildingDesigner
extends RefCounted

## Pack-agnostic architectural articulation.
##
## Given a mass whose storey footprints are fixed (by the village planner or by
## `design_standalone`), the designer chooses the look: stone ground storeys,
## jettied timber uppers, gable wings and their ridge axes, dormer rhythm, bay
## windows, awnings over street doors, window boxes and ivy. Choices are
## deterministic from the mass seed and biased toward the reference village:
## quaint two/three-storey houses with steep dormered roofs and overhangs.
## Features the kit cannot realize are skipped.

var kit: BuildingKit
## Callable(cell: Vector2i, band: int) -> bool: true when space outside the
## mass must stay clear (public air, another owner). Used before projecting
## bays, awnings and roofs. Optional.
var forbidden: Callable = Callable()
## Callable(cell: Vector2i, band: int) -> bool: true where a public floor
## already occupies a crown cell (an upper street); no roof is drawn there.
var walked: Callable = Callable()
## Callable(cell: Vector2i, band: int) -> bool: true where another building
## already fills the cell, closing this crown without a roof.
var covered: Callable = Callable()


func _init(p_kit: BuildingKit) -> void:
	kit = p_kit


func _rng(seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return rng


## A freestanding reference-style house.
func design_standalone(seed: int) -> BuildingMass:
	var rng := _rng(seed)
	var mass := BuildingMass.new()
	mass.stable_id = StringName("designed.%d" % seed)
	mass.seed = seed
	var width := rng.randi_range(3, 5)
	var depth := rng.randi_range(2, 4)
	var cells := BuildingMass.rect_cells(Rect2i(0, 0, width, depth))
	var wing := Rect2i()
	if rng.randf() < 0.4 and width >= 3:
		var wing_width := rng.randi_range(2, mini(3, width - 1))
		var wing_depth := rng.randi_range(2, 3)
		var wing_x := 0 if rng.randf() < 0.5 else width - wing_width
		wing = Rect2i(wing_x, depth, wing_width, wing_depth)
		cells.merge(BuildingMass.rect_cells(wing))
	var storey_count := 2 if rng.randf() < 0.7 else 3
	for s in storey_count:
		mass.add_storey(s * 2, cells, BuildingMass.MATERIAL_TIMBER)
	var ground: Dictionary = mass.storeys[0]
	ground.openings[Vector3i(width / 2, 0, 3)] = BuildingMass.OPENING_DOOR
	articulate(mass, {"terrain_storey": 0})
	return mass


## Articulate a mass whose footprints are fixed. `context`:
##   terrain_storey: index of the storey standing on the ground (-1 none)
##   colour: roof colour override
##   terraced: exposed lower crowns become balconies
##   roof_axis: prefer complete longitudinal wings along this axis (0/1)
##   street_edges: Array[Vector3i] ground-storey edges facing public ways
func articulate(mass: BuildingMass, context: Dictionary) -> void:
	var rng := _rng(hash([mass.seed, &"articulate"]))
	var terrain_storey := int(context.get("terrain_storey", 0))
	var colour := StringName(context.get("colour",
		&"red" if rng.randf() < 0.55 else &"blue"))
	# Stone is a seeded minority of ground storeys (owner direction: a quaint
	# timber village, never a stone fortress); plinths stay on every house.
	var stone_ground := rng.randf() < float(context.get("stone_chance", 0.4))
	_assign_materials(mass, terrain_storey, stone_ground)
	_assign_jetties(mass, terrain_storey, rng)
	_assign_facades(mass, rng, colour)
	_assign_finish(mass, rng, colour)
	_assign_roofs(mass, rng, colour, bool(context.get("terraced", false)),
		int(context.get("roof_axis", -1)))
	_assign_dressing(mass, rng, context)


func _assign_materials(mass: BuildingMass, terrain_storey: int,
		stone_ground: bool) -> void:
	for index in mass.storeys.size():
		var storey: Dictionary = mass.storeys[index]
		var grounded := index == terrain_storey
		storey.material = BuildingMass.MATERIAL_STONE \
			if grounded and stone_ground else BuildingMass.MATERIAL_TIMBER
		storey.plinth = grounded and kit.has_role(&"plinth.stone")


## A storey is inset (so the storey above reads as a jetty) when an identical
## footprint stands directly on it and every part stays at least one module
## wide after the half-module erosion.
func _assign_jetties(mass: BuildingMass, terrain_storey: int,
		rng: RandomNumberGenerator) -> void:
	if not kit.has_role(&"bracket.jetty"):
		return
	for index in mass.storeys.size():
		var storey: Dictionary = mass.storeys[index]
		var above := _storey_at(mass, int(storey.floor_band) + 2)
		if above.is_empty():
			continue
		if not _same_cells(storey.cells, above.cells):
			continue
		var bearing := _storey_at(mass, int(storey.floor_band) - 2)
		if not bearing.is_empty() and not _same_cells(bearing.cells, storey.cells):
			continue
		if not _erodable(storey.cells):
			continue
		# A jetty on a two-module plan leaves a one-module stalk: a tower.
		var extent := _bounds(storey.cells)
		if mini(extent.size.x, extent.size.y) < 3:
			continue
		# Ground storeys alternate flush canopy fronts with jetties; higher storeys
		# jetty only when the one below did not (a single overhang reads best).
		var chance := 0.55 if index == terrain_storey else 0.25
		var below := _storey_at(mass, int(storey.floor_band) - 2)
		if not below.is_empty() and bool(below.get("inset", false)):
			chance = 0.0
		storey.inset = rng.randf() < chance


func _assign_facades(mass: BuildingMass, rng: RandomNumberGenerator,
		colour: StringName) -> void:
	# Every slot's opening is decided here, on exactly the slots the assembler
	# will build, so dressing (window boxes, ivy) always matches the wall.
	for index in mass.storeys.size():
		var storey: Dictionary = mass.storeys[index]
		storey.default_opening = BuildingMass.OPENING_WINDOW
		storey.plain_every = 0
		storey.bay_colour = colour
		var plain_rate := 0.22 if storey.material == BuildingMass.MATERIAL_STONE else 0.3
		var slots := slots_of(mass, storey)
		for slot: Dictionary in slots:
			if not storey.openings.has(slot.edge) and rng.randf() < plain_rate:
				storey.openings[slot.edge] = BuildingMass.OPENING_PLAIN
		if storey.material != BuildingMass.MATERIAL_TIMBER or index == 0:
			continue
		# Bays on the shorter (gable/end) faces of upper timber storeys.
		if rng.randf() > 0.55:
			continue
		var bounds := _bounds(storey.cells)
		var short_x := bounds.size.x <= bounds.size.y
		for slot: Dictionary in slots:
			var dir := int(slot.dir)
			var on_end := (dir == 0 or dir == 2) == short_x
			if not on_end or int(slot.count) < 2:
				continue
			if int(slot.index) == 0 or int(slot.index) == int(slot.count) - 1:
				if int(slot.count) > 2:
					continue
			if not _bay_clear(mass, slot, int(storey.floor_band)):
				continue
			if storey.openings.has(slot.edge) \
					and storey.openings[slot.edge] != BuildingMass.OPENING_PLAIN:
				continue
			if rng.randf() < 0.7:
				storey.openings[slot.edge] = BuildingMass.OPENING_BAY


## The wall slots the assembler will build for this storey.
func slots_of(mass: BuildingMass, storey: Dictionary) -> Array[Dictionary]:
	return BuildingKitAssembler.wall_slots(storey.cells, bool(storey.get("inset", false)),
		BuildingKitAssembler.exposure_for(mass, int(storey.floor_band),
			int(storey.get("bands", 2)), covered))


## Plaster finish per house (a gentle tint on the timber-frame infill).
const FINISHES: Array[Color] = [Color(1.0, 1.0, 1.0), Color(1.0, 0.96, 0.88),
	Color(0.93, 0.96, 1.0), Color(1.0, 0.93, 0.82), Color(0.97, 0.97, 0.93)]


func _assign_finish(mass: BuildingMass, rng: RandomNumberGenerator,
		_colour: StringName) -> void:
	var finish := FINISHES[rng.randi_range(0, FINISHES.size() - 1)]
	for storey: Dictionary in mass.storeys:
		storey.tint = finish if storey.material == BuildingMass.MATERIAL_TIMBER \
			else Color(0.97, 0.98, 1.0)


func _bay_clear(_mass: BuildingMass, slot: Dictionary, band: int) -> bool:
	if not forbidden.is_valid():
		return true
	for cell: Vector2i in slot.outside:
		for b in [band, band + 1]:
			if bool(forbidden.call(cell, b)):
				return false
	return true


## Roof wings over the exposed crown of every storey: a main wing on the
## largest rectangle, ridge along its long axis, then cross wings abutting it.
## A wing whose roof volume would enter kept-clear space turns its ridge; if
## neither ridge fits, the crown becomes a railed timber roof terrace.
func _assign_roofs(mass: BuildingMass, rng: RandomNumberGenerator,
		colour: StringName, terraced := false, ridge_axis := -1) -> void:
	mass.roofs.clear()
	mass.decks.clear()
	for storey: Dictionary in mass.storeys:
		var top_band := int(storey.floor_band) + 2
		var exposed: Dictionary = {}
		var covering := mass.cells_at_band(top_band)
		for cell: Vector2i in storey.cells:
			if covering.has(cell):
				continue
			if walked.is_valid() and bool(walked.call(cell, top_band)):
				continue
			if covered.is_valid() and bool(covered.call(cell, top_band)):
				continue
			exposed[cell] = true
		if exposed.is_empty():
			continue
		if terraced and not covering.is_empty():
			_add_terrace(mass, exposed, covering, top_band)
			continue
		var wings: Array = []
		for rect: Rect2i in decompose(exposed, ridge_axis):
			if ridge_axis >= 0:
				wings.append({"rect": rect, "axis": ridge_axis})
			else:
				wings.append_array(split_deep(rect, rng))
		var main_rect := Rect2i()
		var have_main := false
		var main_axis := 0
		for i in wings.size():
			var spec: Dictionary = wings[i]
			var rect := spec.rect as Rect2i
			var axis := int(spec.get("axis", 0 if rect.size.x >= rect.size.y else 1))
			if bool(spec.get("cross", false)):
				if not _roof_fits(mass, rect, axis, top_band):
					mass.decks.append({"cells": BuildingMass.rect_cells(rect),
						"band": top_band, "rails": true})
					continue
				var cross := mass.add_roof(rect, axis, top_band, colour)
				cross[StringName("open_%s" % spec.open)] = true
				cross[StringName("extend_%s" % spec.open)] = cross_extension(
					rect.size.y if axis == 0 else rect.size.x, MAX_ROOF_DEPTH)
				continue
			var fits := _roof_fits(mass, rect, axis, top_band)
			if not fits:
				axis = 1 - axis
				fits = _roof_fits(mass, rect, axis, top_band)
			if not fits:
				mass.decks.append({"cells": BuildingMass.rect_cells(rect),
					"band": top_band, "rails": true})
				continue
			var wing := mass.add_roof(rect, axis, top_band, colour)
			if not have_main:
				main_rect = rect
				main_axis = axis
				have_main = true
				wing.chimney = rng.randf() < 0.65
				wing.ridge_peaks = rng.randf() < 0.35
				wing.chimney_end = rng.randi_range(0, 1)
			else:
				_join_cross_wing(wing, main_rect, main_axis)
			_place_dormers(wing, rng)


## Lower wings become accessible balconies when the next floor steps back.
## Shared edges belong to the house wall; only the exposed sides get rails.
func _add_terrace(mass: BuildingMass, cells: Dictionary, covering: Dictionary,
		band: int) -> void:
	var open_edges := {}
	var upper := _storey_at(mass, band)
	var door_added := false
	for cell: Vector2i in cells:
		for dir in 4:
			var next := cell + BuildingMass.DIRS[dir]
			if not covering.has(next): continue
			open_edges[BuildingMass.edge_key(cell, dir)] = true
			if not door_added and not upper.is_empty():
				upper.openings[BuildingMass.edge_key(next, (dir + 2) % 4)] = BuildingMass.OPENING_DOOR
				door_added = true
	mass.decks.append({"cells": cells, "band": band, "rails": true,
		"open_edges": open_edges})


func _roof_fits(mass: BuildingMass, rect: Rect2i, axis: int, eave_band: int) -> bool:
	if not forbidden.is_valid():
		return true
	var depth := rect.size.y if axis == 0 else rect.size.x
	var height := float(kit.roof_profile(depth).height)
	var bands := int(ceil(height / kit.band_height() - 0.15))
	var own_above: Dictionary = {}
	for b in range(eave_band, eave_band + bands):
		own_above[b] = mass.cells_at_band(b)
	for x in range(rect.position.x, rect.end.x):
		for z in range(rect.position.y, rect.end.y):
			var cell := Vector2i(x, z)
			for b in range(eave_band, eave_band + bands):
				if (own_above[b] as Dictionary).has(cell):
					continue
				if bool(forbidden.call(cell, b)):
					return false
	return true


const MAX_ROOF_DEPTH := 4


## Splits a crown rectangle deeper than MAX_ROOF_DEPTH into a main wing of
## that depth and a row of 2-3 module cross gables running into it, as the
## reference houses do for wide plans. Returns [{rect, axis?, cross?, open?}].
static func split_deep(rect: Rect2i, rng: RandomNumberGenerator) -> Array:
	var along_x := rect.size.x >= rect.size.y
	var depth := rect.size.y if along_x else rect.size.x
	if depth <= MAX_ROOF_DEPTH:
		return [{"rect": rect}]
	var main_first := rng.randf() < 0.5
	var main: Rect2i
	var rest: Rect2i
	if along_x:
		if main_first:
			main = Rect2i(rect.position, Vector2i(rect.size.x, MAX_ROOF_DEPTH))
			rest = Rect2i(rect.position + Vector2i(0, MAX_ROOF_DEPTH),
				Vector2i(rect.size.x, depth - MAX_ROOF_DEPTH))
		else:
			rest = Rect2i(rect.position, Vector2i(rect.size.x, depth - MAX_ROOF_DEPTH))
			main = Rect2i(rect.position + Vector2i(0, depth - MAX_ROOF_DEPTH),
				Vector2i(rect.size.x, MAX_ROOF_DEPTH))
	else:
		if main_first:
			main = Rect2i(rect.position, Vector2i(MAX_ROOF_DEPTH, rect.size.y))
			rest = Rect2i(rect.position + Vector2i(MAX_ROOF_DEPTH, 0),
				Vector2i(depth - MAX_ROOF_DEPTH, rect.size.y))
		else:
			rest = Rect2i(rect.position, Vector2i(depth - MAX_ROOF_DEPTH, rect.size.y))
			main = Rect2i(rect.position + Vector2i(depth - MAX_ROOF_DEPTH, 0),
				Vector2i(MAX_ROOF_DEPTH, rect.size.y))
	var out: Array = [{"rect": main, "axis": 0 if along_x else 1}]
	var rest_depth := depth - MAX_ROOF_DEPTH
	if rest_depth > MAX_ROOF_DEPTH:
		out.append_array(split_deep(rest, rng))
		return out
	# Cross gables: ridges perpendicular to the main, open toward it.
	var length := rect.size.x if along_x else rect.size.y
	var widths: Array[int] = []
	var left := length
	while left > 0:
		var w := 2 if left == 2 or left == 4 else 3
		if left == 1:
			widths[widths.size() - 1] += 1
			break
		widths.append(mini(w, left))
		left -= widths.back()
	var cursor := 0
	var open_side := "max" if not main_first else "min"
	for w: int in widths:
		var chunk: Rect2i
		if along_x:
			chunk = Rect2i(rest.position + Vector2i(cursor, 0), Vector2i(w, rest.size.y))
		else:
			chunk = Rect2i(rest.position + Vector2i(0, cursor), Vector2i(rest.size.x, w))
		out.append({"rect": chunk, "axis": 1 if along_x else 0, "cross": true,
			"open": open_side})
		cursor += w
	return out


## A secondary wing touching the main wing's long side turns its ridge
## toward it and continues into the main roof far enough that the main slope
## covers its ridge (no ridge board poking out of the main roof). A wing at
## the main's gable end keeps its own gable.
func _join_cross_wing(wing: Dictionary, main: Rect2i, main_axis: int) -> void:
	var rect := wing.rect as Rect2i
	var main_depth := main.size.y if main_axis == 0 else main.size.x
	if rect.end.y == main.position.y or rect.position.y == main.end.y:
		if main_axis != 0:
			return
		wing.axis = 1
		var ext := cross_extension(rect.size.x, main_depth)
		if rect.end.y == main.position.y:
			wing.open_max = true
			wing.extend_max = ext
		else:
			wing.open_min = true
			wing.extend_min = ext
	elif rect.end.x == main.position.x or rect.position.x == main.end.x:
		if main_axis != 1:
			return
		wing.axis = 0
		var ext := cross_extension(rect.size.y, main_depth)
		if rect.end.x == main.position.x:
			wing.open_max = true
			wing.extend_max = ext
		else:
			wing.open_min = true
			wing.extend_min = ext


## Modules a cross wing of `cross_depth` must run into a main roof of
## `main_depth` so that the main slope rises above the cross ridge.
func cross_extension(cross_depth: int, main_depth: int) -> int:
	var ridge := float(kit.roof_profile(cross_depth).height) + 0.35
	return clampi(ceili(ridge / kit.roof_row_rise), 1, maxi(1, main_depth / 2))


func _place_dormers(wing: Dictionary, rng: RandomNumberGenerator) -> void:
	# Dormers never touch: at least one plain roof module between two, and
	# none in the module beside a gable or an open (joined) end.
	var rect := wing.rect as Rect2i
	var axis := int(wing.axis)
	var length := rect.size.x if axis == 0 else rect.size.y
	var depth := rect.size.y if axis == 0 else rect.size.x
	if depth < 2 or length < 3 or rng.randf() < 0.2:
		return
	var u0 := rect.position.x if axis == 0 else rect.position.y
	var pattern := rng.randi_range(0, 2)
	for side in 2:
		if side == 1 and rng.randf() < 0.5:
			continue
		var last := -10
		for p in range(u0 + 1, u0 + length - 1):
			var i := p - u0
			var take := false
			match pattern:
				0: take = i % 2 == 1
				1: take = i == 1 or i == length - 2
				_: take = i == length / 2
			if take and p - last >= 2:
				wing.dormers[Vector2i(side, p)] = true
				last = p


func _assign_dressing(mass: BuildingMass, rng: RandomNumberGenerator,
		context: Dictionary) -> void:
	var band_h := kit.band_height()
	var terrain_storey := int(context.get("terrain_storey", 0))
	# Some houses are dressed heavily (flowers under most windows, ivy on the
	# corners and blank walls), others are plain: a per-house lushness.
	var lush := rng.randf()
	lush *= lush
	var box_chance := 0.25 + 0.5 * lush
	var ivy_chance := 0.18 + 0.45 * lush
	for index in mass.storeys.size():
		var storey: Dictionary = mass.storeys[index]
		var y := float(int(storey.floor_band)) * band_h
		var grounded := index == terrain_storey
		var jettied_above := bool(storey.get("inset", false))
		var above := _storey_at(mass, int(storey.floor_band) + 2)
		for slot: Dictionary in slots_of(mass, storey):
			var kind := StringName(storey.openings.get(slot.edge, storey.default_opening))
			var centre := slot.centre as Vector2
			var dir := int(slot.dir)
			if kind == BuildingMass.OPENING_DOOR and grounded:
				# A porch canopy needs a flush wall above it: under a jetty the
				# brackets already shelter the door, under an eave there is no
				# room, and a bay above would collide.
				var flush_above := not jettied_above and not above.is_empty() \
					and (above.cells as Dictionary).has(Vector2i(slot.edge.x, slot.edge.y)) \
					and StringName((above.openings as Dictionary).get(slot.edge, &"")) \
						!= BuildingMass.OPENING_BAY
				if flush_above and rng.randf() < 0.9 \
						and _awning_room(slot, int(storey.floor_band)):
					mass.decor.append({"kind": &"awning", "centre": centre,
						"dir": dir, "y": y})
				if rng.randf() < 0.45 and _front_open(slot, int(storey.floor_band)):
					var side := 1.0 if rng.randf() < 0.5 else -1.0
					mass.decor.append({"kind": &"doorstep", "centre": centre,
						"dir": dir, "y": y, "side": side,
						"count": rng.randi_range(1, 2)})
			elif kind == BuildingMass.OPENING_WINDOW \
					and storey.material == BuildingMass.MATERIAL_TIMBER \
					and rng.randf() < box_chance and _front_open(slot, int(storey.floor_band)):
				mass.decor.append({"kind": &"window_box", "centre": centre,
					"dir": dir, "y": y})
			if not grounded or not _front_open(slot, int(storey.floor_band)):
				continue
			# Ivy grows from the ground: a climbing patch on a blank wall, or a
			# climber wrapping a convex corner (placed on the face whose RIGHT
			# end is that corner, so every corner has one owner).
			if kind == BuildingMass.OPENING_PLAIN and rng.randf() < ivy_chance:
				mass.decor.append({"kind": &"ivy", "centre": centre, "dir": dir, "y": y})
			elif bool(slot.right_convex) and rng.randf() < ivy_chance:
				mass.decor.append({"kind": &"ivy_corner", "centre": centre,
					"dir": dir, "y": y})


## Nothing built stands in front of the slot at its storey (open ground or a
## public way is fine for visual-only dressing).
func _front_open(slot: Dictionary, band: int) -> bool:
	if not covered.is_valid():
		return true
	for cell: Vector2i in slot.outside:
		if bool(covered.call(cell, band)) or bool(covered.call(cell, band + 1)):
			return false
	return true


## An awning needs a street at least two cells deep in front and open sky
## over its canopy (no bridge, gallery or jetty of another house above).
func _awning_room(slot: Dictionary, band: int) -> bool:
	if not _front_open(slot, band):
		return false
	var dir := BuildingMass.DIRS[int(slot.dir)]
	for cell: Vector2i in slot.outside:
		if covered.is_valid() and (bool(covered.call(cell + dir, band)) \
				or bool(covered.call(cell, band + 2)) \
				or bool(covered.call(cell, band + 3))):
			return false
		if walked.is_valid() and (bool(walked.call(cell, band + 2)) \
				or bool(walked.call(cell, band + 3))):
			return false
		if forbidden.is_valid():
			for above in [band + 2, band + 3]:
				if bool(forbidden.call(cell, above)) and not bool(walked.call(cell, above)) \
						and not _is_public_air(cell, above):
					return false
	return true


## Hook for callers that know public air; the designer treats unknown space
## conservatively.
var public_air: Callable = Callable()


func _is_public_air(cell: Vector2i, band: int) -> bool:
	return public_air.is_valid() and bool(public_air.call(cell, band))


func _decor_clear(slot: Dictionary, band: int) -> bool:
	if not forbidden.is_valid():
		return true
	for cell: Vector2i in slot.outside:
		if bool(forbidden.call(cell, band)) or bool(forbidden.call(cell, band + 1)):
			return false
	return true


# --- helpers -------------------------------------------------------------------

static func _storey_at(mass: BuildingMass, floor_band: int) -> Dictionary:
	for storey: Dictionary in mass.storeys:
		if int(storey.floor_band) == floor_band:
			return storey
	return {}


static func _same_cells(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for cell: Vector2i in a:
		if not b.has(cell):
			return false
	return true


## True when half-module erosion leaves every wall run at least one module.
static func _erodable(cells: Dictionary) -> bool:
	for run: Dictionary in BuildingKitAssembler.boundary_runs(cells):
		var length := int(run.end) - int(run.start)
		if bool(run.start_convex) and bool(run.end_convex) and length < 2:
			return false
	return true


static func _bounds(cells: Dictionary) -> Rect2i:
	var first := true
	var rect := Rect2i()
	for cell: Vector2i in cells:
		if first:
			rect = Rect2i(cell, Vector2i.ONE)
			first = false
		else:
			rect = rect.expand(cell).expand(cell + Vector2i.ONE)
	return rect


## Greedy rectangle decomposition: largest area by default; with a ridge
## axis, longest along that axis first, then largest area.
static func decompose(cells: Dictionary, ridge_axis := -1) -> Array[Rect2i]:
	var remaining := cells.duplicate()
	var out: Array[Rect2i] = []
	while not remaining.is_empty():
		var best := Rect2i()
		var best_area := 0
		var best_span := 0
		var keys := remaining.keys()
		keys.sort()
		for start: Vector2i in keys:
			# Grow a rectangle right then down from each start cell.
			var max_w := 0
			while remaining.has(start + Vector2i(max_w, 0)):
				max_w += 1
			var w_limit := max_w
			var h := 0
			while true:
				var row_w := 0
				while row_w < w_limit and remaining.has(start + Vector2i(row_w, h)):
					row_w += 1
				if row_w == 0:
					break
				w_limit = row_w
				h += 1
				var area := w_limit * h
				# A lot's front-facing wing runs the full house depth. Select it
				# before the wider rear hall, whose shallower roof cannot bury
				# that wing's ridge. Other callers retain largest-area packing.
				var span := (w_limit if ridge_axis == 0 else h) if ridge_axis >= 0 else 0
				if span > best_span or (span == best_span and area > best_area):
					best_span = span
					best_area = area
					best = Rect2i(start, Vector2i(w_limit, h))
		out.append(best)
		for x in range(best.position.x, best.end.x):
			for z in range(best.position.y, best.end.y):
				remaining.erase(Vector2i(x, z))
	return out
