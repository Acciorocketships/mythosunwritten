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
	var catalog := EnvironmentCatalog.load_default()
	var program := FeatureProgram.compile(catalog)
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
			catalog, not skip_projection)
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
					catalog, not skip_projection)
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
		catalog: EnvironmentCatalog,
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
		"collision_enabled_instances": _collision_enabled_instance_count(
			record.payload),
		"collision_disabled_instances": _collision_disabled_instance_count(
			record.payload),
		"generated_collision_boxes": record.payload.collision_boxes.size(),
		"collision_shapes": _collision_shape_count(record.payload, catalog),
		"assets": Array(record.payload.asset_ids()).map(
			func(id: StringName) -> String: return String(id)),
		"prop_results": record.prop_results,
		"urban_status": String(record.urban_fabric.reason),
		"urban_buildings": record.urban_fabric.buildings.size(),
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
		assert(audit.has("spatial_signature"),
			"volumetric records must publish their canonical spatial signature")
		report["spatial_signature"] = String(audit.spatial_signature)
		report["construction_signature"] = String(audit.construction_signature)
		report["entrance_lift_m"] = \
			record.urban_fabric.terrain_entrance_lift_m
		report["terrain_relief_m"] = \
			record.urban_fabric.terrain_relief_m
	return report


static func _collision_enabled_instance_count(
		payload: EnvironmentInstancePayload) -> int:
	var count := 0
	for asset_id: StringName in payload.asset_ids():
		var batch := payload.batches[asset_id] as Dictionary
		var flags: Array = batch.get("collision_enabled", [])
		for index in batch.transforms.size():
			if flags.is_empty() or bool(flags[index]):
				count += 1
	return count


static func _collision_disabled_instance_count(
		payload: EnvironmentInstancePayload) -> int:
	return payload.instance_count - _collision_enabled_instance_count(payload)


static func _collision_shape_count(payload: EnvironmentInstancePayload,
		catalog: EnvironmentCatalog) -> int:
	var count := payload.collision_boxes.size()
	for asset_id: StringName in payload.asset_ids():
		var batch := payload.batches[asset_id] as Dictionary
		var flags: Array = batch.get("collision_enabled", [])
		var descriptor := catalog.descriptor(asset_id)
		assert(descriptor != null)
		for index in batch.transforms.size():
			if flags.is_empty() or bool(flags[index]):
				count += descriptor.collision_piece_count
	for mesh: Dictionary in payload.surface_meshes:
		if not bool(mesh.get("visual_only", false)):
			count += 1
	return count


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
