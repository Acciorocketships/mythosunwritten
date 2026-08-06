extends SceneTree

## Deterministic statistical gate for canonical villages. Unlike the visual
## selector, this records every eligible site in the search window, including
## empty records and every semantic-slot rejection. The JSON output is both a
## regression artifact and the source of strata for adversarial screenshot QA.
const SMOKE_SEEDS := [4242]
const FULL_SEEDS := [4242, 991177, 3046246887, 2697992464]
const SMOKE_RADIUS := 2
const FULL_RADIUS := 4
const THRESHOLDS := {
	"minimum_smoke_records": 3,
	"minimum_full_records": 24,
	"minimum_accepted_records": 1,
	"maximum_incompatible_overlaps": 0,
	"maximum_duplicate_stable_ids": 0,
	"maximum_projection_mismatches": 0,
}

var _full := false
var _output := "/tmp/mythos-village-corpus.json"


func _init() -> void:
	_read_args()
	var catalog := EnvironmentCatalog.load_default()
	var program := FeatureProgram.compile(catalog)
	assert(catalog != null and program != null)
	var seeds := FULL_SEEDS if _full else SMOKE_SEEDS
	var radius := FULL_RADIUS if _full else SMOKE_RADIUS
	var reports: Array[Dictionary] = []
	var totals := _empty_totals()
	var projection_blocks: Dictionary = {}
	for seed_value: int in seeds:
		var report := _run_seed(seed_value, radius, catalog, program)
		reports.append(report)
		_merge_totals(totals, report)
		for value: Variant in report.projection_blocks:
			projection_blocks[Vector2i(int(value[0]), int(value[1]))] = true
	var projection_mismatches := 0
	if _full and not projection_blocks.is_empty():
		projection_mismatches = _verify_projection_order(int(seeds[0]),
			projection_blocks.keys(), catalog)
	totals.projection_mismatches = projection_mismatches
	var threshold_records := int(THRESHOLDS.minimum_full_records) \
		if _full else int(THRESHOLDS.minimum_smoke_records)
	assert(int(totals.records) >= threshold_records)
	assert(int(totals.accepted_records) \
		>= int(THRESHOLDS.minimum_accepted_records))
	assert(int(totals.incompatible_overlaps) \
		<= int(THRESHOLDS.maximum_incompatible_overlaps))
	assert(int(totals.duplicate_stable_ids) \
		<= int(THRESHOLDS.maximum_duplicate_stable_ids))
	assert(projection_mismatches \
		<= int(THRESHOLDS.maximum_projection_mismatches))
	assert(float(totals.maximum_record_radius) \
		<= program.villages.max_record_radius + 0.001)
	if _full:
		for tier: StringName in VillageProgram.PRODUCTION_TIERS:
			assert(int(totals.tiers.get(String(tier), 0)) > 0,
				"Full village corpus must exercise every tier")
	var result := {
		"schema_version": 1,
		"full": _full,
		"seeds": seeds,
		"search_radius": radius,
		"thresholds": THRESHOLDS,
		"totals": totals,
		"per_seed": reports,
	}
	var directory := _output.get_base_dir()
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(_output, FileAccess.WRITE)
	assert(file != null, "Could not write village corpus report")
	file.store_string(JSON.stringify(result, "  "))
	file.close()
	print(("[village_corpus] full=%s records=%d accepted=%d buildings=%d " \
		+ "props=%d foundations=%d overlaps=%d projection_mismatches=%d output=%s") % [
		_full, int(totals.records), int(totals.accepted_records),
		int(totals.urban_buildings), int(totals.accepted_props),
		int(totals.foundation_instances),
		int(totals.incompatible_overlaps), projection_mismatches, _output])
	quit()


func _read_args() -> void:
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		match args[index]:
			"--full":
				_full = true
			"--output":
				if index + 1 < args.size():
					_output = args[index + 1]


