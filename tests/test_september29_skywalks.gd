extends GutTest

## September 29 town review, skywalk stream (owner photos 4, 8, 9; world seed
## 2697992464). Town A = city 1260018864828801968 compact, Town B = city
## 1998423929946073270 compact. Invariants over real towns, not site fixes.

const FROZEN := preload("res://tests/fixtures/frozen_maze_source.gd")
## The two photographed towns plus towns whose skywalk network carried an
## enclosed span on the September 29 baseline (5, 7, 9 standard).
const CITIES: Array = [[1260018864828801968, &"compact"],
	[1998423929946073270, &"compact"], [5, &"standard"], [7, &"standard"],
	[9, &"standard"]]

static var _program: SettlementFabricProgram
static var _towns: Dictionary = {}


static func _town(city: int, profile: StringName) -> WarrenSpatialPlan:
	var key := "%d:%s" % [city, profile]
	if not _towns.has(key):
		if _program == null:
			_program = SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
		var source := WarrenMazeSitePlanner.plan(city, {},
			WarrenVillageScaleProfile.for_id(profile), &"", false)
		_towns[key] = FROZEN.spatial(source, _program)
	return _towns[key]


## Photo 4: a gabled bridge-house over a street met no building at either end;
## its floor lay on a roof (or an open deck) and it touched the town only along
## its bottom edges. A bridge-house is a storey spanning between two buildings:
## every end lane of an enclosed span must be inhabited over the whole bridge
## storey (its floor band and the band above), by a different unit at each end.
func test_every_enclosed_skywalk_abuts_a_building_storey_at_both_ends() -> void:
	var enclosed := 0
	var failures: Array[String] = []
	for job: Array in CITIES:
		var spatial := _town(job[0], job[1])
		var fabric := spatial.compiled_fabric_cache()
		var inhabited := fabric.transformed_cells(&"inhabited")
		for span: Dictionary in SettlementFabricAssembler.maze_skywalk_spans(fabric):
			if not bool(span.get("enclosed", false)):
				continue
			enclosed += 1
			var step := span.step as Vector3i
			for lane: Vector3i in SettlementFabricAssembler._skywalk_candidate_lanes(span):
				var far := lane + step * (int(span.gap) + 1)
				var owners := []
				for end: Vector3i in [lane, far]:
					var owner: Variant = inhabited.get(end)
					if owner == null or inhabited.get(end + Vector3i.UP) != owner:
						failures.append("%s: %s end %s not inside a building storey" % [
							job, span, end])
					owners.append(owner)
				if owners[0] != null and owners[0] == owners[1]:
					failures.append("%s: %s joins one unit to itself" % [job, span])
	assert_eq(failures, [] as Array[String],
		"A bridge-house must meet a building wall over its full storey at both ends")
	gut.p("enclosed spans checked: %d" % enclosed)


## The planner's own bridge-houses (source bridge compounds) already carry
## their endpoint houses; pin that each body is abutted on both span ends over
## every band it occupies.
func test_source_bridge_houses_abut_endpoint_houses() -> void:
	var bodies := 0
	var failures: Array[String] = []
	for job: Array in CITIES:
		var spatial := _town(job[0], job[1])
		var owner: Dictionary = {}
		for building: WarrenBuildingVolume in spatial.buildings:
			for cell: Vector3i in building.private_cells:
				owner[cell] = building.stable_id
		for building: WarrenBuildingVolume in spatial.buildings:
			if not String(building.stable_id).begins_with("spatial.maze_bridge."):
				continue
			bodies += 1
			var cells: Dictionary = {}
			for cell: Vector3i in building.private_cells:
				cells[cell] = true
			var abutted_axis := false
			for axis: Vector3i in [Vector3i(1, 0, 0), Vector3i(0, 0, 1)]:
				var ok := true
				for cell: Vector3i in building.private_cells:
					for dir: Vector3i in [axis, -axis]:
						var next := cell + dir
						if cells.has(next):
							continue
						ok = ok and owner.has(next) and owner[next] != building.stable_id
				abutted_axis = abutted_axis or ok
			if not abutted_axis:
				failures.append("%s: %s" % [job, building.stable_id])
	assert_eq(failures, [] as Array[String],
		"Every source bridge-house body is abutted by buildings at both span ends")
	gut.p("source bridge bodies checked: %d" % bodies)


static func _built(spatial: WarrenSpatialPlan) -> Dictionary:
	var key := "built:%s" % spatial.stable_id
	if not _towns.has(key):
		_towns[key] = KitVillageBuildings.build(spatial, spatial.compiled_fabric_cache(),
			SuntailBuildingKit.create())
	return _towns[key]


