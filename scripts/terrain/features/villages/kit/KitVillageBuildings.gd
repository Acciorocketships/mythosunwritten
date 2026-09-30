class_name KitVillageBuildings
extends RefCounted

## Adapter from the sealed warren plan to kit-built buildings.
##
## The planner's buildings (`WarrenSpatialPlan.buildings`: rooms stacked in
## 3 m / two-band storeys on the 1.5 m authored lattice) become pack-agnostic
## `BuildingMass`es on a one-module-per-fine-cell grid, are articulated by
## `BuildingDesigner`, realized by `BuildingKitAssembler`, and mapped back into
## the authored lattice frame. Legacy recipe placements owned by those
## buildings are withdrawn; public surfaces, guards, stairs and turf are not
## touched. Occupancy, collision boxes and terrain grade remain plan facts.

## Native kit metres -> authored lattice metres: one module per 1.5 m fine
## cell horizontally, one kit band per 1.5 m band vertically. Fine cells are
## centred on `cell * 1.5`; bands start at `band * 1.5`.
static func native_to_lattice(kit: BuildingKit) -> Transform3D:
	var h := FabricRecipe.CELL_SIZE / kit.module_width
	var v := WarrenVolumePlan.VERTICAL_BAND_SIZE_M / kit.band_height()
	return Transform3D(Basis.from_scale(Vector3(h, v, h)),
		Vector3(-FabricRecipe.CELL_SIZE * 0.5, 0.0, -FabricRecipe.CELL_SIZE * 0.5))


## Lattice metres a kit wall's outer face stands proud of its cell edge.
static func wall_face_lattice(kit: BuildingKit) -> float:
	return kit.wall_face * FabricRecipe.CELL_SIZE / kit.module_width


## Feature kinds whose legacy recipe units are superseded by kit buildings.
const REPLACED_FEATURE_KINDS: Array[StringName] = [
	&"facade_bay", &"prefab_landmark", &"balcony", &"room_overhang_support",
	&"arcade_overhang_support",
]
## Terrace-payload families that belonged to the legacy buildings.
const REPLACED_TERRACE_PREFIXES: Array[String] = ["house-plinth", "maze-skywalk",
	"maze-stone", "masonry-joint", "masonry-room-return", "masonry-room-seam",
	"maze-outcrop"]
## Legacy fabric placement families the kit supersedes.
const REPLACED_PLACEMENT_PREFIXES: Array[String] = ["facade-corner",
	"facade-joint", "facade-run-joint", "facade-door-return"]


## One kit house: every planner building volume of one lineage (a house's
## storeys arrive as `...partNN` volumes) or one reserved landmark.
static func house_id_for(building_id: StringName) -> StringName:
	var id := String(building_id)
	var index := id.rfind(".part")
	return StringName(id.substr(0, index)) if index > 0 else building_id


## Returns {payload: EnvironmentInstancePayload (town-local lattice frame),
## replaced_units: Dictionary unit stable_id -> true, masses: Array, plus the
## native-frame roof union inputs placements / roofs / walls}.
static func build(spatial: WarrenSpatialPlan, fabric: SettlementFabricPlan,
		kit: BuildingKit) -> Dictionary:
	var grid := spatial.grid
	var houses := _houses(spatial)
	var owner_at: Dictionary = {}
	for house_id: StringName in houses:
		for cell: Vector3i in (houses[house_id] as Dictionary).cells:
			owner_at[cell] = house_id
	var replaced := _replaced_units(spatial, fabric)
	var spans := SettlementFabricAssembler.maze_skywalk_spans(fabric)
	var passages := _passage_house_claims(spans, houses, owner_at)
	var feature_masses := _feature_masses(spatial, fabric, houses, grid, spans)
	# Adjacent lots on one ground become one building (after the balconies
	# have opened their doors in their owner lots).
	houses = merge_houses(houses, spatial.world_seed)
	owner_at.clear()
	for house_id: StringName in houses:
		for cell: Vector3i in (houses[house_id] as Dictionary).cells:
			owner_at[cell] = house_id
	var payload := EnvironmentInstancePayload.new()
	var map := native_to_lattice(kit)
	var masses: Array[BuildingMass] = []
	var ids := sorted_ids(houses.keys())
	var flights := flight_columns(spatial, fabric)
	var canopy_claims: Array = []
	var podium := _podium_cells(feature_masses)
	for house_id: StringName in ids:
		var house: Dictionary = houses[house_id]
		var mass := _mass_for(house_id, house, grid, owner_at, spatial.world_seed, kit,
			flights, canopy_claims, podium, passages)
		if mass != null:
			masses.append(mass)
	var house_masses := masses.duplicate()
	masses.append_array(feature_masses)
	var joins := preload("res://scripts/terrain/features/villages/kit/KitRoofJunctions.gd").join(masses,
		func(cell: Vector2i, band: int) -> bool:
			var p := Vector3i(cell.x, band, cell.y)
			return not grid.contains(p) or grid.use_at(p) in [WarrenSpatialGrid.Use.OUTSIDE, WarrenSpatialGrid.Use.ALLOCATABLE])
	var roofs: Array[Dictionary] = []
	var walls: Array[Dictionary] = []
	var union_script := preload("res://scripts/terrain/features/villages/kit/KitRoofMeshUnion.gd")
	for mass: BuildingMass in masses:
		for roof: Dictionary in mass.roofs:
			roof.union_index = roofs.size()
			roofs.append(roof)
		for storey: Dictionary in mass.storeys:
			for rect: Rect2i in BuildingDesigner.decompose(storey.cells):
				walls.append(union_script.box_volume(AABB(Vector3(rect.position.x * kit.module_width,
					storey.floor_band * kit.band_height(), rect.position.y * kit.module_width),
					Vector3(rect.size.x * kit.module_width, int(storey.get("bands", 2)) * kit.band_height(), rect.size.y * kit.module_width))))
	# Walkers' clearance above a public floor, in native metres: an eave is
	# trimmed only where it would actually reach a walker's head. Trimming it
	# to the planner's two-band headroom cut the flared eave off at the wall
	# line and left a see-through slot under the roof (September 27 photo 11).
	var clearance := TraversalEnvelope.MIN_HEADROOM / VillageWorldScale.VERTICAL_SCALE \
		* kit.band_height() / WarrenVolumePlan.VERTICAL_BAND_SIZE_M
	for floor_cell: Vector3i in spatial.route_floor_cells:
		# Public headroom is open air: it trims eaves hanging into a lane but
		# never a gable wall standing on its own wall line (a hole).
		var headroom := union_script.box_volume(AABB(Vector3(floor_cell.x * kit.module_width,
			floor_cell.y * kit.band_height(), floor_cell.z * kit.module_width),
			Vector3(kit.module_width, clearance, kit.module_width)))
		headroom["open"] = true
		walls.append(headroom)
	var placements: Array[Dictionary] = []
	for mass: BuildingMass in masses:
		var own := StringName(String(mass.stable_id).trim_prefix("kit."))
		var assembler := BuildingKitAssembler.new(kit)
		assembler.prop_scale = VillageWorldScale.kit_human_prop_scale()
		assembler.external_blocked = func(cell: Vector2i, band: int) -> bool:
			return _solid_other(grid, owner_at, own, Vector3i(cell.x, band, cell.y))
		placements.append_array(assembler.assemble(mass))
	var roof_audit := union_script.append(placements, roofs, walls, kit, map, payload)
	roof_audit["joins"] = joins
	return {"payload": payload, "replaced_units": replaced, "masses": masses, "houses": house_masses,
		"roof_audit": roof_audit, "placements": placements, "roofs": roofs, "walls": walls}