static func _run_seed(seed_value: int, radius: int,
		catalog: EnvironmentCatalog, program: FeatureProgram) -> Dictionary:
	var water := TerrainWorldTuning.make_water(seed_value)
	var heightfield := TerrainWorldTuning.make_heightfield(seed_value, water)
	var fields := WorldFieldBlockCache.new(heightfield, water,
		program.query_margin, program.shore_distance_limit,
		program.field_cache_cap)
	var settlements := SettlementPlan.new(seed_value, water)
	var world := WorldFeaturePlan.new(seed_value, water, fields, program,
		settlements)
	var report := _empty_totals()
	report.seed = seed_value
	report.projection_blocks = []
	var stable_ids: Dictionary = {}
	var block_payloads: Dictionary = {}
	var started := Time.get_ticks_usec()
	for z in range(-radius, radius + 1):
		for x in range(-radius, radius + 1):
			var super_cell := Vector2i(x, z)
			if settlements.site_for(super_cell).is_empty():
				continue
			report.sites += 1
			var frame := world.frame_for(super_cell)
			if frame == null or frame.is_dormant():
				report.dormant_sites += 1
				continue
			var record := world.village_plan().record_for(frame)
			assert(record != null and record.validate(program.villages))
			report.records += 1
			var tier_key := String(record.tier)
			report.tiers[tier_key] = int(report.tiers.get(tier_key, 0)) + 1
			assert(record.prop_results.size() \
				== program.villages.prop_slots_for_tier(record.tier).size())
			report.props += record.prop_results.size()
			report.accepted_props += record.prop_results.values().count(&"accepted")
			if record.urban_fabric.accepted:
				report.accepted_records += 1
			for reason: StringName in record.prop_results.values():
				var reason_key := String(reason)
				report.prop_results[reason_key] = int(
					report.prop_results.get(reason_key, 0)) + 1
			var urban_key := String(record.urban_fabric.reason)
			report.urban_results[urban_key] = int(
				report.urban_results.get(urban_key, 0)) + 1
			report.urban_candidates += 1
			if record.urban_fabric.accepted:
				var fabric := record.urban_fabric
				report.urban_accepted += 1
				report.urban_buildings += fabric.buildings.size()
				if fabric.generation_kind in [
						VillageUrbanFabricPlan.GenerationKind.SECTIONAL_WARREN,
						VillageUrbanFabricPlan.GenerationKind.VOLUMETRIC_WARREN]:
					var audit := fabric.fabric_audit
					report.urban_ground_streets += int(
						audit.terrain_street_cell_count)
					report.urban_aerial_links += int(audit.skywalk_link_count)
					report.urban_platforms += int(audit.audited_platform_count)
					report.urban_public_stairs += int(audit.stair_count)
					report.urban_timber_cells += int(
						audit.structural_court_cell_count)
					report.maximum_urban_bands = maxi(
						int(report.maximum_urban_bands),
						int(audit.vertical_span_cells))
				else:
					report.urban_natural_buildings += fabric.natural_building_count
					report.urban_retained_buildings += fabric.retained_building_count
					report.urban_ground_streets \
						+= fabric.circulation.ground_street_count
					report.urban_aerial_links \
						+= fabric.circulation.aerial_link_count
					report.urban_platforms += fabric.circulation.platforms.size()
					report.urban_public_stairs += fabric.public_stair_count
					report.urban_supports += fabric.timber.support_count
					report.urban_support_pieces += fabric.timber.support_piece_count
					report.urban_railings += fabric.timber.railing_count
					report.urban_timber_cells += fabric.timber.cells.size()
					report.urban_rock_pieces += fabric.rock_piece_count
					for cell: VillageTimberCell in fabric.timber.cells:
						if cell.kind == VillageTimberCell.Kind.SKIRT:
							report.urban_skirt_cells += 1
						elif cell.kind == VillageTimberCell.Kind.WALKWAY:
							report.urban_walkway_cells += 1
					report.maximum_urban_bands = maxi(
						int(report.maximum_urban_bands),
						fabric.massing.elevation_band_count)
			var radius_used := _rect_radius(record.centre, record.bounds)
			report.maximum_record_radius = maxf(
				float(report.maximum_record_radius), radius_used)
			var occupancy := VillageOccupancy.new()
			for volume: VillageOccupancyVolume in record.occupancy:
				if not occupancy.add(volume):
					report.incompatible_overlaps += 1
			for asset_id: StringName in record.payload.asset_ids():
				var descriptor := catalog.descriptor(asset_id)
				assert(descriptor != null)
				var batch: Dictionary = record.payload.batches[asset_id]
				var count: int = batch.transforms.size()
				report.demanded_assets[String(asset_id)] = int(
					report.demanded_assets.get(String(asset_id), 0)) + count
				report.collision_shapes += count \
					* descriptor.collision_piece_count
				if asset_id == program.villages.foundation_asset_id:
					report.foundation_instances += count
				for index in count:
					if not batch.ids.is_empty():
						var stable_id: StringName = batch.ids[index]
						if stable_ids.has(stable_id):
							report.duplicate_stable_ids += 1
						stable_ids[stable_id] = true
					var transform: Transform3D = batch.transforms[index]
					var block := Vector2i(floori(transform.origin.x \
						/ TerrainChunkMesher.CHUNK_WORLD),
						floori(transform.origin.z \
						/ TerrainChunkMesher.CHUNK_WORLD))
					block_payloads[block] = int(
						block_payloads.get(block, 0)) + 1
	var blocks: Array[Vector2i] = []
	blocks.assign(block_payloads.keys())
	blocks.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x))
	for block: Vector2i in blocks:
		report.projection_blocks.append([block.x, block.y])
		report.maximum_block_payload = maxi(int(report.maximum_block_payload),
			int(block_payloads[block]))
	report.elapsed_ms = float(Time.get_ticks_usec() - started) / 1000.0
	report.erase("projection_mismatches")
	print(("[village_corpus] seed=%d records=%d tiers=%s urban=%d/%d " \
		+ "urban_reasons=%s " \
		+ "foundations=%d max_radius=%.2f elapsed_ms=%.1f") % [
		seed_value, int(report.records), report.tiers,
		int(report.urban_accepted), int(report.urban_candidates),
		report.urban_results,
		int(report.foundation_instances), float(report.maximum_record_radius),
		float(report.elapsed_ms)])
	return report


