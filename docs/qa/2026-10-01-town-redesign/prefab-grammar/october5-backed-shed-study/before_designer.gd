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
## Callable(cell: Vector2i, band: int) -> bool: true where a public stair,
## ramp or gate approach flight (or its swept headroom) crosses this column
## near `band`. Nothing that stands on the floor (porch canopies, doorstep
## props) may be placed there.
var flight: Callable = Callable()
## Porch canopies already kept by neighbouring houses of the same town
## ({rect: Rect2, y: float}), shared by reference across designers so two
## houses at an inner corner never raise canopies into each other.
var canopy_claims: Array = []
## Town context gently favors the less-used ridge axis on free square
## crowns. Equal weights preserve standalone gable/eave-front variation.
var square_axis_weights := Vector2.ONE


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
	_assign_finish(mass, rng, colour)
	_assign_roofs(mass, rng, colour, bool(context.get("terraced", false)),
		int(context.get("roof_axis", -1)))
	_assign_facades(mass, rng, colour)
	_assign_dressing(mass, rng, context)


func _assign_materials(mass: BuildingMass, terrain_storey: int,
		stone_ground: bool) -> void:
	for index in mass.storeys.size():
		var storey: Dictionary = mass.storeys[index]
		var grounded := index == terrain_storey
		storey.material = BuildingMass.MATERIAL_STONE \
			if grounded and stone_ground else BuildingMass.MATERIAL_TIMBER
		# A compound's member on higher ground has its own footing course
		# (the assembler omits it wherever a storey stands below).
		storey.plinth = (grounded or not (storey.get("grounded", {}) as Dictionary).is_empty()) \
			and kit.has_role(&"plinth.stone")


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
		# A balcony above bears its rakers on this storey's wall at the upper
		# storey's module joints. Insetting the wall would shift its module
		# lattice half a module (joints become window centres) and leave the
		# rakers hanging in front of its openings.
		if bool(above.get("bears_balcony", false)) or bool(storey.get("abutted", false)):
			continue
		# A storey touching another building stays flush: the half-module
		# inset would open a dead slot between the two walls, its windows
		# looking at the neighbour's wall and corner posts a metre away.
		if _touches_other(storey):
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
		storey["bay_roles"] = {}
		storey["bay_offsets"] = {}
		storey.default_opening = BuildingMass.OPENING_WINDOW
		storey.plain_every = 0
		storey.bay_colour = colour
		var plain_rate := 0.22 if storey.material == BuildingMass.MATERIAL_STONE else 0.3
		var slots := slots_of(mass, storey)
		for slot: Dictionary in slots:
			if not storey.openings.has(slot.edge) and rng.randf() < plain_rate:
				storey.openings[slot.edge] = BuildingMass.OPENING_PLAIN
			# Retained ground can cover only the lower half of an exposed wall.
			# Keep its opening candidate for the measured native-panel fitter;
			# a high sill may clear the backing without moving the storey.
			if _lower_band_backed(slot, int(storey.floor_band)) \
					and StringName(storey.openings.get(slot.edge, &"")) \
						!= BuildingMass.OPENING_DOOR:
				if int(storey.get("bands",2)) == 2 \
						and not _lower_band_backed(slot, int(storey.floor_band)+1):
					if not storey.has("opening_min_y"): storey.opening_min_y = {}
					storey.opening_min_y[slot.edge] = (int(storey.floor_band)+1)*kit.band_height()+0.05
				else:
					storey.openings[slot.edge] = BuildingMass.OPENING_PLAIN
		if storey.material != BuildingMass.MATERIAL_TIMBER or index == 0:
			continue
		# Break up every long face with separated projecting oriels. The phase
		# changes by floor and face; corners and doors keep their own vocabulary.
		var phases := {}
		var selected_runs := {}
		for slot: Dictionary in slots:
			var dir := int(slot.dir)
			if not phases.has(dir): phases[dir] = rng.randi_range(0, 2)
			var position := int(slot.index)
			var length := int(slot.count)
			if length < 2: continue
			if length > 2 and (position == 0 or position == length - 1): continue
			var first := 0 if length == 2 else 1
			var phase := int(phases[dir]) % mini(3, length - 2 if length > 2 else 2)
			if posmod(position - first - phase, 3) != 0: continue
			if not _bay_clear(mass, slot, int(storey.floor_band)): continue
			var opening := StringName(storey.openings.get(slot.edge, BuildingMass.OPENING_WINDOW))
			if opening not in [BuildingMass.OPENING_WINDOW, BuildingMass.OPENING_PLAIN]: continue
			var centre := slot.centre as Vector2
			var run := Vector2(dir, centre.x if dir % 2 == 0 else centre.y)
			if not selected_runs.has(run) or rng.randf() < 0.75:
				storey.openings[slot.edge] = BuildingMass.OPENING_BAY
				selected_runs[run] = true
		# Small independent spire bays were rejected as tacked-on decoration.
		# Full towers are proposed by KitTownTowers with host/bearing/roof
		# contracts; ordinary projecting window bays remain available here.