static func _placements_by_mass(built: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for placement: Dictionary in built.placements:
		var mass_id := String(placement.stable_id).get_slice("/", 0)
		if not out.has(mass_id):
			out[mass_id] = []
		(out[mass_id] as Array).append(placement)
	return out


static func _has_placement(placements: Array, roles: Array, at: Vector3,
		kit: BuildingKit, tolerance := 0.3) -> bool:
	for placement: Dictionary in placements:
		if not roles.has(placement.role):
			continue
		var origin := (placement.transform as Transform3D).origin
		if Vector2(origin.x, origin.z).distance_to(Vector2(at.x, at.z)) \
				< tolerance * kit.module_width and absf(origin.y - at.y) < 0.3:
			return true
	return false


## Photo 8: along the underside of a bridge-house over a lane, the wall panels'
## plaster bottoms met the soffit boards at their outer edge and flickered. A
## storey whose wall stands over open air closes that edge with the same
## continuous floor beam a jetty carries, whatever its height in the house.
func test_exposed_wall_bases_over_air_carry_a_floor_beam() -> void:
	var kit := SuntailBuildingKit.create()
	var checked := 0
	var failures: Array[String] = []
	for job: Array in CITIES:
		var spatial := _town(job[0], job[1])
		var grid := spatial.grid
		var houses := KitVillageBuildings._houses(spatial)
		var owner: Dictionary = {}
		for house_id: StringName in houses:
			for cell: Vector3i in (houses[house_id] as Dictionary).cells:
				owner[cell] = house_id
		var built := _built(spatial)
		var by_mass := _placements_by_mass(built)
		for mass: BuildingMass in built.masses:
			var house_id := StringName(String(mass.stable_id).trim_prefix("kit."))
			if not houses.has(house_id):
				continue
			for storey: Dictionary in mass.storeys:
				var floor := int(storey.floor_band)
				for slot: Dictionary in BuildingKitAssembler.wall_slots(storey.cells, false):
					var edge := slot.edge as Vector3i
					if StringName(storey.openings.get(edge, storey.default_opening)) \
							== BuildingMass.OPENING_NONE:
						continue
					var inside := Vector2i(edge.x, edge.y)
					var under := Vector3i(inside.x, floor - 1, inside.y)
					if owner.has(under) or not grid.contains(under) or grid.use_at(under) \
							not in [WarrenSpatialGrid.Use.PUBLIC_AIR, WarrenSpatialGrid.Use.DAYLIGHT_AIR]:
						continue
					var outside := inside + BuildingMass.DIRS[edge.z]
					var beyond := Vector3i(outside.x, floor, outside.y)
					if owner.has(beyond) or (grid.contains(beyond) and grid.use_at(beyond) \
							== WarrenSpatialGrid.Use.STRUCTURAL_VOLUME):
						continue
					checked += 1
					var centre := slot.centre as Vector2
					if not _has_placement(by_mass.get(String(mass.stable_id), []),
							[&"trim.floor_beam", &"trim.floor_beam_corner"],
							Vector3(centre.x * kit.module_width, floor * kit.band_height(),
								centre.y * kit.module_width), kit):
						failures.append("%s: %s floor %d edge %s" % [job, mass.stable_id, floor, edge])
	assert_gt(checked, 0, "the corpus has walls standing over open air")
	assert_eq(failures, [] as Array[String],
		"A wall standing over open air closes its base with a floor beam")


## Photo 9: a loggia recessed into the top storey sat under the house roof with
## nothing between: from the street one looked up into the hollow attic (roof
## boards, gable walls from behind, a floating chimney base) and read it as "no
## roof". Roof over free air closes the attic with a boarded ceiling at the
## eave, as the floor of a storey above closes a lower loggia.
func test_roof_over_free_air_closes_the_attic() -> void:
	var kit := SuntailBuildingKit.create()
	var checked := 0
	var failures: Array[String] = []
	for job: Array in CITIES:
		var spatial := _town(job[0], job[1])
		var houses := KitVillageBuildings._houses(spatial)
		var owner: Dictionary = {}
		for house_id: StringName in houses:
			for cell: Vector3i in (houses[house_id] as Dictionary).cells:
				owner[cell] = house_id
		var built := _built(spatial)
		var by_mass := _placements_by_mass(built)
		for mass: BuildingMass in built.masses:
			var house_id := StringName(String(mass.stable_id).trim_prefix("kit."))
			if not houses.has(house_id):
				continue
			for roof: Dictionary in mass.roofs:
				var eave := int(roof.eave_band)
				var below := mass.cells_at_band(eave - 1)
				var level := mass.cells_at_band(eave)
				for cell: Vector2i in BuildingMass.rect_cells(roof.rect as Rect2i):
					if below.has(cell) or level.has(cell):
						continue
					var other: Variant = owner.get(Vector3i(cell.x, eave - 1, cell.y))
					if other != null and other != house_id:
						continue
					checked += 1
					if not _has_placement(by_mass.get(String(mass.stable_id), []),
							[&"deck.board"], Vector3((cell.x + 0.5) * kit.module_width,
								eave * kit.band_height(), (cell.y + 0.5) * kit.module_width), kit):
						failures.append("%s: %s roof %s cell %s" % [job, mass.stable_id, roof.rect, cell])
	assert_gt(checked, 0, "the corpus has roof over free air (loggias, porches)")
	assert_eq(failures, [] as Array[String],
		"Roof over free air closes the attic at the eave")