## Balconies, overhang supports and skywalks as kit masses. Balconies also
## open a door in their owner house, so this runs before houses are designed.
static func _feature_masses(spatial: WarrenSpatialPlan, fabric: SettlementFabricPlan,
		houses: Dictionary, grid: WarrenSpatialGrid,
		spans: Array[Dictionary]) -> Array[BuildingMass]:
	var out: Array[BuildingMass] = []
	for feature: WarrenFeatureReservation in spatial.features:
		match feature.kind:
			&"balcony":
				var balcony := _balcony_mass(feature, houses, grid, spatial.world_seed)
				if balcony != null:
					out.append(balcony)
			&"room_overhang_support", &"arcade_overhang_support":
				out.append(_support_mass(feature, grid, spatial.world_seed))
	for span: Dictionary in spans:
		out.append(_skywalk_mass(span, spatial.world_seed))
	# The legacy fabric can classify a passage crown as a flat roof and
	# subtract it from retained-terrain skin. Every crown -- a bored tunnel's
	# ceiling or a rock shoulder left over a street -- gets its own kit closure
	# here. A crown survives the plan only while it carries a room or walk
	# (`WarrenVolumetricSolver.unborne_crown_cells`), so it is drawn as its
	# whole stone run up to that construction: its lowest band alone left the
	# rest invisible and the slab floating under the house it bears.
	if spatial.source_volume != null:
		var source := spatial.source_volume.mass_context.get(&"maze_source_plan") as WarrenMazeSourcePlan
		if source != null:
			var ceilings := {}
			for crown: Vector3i in grid.cells_with_use(WarrenSpatialGrid.Use.STRUCTURAL_VOLUME):
				if fabric.retained_terrace_cells.has(crown) \
						or grid.owner_name_at(crown) != WarrenVolumetricSolver.MAZE_STONE_FEATURE_ID \
						or grid.use_at(crown + Vector3i.DOWN) != WarrenSpatialGrid.Use.PUBLIC_AIR:
					continue
				var fine := crown
				while grid.use_at(fine) == WarrenSpatialGrid.Use.STRUCTURAL_VOLUME \
						and grid.owner_name_at(fine) == WarrenVolumetricSolver.MAZE_STONE_FEATURE_ID \
						and not fabric.retained_terrace_cells.has(fine):
					ceilings[fine] = true
					fine += Vector3i.UP
			var tunnel := _retained_mass(ceilings, spatial.world_seed)
			if tunnel != null:
				tunnel.stable_id = &"kit.tunnel-ceilings"
				# No deck of its own: the room or public floor it carries
				# already closes its top.
				for storey: Dictionary in tunnel.storeys:
					storey.material = BuildingMass.MATERIAL_TIMBER
					storey.default_opening = BuildingMass.OPENING_PLAIN
					storey.soffit = true
				out.append(tunnel)
	# A raised district's plinth is its own coursed-stone retaining wall; the
	# rest of the retained massif keeps the ordinary treatment.
	var split := _split_platform_cells(spatial, fabric.retained_terrace_cells)
	var retained := _retained_mass(split.rest, spatial.world_seed)
	var platform := _platform_wall_mass(split.platform, spatial.world_seed,
		_platform_gate_edges(spatial))
	var envelope := spatial.source_volume.envelope if spatial.source_volume != null else null
	for wall: BuildingMass in [retained, platform]:
		if wall == null:
			continue
		for storey: Dictionary in wall.storeys:
			var floor := int(storey.floor_band)
			# A one-band foot course whose every cell stands at or below its
			# column's ground datum sinks a full panel into the ground.
			var sunk := int(storey.get("bands", 2)) == 1
			for cell: Vector2i in storey.cells:
				if grid.use_at(Vector3i(cell.x, floor - 1, cell.y)) == WarrenSpatialGrid.Use.PUBLIC_AIR:
					storey["soffit"] = true
				var ground := envelope.ground_at(Vector2i(floori(cell.x / 2.0),
					floori(cell.y / 2.0))) if envelope != null else 0
				sunk = sunk and floor <= ground
			storey["sunk"] = sunk
		out.append(wall)
	return out


## Retained cells split into the raised district's plinth (fine cells of a
## platform column below its bearing surface, `WarrenMassif.bearing_at`) and
## the rest. A town without a platform has an empty plinth.
static func _split_platform_cells(spatial: WarrenSpatialPlan,
		retained: Dictionary) -> Dictionary:
	var massif: WarrenMassif = null
	if spatial.source_volume != null:
		massif = spatial.source_volume.mass_context.get(&"massif") as WarrenMassif
	if massif == null or massif.platform_columns().is_empty():
		return {"platform": {}, "rest": retained}
	var platform: Dictionary = {}
	var rest: Dictionary = {}
	for cell: Vector3i in retained:
		var column := Vector2i(floori(cell.x / 2.0), floori(cell.z / 2.0))
		if massif.is_platform(column) and cell.y < massif.bearing_at(column):
			platform[cell] = retained[cell]
		else:
			rest[cell] = retained[cell]
	return {"platform": platform, "rest": rest}


## The plinth of a raised district (WarrenTownPlatform): coursed stone from
## the ground to the platform's bearing surface, whatever its height -- the
## one place a town wears a tall stone wall. Windowless and flush, like any
## retaining course; the houses standing on it stay timber and plaster.
static func _platform_wall_mass(cells: Dictionary, world_seed: int,
		gates: Dictionary = {}) -> BuildingMass:
	var mass := _retained_mass(cells, world_seed)
	if mass == null:
		return null
	mass.stable_id = &"kit.platform-wall"
	for storey: Dictionary in mass.storeys:
		storey.material = BuildingMass.MATERIAL_STONE
		# A fortification (BuildingKitAssembler._assemble_fortified), not a
		# retaining course: plain stone, parapet, turrets and gate.
		storey["fortified"] = true
		storey["gates"] = gates
	return mass


## Module-cell rim edges where a gate flight (WarrenPlatformStreets
## .carve_gate) enters the raised district: edge key -> true on the gate's
## left cell (seen from outside), false on the other.
static func _platform_gate_edges(spatial: WarrenSpatialPlan) -> Dictionary:
	var out: Dictionary = {}
	if spatial.source_volume == null:
		return out
	var source := spatial.source_volume.mass_context.get(&"maze_source_plan") \
		as WarrenMazeSourcePlan
	if source == null or source.excavation == null:
		return out
	for lane: Dictionary in source.excavation.lanes:
		if StringName(lane.get("feature_kind", &"")) != &"citadel_gate":
			continue
		for transition: Dictionary in lane.transitions:
			var gate := transition.to as Vector3i
			var from := transition.from as Vector3i
			if not source.massif.is_platform(Vector2i(gate.x, gate.z)) \
					or source.massif.is_platform(Vector2i(from.x, from.z)):
				continue
			var step := Vector2i(from.x - gate.x, from.z - gate.z)
			var dir := BuildingMass.DIRS.find(step)
			if dir < 0:
				continue
			var right := BuildingKitAssembler.right_of(dir)
			var cells: Array[Vector2i] = []
			for dz in 2:
				for dx in 2:
					var fine := Vector2i(gate.x * 2 + dx, gate.z * 2 + dz)
					var ahead := fine + step
					if Vector2i(floori(ahead.x / 2.0), floori(ahead.y / 2.0)) \
							!= Vector2i(gate.x, gate.z):
						cells.append(fine)
			for fine: Vector2i in cells:
				out[BuildingMass.edge_key(fine, dir)] = not cells.has(fine - right)
	return out