## True when any cell beside the storey's footprint is filled by another
## building within the storey's bands.
func _touches_other(storey: Dictionary) -> bool:
	if not covered.is_valid():
		return false
	var band := int(storey.floor_band)
	for cell: Vector2i in storey.cells:
		for dir in 4:
			var beside: Vector2i = cell + BuildingMass.DIRS[dir]
			if (storey.cells as Dictionary).has(beside):
				continue
			for rise in int(storey.get("bands", 2)):
				if bool(covered.call(beside, band + rise)):
					return true
	return false


func _lower_band_backed(slot: Dictionary, band: int) -> bool:
	if not covered.is_valid():
		return false
	for cell: Vector2i in slot.outside:
		if bool(covered.call(cell, band)):
			return true
	return false


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


func _bay_clear(mass: BuildingMass, slot: Dictionary, band: int) -> bool:
	for cell: Vector2i in slot.outside:
		if mass.cells_at_band(band).has(cell): return false
		for deck: Dictionary in mass.decks:
			if int(deck.band) == band and deck.cells.has(cell): return false
		for b in [band, band + 1]:
			if forbidden.is_valid() and bool(forbidden.call(cell, b)): return false
	return true


func _oriel_gable_centre(mass: BuildingMass, slot: Dictionary, band: int) -> Vector2:
	var dir := int(slot.dir)
	var centre: Vector2 = slot.centre
	for roof: Dictionary in mass.roofs:
		if int(roof.eave_band)!=band+2 or int(roof.axis)!=dir%2: continue
		var rect: Rect2i = roof.rect
		var line := float(rect.end.x if dir==0 else rect.end.y if dir==1 else rect.position.x if dir==2 else rect.position.y)
		if absf((centre.x if dir%2==0 else centre.y)-line)>0.01: continue
		var target := Vector2(rect.position)+Vector2(rect.size)*0.5
		if dir%2==0: target.x = centre.x
		else: target.y = centre.y
		var backed := true
		var inward := -Vector2(BuildingMass.DIRS[dir])*0.05
		var right := Vector2(BuildingKitAssembler.right_of(dir))
		for along: float in [-0.49,0.49]:
			var point := target+inward+right*along
			if not mass.cells_at_band(band).has(Vector2i(floori(point.x),floori(point.y))): backed = false
		if backed and target.distance_to(centre)<=1.01: return target
	return Vector2(INF,INF)

func _oriel_clear(mass: BuildingMass, slot: Dictionary, band: int) -> bool:
	if not kit.has_role(&"bay.spire") or not kit.oriel_bounds.has_volume(): return false
	var centre: Vector2 = slot.centre
	var pose := Transform3D(Basis(Vector3.UP,BuildingKitAssembler.yaw_for_dir(int(slot.dir))),
		Vector3(centre.x*kit.module_width,float(band)*kit.band_height()+kit.band_height()*2.0/3.0,
			centre.y*kit.module_width))
	var box := (pose*kit.oriel_bounds).grow(-0.002)
	var own := mass.cells_at_band(band)
	for x in range(floori(box.position.x/kit.module_width),ceili(box.end.x/kit.module_width)):
		for z in range(floori(box.position.z/kit.module_width),ceili(box.end.z/kit.module_width)):
			var cell := Vector2i(x,z)
			if own.has(cell): continue # the shallow backing is the host facade
			for b in range(floori(box.position.y/kit.band_height()),ceili(box.end.y/kit.band_height())):
				if mass.cells_at_band(b).has(cell): return false
				if forbidden.is_valid() and bool(forbidden.call(cell,b)): return false
	return true


