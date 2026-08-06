extends SceneTree

## Headless deterministic corpus discovery. This uses the production path,
## terrain, water, and village plans but creates no scene-tree resources.
## Runtime screenshot harnesses consume its printed seed/site pins.
const DEFAULT_SEED := 4242
const SEARCH_RADIUS := 3
const TARGET_RECORDS := 3

func _init() -> void:
	var seed_value := DEFAULT_SEED
	var requested_super_cell := Vector2i.ZERO
	var has_requested_super_cell := false
	var skip_projection := false
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		match args[index]:
			"--seed":
				if index + 1 < args.size():
					seed_value = int(args[index + 1])
			"--super-x":
				if index + 1 < args.size():
					requested_super_cell.x = int(args[index + 1])
					has_requested_super_cell = true
			"--super-z":
				if index + 1 < args.size():
					requested_super_cell.y = int(args[index + 1])
					has_requested_super_cell = true
			"--skip-projection":
				skip_projection = true
	var water := TerrainWorldTuning.make_water(seed_value)
	var heightfield := TerrainWorldTuning.make_heightfield(seed_value, water)
	var program := FeatureProgram.compile(EnvironmentCatalog.load_default())
	assert(program != null)
	var fields := WorldFieldBlockCache.new(heightfield, water,
		program.query_margin, program.shore_distance_limit,
		program.field_cache_cap)
	var settlements := SettlementPlan.new(seed_value, water)
	var world := WorldFeaturePlan.new(seed_value, water, fields, program,
		settlements)
	var report: Array[Dictionary] = []
	if has_requested_super_cell:
		var pinned := _record_report(world, fields, requested_super_cell,
			not skip_projection)
		print(JSON.stringify(pinned, "  "))
		quit(1 if pinned.is_empty() else 0)
		return
	for distance in SEARCH_RADIUS * 2 + 1:
		for z in range(-SEARCH_RADIUS, SEARCH_RADIUS + 1):
			for x in range(-SEARCH_RADIUS, SEARCH_RADIUS + 1):
				if maxi(absi(x), absi(z)) != distance:
					continue
				var super_cell := Vector2i(x, z)
				var record_report := _record_report(world, fields, super_cell,
					not skip_projection)
				if record_report.is_empty():
					continue
				record_report.seed = seed_value
				report.append(record_report)
				if report.size() >= TARGET_RECORDS:
					print(JSON.stringify(report, "  "))
					quit()
					return
	print(JSON.stringify(report, "  "))
	quit(1 if report.is_empty() else 0)


static func _record_report(world: WorldFeaturePlan,
		fields: WorldFieldBlockCache, super_cell: Vector2i,
		include_projection: bool = true) -> Dictionary:
	var frame := world.frame_for(super_cell)
	if frame == null or frame.is_dormant():
		return {}
	var record := world.village_plan().record_for(frame)
	if record == null or record.is_empty():
		return {}
	var report := {
		"super_cell": [super_cell.x, super_cell.y],
		"settlement_id": String(record.stable_id),
		"centre": [record.centre.x, record.centre.y],
		"tier": String(record.tier),
		"theme": String(record.theme),
		"instances": record.payload.instance_count,
		"assets": Array(record.payload.asset_ids()).map(
			func(id: StringName) -> String: return String(id)),
		"prop_results": record.prop_results,
		"urban_status": String(record.urban_fabric.reason),
		"urban_buildings": record.urban_fabric.buildings.size(),
		"urban_candidate_audit": record.urban_fabric.candidate_audit,
		"projected_blocks": _projection_counts(world, record) \
			if include_projection else {},
		"placement_origins": _placement_origins(record),
	}
	if record.urban_fabric.generation_kind in [
			VillageUrbanFabricPlan.GenerationKind.SECTIONAL_WARREN,
			VillageUrbanFabricPlan.GenerationKind.VOLUMETRIC_WARREN]:
		var audit := record.urban_fabric.fabric_audit
		report["generation_kind"] = "volumetric_warren" \
			if record.urban_fabric.generation_kind \
				== VillageUrbanFabricPlan.GenerationKind.VOLUMETRIC_WARREN \
			else "sectional_warren"
		report["urban_elevation_bands"] = int(audit.vertical_span_cells)
		report["urban_ground_streets"] = int(audit.terrain_street_cell_count)
		report["urban_aerial_links"] = int(audit.skywalk_link_count)
		report["urban_platforms"] = int(audit.audited_platform_count)
		report["urban_public_stairs"] = int(audit.stair_count)
		report["maze_route_signature"] = String(audit.maze_route_signature)
		report["construction_signature"] = String(audit.construction_signature)
		report["entrance_lift_m"] = \
			record.urban_fabric.terrain_entrance_lift_m
		report["terrain_relief_m"] = \
			record.urban_fabric.terrain_relief_m
	else:
		report["generation_kind"] = "legacy_terrain_massing"
		report["urban_elevation_bands"] = \
			record.urban_fabric.massing.elevation_band_count
		report["urban_ground_streets"] = \
			record.urban_fabric.circulation.ground_street_count
		report["urban_aerial_links"] = \
			record.urban_fabric.circulation.aerial_link_count
		report["urban_platforms"] = \
			record.urban_fabric.circulation.platforms.size()
		report["urban_public_stairs"] = record.urban_fabric.public_stair_count
	return report


static func _projection_counts(world: WorldFeaturePlan,
		record: VillageRecord) -> Dictionary:
	var blocks: Dictionary = {}
	for asset_id: StringName in record.payload.asset_ids():
		for transform: Transform3D in record.payload.batches[asset_id].transforms:
			var point := Vector2(transform.origin.x, transform.origin.z)
			blocks[WorldFieldBlockCache.key_of(point)] = true
	var out: Dictionary = {}
	for block: Vector2i in blocks:
		var payload := world.context_for(block).placements()
		out["%d,%d" % [block.x, block.y]] = payload.instance_count
	return out

static func _placement_origins(record: VillageRecord) -> Dictionary:
	var out: Dictionary = {}
	for asset_id: StringName in record.payload.asset_ids():
		var values: Array = []
		for transform: Transform3D in record.payload.batches[asset_id].transforms:
			if values.size() >= 8:
				break
			values.append([transform.origin.x, transform.origin.y,
				transform.origin.z])
		out[String(asset_id)] = values
	return out