## The retained massif (terraces that are not houses) wears the kit too: a
## stone ground course and timber-framed storeys, walls rising exactly to the
## terrace top (a lone top band is a coursed stone band), and no roof: its
## crown is the garden or deck the public realm already lays there.
static func _retained_mass(retained: Dictionary, world_seed: int) -> BuildingMass:
	if retained.is_empty():
		return null
	var columns: Dictionary = {}
	var base := 1 << 20
	for cell: Vector3i in retained:
		var column := Vector2i(cell.x, cell.z)
		if not columns.has(column):
			columns[column] = {}
		(columns[column] as Dictionary)[cell.y] = true
		base = mini(base, cell.y)
	var mass := _feature_base("retained", world_seed)
	mass.ground_band = base
	var layers: Dictionary = {}
	for column: Vector2i in columns:
		var bands: Dictionary = columns[column]
		var top := -(1 << 20)
		for band: int in bands:
			top = maxi(top, band)
		# Full storeys hang from the terrace top; an odd remaining band is a
		# stone base course at the foot, never a parapet above timber.
		var band := top
		while bands.has(band):
			var key: Vector2i
			if bands.has(band - 1):
				key = Vector2i(band - 1, 2)
				band -= 2
			else:
				key = Vector2i(band, 1)
				band -= 1
			if not layers.has(key):
				layers[key] = {}
			(layers[key] as Dictionary)[column] = true
	var keys := layers.keys()
	keys.sort()
	for key: Vector2i in keys:
		# Stone only as a low retaining course; taller retained faces wear
		# timber-framed storeys like the houses around them.
		var material := BuildingMass.MATERIAL_STONE if key.x - base < 2 \
			and _layer_is_low(columns, layers[key], key.x) \
			else BuildingMass.MATERIAL_TIMBER
		var storey := mass.add_storey(key.x, layers[key], material)
		storey.bands = key.y
		# Retained ground is solid earth behind its face: a retaining wall or
		# podium has no rooms, so it never shows windows or doors, and its
		# masonry stays flush under the lawn it retains.
		storey.default_opening = BuildingMass.OPENING_PLAIN
		storey.retaining = true
	return mass


static func _feature_base(feature_id: String, world_seed: int) -> BuildingMass:
	var mass := BuildingMass.new()
	mass.stable_id = StringName("kit.%s" % feature_id)
	mass.seed = hash([world_seed, feature_id])
	return mass


static func _balcony_mass(feature: WarrenFeatureReservation, houses: Dictionary,
		grid: WarrenSpatialGrid, world_seed: int) -> BuildingMass:
	if feature.reserved_cells.is_empty():
		return null
	var band := 1 << 20
	for cell: Vector3i in feature.reserved_cells:
		band = mini(band, cell.y)
	var deck: Dictionary = {}
	for cell: Vector3i in feature.reserved_cells:
		if cell.y == band:
			deck[Vector2i(cell.x, cell.z)] = true
	var mass := _feature_base(String(feature.stable_id), world_seed)
	mass.ground_band = band
	mass.decks.append({"cells": deck, "band": band, "rails": true, "open_edges": {}})
	# The owner room gets a door onto its balcony.
	for endpoint: Dictionary in feature.endpoints:
		var owner := house_id_for(StringName(endpoint.get("owner_id", &"")))
		var cell := endpoint.get("cell", Vector3i.ZERO) as Vector3i
		for dir in 4:
			var next := Vector2i(cell.x, cell.z) + BuildingMass.DIRS[dir]
			if deck.has(next) and houses.has(owner):
				(houses[owner].doors as Array).append({"cell": cell,
					"direction": Vector3i(BuildingMass.DIRS[dir].x, 0,
						BuildingMass.DIRS[dir].y), "balcony": true})
				break
	# Short wall-tied brackets carry the whole platform. A high balcony must
	# not grow an isolated pole through several floors to reach the terrain.
	# Each bracket bears on a wall-module joint (a cell vertex on the wall
	# line) and runs square to the wall: a module's window or door is centred
	# between two joints, so no bracket ever crosses an opening.
	var braced: Dictionary = {}
	for cell: Vector2i in deck:
		var support := _balcony_bearing(grid, deck, cell, band)
		if support.is_empty(): continue
		var normal := support.normal as Vector2
		for joint: Vector2 in support.joints:
			if braced.has(joint): continue
			braced[joint] = true
			var outer: Vector2 = joint + normal * float(support.reach)
			mass.decor.append({"kind": &"raker", "dir": 0, "centre": joint,
				"from": Vector3(joint.x, band - 0.85, joint.y),
				"to": Vector3(outer.x, band - 0.08, outer.y)})
			mass.decor.append({"kind": &"raker", "dir": 0, "centre": joint,
				"from": Vector3(joint.x, band - 0.08, joint.y),
				"to": Vector3(outer.x, band - 0.08, outer.y)})
	mass.decor.append({"kind": &"planter", "dir": 1,
		"centre": Vector2(deck.keys()[0]) + Vector2(0.5, 0.5), "y_band": band})
	return mass


static func _balcony_bearing(grid: WarrenSpatialGrid, deck: Dictionary,
		cell: Vector2i, band: int) -> Dictionary:
	var centre := Vector2(cell) + Vector2(0.5, 0.5)
	var best := {}
	var nearest := INF
	for dz in range(-3, 4):
		for dx in range(-3, 4):
			var probe := cell + Vector2i(dx, dz)
			if deck.has(probe): continue
			if grid.use_at(Vector3i(probe.x, band, probe.y)) != WarrenSpatialGrid.Use.PRIVATE_VOLUME: continue
			var wall := centre.clamp(Vector2(probe), Vector2(probe + Vector2i.ONE))
			var distance := centre.distance_to(wall)
			if distance >= nearest or distance > 3.0: continue
			var clear := true
			for k in range(1, ceili(distance * 4.0) + 1):
				var p := wall.lerp(centre, float(k) / ceili(distance * 4.0))
				var between := Vector2i(floori(p.x), floori(p.y))
				if not deck.has(between): clear = false
				if grid.use_at(Vector3i(between.x, band - 1, between.y)) == WarrenSpatialGrid.Use.PUBLIC_AIR: clear = false
			if clear:
				nearest = distance
				best = {"dir": 0, "wall": wall}
	if best.is_empty():
		return best
	# The bearing point on the wall face, moved along the face to the module
	# joints either side of it (a wall corner already is a joint).
	var wall: Vector2 = best.wall
	var normal := (centre - wall).normalized()
	var joints: Array[Vector2] = []
	if absf(normal.x) > 0.99:
		joints = [Vector2(wall.x, floorf(wall.y)), Vector2(wall.x, ceilf(wall.y))]
	elif absf(normal.y) > 0.99:
		joints = [Vector2(floorf(wall.x), wall.y), Vector2(ceilf(wall.x), wall.y)]
	else:
		joints = [wall]
	best.normal = normal
	best.joints = joints
	best.reach = nearest + 0.35
	return best