## Roof wings over the exposed crown of every storey: a main wing on the
## largest rectangle, ridge along its long axis, then cross wings abutting it.
## A wing whose roof volume would enter kept-clear space turns its ridge; if
## neither ridge fits, the crown becomes a railed timber roof terrace.
func _assign_roofs(mass: BuildingMass, rng: RandomNumberGenerator,
		colour: StringName, terraced := false, ridge_axis := -1) -> void:
	mass.roofs.clear()
	mass.roof_design_trace.clear()
	mass.decks.clear()
	var square_axis := _square_axis(mass)
	var front := front_dir(mass)
	var eave_axis := 1 - front % 2 if front >= 0 else square_axis
	for storey: Dictionary in mass.storeys:
		var top_band := int(storey.floor_band) + 2
		storey["covered_crown"] = {}
		var exposed: Dictionary = {}
		var covering := mass.cells_at_band(top_band)
		for cell: Vector2i in storey.cells:
			if covering.has(cell):
				continue
			if walked.is_valid() and bool(walked.call(cell, top_band)):
				continue
			if covered.is_valid() and bool(covered.call(cell, top_band)):
				# Structural occupancy can be a hollow retaining skin. Remember
				# the suppressed roof so the finished town can supply a ceiling
				# unless another room's actual floor already closes this crown.
				storey.covered_crown[cell] = true
				continue
			exposed[cell] = true
		if exposed.is_empty():
			continue
		if terraced and not covering.is_empty():
			# A compound building roofs each merged lot's own top; only a
			# crown beneath the same lot's upper storey is a terrace.
			var roofed: Dictionary = storey.get("roofed", {})
			var terrace: Dictionary = {}
			for cell: Vector2i in exposed:
				if not roofed.has(cell): terrace[cell] = true
			for cell: Vector2i in terrace: exposed.erase(cell)
			if not terrace.is_empty():
				_add_terrace(mass, terrace, covering, top_band)
			if exposed.is_empty():
				continue
		var wings: Array = []
		var rects := _absorb_slivers(mass, decompose(exposed, ridge_axis),
			exposed, storey.cells, top_band)
		# A compound's notched crown can leave strips the whole-crown
		# packing cannot absorb; its members' own crowns may pack cleanly.
		# The same when a compound's whole-crown wing would point a tall gable
		# into a neighbouring building (the members' own lower gables did not).
		if (_slivers(rects) > 0 or _abutting(mass, rects, top_band) > 0) \
				and storey.has("crown_parts"):
			var parted: Array[Rect2i] = []
			for part: Dictionary in storey.crown_parts:
				var own := {}
				for cell: Vector2i in part:
					if exposed.has(cell): own[cell] = true
				if not own.is_empty():
					parted.append_array(decompose(own, ridge_axis))
			parted = _absorb_slivers(mass, parted, exposed, storey.cells, top_band)
			if _slivers(parted) <= _slivers(rects) \
					and _abutting(mass, parted, top_band) < _abutting(mass, rects, top_band) \
					or _slivers(parted) < _slivers(rects):
				rects = parted
		for rect: Rect2i in rects:
			# A strip that could not join the larger wing beside it becomes a
			# flat boarded roof rather than a tiny pitched roof perched at its
			# edge. No storey reaches it, so it is not a (railed) terrace.
			if mini(rect.size.x, rect.size.y) < 2 and _beside_wing(rect, rects):
				mass.decks.append({"cells": BuildingMass.rect_cells(rect),
					"band": top_band, "rails": false})
				continue
			var preferred_depth := rect.size.y if ridge_axis == 0 else rect.size.x
			if ridge_axis >= 0 and preferred_depth <= MAX_ROOF_DEPTH:
				wings.append({"rect": rect, "axis": ridge_axis})
			else:
				wings.append_array(split_deep(rect, rng))
		# A long hall can carry a transverse pavilion. Both roofs stay on
		# the existing rooms; native junctions close their meeting slopes.
		# Try a taller bay, then a lower cross wing where the setting is tight.
		if ridge_axis < 0:
			var articulated: Array = []
			for spec: Dictionary in wings:
				var range_rect: Rect2i = spec.rect
				var range_axis := int(spec.get("axis", _natural_axis(range_rect, square_axis)))
				var range_rng := _rng(hash([mass.seed, range_rect, top_band, "range.end_bay"]))
				var end_bay := _range_end_bay(mass, range_rect, range_axis, top_band, range_rng, 0, articulated)
				if end_bay.is_empty(): articulated.append(spec)
				else: articulated.append_array(end_bay)
			wings = articulated
		var main_rect := Rect2i()
		var have_main := false
		var main_axis := 0
		for i in wings.size():
			var spec: Dictionary = wings[i]
			var rect := spec.rect as Rect2i
			var axis := int(spec.get("axis", _natural_axis(rect, square_axis)))
			var cross := bool(spec.get("cross", false))
			if have_main and not cross:
				axis = _wing_axis(rect, axis, main_rect, main_axis)
			# A square crown's ridge is a free choice: never point a gable
			# into another building standing above the eave (its taller wall
			# half-buries the gable triangle and the union leaves holes).
			if not cross and rect.size.x == rect.size.y \
					and _gable_abuts(mass, rect, axis, top_band) \
					and not _gable_abuts(mass, rect, 1 - axis, top_band):
				axis = 1 - axis
			var fits := _roof_fits(mass, rect, axis, top_band)
			if not fits and not cross:
				axis = 1 - axis
				fits = _roof_fits(mass, rect, axis, top_band)
			if not fits and not cross:
				# A deep crown (a merged range) whose tall roof would enter
				# kept-clear space above: a double pile of shallower parallel
				# roofs, eaves to the street, before a flat terrace.
				var piles := _double_pile(mass, rect, eave_axis, top_band)
				if not piles.is_empty():
					for pile: Rect2i in piles.rects:
						mass.add_roof(pile, int(piles.axis), top_band, colour)
					continue
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
			if not cross:
				_place_dormers(wing, rng)
			else:
				# A connected hall is still an inhabited roof. Its interior bays
				# can carry native dormers; the town-wide measured fitter rejects
				# openings hidden by the host roof. Keep this draw independent so
				# adding it cannot reshuffle the house's other design choices.
				_place_dormers(wing, _rng(hash([mass.seed, rect, top_band, "cross.dormers"])))
	# Wings meeting a larger wing become branches running into it; the same
	# rule reconciles roofs across houses (KitRoofJunctions).
	var masses: Array[BuildingMass] = [mass]
	KitRoofJunctions.join(masses, func(cell: Vector2i, band: int) -> bool:
		return not forbidden.is_valid() or not bool(forbidden.call(cell, band)))
	# Roof area over free air is a porch/loggia carried on corner posts.
	var posted: Dictionary = {}
	for roof: Dictionary in mass.roofs:
		var posts: Variant = _porch_posts(mass, roof.rect, int(roof.eave_band))
		if posts == null: continue
		for item: Dictionary in posts:
			var key := Vector3i(int(item.centre.x), int(item.centre.y), int(item.to_band))
			if posted.has(key): continue
			posted[key] = true
			mass.decor.append(item)