static func _verify_projection_order(seed_value: int, blocks_value: Array,
		catalog: EnvironmentCatalog) -> int:
	var blocks: Array[Vector2i] = []
	blocks.assign(blocks_value)
	blocks.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x))
	# Bound the expensive order audit without weakening its purpose: the first,
	# middle, and last ownership blocks exercise negative/positive coordinates
	# and distinct cache histories in two independently constructed worlds.
	var selected: Array[Vector2i] = []
	for index: int in [0, blocks.size() / 2, blocks.size() - 1]:
		if index >= 0 and index < blocks.size() \
				and not selected.has(blocks[index]):
			selected.append(blocks[index])
	var forward := _projection_signatures(seed_value, selected, catalog)
	selected.reverse()
	var reverse := _projection_signatures(seed_value, selected, catalog)
	var mismatches := 0
	for block: Vector2i in selected:
		if forward.get(block) != reverse.get(block):
			mismatches += 1
	return mismatches


static func _projection_signatures(seed_value: int,
		blocks: Array[Vector2i], catalog: EnvironmentCatalog) -> Dictionary:
	var water := TerrainWorldTuning.make_water(seed_value)
	var heightfield := TerrainWorldTuning.make_heightfield(seed_value, water)
	var program := FeatureProgram.compile(catalog)
	var fields := WorldFieldBlockCache.new(heightfield, water,
		program.query_margin, program.shore_distance_limit,
		program.field_cache_cap)
	var settlements := SettlementPlan.new(seed_value, water)
	var world := WorldFeaturePlan.new(seed_value, water, fields, program,
		settlements)
	var out: Dictionary = {}
	for block: Vector2i in blocks:
		out[block] = _context_signature(block, world.context_for(block))
	return out