static func _support_mass(feature: WarrenFeatureReservation, grid: WarrenSpatialGrid,
		world_seed: int) -> BuildingMass:
	var mass := _feature_base(String(feature.stable_id), world_seed)
	var low := 1 << 20
	var high := -(1 << 20)
	var cells: Dictionary = {}
	for cell: Vector3i in feature.reserved_cells:
		low = mini(low, cell.y)
		high = maxi(high, cell.y + 1)
		cells[Vector2i(cell.x, cell.z)] = true
	var rect := BuildingDesigner._bounds(cells)
	# Each post stands on one of the overhang's outer corner vertices: a
	# wall-module joint of every wall on either line through it, like a
	# balcony raker's. A module's window or door is centred between two
	# joints, so a post on a joint never stands in front of an opening (the
	# former corner-cell point, pushed diagonally outward, could).
	for vertex: Vector2i in [rect.position, Vector2i(rect.end.x, rect.position.y),
			Vector2i(rect.position.x, rect.end.y), rect.end]:
		var corner := Vector2i(mini(vertex.x, rect.end.x - 1),
			mini(vertex.y, rect.end.y - 1))
		# A post stands only on ground or structure, never in a public way.
		var landing := _post_landing(grid, Vector3i(corner.x, low - 1, corner.y))
		if landing == 1 << 20:
			continue
		mass.decor.append({"kind": &"post", "dir": 1, "centre": Vector2(vertex),
			"from_band": landing, "to_band": high})
	return mass


## An enclosed span is a timber bridge-house: windowed walls, open ends, a
## roof along the span and a boarded underside. Open spans are railed decks.
static func _skywalk_mass(span: Dictionary, world_seed: int) -> BuildingMass:
	var cell := span.cell as Vector3i
	var step := span.step as Vector3i
	var gap := int(span.gap)
	var width := int(span.get("width", 1))
	var cross := span.get("cross", Vector3i(step.z, 0, step.x)) as Vector3i
	var cells: Dictionary = {}
	for k in range(1, gap + 1):
		var c := cell + step * k
		cells[Vector2i(c.x, c.z)] = true
		if width == 2:
			cells[Vector2i(c.x + cross.x, c.z + cross.z)] = true
	var mass := _feature_base("skywalk.%d.%d.%d.%d.%d" % [cell.x, cell.y, cell.z,
		step.x, step.z], world_seed)
	mass.ground_band = cell.y - 100
	var dir_along := BuildingMass.DIRS.find(Vector2i(step.x, step.z))
	var open_edges: Dictionary = {}
	for c: Vector2i in cells:
		for d in [dir_along, (dir_along + 2) % 4]:
			if not cells.has(c + BuildingMass.DIRS[d]):
				open_edges[BuildingMass.edge_key(c, d)] = true
	if gap > 1 and bool(span.get("enclosed", false)):
		var storey := mass.add_storey(cell.y, cells, BuildingMass.MATERIAL_TIMBER)
		for key: Vector3i in open_edges:
			storey.openings[key] = BuildingMass.OPENING_NONE
		var rect := BuildingDesigner._bounds(cells)
		# The ridge runs along the span when the bridge is two modules wide.
		# A one-module-wide bridge-house instead turns its ridge across the
		# span: a roof one module deep is a lone ridge-top strip (the owner's
		# "tiny roof"), while the transverse roof is `gap` modules deep, its
		# slopes running into the two endpoint houses (trimmed inside their
		# walls) and its gables facing the lane it crosses, like a gatehouse.
		var along := 0 if step.x != 0 else 1
		var axis := along if width >= 2 else 1 - along
		var colour := &"blue" if absi(hash([world_seed, cell])) % 2 == 0 else &"red"
		# Closed gables: an end meeting a taller endpoint house is trimmed
		# inside its walls; one standing clear of a lower endpoint stays a
		# finished gable (an unconditionally open end was see-through).
		# KitRoofJunctions still opens an end into a same-eave host roof.
		mass.add_roof(rect, axis, cell.y + 2, colour)
		# Timber portal posts frame each open end.
		for key: Vector3i in open_edges:
			var c := Vector2(key.x, key.y) + Vector2(0.5, 0.5) \
				+ Vector2(BuildingMass.DIRS[key.z]) * 0.45
			var side := Vector2(BuildingMass.DIRS[(key.z + 1) % 4])
			for sign: float in [-1.0, 1.0]:
				var at: Vector2 = c + side * 0.45 * sign
				var near := Vector2i(floori(at.x + side.x * 0.1 * sign), floori(at.y + side.y * 0.1 * sign))
				var far := Vector2i(floori(at.x + side.x * 0.6 * sign), floori(at.y + side.y * 0.6 * sign))
				if cells.has(near) and not cells.has(far):
					mass.decor.append({"kind": &"frame_post", "dir": key.z, "centre": at,
						"from_band": cell.y, "to_band": cell.y + 2})
	else:
		mass.decks.append({"cells": cells, "band": cell.y, "rails": true,
			"open_edges": open_edges})
	return mass


## A bridge-house spans between two building storeys (see
## `SettlementFabricAssembler._maze_passage_house_candidates`). Each endpoint
## house opens a door onto the passage at the bridge floor, and the passage's
## body and roof air is kept clear of the houses' own articulation (jetties,
## bays, canopies) so nothing grows into it. Returns the reserved cells.
static func _passage_house_claims(spans: Array[Dictionary],
		houses: Dictionary, owner_at: Dictionary) -> Dictionary:
	var reserved: Dictionary = {}
	for span: Dictionary in spans:
		if not bool(span.get("enclosed", false)):
			continue
		var step := span.step as Vector3i
		var lanes := SettlementFabricAssembler._skywalk_candidate_lanes(span)
		var near := lanes[0]
		var far := near + step * (int(span.gap) + 1)
		for end: Array in [[near, step], [far, -step]]:
			var house_id: Variant = owner_at.get(end[0])
			if house_id != null and houses.has(house_id):
				(houses[house_id].doors as Array).append({"cell": end[0],
					"direction": end[1], "passage": true})
		for lane: Vector3i in lanes:
			for index in range(1, int(span.gap) + 1):
				for rise in 4:
					reserved[lane + step * index + Vector3i.UP * rise] = true
	return reserved


static func _layer_is_low(columns: Dictionary, cells: Dictionary, floor: int) -> bool:
	for column: Vector2i in cells:
		if (columns[column] as Dictionary).has(floor + 2):
			return false
	return true


## Band a post may stand on below `cell`, or 1 << 20 when the column meets a
## public walk (a post there would block the way) before ground or structure.
static func _post_landing(grid: WarrenSpatialGrid, cell: Vector3i) -> int:
	var probe := cell
	while probe.y > -64:
		if not grid.contains(probe):
			return probe.y + 1
		var use := grid.use_at(probe)
		if use == WarrenSpatialGrid.Use.STRUCTURAL_VOLUME:
			return probe.y + 1
		if use == WarrenSpatialGrid.Use.PUBLIC_AIR and _walked(grid, probe):
			return 1 << 20
		probe.y -= 1
	return 1 << 20


## Lowest free band beneath `cell` before a floor, a solid or the envelope.
static func _ground_band_below(grid: WarrenSpatialGrid, cell: Vector3i) -> int:
	var probe := cell
	while probe.y > -64:
		if not grid.contains(probe):
			return probe.y + 1
		var use := grid.use_at(probe)
		if use == WarrenSpatialGrid.Use.PRIVATE_VOLUME \
				or use == WarrenSpatialGrid.Use.STRUCTURAL_VOLUME:
			return probe.y + 1
		if use == WarrenSpatialGrid.Use.PUBLIC_AIR and _walked(grid, probe):
			return probe.y
		probe.y -= 1
	return probe.y


