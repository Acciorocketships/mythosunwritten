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
## replaced_units: Dictionary unit stable_id -> true, masses: Array}.
static func build(spatial: WarrenSpatialPlan, fabric: SettlementFabricPlan,
		kit: BuildingKit) -> Dictionary:
	var grid := spatial.grid
	var houses := _houses(spatial)
	var owner_at: Dictionary = {}
	for house_id: StringName in houses:
		for cell: Vector3i in (houses[house_id] as Dictionary).cells:
			owner_at[cell] = house_id
	var replaced := _replaced_units(spatial, fabric)
	var feature_masses := _feature_masses(spatial, fabric, houses, grid, owner_at)
	var payload := EnvironmentInstancePayload.new()
	var map := native_to_lattice(kit)
	var masses: Array[BuildingMass] = []
	var ids := houses.keys()
	ids.sort()
	for house_id: StringName in ids:
		var house: Dictionary = houses[house_id]
		var mass := _mass_for(house_id, house, grid, owner_at, spatial.world_seed, kit)
		if mass != null:
			masses.append(mass)
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
	for floor_cell: Vector3i in spatial.route_floor_cells:
		walls.append(union_script.box_volume(AABB(Vector3(floor_cell.x * kit.module_width,
			floor_cell.y * kit.band_height(), floor_cell.z * kit.module_width),
			Vector3(kit.module_width, WarrenVolumePlan.HEADROOM_BANDS * kit.band_height(), kit.module_width))))
	var placements: Array[Dictionary] = []
	for mass: BuildingMass in masses:
		var own := StringName(String(mass.stable_id).trim_prefix("kit."))
		var assembler := BuildingKitAssembler.new(kit)
		assembler.external_blocked = func(cell: Vector2i, band: int) -> bool:
			return _solid_other(grid, owner_at, own, Vector3i(cell.x, band, cell.y))
		placements.append_array(assembler.assemble(mass))
	var roof_audit := union_script.append(placements, roofs, walls, kit, map, payload)
	roof_audit["joins"] = joins
	return {"payload": payload, "replaced_units": replaced, "masses": masses, "roof_audit": roof_audit}