## `rect` split into parallel piles two modules deep (the last one three
## when the depth is odd), each roofed with its ridge along `axis` (then the
## other axis): {axis, rects}, or {} when the rect is not deep enough for two
## piles or a pile's roof does not fit either.
func _double_pile(mass: BuildingMass, rect: Rect2i, axis: int, band: int) -> Dictionary:
	for ridge: int in [axis, 1 - axis]:
		var side := 1 - ridge
		if rect.size[side] < 4:
			continue
		var piles: Array[Rect2i] = []
		var at := rect.position[side]
		while at < rect.end[side]:
			var pile := rect
			pile.position[side] = at
			pile.size[side] = 3 if rect.end[side] - at == 3 else 2
			piles.append(pile)
			at += pile.size[side]
		var fits := true
		for pile: Rect2i in piles:
			fits = fits and _roof_fits(mass, pile, ridge, band)
		if fits:
			return {"axis": ridge, "rects": piles}
	return {}


## Crown rectangles whose gable, taller than one storey, would face another
## building whichever way a square one turns its ridge.
func _abutting(mass: BuildingMass, rects: Array[Rect2i], band: int) -> int:
	var count := 0
	for rect: Rect2i in rects:
		var axis := _natural_axis(rect, 0)
		if float(kit.roof_profile(rect.size[1 - axis]).height) <= kit.storey_height:
			continue
		if not _gable_abuts(mass, rect, axis, band):
			continue
		if rect.size.x == rect.size.y and not _gable_abuts(mass, rect, 1 - axis, band):
			continue
		count += 1
	return count


## True when a gable end of `rect` roofed along `axis` (eave at `band`)
## faces another building's solid within the gable's height.
func _gable_abuts(mass: BuildingMass, rect: Rect2i, axis: int, band: int) -> bool:
	if not covered.is_valid():
		return false
	var side := 1 - axis
	var bands := int(ceil(float(kit.roof_profile(rect.size[side]).height) / kit.band_height() - 0.15))
	for end: int in [rect.position[axis] - 1, rect.end[axis]]:
		for across in range(rect.position[side], rect.end[side]):
			var cell := Vector2i.ZERO
			cell[axis] = end
			cell[side] = across
			for b in range(band, band + bands):
				if bool(covered.call(cell, b)):
					return true
	return false


## A cross wing may terminate against a taller house only when its entire
## gable envelope is backed. Partial contacts still leave exposed cut edges.
## Keep at least one free end so the new gable contributes to the street.
func _cross_gable_obstructed(rect: Rect2i, axis: int, band: int, protect_walk_rim := false) -> bool:
	var side := 1-axis
	var bands := int(ceil(float(kit.roof_profile(rect.size[side]).height) / kit.band_height()-0.15))
	# A walk deck at ridge height can carry a railing outside its own floor
	# cells. Keep the new gable's ridge/verge away from that one-cell rim.
	if protect_walk_rim and walked.is_valid():
		for x in range(rect.position.x-1,rect.end.x+1):
			for z in range(rect.position.y-1,rect.end.y+1):
				for b in range(band,band+bands+1):
					if bool(walked.call(Vector2i(x,z),b)): return true
	if not covered.is_valid(): return false
	var free_ends := 0
	for end: int in [rect.position[axis]-1,rect.end[axis]]:
		var occupied := 0
		var total := rect.size[side]*bands
		for across in range(rect.position[side],rect.end[side]):
			var cell := Vector2i.ZERO
			cell[axis] = end
			cell[side] = across
			for b in range(band,band+bands):
				occupied += int(bool(covered.call(cell,b)))
		if occupied==0: free_ends += 1
		elif occupied!=total: return true
	return free_ends==0


## Ridge of a crown rectangle: along its long side; a square crown turns
## its ridge by the house's own choice (`square_axis`). The former fixed
## tie-break ran every square house's ridge along X, so a town of one-lot
## houses read as rows of gables all facing one way (photo 11).
static func _natural_axis(rect: Rect2i, square_axis: int) -> int:
	if rect.size.x == rect.size.y:
		return square_axis
	return 0 if rect.size.x > rect.size.y else 1


## Whether a square crown shows its gable or its eave to the street its
## front door opens onto (an even, seeded mix of gable- and eave-fronted
## houses); a house without a door picks an axis.
func _square_axis(mass: BuildingMass) -> int:
	var front := front_dir(mass)
	var preferred := front % 2 if front >= 0 else 0
	var share := square_axis_weights[preferred] / (square_axis_weights.x + square_axis_weights.y)
	var gable_front := _rng(hash([mass.seed, &"ridge"])).randf() < share
	return preferred if gable_front else 1 - preferred


## Face (BuildingMass.DIRS index) of the house's lowest door, or -1.
static func front_dir(mass: BuildingMass) -> int:
	var front := -1
	var lowest := 1 << 20
	for storey: Dictionary in mass.storeys:
		for key: Vector3i in storey.openings:
			if StringName(storey.openings[key]) == BuildingMass.OPENING_DOOR \
					and int(storey.floor_band) < lowest:
				lowest = int(storey.floor_band)
				front = key.z
	return front