static func _houses(spatial: WarrenSpatialPlan) -> Dictionary:
	var houses: Dictionary = {}
	for building: WarrenBuildingVolume in spatial.buildings:
		var house_id := house_id_for(building.stable_id)
		# A maze back room (or passage cover) is its parcel's own room: the
		# planner's one building, not a separate house beside it (which stood
		# as a twin gable against its host).
		for room: WarrenRoomStamp in building.room_records:
			var host := StringName(room.audit.get("back_room_parcel_id", &""))
			if not host.is_empty():
				house_id = StringName("spatial.%s" % host)
		if not houses.has(house_id):
			houses[house_id] = {"cells": [], "storeys": {}, "doors": [],
				"terrain_band": 1 << 20, "landmark": false, "grounded": {}}
		var house: Dictionary = houses[house_id]
		(house.cells as Array).append_array(building.private_cells)
		for room: WarrenRoomStamp in building.room_records:
			if room.private_cells.is_empty():
				continue
			var floor := 1 << 20
			for cell: Vector3i in room.private_cells:
				floor = mini(floor, cell.y)
			_add_storey_cells(house, floor, room.private_cells)
			if room.terrain_bearing:
				house.terrain_band = mini(int(house.terrain_band), floor)
				# Cells resting on the ground at this floor (a room on higher
				# ground than the house's lowest one): footing, not soffit.
				if not (house.grounded as Dictionary).has(floor):
					house.grounded[floor] = {}
				for cell: Vector3i in room.private_cells:
					if cell.y == floor:
						(house.grounded[floor] as Dictionary)[Vector2i(cell.x, cell.z)] = true
		for threshold: Dictionary in building.thresholds:
			(house.doors as Array).append({"cell": threshold.private_cell,
				"direction": threshold.direction})
	var source: WarrenMazeSourcePlan = null
	if spatial.source_volume != null:
		source = spatial.source_volume.mass_context.get(&"maze_source_plan") as WarrenMazeSourcePlan
	for feature: WarrenFeatureReservation in spatial.features:
		if feature.kind != &"prefab_landmark" or feature.reserved_cells.is_empty():
			continue
		houses[feature.stable_id] = _landmark_house(feature, source)
	return houses


## `ids` (StringNames) in lexicographic order. `Array.sort()` orders
## StringNames by their interned pointers, not their text, so the order (and
## every order-dependent choice after it: shared canopy claims, roof joins,
## merges) changed with whatever the process had interned before; a town
## was not a pure function of its seed (September 29 review).
static func sorted_ids(ids: Array) -> Array:
	var out := ids.duplicate()
	out.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
	return out


## Compound buildings (September 29 town review, photo 11). The planner
## parcels a town into one-macro-cell lots; built one by one they read as a
## row of identical little gabled boxes. Neighbouring lots standing on the
## same ground merge, by a seeded choice per shared wall, into one building
## of at most MERGE_MAX_CELLS modules and MERGE_MAX_SPAN across, so its crown
## is designed as a whole: a side-gabled range, an L or T with a main ridge
## and wings, a block stepping up the slope (grounds one storey apart) or
## a taller part beside a lower one that keeps its own roof. Occupancy,
## doors and bearing stay the planner's; only the kit's building identity
## (walls, roofs, colour) changes. A lot bearing a building that does not
## stand on the ground (a bridge-house, an upper room on its roof or beside
## it) keeps its own identity: that building's seams are coordinated with it.
const MERGE_CHANCE := 0.5
const RANGE_MERGE_CHANCE := 1.0
const MERGE_MAX_CELLS := 24
const MERGE_MAX_SPAN := 8