## Balconies, overhang supports and skywalks as kit masses. Balconies also
## open a door in their owner house, so this runs before houses are designed.
static func _feature_masses(spatial: WarrenSpatialPlan, fabric: SettlementFabricPlan,
		houses: Dictionary, grid: WarrenSpatialGrid, owner_at: Dictionary) -> Array[BuildingMass]:
	var out: Array[BuildingMass] = []
	for feature: WarrenFeatureReservation in spatial.features:
		match feature.kind:
			&"balcony":
				var balcony := _balcony_mass(feature, houses, grid, spatial.world_seed)
				if balcony != null:
					out.append(balcony)
			&"room_overhang_support", &"arcade_overhang_support":
				out.append(_support_mass(feature, grid, spatial.world_seed))
	for span: Dictionary in SettlementFabricAssembler.maze_skywalk_spans(fabric):
		out.append(_skywalk_mass(span, spatial.world_seed))
	# The legacy fabric can classify a tunnel slab as a flat roof and subtract
	# it from retained-terrain skin. Give those owned structural cells their
	# own kit closure, independently of house roof/deck replacement.
	if spatial.source_volume != null:
		var source := spatial.source_volume.mass_context.get(&"maze_source_plan") as WarrenMazeSourcePlan
		if source != null:
			var ceilings := {}
			for walk: Vector3i in source.excavation.tunnel_cells:
				var roof := source.passage_headroom_top(walk)
				for fine: Vector3i in WarrenVolumetricSolver._fine_square(Vector3i(walk.x, roof, walk.z)):
					if grid.use_at(fine) == WarrenSpatialGrid.Use.STRUCTURAL_VOLUME and not fabric.retained_terrace_cells.has(fine):
						ceilings[fine] = true
			var tunnel := _retained_mass(ceilings, spatial.world_seed)
			if tunnel != null:
				tunnel.stable_id = &"kit.tunnel-ceilings"
				for storey: Dictionary in tunnel.storeys:
					storey.material = BuildingMass.MATERIAL_TIMBER
					storey.default_opening = BuildingMass.OPENING_PLAIN
					storey.soffit = true
					tunnel.decks.append({"cells": storey.cells, "band": int(storey.floor_band) + int(storey.bands), "rails": false})
				out.append(tunnel)
	var retained := _retained_mass(fabric.retained_terrace_cells, spatial.world_seed)
	if retained != null:
		for storey: Dictionary in retained.storeys:
			for cell: Vector2i in storey.cells:
				if grid.use_at(Vector3i(cell.x, int(storey.floor_band) - 1, cell.y)) == WarrenSpatialGrid.Use.PUBLIC_AIR:
					storey["soffit"] = true
		out.append(retained)
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
		storey.plain_every = 3
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
	for cell: Vector2i in deck:
		var support := _balcony_bearing(grid, deck, cell, band)
		if support.is_empty(): continue
		var wall := support.wall as Vector2
		var outer := Vector2(cell) + Vector2(0.5, 0.5)
		outer += (outer - wall).normalized() * 0.35
		mass.decor.append({"kind": &"raker", "dir": 0, "centre": wall,
			"from": Vector3(wall.x, band - 0.85, wall.y),
			"to": Vector3(outer.x, band - 0.08, outer.y)})
		mass.decor.append({"kind": &"raker", "dir": 0, "centre": wall,
			"from": Vector3(wall.x, band - 0.08, wall.y),
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
	for corner: Vector2i in [rect.position, Vector2i(rect.end.x - 1, rect.position.y),
			Vector2i(rect.position.x, rect.end.y - 1), rect.end - Vector2i.ONE]:
		# A post stands only on ground or structure, never in a public way.
		var landing := _post_landing(grid, Vector3i(corner.x, low - 1, corner.y))
		if landing == 1 << 20:
			continue
		var centre := Vector2(corner) + Vector2(0.5, 0.5) \
			+ (Vector2(corner) - Vector2(rect.get_center()) + Vector2(0.5, 0.5)).normalized() * 0.3
		mass.decor.append({"kind": &"post", "dir": 1, "centre": centre,
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
		var axis := 0 if step.x != 0 else 1
		var colour := &"blue" if absi(hash([world_seed, cell])) % 2 == 0 else &"red"
		var wing := mass.add_roof(rect, axis, cell.y + 2, colour)
		wing.open_min = true
		wing.open_max = true
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
		if not houses.has(house_id):
			houses[house_id] = {"cells": [], "storeys": {}, "doors": [],
				"terrain_band": 1 << 20, "landmark": false}
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
		for threshold: Dictionary in building.thresholds:
			(house.doors as Array).append({"cell": threshold.private_cell,
				"direction": threshold.direction})
	for feature: WarrenFeatureReservation in spatial.features:
		if feature.kind != &"prefab_landmark" or feature.reserved_cells.is_empty():
			continue
		houses[feature.stable_id] = _landmark_house(feature)
	return houses


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
static func _landmark_house(feature: WarrenFeatureReservation) -> Dictionary:
	# The reservation is the measured shell ring of a complete prefab; the
	# house is its whole rectangle. Landmarks are the village's large houses:
	# two or three storeys whatever the prefab's height was.
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


static func _mass_for(house_id: StringName, house: Dictionary,
		grid: WarrenSpatialGrid, owner_at: Dictionary, world_seed: int,
		kit: BuildingKit) -> BuildingMass:
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
		mass.add_storey(floor, storeys_by_band[floor], BuildingMass.MATERIAL_TIMBER)
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
	var designer := BuildingDesigner.new(kit)
	designer.forbidden = func(cell: Vector2i, band: int) -> bool:
		return _keep_clear(grid, owner_at, house_id, Vector3i(cell.x, band, cell.y))
	designer.walked = func(cell: Vector2i, band: int) -> bool:
		return _walked(grid, Vector3i(cell.x, band, cell.y))
	designer.public_air = func(cell: Vector2i, band: int) -> bool:
		var probe := Vector3i(cell.x, band, cell.y)
		return grid.contains(probe) and grid.use_at(probe) == WarrenSpatialGrid.Use.PUBLIC_AIR \
			and not _walked(grid, probe)
	designer.covered = func(cell: Vector2i, band: int) -> bool:
		return _solid_other(grid, owner_at, house_id, Vector3i(cell.x, band, cell.y))
	preload("res://scripts/terrain/features/villages/kit/KitLoggias.gd").recess(mass, designer.forbidden, designer.walked)
	designer.articulate(mass, {"terrain_storey": terrain_storey, "terraced": true,
		"colour": _district_colour(world_seed, house.cells)})
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