static func _context_signature(block: Vector2i,
		context: FeatureContext) -> String:
	var ids: Array[String] = []
	var payload := context.placements()
	for asset_id: StringName in payload.asset_ids():
		var batch: Dictionary = payload.batches[asset_id]
		for index in batch.transforms.size():
			var stable := String(batch.ids[index]) if not batch.ids.is_empty() \
				else "anonymous.%d" % index
			var origin: Vector3 = (batch.transforms[index] as Transform3D).origin
			ids.append("%s|%s|%.3f,%.3f,%.3f" % [asset_id, stable,
				origin.x, origin.y, origin.z])
	ids.sort()
	var masks: Array[String] = []
	var mask_cells: Array[Vector2i] = []
	mask_cells.assign(context.connection_masks.keys())
	mask_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x))
	for cell: Vector2i in mask_cells:
		masks.append("%d,%d=%d" % [cell.x, cell.y,
			int(context.connection_masks[cell])])
	var samples: Array[String] = []
	var origin := Vector2(block) * TerrainChunkMesher.CHUNK_WORLD
	for local: Vector2 in [Vector2(24.0, 24.0), Vector2(96.0, 96.0),
			Vector2(168.0, 168.0)]:
		var point := origin + local
		samples.append("%d:%.4f" % [context.surface_at(point),
			context.clearance_at(point)])
	return "#".join(ids) + "|" + "#".join(masks) + "|" \
		+ "#".join(samples)


static func _empty_totals() -> Dictionary:
	return {
		"sites": 0,
		"dormant_sites": 0,
		"records": 0,
		"accepted_records": 0,
		"props": 0,
		"accepted_props": 0,
		"urban_candidates": 0,
		"urban_accepted": 0,
		"urban_buildings": 0,
		"urban_natural_buildings": 0,
		"urban_retained_buildings": 0,
		"urban_ground_streets": 0,
		"urban_aerial_links": 0,
		"urban_platforms": 0,
		"urban_public_stairs": 0,
		"urban_supports": 0,
		"urban_support_pieces": 0,
		"urban_railings": 0,
		"urban_timber_cells": 0,
		"urban_rock_pieces": 0,
		"urban_skirt_cells": 0,
		"urban_walkway_cells": 0,
		"maximum_urban_bands": 0,
		"foundation_instances": 0,
		"collision_shapes": 0,
		"incompatible_overlaps": 0,
		"duplicate_stable_ids": 0,
		"maximum_record_radius": 0.0,
		"maximum_block_payload": 0,
		"projection_mismatches": 0,
		"tiers": {},
		"prop_results": {},
		"urban_results": {},
		"demanded_assets": {},
	}


static func _merge_totals(totals: Dictionary, report: Dictionary) -> void:
	for key: String in ["sites", "dormant_sites", "records",
			"accepted_records", "props", "accepted_props",
			"urban_candidates", "urban_accepted", "urban_buildings",
			"urban_natural_buildings", "urban_retained_buildings",
			"urban_ground_streets", "urban_aerial_links",
			"urban_platforms", "urban_public_stairs", "urban_supports",
			"urban_support_pieces", "urban_railings",
			"urban_timber_cells", "urban_rock_pieces",
			"urban_skirt_cells", "urban_walkway_cells",
			"foundation_instances", "collision_shapes",
			"incompatible_overlaps", "duplicate_stable_ids"]:
		totals[key] = int(totals[key]) + int(report[key])
	for key: String in ["tiers", "prop_results", "urban_results",
			"demanded_assets"]:
		for child: Variant in report[key]:
			totals[key][child] = int(totals[key].get(child, 0)) \
				+ int(report[key][child])
	totals.maximum_record_radius = maxf(float(totals.maximum_record_radius),
		float(report.maximum_record_radius))
	totals.maximum_block_payload = maxi(int(totals.maximum_block_payload),
		int(report.maximum_block_payload))
	totals.maximum_urban_bands = maxi(int(totals.maximum_urban_bands),
		int(report.maximum_urban_bands))


static func _rect_radius(centre: Vector2, bounds: Rect2) -> float:
	var out := 0.0
	for corner: Vector2 in [bounds.position,
			Vector2(bounds.end.x, bounds.position.y), bounds.end,
			Vector2(bounds.position.x, bounds.end.y)]:
		out = maxf(out, centre.distance_to(corner))
	return out