static func merge_houses(houses: Dictionary, world_seed: int) -> Dictionary:
	var ids := sorted_ids(houses.keys())
	var owner: Dictionary = {}
	for house_id: StringName in ids:
		for cell: Vector3i in (houses[house_id] as Dictionary).cells:
			owner[cell] = house_id
	# Lots that may merge: whole storeys on their own base (terrain, a terrace
	# or another lot), keyed by their lowest storey.
	var ground: Dictionary = {}
	for house_id: StringName in ids:
		var house: Dictionary = houses[house_id]
		if bool(house.landmark) or int(house.terrain_band) >= (1 << 20):
			continue
		var floors: Array = (house.storeys as Dictionary).keys()
		floors.sort()
		if int(floors[0]) != int(house.terrain_band):
			continue
		var phase_ok := true
		for floor: int in floors:
			phase_ok = phase_ok and posmod(floor - int(house.terrain_band), 2) == 0
		if phase_ok:
			ground[house_id] = house.storeys[floors[0]]
	# A lot touching a building that cannot merge (a bridge-house, a
	# landmark, a split-level room) keeps its identity: that building's
	# seams are coordinated with it.
	var bearing: Dictionary = {}
	var stacked: Dictionary = {}
	for cell: Vector3i in owner:
		var house_id: StringName = owner[cell]
		var below: StringName = owner.get(cell + Vector3i.DOWN, &"")
		if below != &"" and below != house_id:
			stacked[[below, house_id]] = true
			if not ground.has(house_id): bearing[below] = true
			if not ground.has(below): bearing[house_id] = true
		if ground.has(house_id):
			continue
		for step: Vector3i in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1),
				Vector3i(0, 0, -1)]:
			var other: StringName = owner.get(cell + step, &"")
			if other != &"" and other != house_id:
				bearing[other] = true
	var pairs: Array = []
	# A lineage standing on another lot is one building with it (a tower
	# of one-storey lots): always merged, before any neighbour.
	for pair: Array in stacked:
		var lower: StringName = pair[0]
		var upper: StringName = pair[1]
		if not ground.has(lower) or not ground.has(upper) \
				or bearing.has(lower) or bearing.has(upper):
			continue
		if posmod(int(houses[upper].terrain_band) - int(houses[lower].terrain_band), 2) != 0:
			continue
		pairs.append([-1000.0, lower, upper])
	for a: StringName in ids:
		if not ground.has(a) or bearing.has(a): continue
		for b: StringName in ids:
			if String(b) <= String(a) or not ground.has(b) or bearing.has(b): continue
			# Lots whose grounds differ by at most one storey (a house stepping
			# up the slope), on the same storey phase.
			var rise := int(houses[b].terrain_band) - int(houses[a].terrain_band)
			if absi(rise) > 2 or rise % 2 != 0: continue
			# They share at least one whole wall module of one storey (two
			# modules, two bands), never a corner touch.
			var shared := 0
			for cell: Vector3i in houses[a].cells:
				for step: Vector3i in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
						Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
					if owner.get(cell + step, &"") == b: shared += 1
			if shared < 4: continue
			# Two lots whose union is one rectangle would otherwise stand as
			# side-by-side copies (twin gables, the photo-11 sawtooth): they
			# usually become one range and merge first. Other contacts make
			# L/T compounds less often.
			var union: Dictionary = (ground[a] as Dictionary).duplicate()
			union.merge(ground[b])
			var box := BuildingDesigner._bounds(union)
			var range_pair := box.get_area() == union.size() \
				and int(houses[a].terrain_band) == int(houses[b].terrain_band)
			var roll := float(absi(hash([world_seed, a, b, &"merge"])) % 10000) / 10000.0
			if roll < (RANGE_MERGE_CHANCE if range_pair else MERGE_CHANCE):
				# Ranges first, longest shared wall first (twins sharing a long
				# side before a lot extending a row), then the seeded roll.
				pairs.append([(0.0 if range_pair else 1000.0) - float(shared) + roll, a, b])
	pairs.sort_custom(func(p: Array, q: Array) -> bool:
		return p[0] < q[0] or (p[0] == q[0] and String(p[1]) + String(p[2]) < String(q[1]) + String(q[2])))
	var root: Dictionary = {}
	var members: Dictionary = {}
	for house_id: StringName in ids:
		root[house_id] = house_id
		members[house_id] = [house_id]
	for pair: Array in pairs:
		var ra: StringName = root[pair[1]]
		var rb: StringName = root[pair[2]]
		if ra == rb: continue
		var cells: Dictionary = {}
		for member: StringName in (members[ra] as Array) + (members[rb] as Array):
			for cell: Vector3i in houses[member].cells:
				cells[Vector2i(cell.x, cell.z)] = true
		var extent := BuildingDesigner._bounds(cells)
		if cells.size() > MERGE_MAX_CELLS or maxi(extent.size.x, extent.size.y) > MERGE_MAX_SPAN:
			continue
		var keep := ra if String(ra) < String(rb) else rb
		var gone := rb if keep == ra else ra
		(members[keep] as Array).append_array(members[gone])
		for member: StringName in members[gone]:
			root[member] = keep
		members.erase(gone)
	var out: Dictionary = {}
	for keep: StringName in members:
		var group: Array = members[keep]
		if group.size() == 1:
			out[keep] = houses[keep]
			continue
		group = sorted_ids(group)
		var merged := {"cells": [], "storeys": {}, "doors": [], "terrain_band": 1 << 20,
			"landmark": false, "roof_crowns": {}, "grounded": {}, "crown_parts": {},
			"members": group}
		var tops: Dictionary = {}
		for member: StringName in group:
			var house: Dictionary = houses[member]
			(merged.cells as Array).append_array(house.cells)
			(merged.doors as Array).append_array(house.doors)
			merged.terrain_band = mini(int(merged.terrain_band), int(house.terrain_band))
			var base := int(house.terrain_band)
			if not (merged.grounded as Dictionary).has(base):
				merged.grounded[base] = {}
			(merged.grounded[base] as Dictionary).merge(house.storeys[base])
			for floor: int in house.get("grounded", {}):
				if not (merged.grounded as Dictionary).has(floor):
					merged.grounded[floor] = {}
				(merged.grounded[floor] as Dictionary).merge(house.grounded[floor])
			var top := -(1 << 20)
			for floor: int in house.storeys:
				top = maxi(top, floor)
				if not (merged.storeys as Dictionary).has(floor):
					merged.storeys[floor] = {}
				(merged.storeys[floor] as Dictionary).merge(house.storeys[floor])
			tops[member] = top
		# Each member's own top is roofed in the compound unless another
		# member stands directly on it; crowns beneath the compound's own
		# upper storeys (a stepped plan, a recessed loggia) keep the house's
		# terrace rule.
		var solid: Dictionary = {}
		for member: StringName in group:
			for cell: Vector3i in houses[member].cells:
				solid[cell] = true
		for member: StringName in group:
			var top: int = tops[member]
			if not (merged.roof_crowns as Dictionary).has(top):
				merged.roof_crowns[top] = {}
			for cell: Vector2i in houses[member].storeys[top]:
				if not solid.has(Vector3i(cell.x, top + 2, cell.y)):
					(merged.roof_crowns[top] as Dictionary)[cell] = true
		# Every member's footprint per storey: the designer may fall back to
		# the members' own crown packing.
		for member: StringName in group:
			for floor: int in houses[member].storeys:
				if not (merged.crown_parts as Dictionary).has(floor):
					merged.crown_parts[floor] = []
				(merged.crown_parts[floor] as Array).append(houses[member].storeys[floor])
		out[keep] = merged
	return out


static func _add_storey_cells(house: Dictionary, floor: int,
		cells: Array) -> void:
	var storeys: Dictionary = house.storeys
	if not storeys.has(floor):
		storeys[floor] = {}
	for cell: Vector3i in cells:
		if cell.y == floor:
			(storeys[floor] as Dictionary)[Vector2i(cell.x, cell.z)] = true


## A reserved landmark becomes a kit house on its terrain-rooted footprint:
## storeys fill the reserved height below a two-band roof allowance.
static func _landmark_house(feature: WarrenFeatureReservation,
		source: WarrenMazeSourcePlan = null) -> Dictionary:
	# The reservation is the measured shell ring of a complete prefab; the
	# house is its whole rectangle. Landmarks are the village's large houses:
	# two or three storeys whatever the prefab's height was -- except on the
	# town's edge rings, where they keep the same one-storey-per-ring profile
	# as every other house (September 29 edges; a landmark on the rim is a
	# long one-storey hall, not a three-storey wall on the lawn).
	var base := 1 << 20
	var top := -(1 << 20)
	var ring: Dictionary = {}
	for cell: Vector3i in feature.reserved_cells:
		base = mini(base, cell.y)
		top = maxi(top, cell.y + 1)
	for cell: Vector3i in feature.reserved_cells:
		if cell.y == base:
			ring[Vector2i(cell.x, cell.z)] = true
	var rect := BuildingDesigner._bounds(ring)
	var storey_count := clampi((top - base) / 2, 2, 3)
	if source != null:
		var columns: Array = []
		for cell: Vector2i in ring:
			columns.append(Vector2i(floori(cell.x / 2.0), floori(cell.y / 2.0)))
		var cap := WarrenPlotPlanner.edge_storey_cap(source, columns, base)
		if cap >= 0:
			storey_count = clampi(cap, 1, storey_count)
	var house := {"cells": [], "storeys": {}, "doors": [], "terrain_band": base,
		"landmark": true}
	for s in storey_count:
		var floor := base + s * 2
		var layer: Array = []
		for x in range(rect.position.x, rect.end.x):
			for z in range(rect.position.y, rect.end.y):
				layer.append(Vector3i(x, floor, z))
				layer.append(Vector3i(x, floor + 1, z))
		(house.cells as Array).append_array(layer)
		_add_storey_cells(house, floor, layer)
	# The reserved volume above a capped landmark stays its own air: its roof
	# may rise into it (it is not another owner's space to keep clear).
	var own_air: Dictionary = {}
	for cell: Vector3i in feature.reserved_cells:
		if cell.y >= base + storey_count * 2:
			own_air[cell] = true
	house["own_air"] = own_air
	var entrance := feature.audit.get("landmark_entrance_cell", Vector3i.ZERO) as Vector3i
	var landing := feature.audit.get("landmark_public_landing_cell", entrance) as Vector3i
	if entrance != landing:
		(house.doors as Array).append({"cell": entrance,
			"direction": landing - entrance})
	return house


