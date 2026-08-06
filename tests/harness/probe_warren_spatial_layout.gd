extends SceneTree

## Prints compact macro-lattice slices for one production-terrain warren. This
## is a topology diagnostic: it distinguishes public route, inhabited mass,
## infill platform, and genuinely empty undercroft before visual fixes are made.
const DEFAULT_SEED := 2697992464
const DEFAULT_SUPER_CELL := Vector2i(0, -1)
const REGION_RADIUS := 5


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var world_seed := _argument_int(args, "--seed", DEFAULT_SEED)
	var super_cell := Vector2i(
		_argument_int(args, "--super-x", DEFAULT_SUPER_CELL.x),
		_argument_int(args, "--super-z", DEFAULT_SUPER_CELL.y))
	var water := TerrainWorldTuning.make_water(world_seed)
	var site := SettlementPlan.new(world_seed, water).site_for(super_cell)
	assert(not site.is_empty())
	var cell := site.cell as Vector2i
	var heightfield := TerrainWorldTuning.make_heightfield(world_seed, water)
	var region := heightfield.compute_region(cell.x, cell.y, REGION_RADIUS)
	var terrain := VillageTerrainView.from_region(region)
	var program := VillageProgram.compile({}, EnvironmentCatalog.load_default())
	var frame := VillageFrame.from_mask(site, 1, region,
		_empty_water(region, cell))
	var village_plan := VillagePlan.new(world_seed, program)
	var urban := VillageWarrenFabricSolver.solve(terrain,
		village_plan._warren_seed(frame), frame.settlement_id, frame.centre,
		Vector2.RIGHT, program)
	assert(urban.accepted and urban.volumetric_town != null)
	var town := urban.volumetric_town.assets.town
	var route: Dictionary = {}
	for route_cell: Vector3i in town.volume.primary_itinerary:
		route[route_cell] = true
	var buildings := town.pruning.building_cells
	var extensions: Dictionary = {}
	for node_value: PublicRealmNode in town.public_realm.nodes:
		for fine_cell: Vector3i in node_value.surface_cells:
			var macro_cell := Vector3i(floori(float(fine_cell.x) / 2.0),
				fine_cell.y, floori(float(fine_cell.z) / 2.0))
			if not route.has(macro_cell):
				extensions[macro_cell] = true
	var minimum := Vector2i(2147483647, 2147483647)
	var maximum := Vector2i(-2147483648, -2147483648)
	var minimum_y := 2147483647
	var maximum_y := -2147483648
	for column_value: Variant in town.parcels.urban_core_columns.keys():
		var column := column_value as Vector2i
		minimum.x = mini(minimum.x, column.x)
		minimum.y = mini(minimum.y, column.y)
		maximum.x = maxi(maximum.x, column.x)
		maximum.y = maxi(maximum.y, column.y)
		minimum_y = mini(minimum_y, town.volume.envelope.ground_at(column))
		maximum_y = maxi(maximum_y, town.volume.envelope.top_at(column) - 1)
	print("seed=%d city_seed=%d attempt=%d bounds=%s..%s y=%d..%d" % [
		world_seed, urban.volumetric_town.world_seed,
		int(town.audit.route_attempt), minimum, maximum, minimum_y, maximum_y])
	print("primary_itinerary=%s" % [town.volume.primary_itinerary])
	for y in range(maximum_y, minimum_y - 1, -1):
		print("y=%d  B=building R=route P=infill g=natural ground .=air" % y)
		for z in range(minimum.y, maximum.y + 1):
			var line := ""
			for x in range(minimum.x, maximum.x + 1):
				var lattice_cell := Vector3i(x, y, z)
				var column := Vector2i(x, z)
				if buildings.has(lattice_cell):
					line += "B"
				elif route.has(lattice_cell):
					line += "R"
				elif extensions.has(lattice_cell):
					line += "P"
				elif town.volume.envelope.ground_at(column) == y:
					line += "g"
				else:
					line += "."
			print(line)
	quit(0)


static func _argument_int(args: PackedStringArray, key: String,
		fallback: int) -> int:
	var index := args.find(key)
	return fallback if index < 0 or index + 1 >= args.size() \
		else int(args[index + 1])


static func _empty_water(region: HeightfieldRegion,
		cell: Vector2i) -> WaterFieldContext:
	var context := WaterFieldContext.new()
	context._ctx = {"ponds": [], "rivers": [], "buckets": {},
		"region": region}
	context._region = region
	var centre := Vector2(cell) * TerrainSurfaceField.TILE
	var radius := float(REGION_RADIUS) * TerrainSurfaceField.TILE
	context._coverage = Rect2(centre - Vector2.ONE * radius,
		Vector2.ONE * radius * 2.0)
	context._shore_limit = 0.0
	return context