## Lower wings become accessible balconies when the next floor steps back.
## Shared edges belong to the house wall; only the exposed sides get rails.
func _add_terrace(mass: BuildingMass, cells: Dictionary, covering: Dictionary,
		band: int) -> void:
	# A T-shaped crown can leave two separate terraces. Each must get its
	# own doorway rather than inheriting the first component's access.
	var remaining := cells.duplicate()
	var upper := _storey_at(mass, band)
	while not remaining.is_empty():
		var component := {}
		var pending: Array = [remaining.keys()[0]]
		while not pending.is_empty():
			var cell: Vector2i = pending.pop_back()
			if not remaining.has(cell): continue
			remaining.erase(cell)
			component[cell] = true
			for step: Vector2i in BuildingMass.DIRS:
				if remaining.has(cell + step): pending.append(cell + step)
		var open_edges := {}
		var door_added := false
		for cell: Vector2i in component:
			for dir in 4:
				var next := cell + BuildingMass.DIRS[dir]
				if not covering.has(next): continue
				open_edges[BuildingMass.edge_key(cell, dir)] = true
				if not door_added and not upper.is_empty():
					upper.openings[BuildingMass.edge_key(next, (dir + 2) % 4)] = BuildingMass.OPENING_DOOR
					door_added = true
		mass.decks.append({"cells": component, "band": band, "rails": true,
			"open_edges": open_edges})


func _roof_fits(mass: BuildingMass, rect: Rect2i, axis: int, eave_band: int) -> bool:
	if not forbidden.is_valid():
		return true
	var depth := rect.size.y if axis == 0 else rect.size.x
	var height := kit.roof_clearance_height(depth)
	var bands := int(ceil(height / kit.band_height()))
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


func _range_end_bay(mass: BuildingMass, rect: Rect2i, axis: int,
		band: int, rng: RandomNumberGenerator, joined_ends: int = 0, neighbours: Array = []) -> Array:
	var depth := rect.size[1 - axis]
	var length := rect.size[axis]
	if depth < 2 or depth > 4 or length < maxi(4, maxi(depth + 2, ceili(depth * 1.5))): return []
	var trace := {"rect": rect, "axis": axis, "band": band, "outcome": "blocked", "roof_rejections": 0, "gable_rejections": 0}
	mass.roof_design_trace.append(trace)
	# Broad halls may remain simple. Two-to-one ranges always seek a
	# connected cross-gable; the same roll varies end versus central pavilions.
	var roll := rng.randf()
	var elongated := length >= depth * 2
	if roll >= 0.8 and not elongated:
		trace.outcome = "simple_roll"
		return []
	var preferred_start := rng.randf() < 0.5
	# A lower cross wing can tuck beneath an existing upper facade when the
	# taller pavilion cannot. Both use complete native roof profiles.
	var widths: Array[int] = [mini(MAX_ROOF_DEPTH, mini(depth+1,length-2))]
	if widths[0] != depth: widths.append(depth)
	for width: int in widths:
		var ends: Array[int] = [0,length-width]
		if not preferred_start: ends.reverse()
		var inner: Array[int] = []
		for start in range(2,length-width-1): inner.append(start)
		inner.sort_custom(func(a: int,b: int) -> bool:
			var da := absi(2*a-(length-width))
			var db := absi(2*b-(length-width))
			return da < db if da != db else (a < b if preferred_start else a > b))
		var starts: Array[int] = []
		starts.append_array(inner if roll >= 0.8 else ends)
		starts.append_array(ends if roll >= 0.8 else inner)
		for start: int in starts:
			# Keep a real hall between successive pavilions, rather than
			# introducing another pair of touching parallel gables.
			if joined_ends & 1 and start < 2: continue
			if joined_ends & 2 and length-start-width < 2: continue
			var bay := rect
			bay.position[axis] += start
			bay.size[axis] = width
			if _recreates_long_roof(bay, 1-axis, neighbours): continue
			if not _roof_fits(mass,bay,1-axis,band):
				trace.roof_rejections += 1
				continue
			if _cross_gable_obstructed(bay,1-axis,band,width==depth):
				trace.gable_rejections += 1
				continue
			var pieces: Array = [{"rect":bay,"axis":1-axis,"cross":true}]
			var fits := true
			for interval: Vector2i in [Vector2i(0,start),Vector2i(start+width,length)]:
				if interval.y == interval.x: continue
				var hall := rect
				hall.position[axis] += interval.x
				hall.size[axis] = interval.y-interval.x
				fits = fits and _roof_fits(mass,hall,axis,band)
				var joins := (joined_ends & 1) | 2 if interval.x == 0 else (joined_ends & 2) | 1
				pieces.append({"rect":hall,"axis":axis,"cross":true,"joined_ends":joins})
			if fits:
				trace.outcome = "cross_gable"
				trace.bay = bay
				# An end pavilion must not leave an arbitrarily long plain
				# remainder. Recur on strictly smaller supported hall pieces;
				# their native envelopes and gables undergo the same checks.
				var articulated: Array = [pieces[0]]
				for hall: Dictionary in pieces.slice(1):
					var next := _range_end_bay(mass, hall.rect, axis, band, rng, int(hall.joined_ends), neighbours + articulated)
					if next.is_empty(): articulated.append(hall)
					else: articulated.append_array(next)
				return articulated
			trace.roof_rejections += 1
	return []