static func _replaced_units(spatial: WarrenSpatialPlan,
		fabric: SettlementFabricPlan) -> Dictionary:
	var room_ids: Dictionary = {}
	for building: WarrenBuildingVolume in spatial.buildings:
		for room: WarrenRoomStamp in building.room_records:
			room_ids[room.stable_id] = true
	var feature_ids: Dictionary = {}
	for feature: WarrenFeatureReservation in spatial.features:
		if feature.kind in REPLACED_FEATURE_KINDS:
			feature_ids[feature.stable_id] = true
	var replaced: Dictionary = {}
	for unit: FabricUnit in fabric.units:
		var id := String(unit.stable_id)
		if id.begins_with("spatial.fabric."):
			var rest := id.trim_prefix("spatial.fabric.")
			if room_ids.has(StringName(rest)) \
					or feature_ids.has(StringName(rest.get_slice(".component", 0))):
				replaced[unit.stable_id] = true
		elif id.begins_with("spatial.roof."):
			var room_id := id.trim_prefix("spatial.roof.")
			for suffix: String in [".tile", ".garden"]:
				var cut := room_id.find(suffix)
				if cut > 0:
					room_id = room_id.substr(0, cut)
			if room_ids.has(StringName(room_id)):
				replaced[unit.stable_id] = true
	return replaced


## Drops placements whose stable id starts with one of `prefixes`.
static func without_prefixes(source: EnvironmentInstancePayload,
		prefixes: Array[String]) -> EnvironmentInstancePayload:
	var out := EnvironmentInstancePayload.new()
	for asset_id: StringName in source.asset_ids():
		var batch: Dictionary = source.batches[asset_id]
		for index in batch.transforms.size():
			var id := String(batch.ids[index]) if not batch.ids.is_empty() else ""
			var drop := false
			for prefix: String in prefixes:
				drop = drop or id.begins_with(prefix)
			if drop:
				continue
			var flags: Array = batch.get("collision_enabled", [])
			var owners: Array = batch.get("visibility_owners", [])
			out.add(asset_id, batch.transforms[index], batch.colors[index],
				StringName(id), flags.is_empty() or bool(flags[index]),
				owners[index] if index < owners.size() else AABB())
	for mesh: Dictionary in source.surface_meshes:
		if not _has_prefix(String(mesh.get("stable_id", "")), prefixes):
			out.add_surface_mesh(mesh)
	for box: Dictionary in source.collision_boxes:
		if not _has_prefix(String(box.get("stable_id", "")), prefixes):
			out.add_collision_box(box.transform, box.size, StringName(box.get("stable_id", &"")))
	return out


static func _has_prefix(id: String, prefixes: Array[String]) -> bool:
	for prefix: String in prefixes:
		if id.begins_with(prefix):
			return true
	return false


## `SettlementFabricAssembler.payload` without the replaced building units.
static func legacy_payload_without(fabric: SettlementFabricPlan,
		replaced_units: Dictionary) -> EnvironmentInstancePayload:
	var out := EnvironmentInstancePayload.new()
	for placement: Dictionary in fabric.expanded_placements():
		var stable_id := String(placement.stable_id)
		var unit_id := StringName(stable_id.get_slice("/", 0))
		if replaced_units.has(unit_id):
			continue
		var family_dropped := false
		for prefix: String in REPLACED_PLACEMENT_PREFIXES:
			family_dropped = family_dropped or stable_id.begins_with(prefix)
		if family_dropped:
			continue
		out.add(StringName(placement.asset_id),
			placement.transform as Transform3D, Color.WHITE,
			StringName(placement.stable_id), true,
			placement.get("visibility_owner", placement.get("bounds", AABB())) as AABB)
	for cap: Dictionary in fabric.wall_cap_surfaces:
		var owner := StringName(String(cap.get("stable_id", "")).get_slice("/", 0))
		if replaced_units.has(owner):
			continue
		out.add_surface_mesh(cap)
	return out


static func _solid_other(grid: WarrenSpatialGrid, owner_at: Dictionary,
		own_id: StringName, cell: Vector3i) -> bool:
	if owner_at.has(cell):
		return owner_at[cell] != own_id
	if not grid.contains(cell):
		return false
	return grid.use_at(cell) == WarrenSpatialGrid.Use.STRUCTURAL_VOLUME


## True where the kit may not put anything outside the mass (public air and
## its walked floors, reserved daylight, other owners, retained structure).
static func _keep_clear(grid: WarrenSpatialGrid, owner_at: Dictionary,
		own_id: StringName, cell: Vector3i) -> bool:
	if owner_at.has(cell):
		return owner_at[cell] != own_id
	if not grid.contains(cell):
		return false
	var use := grid.use_at(cell)
	return use != WarrenSpatialGrid.Use.ALLOCATABLE \
		and use != WarrenSpatialGrid.Use.OUTSIDE


static func _walked(grid: WarrenSpatialGrid, cell: Vector3i) -> bool:
	if not grid.contains(cell) \
			or grid.use_at(cell) != WarrenSpatialGrid.Use.PUBLIC_AIR:
		return false
	var claim := grid.face_claim(cell, Vector3i.DOWN)
	return not claim.is_empty() \
		and int(claim.get("kind", -1)) == WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR


## Plan columns (fine cells) crossed by a public flight: every STAIR claim
## (a sloped transition, its bands) and every raised gate's exterior approach
## flight (any band: it descends to the ground outside the town). Values are
## the claimed bands; gate approaches use an empty list meaning "all bands".
static func flight_columns(spatial: WarrenSpatialPlan,
		fabric: SettlementFabricPlan) -> Dictionary:
	var out: Dictionary = {}
	if fabric == null or fabric.surface_plan == null:
		return out
	for cell: Vector3i in fabric.surface_plan.cells_for_kind(
			PublicRealmSurfacePlan.SurfaceKind.STAIR):
		var column := Vector2i(cell.x, cell.z)
		if not out.has(column):
			out[column] = [cell.y]
		else:
			(out[column] as Array).append(cell.y)
	var size := FabricRecipe.CELL_SIZE
	for spec: Dictionary in VillageWarrenFabricSolver.terrain_contact_specs(spatial, fabric):
		var geometry := VillageWarrenFabricSolver.terrain_contact_local_geometry(spec)
		if not bool(geometry.get("has_stairs", false)):
			continue
		var a := geometry.inner_centre as Vector3
		var b := geometry.outer_centre as Vector3
		var lateral := Vector3(spec.lateral) * float(geometry.half_width)
		var rect := Rect2(Vector2(a.x, a.z), Vector2.ZERO)
		for p: Vector3 in [a - lateral, a + lateral, b - lateral, b + lateral]:
			rect = rect.expand(Vector2(p.x, p.z))
		for x in range(floori(rect.position.x / size + 0.5 + 0.01),
				floori(rect.end.x / size + 0.5 - 0.01) + 1):
			for z in range(floori(rect.position.y / size + 0.5 + 0.01),
					floori(rect.end.y / size + 0.5 - 0.01) + 1):
				out[Vector2i(x, z)] = []
	return out


## True when a flight crosses `cell` within the bands a floor-standing
## feature at `band` would occupy (its floor, its height, one band below).
static func crosses_flight(flights: Dictionary, cell: Vector2i, band: int) -> bool:
	if not flights.has(cell):
		return false
	var bands: Array = flights[cell]
	if bands.is_empty():
		return true
	for claimed: int in bands:
		if claimed >= band - 1 and claimed <= band + 2:
			return true
	return false


