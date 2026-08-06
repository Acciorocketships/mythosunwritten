extends SceneTree

## Fast production-terrain audit for one canonical settlement site.  This
## deliberately skips PathPlan/WorldFeaturePlan projection: it exists to prove
## that the sealed warren's external route landing meets the immutable terrain
## and that the complete footprint stays within the adapter's relief contract.
const DEFAULT_SEED := 2697992464
const DEFAULT_SUPER_CELL := Vector2i(0, -1)
const REGION_RADIUS := 5


func _init() -> void:
	var world_seed := DEFAULT_SEED
	var super_cell := DEFAULT_SUPER_CELL
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		match args[index]:
			"--seed":
				if index + 1 < args.size():
					world_seed = int(args[index + 1])
			"--super-x":
				if index + 1 < args.size():
					super_cell.x = int(args[index + 1])
			"--super-z":
				if index + 1 < args.size():
					super_cell.y = int(args[index + 1])
	var water := TerrainWorldTuning.make_water(world_seed)
	var site := SettlementPlan.new(world_seed, water).site_for(super_cell)
	if site.is_empty():
		print(JSON.stringify({
			"accepted": false,
			"reason": "no settlement site",
			"seed": world_seed,
			"super_cell": [super_cell.x, super_cell.y],
		}, "  "))
		quit(1)
		return
	var cell := site.cell as Vector2i
	var heightfield := TerrainWorldTuning.make_heightfield(world_seed, water)
	var region := heightfield.compute_region(cell.x, cell.y, REGION_RADIUS)
	var terrain := VillageTerrainView.from_region(region)
	var program := VillageProgram.compile({}, EnvironmentCatalog.load_default())
	assert(program != null)
	var frame := VillageFrame.from_mask(site, 1, region,
		_empty_water(region, cell))
	var village_plan := VillagePlan.new(world_seed, program)
	var urban := VillageWarrenFabricSolver.solve(terrain,
		village_plan._warren_seed(frame), frame.settlement_id, frame.centre,
		Vector2.RIGHT, program)
	var support_count := 0
	for entry: Dictionary in urban.entries:
		support_count += int(StringName(entry.get("asset_id", "")) \
			== SettlementFabricAssembler.TIMBER_SUPPORT)
	var parcel_storeys: Array[int] = []
	var parcel_shapes: Array[String] = []
	if urban.volumetric_town != null:
		for parcel: WarrenBuildingParcel in urban.volumetric_town.assets.town.parcels.parcels:
			parcel_storeys.append(parcel.storey_count())
			parcel_shapes.append("%dx%d" % [parcel.width_cells,
				parcel.depth_cells])
	var report := {
		"accepted": urban.accepted,
		"reason": String(urban.reason),
		"seed": world_seed,
		"city_seed": urban.volumetric_town.world_seed \
			if urban.volumetric_town != null else 0,
		"super_cell": [super_cell.x, super_cell.y],
		"site_cell": [cell.x, cell.y],
		"centre": [frame.centre.x, frame.centre.y],
		"terrain_y_at_entrance": terrain.surface_y(frame.centre),
		"entrance_lift_m": urban.terrain_entrance_lift_m,
		"terrain_relief_m": urban.terrain_relief_m,
		"timber_support_piece_count": support_count,
		"route_signature": String(urban.fabric_audit.get(
			"maze_route_signature", "")),
		"construction_signature": String(urban.fabric_audit.get(
			"construction_signature", "")),
		"parcel_count": int(urban.fabric_audit.get("parcel_count", 0)),
		"parcel_shapes": parcel_shapes,
		"parcel_storeys": parcel_storeys,
		"bounded_walk_ratio": float(urban.fabric_audit.get(
			"bounded_walk_ratio", 0.0)),
		"two_sided_walk_ratio": float(urban.fabric_audit.get(
			"two_sided_walk_ratio", 0.0)),
		"occupied_overpass_parcel_count": int(urban.fabric_audit.get(
			"occupied_overpass_parcel_count", 0)),
		"urban_core_open_column_ratio": float(urban.fabric_audit.get(
			"urban_core_open_column_ratio", 0.0)),
		"frontage_ratio": float(urban.fabric_audit.get(
			"frontage_ratio", 0.0)),
		"overhead_route_ratio": float(urban.fabric_audit.get(
			"overhead_route_ratio", 0.0)),
		"through_sightline_count": int(urban.fabric_audit.get(
			"through_sightline_count", 0)),
	}
	print(JSON.stringify(report, "  "))
	quit(0 if urban.accepted else 1)


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