static func _recreates_long_roof(rect: Rect2i, axis: int, neighbours: Array) -> bool:
	# Predict the ordinary collinear union. Adjacent crown strips should not
	# align their pavilions into a new uninterrupted range longer than the one
	# being articulated. Keep the normal joining/closure rules unchanged.
	var joined := rect
	var changed := true
	while changed:
		changed = false
		for neighbour: Dictionary in neighbours:
			var other: Rect2i = neighbour.rect
			if int(neighbour.get("axis", _natural_axis(other, axis))) != axis: continue
			var side := 1-axis
			if other.position[side] != joined.position[side] or other.size[side] != joined.size[side]: continue
			var gap := maxi(other.position[axis], joined.position[axis])-mini(other.end[axis], joined.end[axis])
			if gap > 1: continue
			var united := joined.merge(other)
			if united == joined: continue
			joined = united
			changed = true
	var depth := joined.size[1-axis]
	return joined != rect and joined.size[axis] >= maxi(4, maxi(depth+2, ceili(depth*1.5)))


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


## Ridge axis of a secondary wing beside the main wing: toward the main when
## it stands on the main's long side (a cross gable), along the main's ridge
## when it continues from the main's gable end inside its depth (a lower
## stepped wing). Equal-width continuations share its ridge and merge into
## one roof; narrower continuations meet it as a buried branch.
static func _wing_axis(rect: Rect2i, axis: int, main: Rect2i, main_axis: int) -> int:
	var across := 1 - main_axis
	var beside := rect.end[across] == main.position[across] or rect.position[across] == main.end[across]
	if beside and rect.position[main_axis] >= main.position[main_axis] \
			and rect.end[main_axis] <= main.end[main_axis]:
		return across
	var beyond := rect.end[main_axis] == main.position[main_axis] or rect.position[main_axis] == main.end[main_axis]
	if beyond and rect.position[across] >= main.position[across] and rect.end[across] <= main.end[across] \
			and rect.size[across] <= main.size[across]:
		return main_axis
	return axis


## No wing is one module deep: a lone ridge-top row perches like a tiny roof
## beside the big one (owner review, September 27). A one-module strip joins
## the rectangle it shares an edge with, or grows across its short side, when
## the grown rectangle only adds crown cells or free air the roof may shelter.
## Largest crown coverage wins, then fewest sheltered air cells.
func _absorb_slivers(mass: BuildingMass, rects: Array[Rect2i], exposed: Dictionary,
		footprint: Dictionary, band: int) -> Array[Rect2i]:
	var out := rects.duplicate()
	var progress := true
	while progress:
		progress = false
		for sliver: Rect2i in out:
			if mini(sliver.size.x, sliver.size.y) >= 2:
				continue
			var candidates: Array[Rect2i] = []
			for other: Rect2i in out:
				if other != sliver and other.grow(1).intersects(sliver) \
						and not _diagonal(other, sliver):
					candidates.append(other.merge(sliver))
			for axis in 2:
				if sliver.size[axis] != 1 or sliver.size[1 - axis] < 2: continue
				for sign in [-1, 1]:
					var grown := sliver
					grown.size[axis] += 1
					if sign < 0: grown.position[axis] -= 1
					candidates.append(grown)
			var best := Rect2i()
			var best_score := Vector2i(-1, 0)
			for candidate: Rect2i in candidates:
				if mini(candidate.size.x, candidate.size.y) < 2: continue
				var score := _shelter_score(mass, candidate, out, exposed, footprint, band)
				if score.x > best_score.x or (score.x == best_score.x and score.y > best_score.y):
					best = candidate
					best_score = score
			if best_score.x < 0:
				continue
			var kept: Array[Rect2i] = []
			for other: Rect2i in out:
				if not best.encloses(other): kept.append(other)
			kept.append(best)
			out = kept
			progress = true
			break
	return out


static func _slivers(rects: Array[Rect2i]) -> int:
	var count := 0
	for rect: Rect2i in rects:
		if mini(rect.size.x, rect.size.y) < 2: count += 1
	return count


static func _beside_wing(sliver: Rect2i, rects: Array[Rect2i]) -> bool:
	for other: Rect2i in rects:
		if other != sliver and mini(other.size.x, other.size.y) >= 2 \
				and other.grow(1).intersects(sliver) and not _diagonal(other, sliver):
			return true
	return false


static func _diagonal(a: Rect2i, b: Rect2i) -> bool:
	var dx := maxi(a.position.x, b.position.x) - mini(a.end.x, b.end.x)
	var dy := maxi(a.position.y, b.position.y) - mini(a.end.y, b.end.y)
	return dx >= 0 and dy >= 0