## Cells walled by the retained massif's own courses (terraces and tunnel
## ceilings): the podium houses may stand on.
static func _podium_cells(feature_masses: Array[BuildingMass]) -> Dictionary:
	var podium: Dictionary = {}
	for mass: BuildingMass in feature_masses:
		if mass.stable_id not in [&"kit.retained", &"kit.tunnel-ceilings", &"kit.platform-wall"]:
			continue
		for storey: Dictionary in mass.storeys:
			var floor := int(storey.floor_band)
			for cell: Vector2i in storey.cells:
				for band in range(floor, floor + int(storey.get("bands", 2))):
					podium[Vector3i(cell.x, band, cell.y)] = true
	return podium


static func _mass_for(house_id: StringName, house: Dictionary,
		grid: WarrenSpatialGrid, owner_at: Dictionary, world_seed: int,
		kit: BuildingKit, flights: Dictionary = {}, canopy_claims: Array = [],
		podium: Dictionary = {}, passages: Dictionary = {}) -> BuildingMass:
	var storeys_by_band: Dictionary = house.storeys
	if storeys_by_band.is_empty():
		return null
	var terrain_band := int(house.terrain_band)
	var mass := BuildingMass.new()
	mass.stable_id = StringName("kit.%s" % house_id)
	mass.seed = hash([world_seed, house_id])
	var floors := storeys_by_band.keys()
	floors.sort()
	mass.ground_band = terrain_band if terrain_band < (1 << 20) else int(floors[0])
	var terrain_storey := -1
	for floor: int in floors:
		if floor == terrain_band:
			terrain_storey = mass.storeys.size()
		var storey := mass.add_storey(floor, storeys_by_band[floor], BuildingMass.MATERIAL_TIMBER)
		if house.has("roof_crowns"):
			storey["roofed"] = (house.roof_crowns as Dictionary).get(floor, {})
			storey["crown_parts"] = (house.crown_parts as Dictionary).get(floor, [])
		# A part standing on higher ground than the house's lowest one (a
		# compound member, a back room up the slope): its cells on the
		# terrain or a retained terrace rest on the ground (a footing
		# course, no soffit), not over air.
		if floor != terrain_band:
			var grounded := {}
			for cell: Vector2i in (house.get("grounded", {}) as Dictionary).get(floor, {}):
				var under := Vector3i(cell.x, floor - 1, cell.y)
				if not grid.contains(under) \
						or grid.use_at(under) == WarrenSpatialGrid.Use.STRUCTURAL_VOLUME:
					grounded[cell] = true
			if not grounded.is_empty():
				storey["grounded"] = grounded
		# A storey at or below the house's datum still closes its underside
		# where it hangs over public air (a bridge-house over a lane has no
		# terrain-bearing room, so its lowest floor IS the datum). Without it
		# the lane looked up into the empty room: inner walls, gable timbers
		# and sky between them.
		if floor <= mass.ground_band:
			var overhang: Dictionary = {}
			for cell: Vector2i in storeys_by_band[floor]:
				var under := Vector3i(cell.x, floor - 1, cell.y)
				if grid.contains(under) and grid.use_at(under) in [
						WarrenSpatialGrid.Use.PUBLIC_AIR, WarrenSpatialGrid.Use.DAYLIGHT_AIR]:
					overhang[cell] = true
			if not overhang.is_empty():
				storey["soffit"] = true
				storey["soffit_cells"] = overhang
	for door: Dictionary in house.doors:
		var private_cell := door.cell as Vector3i
		var direction := door.direction as Vector3i
		var dir := BuildingMass.DIRS.find(Vector2i(direction.x, direction.z))
		if dir < 0:
			continue
		var storey := _storey_for_band(mass, private_cell.y)
		if storey.is_empty():
			continue
		storey.openings[BuildingMass.edge_key(Vector2i(private_cell.x,
			private_cell.z), dir)] = BuildingMass.OPENING_DOOR
		if bool(door.get("passage", false)):
			# A passage-house abuts this wall line: the storey stays flush
			# (an inset storey recedes half a module, leaving a gap and the
			# passage's corner posts standing in front of its openings).
			storey["abutted"] = true
		if bool(door.get("balcony", false)):
			# The balcony's rakers bear on the wall below this storey at its
			# module joints; the designer keeps that wall flush (no jetty).
			storey["bears_balcony"] = true
	var designer := BuildingDesigner.new(kit)
	var own_air: Dictionary = house.get("own_air", {})
	designer.forbidden = func(cell: Vector2i, band: int) -> bool:
		return passages.has(Vector3i(cell.x, band, cell.y)) \
			or (not own_air.has(Vector3i(cell.x, band, cell.y)) \
			and _keep_clear(grid, owner_at, house_id, Vector3i(cell.x, band, cell.y)))
	designer.walked = func(cell: Vector2i, band: int) -> bool:
		return _walked(grid, Vector3i(cell.x, band, cell.y))
	designer.public_air = func(cell: Vector2i, band: int) -> bool:
		var probe := Vector3i(cell.x, band, cell.y)
		return grid.contains(probe) and grid.use_at(probe) == WarrenSpatialGrid.Use.PUBLIC_AIR \
			and not _walked(grid, probe)
	designer.covered = func(cell: Vector2i, band: int) -> bool:
		return _solid_other(grid, owner_at, house_id, Vector3i(cell.x, band, cell.y))
	designer.flight = func(cell: Vector2i, band: int) -> bool:
		return crosses_flight(flights, cell, band)
	designer.canopy_claims = canopy_claims
	preload("res://scripts/terrain/features/villages/kit/KitLoggias.gd").recess(mass, designer.forbidden, designer.walked)
	var context := {"terrain_storey": terrain_storey, "terraced": true,
		"colour": _district_colour(world_seed, house.cells)}
	# A house standing on the retained podium already has its masonry base:
	# the podium's course. A stone storey on it would stack a second, deeper
	# stone wall on the course (a 0.2 m jog, offset corner posts, two brick
	# fields; September 29 photo 7), so its ground storey is timber-framed.
	# Likewise beside it: a podium course abutting the ground storey runs
	# its flush face on the same wall line as the storey's deep masonry (a
	# merged compound's range can end against a terrace).
	if terrain_storey >= 0:
		for cell: Vector2i in storeys_by_band[terrain_band]:
			var near := podium.has(Vector3i(cell.x, terrain_band - 1, cell.y))
			for step: Vector2i in BuildingMass.DIRS:
				near = near or podium.has(Vector3i(cell.x + step.x, terrain_band, cell.y + step.y))
			if near:
				context["stone_chance"] = 0.0
				break
	designer.articulate(mass, context)
	return mass


static func _storey_for_band(mass: BuildingMass, band: int) -> Dictionary:
	for storey: Dictionary in mass.storeys:
		if int(storey.floor_band) == band:
			return storey
	for storey: Dictionary in mass.storeys:
		var floor := int(storey.floor_band)
		if band >= floor and band < floor + 2:
			return storey
	return {}


## Roof colour districts: coarse hashed patches so neighbouring houses share
## a colour family, as in the reference village.
static func _district_colour(world_seed: int, cells: Array) -> StringName:
	var centre := Vector2.ZERO
	for cell: Vector3i in cells:
		centre += Vector2(cell.x, cell.z)
	centre /= maxf(1.0, float(cells.size()))
	# Small colour quarters, evenly red and blue, with the odd house breaking
	# ranks so a quarter never reads as one uniform sheet.
	var district := Vector2i(floori(centre.x / 7.0), floori(centre.y / 7.0))
	var blue := absi(hash([world_seed, district])) % 2 == 0
	if absi(hash([world_seed, cells.size(), centre])) % 6 == 0:
		blue = not blue
	return &"blue" if blue else &"red"