## (crown cells covered, -new air cells) for a grown roof rectangle, or x = -1
## when it would split another rectangle or shelter air the roof may not use.
func _shelter_score(mass: BuildingMass, candidate: Rect2i, rects: Array[Rect2i],
		exposed: Dictionary, footprint: Dictionary, band: int) -> Vector2i:
	var host := Rect2i()
	var enclosed: Array[Rect2i] = []
	for other: Rect2i in rects:
		if not candidate.intersects(other): continue
		if not candidate.encloses(other): return Vector2i(-1, 0)
		enclosed.append(other)
		if mini(other.size.x, other.size.y) >= 2 and other.get_area() > host.get_area(): host = other
	var crown := 0
	var absorbed := 0
	var air := 0
	for cell: Vector2i in BuildingMass.rect_cells(candidate):
		if exposed.has(cell):
			crown += 1
			if not host.has_point(cell): absorbed += 1
			continue
		var sheltered := false
		for other: Rect2i in enclosed: sheltered = sheltered or other.has_point(cell)
		if sheltered: continue
		# Air beside the storey (never a covered or walked part of it).
		if footprint.has(cell) or mass.cells_at_band(band).has(cell):
			return Vector2i(-1, 0)
		if (walked.is_valid() and bool(walked.call(cell, band))) \
				or (covered.is_valid() and bool(covered.call(cell, band))):
			return Vector2i(-1, 0)
		air += 1
	# Shelter at most one module strip of new air (or as much air as the
	# crown it absorbs beyond the largest proper wing), never a courtyard.
	if air > maxi(absorbed, maxi(candidate.size.x, candidate.size.y)):
		return Vector2i(-1, 0)
	if not _roof_fits(mass, candidate, 0, band) and not _roof_fits(mass, candidate, 1, band):
		return Vector2i(-1, 0)
	# Sheltered air must read as a deliberate porch: every post must stand.
	if air > 0 and _porch_posts(mass, candidate, band) == null:
		return Vector2i(-1, 0)
	return Vector2i(crown, -air)


## Timber posts carrying a roof `rect` (eave at `band`) wherever it shelters
## free air rather than its own storey: one post at every vertex of that air
## which no wall of the storey below touches (the outer corners of a covered
## strip, and every module along a free edge). Each post stands on the
## highest own floor below it or the house's ground band, at most two storeys
## down. Returns the `post` decor items, or null when a post would stand in
## public or reserved space, on a flight, or deeper than that (the caller
## then keeps a terrace or the unmerged roof instead).
func _porch_posts(mass: BuildingMass, rect: Rect2i, band: int) -> Variant:
	var below := mass.cells_at_band(band - 1)
	var vertices: Dictionary = {}
	for cell: Vector2i in BuildingMass.rect_cells(rect):
		if below.has(cell): continue
		for corner: Vector2i in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.ONE, Vector2i.DOWN]:
			vertices[cell + corner] = true
	var out: Array[Dictionary] = []
	for vertex: Vector2i in vertices:
		var around: Array[Vector2i] = [vertex, vertex - Vector2i.RIGHT,
			vertex - Vector2i.DOWN, vertex - Vector2i.ONE]
		var walled := false
		for cell: Vector2i in around: walled = walled or below.has(cell)
		if walled: continue
		var from := mass.ground_band
		for b in range(band - 2, mass.ground_band - 1, -1):
			var own := mass.cells_at_band(b)
			var floor_found := false
			for cell: Vector2i in around: floor_found = floor_found or own.has(cell)
			if floor_found:
				from = b + 1
				break
		# At most two storeys: a porch, loggia or double-height veranda,
		# never a stilt through a whole tower.
		if band - from < 1 or band - from > 4: return null
		for cell: Vector2i in around:
			if flight.is_valid() and bool(flight.call(cell, from)): return null
			for b in range(from, band):
				if mass.cells_at_band(b).has(cell): continue
				if forbidden.is_valid() and bool(forbidden.call(cell, b)): return null
				if covered.is_valid() and bool(covered.call(cell, b)): return null
		out.append({"kind": &"post", "dir": 0, "centre": Vector2(vertex),
			"from_band": from, "to_band": band})
	return out


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
	var box_chance := (0.5 if context.get("terraced", false) else 0.25) + 0.5 * lush
	var ivy_chance := (0.35 if context.get("terraced", false) else 0.18) + 0.45 * lush
	for index in mass.storeys.size():
		var storey: Dictionary = mass.storeys[index]
		var y := float(int(storey.floor_band)) * band_h
		var grounded := index == terrain_storey
		var jettied_above := bool(storey.get("inset", false))
		var above := _storey_at(mass, int(storey.floor_band) + 2)
		# Wall dressing stands on the wall's outer face; deep masonry is proud
		# of the timber wall plane by this much.
		var proud := kit.face_of(storey.material, bool(storey.get("retaining", false))) - kit.wall_face
		for slot: Dictionary in slots_of(mass, storey):
			var kind := StringName(storey.openings.get(slot.edge, storey.default_opening))
			if (storey.get("passage_edges", {}) as Dictionary).has(slot.edge):
				continue # An internal crossing keeps its full entrance clear.
			var centre := slot.centre as Vector2
			var dir := int(slot.dir)
			var on_ground := grounded or (storey.get("grounded", {}) as Dictionary).has(
				Vector2i(slot.edge.x, slot.edge.y))
			var sheltered := false
			if on_ground and context.get("terraced", false) and not above.is_empty():
				var outside := Vector2i(slot.edge.x, slot.edge.y) + BuildingMass.DIRS[dir]
				sheltered = above.cells.has(outside) and not storey.cells.has(outside)
			if sheltered and rng.randf() < 0.85 and _front_open(slot, int(storey.floor_band)):
				_add_awning(mass, {"kind": &"awning", "centre": centre,
					"dir": dir, "y": y, "sheltered": true, "proud": proud}, int(storey.floor_band))
			if kind == BuildingMass.OPENING_DOOR and on_ground:
				# A porch canopy needs a flush wall above it: under a jetty the
				# brackets already shelter the door, under an eave there is no
				# room, and a bay above would collide.
				var flush_above := not jettied_above and not above.is_empty() \
					and (above.cells as Dictionary).has(Vector2i(slot.edge.x, slot.edge.y)) \
					and StringName((above.openings as Dictionary).get(slot.edge, &"")) \
						!= BuildingMass.OPENING_BAY
				if not sheltered and flush_above and rng.randf() < 0.9 \
						and _awning_room(slot, int(storey.floor_band)):
					_add_awning(mass, {"kind": &"awning", "centre": centre,
						"dir": dir, "y": y, "proud": proud}, int(storey.floor_band))
				if rng.randf() < 0.45 and _front_open(slot, int(storey.floor_band)) \
						and _level_ground(slot.outside, int(storey.floor_band)):
					var side := 1.0 if rng.randf() < 0.5 else -1.0
					mass.decor.append({"kind": &"doorstep", "centre": centre,
						"dir": dir, "y": y, "side": side, "proud": proud,
						"count": rng.randi_range(1, 2)})
			elif kind == BuildingMass.OPENING_WINDOW \
					and storey.material == BuildingMass.MATERIAL_TIMBER \
					and rng.randf() < box_chance and _front_open(slot, int(storey.floor_band)):
				mass.decor.append({"kind": &"window_box", "centre": centre,
					"dir": dir, "y": y})
			if not on_ground or not _front_open(slot, int(storey.floor_band)):
				continue
			# Ivy grows from the ground: a climbing patch on a blank wall, or a
			# climber wrapping a convex corner (placed on the face whose RIGHT
			# end is that corner, so every corner has one owner).
			if kind == BuildingMass.OPENING_PLAIN and rng.randf() < ivy_chance:
				mass.decor.append({"kind": &"ivy", "centre": centre, "dir": dir, "y": y,
					"proud": proud})
			elif bool(slot.right_convex) and rng.randf() < ivy_chance:
				mass.decor.append({"kind": &"ivy_corner", "centre": centre,
					"dir": dir, "y": y, "proud": proud})
	_space_awnings(mass)


## A porch canopy is a free-standing four-post lean-to: every post stands on
## the floor in front of its wall module. Admit it only where that complete
## footprint is level public floor at the storey's own band -- never on a
## stair, ramp or gate flight, over open air, or inside another building.
func _add_awning(mass: BuildingMass, item: Dictionary, band: int) -> void:
	var footprint := BuildingKitAssembler.awning_footprint(kit, item)
	var cells: Array[Vector2i] = []
	for x in range(floori(footprint.position.x + 0.01), ceili(footprint.end.x - 0.01)):
		for z in range(floori(footprint.position.y + 0.01), ceili(footprint.end.y - 0.01)):
			cells.append(Vector2i(x, z))
	for cell: Vector2i in cells:
		if mass.cells_at_band(band).has(cell):
			return
		for b in [band, band + 1]:
			if covered.is_valid() and bool(covered.call(cell, b)):
				return
	if not _level_ground(cells, band):
		return
	item.footprint = footprint
	mass.decor.append(item)


## True when every cell is flat public floor at `band` (or unknown ground on a
## standalone lot) and no flight crosses it.
func _level_ground(cells: Array, band: int) -> bool:
	for cell: Vector2i in cells:
		if flight.is_valid() and bool(flight.call(cell, band)):
			return false
		if walked.is_valid() and not bool(walked.call(cell, band)):
			return false
	return true


## Entrance porches first; then whole sheltered canopies wherever they do not
## overlap one already kept (perpendicular faces of an inner corner compete
## for the same floor).
func _space_awnings(mass: BuildingMass) -> void:
	var candidates: Array[Dictionary] = []
	var retained: Array[Dictionary] = []
	for item: Dictionary in mass.decor:
		if item.kind == &"awning": candidates.append(item)
		else: retained.append(item)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return not a.get("sheltered", false) and b.get("sheltered", false))
	for item: Dictionary in candidates:
		var rect: Rect2 = item.get("footprint", BuildingKitAssembler.awning_footprint(kit, item))
		var clear := true
		for other: Dictionary in canopy_claims:
			if is_equal_approx(float(other.y), float(item.y)) \
					and rect.grow(-0.01).intersects((other.rect as Rect2).grow(-0.01)):
				clear = false
		if clear:
			canopy_claims.append({"rect": rect, "y": float(item.y)})
			retained.append(item)
	mass.decor = retained


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
