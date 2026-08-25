extends SceneTree

## Deterministic, production-field village selector for visual falsification.
## The selector never substitutes a smaller tier/theme quota. Development runs
## may explicitly acknowledge feature strata that the current implementation
## cannot yet supply; the manifest records those gaps and can never be mistaken
## for a closing full-spec review.
const DEFAULT_SEED := 4242
const PER_TIER_THEME := 6
const MAX_SEARCH_RADIUS := 24
const TIERS: Array[StringName] = VillageProgram.PRODUCTION_TIERS
const THEMES: Array[StringName] = [&"blue", &"orange"]

var _seed := DEFAULT_SEED
var _output := "/tmp/mythos-village-visual-corpus.json"
var _development := false
var _maximum_radius := MAX_SEARCH_RADIUS
var _development_limit := -1
var _has_pinned_super_cell := false
var _pinned_super_cell := Vector2i.ZERO


func _init() -> void:
	_read_args()
	var water := TerrainWorldTuning.make_water(_seed)
	var heightfield := TerrainWorldTuning.make_heightfield(_seed, water)
	var catalog := EnvironmentCatalog.load_default()
	var program := FeatureProgram.compile(catalog)
	assert(program != null)
	var fields := WorldFieldBlockCache.new(heightfield, water,
		program.query_margin, program.shore_distance_limit,
		program.field_cache_cap)
	var settlements := SettlementPlan.new(_seed, water)
	var world := WorldFeaturePlan.new(_seed, water, fields, program,
		settlements)
	var selected: Array[Dictionary] = []
	var counts := _empty_counts()
	var searched_radius := 0
	var radii: Array[int] = []
	if _has_pinned_super_cell:
		radii.append(0)
	else:
		radii = _integer_range(_maximum_radius + 1)
	for radius in radii:
		searched_radius = radius
		var cells: Array[Vector2i] = []
		if _has_pinned_super_cell:
			cells.append(_pinned_super_cell)
		else:
			cells = _ring(radius)
		for super_cell: Vector2i in cells:
			if settlements.site_for(super_cell).is_empty():
				continue
			var frame := world.frame_for(super_cell)
			if frame == null or frame.is_dormant():
				continue
			var record := world.village_plan().record_for(frame)
			if record == null or record.payload.instance_count == 0:
				continue
			var bucket := "%s/%s" % [record.tier, record.theme]
			if int(counts.get(bucket, 0)) >= PER_TIER_THEME:
				continue
			selected.append(_entry(super_cell, frame, record,
				program.villages, selected.size(), _seed))
			counts[bucket] = int(counts.get(bucket, 0)) + 1
			if _development_limit >= 0 \
					and selected.size() >= _development_limit:
				break
		if _quota_complete(counts) \
				or (_development_limit >= 0 \
				and selected.size() >= _development_limit):
			break
	var coverage := _coverage(selected, counts, searched_radius)
	var manifest := {
		"schema_version": 1,
		"world_seed": _seed,
		"production_tuning": {
			"heightfield_amplitude": TerrainWorldTuning.HEIGHTFIELD_AMPLITUDE,
			"heightfield_max_storeys": TerrainWorldTuning.HEIGHTFIELD_MAX_STOREYS,
			"max_cliff_step": TerrainWorldTuning.MAX_CLIFF_STEP,
		},
		"fixed_capture": {"resolution": [1920, 1080], "fov": 58.0},
		"coverage": coverage,
		"villages": selected,
	}
	var directory := _output.get_base_dir()
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(_output, FileAccess.WRITE)
	assert(file != null, "Could not write village visual corpus manifest")
	file.store_string(JSON.stringify(manifest, "  "))
	file.close()
	print("[village_visual_corpus] output=%s villages=%d radius=%d counts=%s unmet=%s" \
		% [_output, selected.size(), searched_radius, counts, coverage.unmet])
	if not bool(coverage.tier_theme_complete) and not _development:
		quit(1)
	elif not bool(coverage.full_spec_complete) and not _development:
		push_error("Full visual corpus strata are unavailable; rerun with --development only for an explicitly non-closing review")
		quit(2)
	else:
		quit()


func _read_args() -> void:
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		match args[index]:
			"--seed":
				if index + 1 < args.size():
					_seed = int(args[index + 1])
			"--output":
				if index + 1 < args.size():
					_output = args[index + 1]
			"--max-radius":
				if index + 1 < args.size():
					_maximum_radius = int(args[index + 1])
			"--development":
				_development = true
			"--limit":
				if index + 1 < args.size():
					_development_limit = int(args[index + 1])
			"--super-x":
				if index + 1 < args.size():
					_pinned_super_cell.x = int(args[index + 1])
					_has_pinned_super_cell = true
			"--super-z":
				if index + 1 < args.size():
					_pinned_super_cell.y = int(args[index + 1])
					_has_pinned_super_cell = true
	assert(_development_limit < 0 or (_development \
		and _development_limit > 0),
		"A reduced corpus limit is permitted only in explicit development runs")


static func _empty_counts() -> Dictionary:
	var out: Dictionary = {}
	for tier: StringName in TIERS:
		for theme: StringName in THEMES:
			out["%s/%s" % [tier, theme]] = 0
	return out


static func _integer_range(count: int) -> Array[int]:
	var out: Array[int] = []
	for value in count:
		out.append(value)
	return out


static func _quota_complete(counts: Dictionary) -> bool:
	for value: Variant in counts.values():
		if int(value) < PER_TIER_THEME:
			return false
	return true


static func _ring(radius: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if radius == 0:
		return [Vector2i.ZERO]
	for z in range(-radius, radius + 1):
		for x in range(-radius, radius + 1):
			if maxi(absi(x), absi(z)) == radius:
				out.append(Vector2i(x, z))
	return out


static func _entry(super_cell: Vector2i, frame: VillageFrame,
		record: VillageRecord, program: VillageProgram, index: int,
		world_seed: int) -> Dictionary:
	var assets: Array[String] = []
	var foundation_count := 0
	var buildings: Array[Dictionary] = []
	var props: Array[Dictionary] = []
	var foundations: Array[Dictionary] = []
	var urban_placements: Array[Dictionary] = []
	for asset_id: StringName in record.payload.asset_ids():
		assets.append(String(asset_id))
		var batch: Dictionary = record.payload.batches[asset_id]
		for placement_index in batch.transforms.size():
			var placement_id := String(batch.ids[placement_index])
			if placement_id.contains(".urban."):
				var placement_transform: Transform3D = \
					batch.transforms[placement_index]
				urban_placements.append({
					"asset_id": String(asset_id),
					"stable_id": placement_id,
					"origin": _v3(placement_transform.origin),
					"yaw": placement_transform.basis.get_euler().y,
				})
		if asset_id == program.foundation_asset_id:
			foundation_count += batch.transforms.size()
			for placement_index in batch.transforms.size():
				var transform: Transform3D = batch.transforms[placement_index]
				foundations.append({
					"stable_id": String(batch.ids[placement_index]),
					"origin": _v3(transform.origin),
					"yaw": transform.basis.get_euler().y,
				})
			continue
		var spec := program.spec_for_asset(asset_id)
		if spec == null:
			var prop_spec := program.prop_spec_for_asset(asset_id)
			if prop_spec != null:
				for placement_index in batch.transforms.size():
					var transform: Transform3D = batch.transforms[placement_index]
					props.append({
						"asset_id": String(asset_id),
						"stable_id": String(batch.ids[placement_index]),
						"origin": _v3(transform.origin),
						"yaw": transform.basis.get_euler().y,
					})
			continue
		for placement_index in batch.transforms.size():
			var transform: Transform3D = batch.transforms[placement_index]
			buildings.append({
				"asset_id": String(asset_id),
				"stable_id": String(batch.ids[placement_index]),
				"origin": _v3(transform.origin),
				"yaw": transform.basis.get_euler().y,
			})
	buildings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.stable_id) < String(b.stable_id))
	props.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.stable_id) < String(b.stable_id))
	foundations.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a.origin[1]), float(b.origin[1])):
			return float(a.origin[1]) < float(b.origin[1])
		return String(a.stable_id) < String(b.stable_id))
	urban_placements.sort_custom(func(a: Dictionary,
			b: Dictionary) -> bool:
		return String(a.stable_id) < String(b.stable_id))
	var centre_y := TerrainSurfaceField.surface_y(frame.region,
		frame.centre.x, frame.centre.y)
	var sectional := record.urban_fabric.generation_kind in [
		VillageUrbanFabricPlan.GenerationKind.SECTIONAL_WARREN,
		VillageUrbanFabricPlan.GenerationKind.VOLUMETRIC_WARREN]
	var views := _sectional_views(frame, record, centre_y) if sectional \
		else _views(frame, record, program, buildings, props, foundations,
			centre_y)
	var block_local := Vector2(fposmod(frame.centre.x,
		TerrainChunkMesher.CHUNK_WORLD), fposmod(frame.centre.y,
		TerrainChunkMesher.CHUNK_WORLD))
	if sectional:
		return _sectional_entry(super_cell, frame, record, index, world_seed,
			assets, foundation_count, buildings, props, foundations,
			urban_placements, views, block_local, centre_y)
	return {
		"review_index": index,
		"seed": world_seed,
		"settlement_id": String(record.stable_id),
		"super_cell": [super_cell.x, super_cell.y],
		"cell": [frame.cell.x, frame.cell.y],
		"centre": [frame.centre.x, centre_y, frame.centre.y],
		"tier": String(record.tier),
		"theme": String(record.theme),
		"incident_directions": frame.incident_directions.map(
			func(value: Vector2i) -> Array: return [value.x, value.y]),
		"block_local": [block_local.x, block_local.y],
		"payload_instances": record.payload.instance_count,
		"foundation_instances": foundation_count,
		"street_axis": [record.street_axis.x, record.street_axis.y],
		"prop_results": _string_dictionary(record.prop_results),
		"accepted_prop_count": record.prop_results.values().count(&"accepted"),
		"urban_status": String(record.urban_fabric.reason),
		"urban_building_count": record.urban_fabric.buildings.size(),
		"urban_building_design_count": _urban_design_count(
			record.urban_fabric.buildings),
		"urban_natural_building_count": \
			record.urban_fabric.natural_building_count,
		"urban_retained_building_count": \
			record.urban_fabric.retained_building_count,
		"urban_elevation_band_count": \
			record.urban_fabric.massing.elevation_band_count,
		"urban_half_rise_count": record.urban_fabric.massing.half_rise_count,
		"urban_ground_street_count": \
			record.urban_fabric.circulation.ground_street_count,
		"urban_aerial_link_count": \
			record.urban_fabric.circulation.aerial_link_count,
		"urban_platform_count": \
			record.urban_fabric.circulation.platforms.size(),
		"urban_public_stair_count": record.urban_fabric.public_stair_count,
		"urban_support_count": record.urban_fabric.timber.support_count,
		"urban_support_piece_count": \
			record.urban_fabric.timber.support_piece_count,
		"urban_railing_count": record.urban_fabric.timber.railing_count,
		"urban_timber_cell_count": record.urban_fabric.timber.cells.size(),
		"urban_rock_piece_count": record.urban_fabric.rock_piece_count,
		"urban_buildings": _urban_buildings_json(
			record.urban_fabric.buildings),
		"urban_links": _urban_links_json(
			record.urban_fabric.circulation.links),
		"urban_platforms": _urban_platforms_json(
			record.urban_fabric.circulation.platforms),
		"urban_stair_runs": _urban_stair_runs_json(
			record.urban_fabric.route_stairs.runs),
		"outskirts_shelter_count": record.outskirts.placements.size(),
		"outskirts_route_stair_count": record.outskirts.route_stair_count,
		"outskirts_shelters": _outskirts_shelters_json(record.outskirts,
			program, record.stable_id),
		"outskirts_audit": record.outskirts.audit,
		"assets": assets,
		"buildings": buildings,
		"props": props,
		"foundations": foundations,
		"urban_placements": urban_placements,
		"views": views,
	}


static func _sectional_entry(super_cell: Vector2i, frame: VillageFrame,
		record: VillageRecord, index: int, world_seed: int,
		assets: Array[String], foundation_count: int,
		buildings: Array[Dictionary], props: Array[Dictionary],
		foundations: Array[Dictionary], urban_placements: Array[Dictionary],
		views: Array[Dictionary], block_local: Vector2, centre_y: float
		) -> Dictionary:
	var audit := record.urban_fabric.fabric_audit
	var support_count := int((record.payload.batches.get(
		SettlementFabricAssembler.TIMBER_SUPPORT, {}) as Dictionary).get(
			"transforms", []).size())
	var railing_count := int((record.payload.batches.get(
		SettlementFabricAssembler.PLANK_RAILING, {}) as Dictionary).get(
			"transforms", []).size())
	return {
		"review_index": index,
		"seed": world_seed,
		"settlement_id": String(record.stable_id),
		"super_cell": [super_cell.x, super_cell.y],
		"cell": [frame.cell.x, frame.cell.y],
		"centre": [frame.centre.x, centre_y, frame.centre.y],
		"tier": String(record.tier),
		"theme": String(record.theme),
		"generation_kind": "volumetric_warren" if record.urban_fabric.generation_kind \
			== VillageUrbanFabricPlan.GenerationKind.VOLUMETRIC_WARREN \
			else "sectional_warren",
		"maze_route_signature": String(audit.get("maze_route_signature", "")),
		"maze_canonical_route_signature": String(
			audit.get("maze_canonical_route_signature", "")),
		"construction_signature": String(audit.get(
			"construction_signature", "")),
		# Keep the falsification evidence beside every capture target. A reviewer
		# can distinguish a visually suspicious seam from a generator that already
		# violated its sealed graph, support, or placement contract.
		"sectional_structural_audit": {
			"infill_lightwell_count": int(audit.get(
				"infill_lightwell_count", -1)),
			"uncovered_core_column_count": int(audit.get(
				"uncovered_core_column_count", -1)),
			"max_uncovered_core_component_size": int(audit.get(
				"max_uncovered_core_component_size", -1)),
			"stair_endpoint_gap_count": int(audit.get(
				"stair_endpoint_gap_count", -1)),
			"stair_endpoint_missing_landing_count": int(
				audit.get("stair_endpoint_missing_landing_count", -1)),
			"stair_to_stair_edge_count": int(audit.get(
				"stair_to_stair_edge_count", -1)),
			"platform_dead_end_count": int(audit.get(
				"platform_dead_end_count", -1)),
			"isolated_platform_count": int(audit.get(
				"isolated_platform_count", -1)),
			"unsupported_platform_count": int(audit.get(
				"unsupported_platform_count", -1)),
			"unsupported_stair_count": int(audit.get(
				"unsupported_stair_count", -1)),
			"unserved_entrance_count": int(audit.get(
				"unserved_entrance_count", -1)),
			"detached_building_stack_count": int(
				audit.get("detached_building_stack_count", -1)),
			"visual_envelope_overlap_count": int(
				audit.get("visual_envelope_overlap_count", -1)),
			"frontage_ratio": float(audit.get("frontage_ratio", 0.0)),
			"overhead_route_ratio": float(audit.get(
				"overhead_route_ratio", 0.0)),
			"max_uncovered_route_component_size": int(audit.get(
				"max_uncovered_route_component_size", -1)),
			"max_uncovered_route_component_cells": audit.get(
				"max_uncovered_route_component_cells", []),
			"through_sightline_count": int(audit.get(
				"through_sightline_count", -1)),
			"visual_quality_target_met": bool(audit.get(
				"visual_quality_target_met", false)),
		},
		# TASK F1. The legacy `volumetric_town` lineage died with the searched
		# pipeline and nothing production builds carries one, so these two
		# diagnostics have no source left to read.
		"sectional_daylight_voids": [],
		"sectional_infill_diagnostic": {},
		"incident_directions": frame.incident_directions.map(
			func(value: Vector2i) -> Array: return [value.x, value.y]),
		"block_local": [block_local.x, block_local.y],
		"payload_instances": record.payload.instance_count,
		"foundation_instances": foundation_count,
		"street_axis": [record.street_axis.x, record.street_axis.y],
		"prop_results": _string_dictionary(record.prop_results),
		"accepted_prop_count": 0,
		"urban_status": String(record.urban_fabric.reason),
		"urban_building_count": int(audit.get("building_stack_count", 0)),
		"urban_building_design_count": int(audit.get(
			"recipe_family_count", audit.get("prefab_asset_count", 0))),
		"urban_natural_building_count": 0,
		"urban_retained_building_count": 0,
		"urban_elevation_band_count": int(audit.get("vertical_span_cells",
			audit.get("elevation_band_count", 0))),
		"urban_half_rise_count": int(audit.get(
			"half_level_neighbor_pair_count", 0)),
		"urban_ground_street_count": int(audit.get(
			"terrain_street_cell_count", 0)),
		"urban_aerial_link_count": int(audit.get("skywalk_link_count", 0)),
		"urban_platform_count": int(audit.get("audited_platform_count", 0)),
		"urban_public_stair_count": int(audit.get("stair_count", 0)),
		"urban_support_count": support_count,
		"urban_support_piece_count": support_count,
		"urban_railing_count": railing_count,
		"urban_timber_cell_count": int(audit.get(
			"structural_court_cell_count", 0)),
		"urban_rock_piece_count": 0,
		"urban_buildings": record.urban_fabric.buildings,
		"urban_links": [],
		"urban_platforms": [],
		"urban_stair_runs": [],
		"outskirts_shelter_count": 0,
		"outskirts_route_stair_count": 0,
		"outskirts_shelters": [],
		"outskirts_audit": {},
		"assets": assets,
		"buildings": buildings,
		"props": props,
		"foundations": foundations,
		"urban_placements": urban_placements,
		"views": views,
	}

static func _string_dictionary(source: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var keys: Array = source.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool:
		return String(a) < String(b))
	for key: Variant in keys:
		out[String(key)] = String(source[key])
	return out


static func _urban_buildings_json(
		source: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for building: Dictionary in source:
		var transform := building.transform as Transform3D
		var entrance := building.entrance as Vector2
		var outward := building.entrance_outward as Vector2
		out.append({
			"key": String(building.key),
			"stable_id": String(building.stable_id),
			"asset_id": String(building.asset_id),
			"origin": _v3(transform.origin),
			"yaw": transform.basis.get_euler().y,
			"floor_y": float(building.floor_y),
			"natural": bool(building.natural),
			"entrance": [entrance.x, entrance.y],
			"outward": [outward.x, outward.y],
		})
	return out


static func _urban_design_count(source: Array[Dictionary]) -> int:
	var designs: Dictionary = {}
	for building: Dictionary in source:
		designs[StringName(building.asset_id)] = true
	return designs.size()


static func _urban_links_json(
		source: Array[VillageCirculationLink]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for link: VillageCirculationLink in source:
		out.append({
			"key": String(link.stable_key),
			"kind": link.kind,
			"from": String(link.from_key),
			"to": String(link.to_key),
			"length": link.length,
			"stair_count": link.stair_count,
			"control_points": link.control_points.map(
				func(point: Vector3) -> Array[float]: return _v3(point)),
		})
	return out


static func _urban_platforms_json(
		source: Array[VillagePlatformRegion]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for platform: VillagePlatformRegion in source:
		var centre := _platform_centre(platform)
		out.append({
			"key": String(platform.stable_key),
			"centre": [centre.x, platform.surface_y, centre.y],
			"yaw": platform.yaw,
			"cells": platform.cell_centres.map(
				func(cell: Vector2) -> Array[float]: return [cell.x, cell.y]),
			"frontages": Array(platform.frontage_keys).map(
				func(key: StringName) -> String: return String(key)),
		})
	return out


static func _platform_centre(platform: VillagePlatformRegion) -> Vector2:
	var centre := Vector2.ZERO
	for cell: Vector2 in platform.cell_centres:
		centre += cell
	return centre / float(platform.cell_centres.size())


static func _urban_stair_runs_json(
		source: Array[VillageRouteStairRun]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for run: VillageRouteStairRun in source:
		out.append({
			"key": String(run.stable_key),
			"link": String(run.link_key),
			"start_distance": run.start_distance,
			"end_distance": run.end_distance,
			"from_y": run.from_y,
			"to_y": run.to_y,
			"stair_count": run.stair_count,
		})
	return out


static func _outskirts_shelters_json(plan: VillageOutskirtsPlan,
		program: VillageProgram,
		settlement_id: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for placement: VillageMassingPlacement in plan.placements:
		var spec := program.assets[placement.asset_id] as VillageAssetSpec
		var transform := placement.building_transform(spec)
		out.append({"key": String(placement.stable_key),
			"stable_id": "%s.%s" % [settlement_id, placement.stable_key],
			"asset_id": String(placement.asset_id),
			"origin": _v3(transform.origin),
			"floor_y": placement.floor_y,
			"entrance": [placement.entrance.x, placement.entrance.y]})
	return out


static func _street_segments_json(source: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for segment: Dictionary in source:
		var start: Vector2 = segment.start
		var end: Vector2 = segment.end
		out.append({"key": String(segment.key),
			"start": [start.x, start.y], "end": [end.x, end.y]})
	return out


static func _elevated_buildings_json(
		source: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for building: Dictionary in source:
		var centre: Vector2 = building.centre
		var extents: Vector2 = building.half_extents
		var door: Vector2 = building.door
		var outward: Vector2 = building.outward
		var plinth_centre: Vector2 = building.plinth_centre
		var plinth_extents: Vector2 = building.plinth_half_extents
		out.append({"key": String(building.key),
			"centre": [centre.x, centre.y],
			"half_extents": [extents.x, extents.y],
			"building_asset_id": String(building.building_asset_id),
			"door": [door.x, door.y],
			"outward": [outward.x, outward.y],
			"plinth_centre": [plinth_centre.x, plinth_centre.y],
			"plinth_half_extents": [plinth_extents.x, plinth_extents.y],
			"plinth_angle": float(building.plinth_angle),
			"rock_piece_count": int(building.rock_piece_count),
			"floor_y": float(building.floor_y),
			"level": int(building.level),
			"support_count": int(building.support_count),
			"tile_count": int(building.tile_count)})
	return out


static func _elevated_walkways_json(
		source: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for segment: Dictionary in source:
		var start: Vector2 = segment.start
		var end: Vector2 = segment.end
		out.append({"key": String(segment.key),
			"start": [start.x, start.y], "end": [end.x, end.y],
			"level": int(segment.level), "y": float(segment.y)})
	return out


static func _elevated_transitions_json(
		source: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for transition: Dictionary in source:
		var item := {"key": String(transition.key),
			"kind": String(transition.kind),
			"low_level": int(transition.get("low_level", 0)),
			"high_level": int(transition.get("high_level", 0)),
			"low_y": float(transition.low_y),
			"high_y": float(transition.high_y),
			"residual_step": float(transition.residual_step)}
		if transition.has("bottom"):
			var bottom: Vector2 = transition.bottom
			var top: Vector2 = transition.top
			item["bottom"] = [bottom.x, bottom.y]
			item["top"] = [top.x, top.y]
			item["stair_base_y"] = float(transition.stair_base_y)
		out.append(item)
	return out


static func _elevated_undercroft_json(source: Dictionary) -> Dictionary:
	if source.is_empty():
		return {}
	var centre: Vector2 = source.centre
	var normal: Vector2 = source.normal
	var tangent: Vector2 = source.tangent
	var extents: Vector2 = source.half_extents
	return {"centre": [centre.x, centre.y],
		"normal": [normal.x, normal.y], "tangent": [tangent.x, tangent.y],
		"half_extents": [extents.x, extents.y],
		"ground_y": float(source.ground_y),
		"ceiling_y": float(source.ceiling_y),
		"seam_key": String(source.seam_key)}


static func _sectional_views(frame: VillageFrame, record: VillageRecord,
		ground_y: float) -> Array[Dictionary]:
	## The production warren has no parallel legacy links/platform objects.  Its
	## sealed fabric is reviewed from the record bounds and actual transformed
	## payload, keeping camera authorship downstream of the generated geometry.
	var out: Array[Dictionary] = []
	var bounds := record.bounds
	var xz_centre := bounds.get_center()
	var minimum_y := ground_y
	var maximum_y := ground_y
	for asset_id: StringName in record.payload.asset_ids():
		for transform: Transform3D in record.payload.batches[asset_id].transforms:
			minimum_y = minf(minimum_y, transform.origin.y)
			maximum_y = maxf(maximum_y, transform.origin.y)
	var vertical_centre := (minimum_y + maximum_y) * 0.5
	var centre := Vector3(xz_centre.x, vertical_centre, xz_centre.y)
	var span := maxf(bounds.size.x, bounds.size.y)
	var orbit := maxf(42.0, span * 0.92)
	var eye_y := maximum_y + maxf(18.0, span * 0.38)
	for record_value: Dictionary in [
		{"name": "warren_skyline_ne", "direction": Vector2(1.0, 1.0)},
		{"name": "warren_skyline_sw", "direction": Vector2(-1.0, -1.0)},
		{"name": "warren_skyline_nw", "direction": Vector2(-1.0, 1.0)},
		{"name": "warren_skyline_se", "direction": Vector2(1.0, -1.0)},
	]:
		var direction := (record_value.direction as Vector2).normalized()
		_add_view(out, String(record_value.name),
			Vector3(xz_centre.x + direction.x * orbit, eye_y,
				xz_centre.y + direction.y * orbit),
			centre, 54.0, span * 0.7)
	var main := _main_approach(frame)
	var cross := Vector2(-main.y, main.x)
	# TASK F1: the legacy volumetric route lineage is gone; see above.
	var route_points: Array[Vector3] = []
	if route_points.size() >= 2:
		var entry := route_points[0]
		var entry_next := route_points[mini(2, route_points.size() - 1)]
		var entry_direction := Vector2(entry_next.x - entry.x,
			entry_next.z - entry.z).normalized()
		var entry_camera_xz := Vector2(entry.x, entry.z) \
			- entry_direction * 7.5
		_add_view(out, "warren_ground_entry",
			_terrain_eye(frame, entry_camera_xz, 2.2),
			entry_next + Vector3.UP * 1.8, 62.0, 9.0)
		# The reverse proof stands on the generated exterior route itself. A
		# bounds-derived orbit could land behind a facade and photograph only an
		# outside wall, which says nothing about connected circulation.
		var reverse_index := route_points.size() - 1
		var reverse := route_points[reverse_index]
		var reverse_target := route_points[maxi(0, reverse_index - 2)]
		_add_view(out, "warren_ground_reverse",
			reverse + Vector3.UP * 2.2,
			reverse_target + Vector3.UP * 1.8, 68.0, 6.0)
		var middle_index := route_points.size() / 2
		var middle := route_points[middle_index]
		var middle_target := route_points[mini(route_points.size() - 1,
			middle_index + 2)]
		_add_view(out, "warren_route_mid",
			middle + Vector3.UP * 2.2,
			middle_target + Vector3.UP * 1.8, 68.0, 6.0)
		var highest_index := _highest_route_point_index(route_points)
		var high_target_index := maxi(0, highest_index - 2) \
			if highest_index >= route_points.size() - 1 \
			else mini(route_points.size() - 1, highest_index + 2)
		_add_view(out, "warren_route_high",
			route_points[highest_index] + Vector3.UP * 2.2,
			route_points[high_target_index] + Vector3.UP * 1.8,
			68.0, 6.0)
	else:
		for record_value: Dictionary in [
			{"name": "warren_ground_entry", "direction": main},
			{"name": "warren_ground_reverse", "direction": -main},
		]:
			var direction := record_value.direction as Vector2
			var camera_xz := xz_centre + direction * maxf(24.0, span * 0.56)
			_add_view(out, String(record_value.name),
				_terrain_eye(frame, camera_xz, 2.2),
				Vector3(xz_centre.x, ground_y + 4.0, xz_centre.y),
				62.0, span * 0.5)
	# Hostile cross-axis views remain bounds-derived deliberately: they try to
	# expose a straight tunnel through the mass instead of following the route.
	for record_value: Dictionary in [
		{"name": "warren_ground_cross_a", "direction": cross},
		{"name": "warren_ground_cross_b", "direction": -cross},
	]:
		var direction := record_value.direction as Vector2
		var camera_xz := xz_centre + direction * maxf(24.0, span * 0.56)
		_add_view(out, String(record_value.name),
			_terrain_eye(frame, camera_xz, 2.2),
			Vector3(xz_centre.x, ground_y + 4.0, xz_centre.y),
			62.0, span * 0.5)
	# High oblique views make disconnected stair/platform seams and unroofed
	# outcroppings conspicuous; an issue-seeking reviewer should treat finding
	# either as a successful review result.
	_add_view(out, "warren_network_above",
		Vector3(xz_centre.x + cross.x * span * 0.35,
			maximum_y + span * 0.65,
			xz_centre.y + cross.y * span * 0.35),
		centre, 58.0, span)
	return out

static func _highest_route_point_index(points: Array[Vector3]) -> int:
	var result := 0
	for index in range(1, points.size()):
		if points[index].y > points[result].y:
			result = index
	return result


static func _views(frame: VillageFrame, record: VillageRecord,
		program: VillageProgram, buildings: Array[Dictionary],
		props: Array[Dictionary],
		foundations: Array[Dictionary],
		ground_y: float) -> Array[Dictionary]:
	var centre := Vector3(frame.centre.x, ground_y, frame.centre.y)
	var main := _main_approach(frame)
	var out: Array[Dictionary] = []
	_add_view(out, "skyline", centre + Vector3(100.0, 82.0, 112.0),
		centre + Vector3.UP * 5.0, 52.0, 42.0)
	_add_view(out, "skyline_reverse", centre + Vector3(-104.0, 76.0, -96.0),
		centre + Vector3.UP * 5.0, 52.0, 42.0)
	_add_view(out, "plaza_eye", _terrain_eye(frame,
		frame.centre + main * 24.0, 2.2),
		centre + Vector3.UP * 2.0, 58.0)
	_add_view(out, "main_approach", _terrain_eye(frame,
		frame.centre + main * 70.0, 2.2),
		centre + Vector3.UP * 2.4, 58.0)
	var street := _longest_ground_link(record.urban_fabric.circulation.links)
	if street != null:
		var start := Vector2(street.samples[0].x, street.samples[0].z)
		var last: Vector3 = street.samples[-1]
		var end := Vector2(last.x, last.z)
		var tangent := (end - start).normalized()
		var inbound_xz := start - tangent * 8.0
		var outbound_xz := end + tangent * 8.0
		_add_view(out, "street_inbound", _terrain_eye(frame, inbound_xz, 2.2),
			_terrain_eye(frame, end, 2.4), 64.0, 3.0)
		_add_view(out, "street_outbound", _terrain_eye(frame, outbound_xz, 2.2),
			_terrain_eye(frame, start, 2.4), 64.0, 3.0)
	else:
		var side := Vector2(-main.y, main.x)
		var first := _safe_orbit_position(frame, side, main, 46.0, 2.2,
			buildings, program)
		var reverse := _safe_orbit_position(frame, -side, main, 46.0, 2.2,
			buildings, program)
		_add_view(out, "open_ring_lane_inbound", first,
			centre + Vector3.UP * 2.2, 64.0)
		_add_view(out, "open_ring_lane_reverse", reverse,
			centre + Vector3.UP * 2.2, 64.0)
	if not buildings.is_empty():
		_append_door_views(out, buildings, program)
		var structural_volumes: Array[VillageOccupancyVolume] = []
		if record.urban_fabric != null and record.urban_fabric.accepted:
			structural_volumes = record.urban_fabric.volumes
		_append_foundation_view(out, frame, centre, buildings, foundations,
			program, structural_volumes)
	else:
		_add_view(out, "empty_record_probe",
			_terrain_eye(frame, frame.centre - main * 20.0, 2.0),
			centre + Vector3.UP * 2.0, 58.0)
	_append_prop_views(out, frame, props, program)
	_append_urban_views(out, frame, record, buildings, program)
	_append_outskirts_views(out, frame, record, buildings, program)
	return out


static func _append_outskirts_views(out: Array[Dictionary],
		frame: VillageFrame, record: VillageRecord,
		buildings: Array[Dictionary], program: VillageProgram) -> void:
	if record.outskirts == null or not record.outskirts.accepted:
		return
	for placement: VillageMassingPlacement in record.outskirts.placements:
		var target := Vector3(placement.entrance.x,
			placement.floor_y + 2.4, placement.entrance.y)
		var side := Vector2(-placement.entrance_outward.y,
			placement.entrance_outward.x)
		var preferred := target + _xz(
			placement.entrance_outward * 18.0 + side * 3.0, 3.2)
		var stable_id := StringName("%s.%s" % [record.stable_id,
			placement.stable_key])
		_add_view(out, "outskirts_%s" % _safe_recipe_id(
			String(placement.stable_key)),
			_safe_elevated_camera(frame, preferred, target, buildings,
				program, stable_id), target, 58.0, 8.0)


static func _append_urban_views(out: Array[Dictionary], frame: VillageFrame,
		record: VillageRecord, buildings: Array[Dictionary],
		program: VillageProgram) -> void:
	var fabric := record.urban_fabric
	if fabric == null or not fabric.accepted:
		return
	var top_y := -INF
	for building: Dictionary in fabric.buildings:
		top_y = maxf(top_y, float(building.floor_y))
	var core := fabric.massing.core.anchor
	var centre := Vector3(core.x, top_y, core.y)
	var axis := record.street_axis
	var cross := Vector2(-axis.y, axis.x)
	_add_view(out, "urban_web_above",
		centre + Vector3(cross.x * 24.0, 32.0, cross.y * 24.0),
		centre - Vector3.UP * 3.0, 58.0, 38.0)
	var ground_link := _longest_ground_link(fabric.circulation.links)
	if ground_link != null:
		var low_start: Vector3 = ground_link.samples[0]
		var low_end: Vector3 = ground_link.samples[-1]
		var low_direction := Vector2(low_end.x - low_start.x,
			low_end.z - low_start.z).normalized()
		_add_view(out, "urban_lower_street",
			low_start + _xz(-low_direction * 5.0, 2.1),
			low_end + Vector3.UP * 1.8, 66.0, 16.0)
	for building: Dictionary in fabric.buildings:
		var door := building.entrance as Vector2
		var outward := building.entrance_outward as Vector2
		var side := Vector2(-outward.y, outward.x)
		var floor_y := float(building.floor_y)
		var target := Vector3(door.x, floor_y - 0.8, door.y) \
			- _xz(outward * 2.0, 0.0)
		var preferred := Vector3(door.x, floor_y + 5.5, door.y) \
			+ _xz(outward * 24.0 + side * 3.0, 0.0)
		var subject_id := StringName(building.stable_id)
		var placement := _placement_for_key(fabric.massing.placements,
			StringName(building.key))
		var subject_radius := 12.0 if placement == null else maxf(12.0,
			placement.solid_half_extents.length() + 4.0)
		_add_view(out, "urban_building_%s_overhang" \
			% _safe_recipe_id(String(building.key)),
			_safe_elevated_camera(frame, preferred, target, buildings, program,
				subject_id, fabric.volumes),
			target, 58.0, subject_radius)
	for link: VillageCirculationLink in fabric.circulation.links:
		if not link.is_aerial():
			continue
		var middle_index := link.samples.size() / 2
		var point: Vector3 = link.samples[middle_index]
		var prior: Vector3 = link.samples[maxi(0, middle_index - 1)]
		var next: Vector3 = link.samples[mini(link.samples.size() - 1,
			middle_index + 1)]
		var direction := Vector2(next.x - prior.x, next.z - prior.z).normalized()
		var side := Vector2(-direction.y, direction.x)
		var aerial_target := point + Vector3.UP * 0.5
		for side_index in 2:
			var view_side := side if side_index == 0 else -side
			var aerial_preferred := aerial_target \
				+ _xz(view_side * 14.0, 8.0)
			_add_view(out, "urban_aerial_%s_side_%s" \
				% [_safe_recipe_id(String(link.stable_key)),
					"a" if side_index == 0 else "b"],
				_safe_elevated_camera(frame, aerial_preferred, aerial_target,
					buildings, program, &"", fabric.volumes),
				aerial_target, 55.0, 2.0)
	for platform: VillagePlatformRegion in fabric.circulation.platforms:
		var platform_side := Vector2.RIGHT.rotated(platform.yaw)
		var platform_centre := _platform_centre(platform)
		var platform_target := Vector3(platform_centre.x,
			platform.surface_y + 0.5, platform_centre.y)
		for side_index in 2:
			var view_side := platform_side if side_index == 0 \
				else -platform_side
			var platform_preferred := platform_target \
				+ _xz(view_side * 12.0, 8.0)
			_add_view(out, "urban_platform_%s_side_%s" \
				% [_safe_recipe_id(String(platform.stable_key)),
					"a" if side_index == 0 else "b"],
				_safe_elevated_camera(frame, platform_preferred,
					platform_target, buildings, program, &"", fabric.volumes),
				platform_target, 55.0, 2.0)
	for run: VillageRouteStairRun in fabric.route_stairs.runs:
		var link := _link_for_key(fabric.circulation.links, run.link_key)
		if link == null:
			continue
		var start := _point_on_link(link, run.start_distance)
		var end := _point_on_link(link, run.end_distance)
		var stair_direction := Vector2(end.x - start.x, end.z - start.z)
		if stair_direction.length_squared() <= 0.001:
			continue
		stair_direction = stair_direction.normalized()
		var stair_side := Vector2(-stair_direction.y, stair_direction.x)
		var stair_target := start.lerp(end, 0.5)
		stair_target.y = (run.from_y + run.to_y) * 0.5 + 0.4
		for side_index in 2:
			var view_side := stair_side if side_index == 0 else -stair_side
			var along := -stair_direction if side_index == 0 \
				else stair_direction
			var stair_preferred := stair_target \
				+ _xz(view_side * 10.0 + along * 4.0, 7.0)
			_add_view(out, "urban_stair_%s_side_%s" \
				% [_safe_recipe_id(String(run.stable_key)),
					"a" if side_index == 0 else "b"],
				_safe_elevated_camera(frame, stair_preferred, stair_target,
					buildings, program, &"", fabric.volumes),
				stair_target, 55.0, 2.0)


static func _placement_for_key(source: Array[VillageMassingPlacement],
		key: StringName) -> VillageMassingPlacement:
	for placement: VillageMassingPlacement in source:
		if placement.stable_key == key:
			return placement
	return null


static func _link_for_key(source: Array[VillageCirculationLink],
		key: StringName) -> VillageCirculationLink:
	for link: VillageCirculationLink in source:
		if link.stable_key == key:
			return link
	return null


static func _point_on_link(link: VillageCirculationLink,
		distance: float) -> Vector3:
	var travelled := 0.0
	for index in range(1, link.samples.size()):
		var a: Vector3 = link.samples[index - 1]
		var b: Vector3 = link.samples[index]
		var span := Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
		if travelled + span >= distance - 0.001:
			var t := 0.0 if span <= 0.001 \
				else clampf((distance - travelled) / span, 0.0, 1.0)
			return a.lerp(b, t)
		travelled += span
	return link.samples[-1]


static func _longest_ground_link(
		links: Array[VillageCirculationLink]) -> VillageCirculationLink:
	var selected: VillageCirculationLink
	for link: VillageCirculationLink in links:
		if link.kind != VillageCirculationLink.Kind.GROUND_STREET \
				and link.kind != VillageCirculationLink.Kind.GROUND_STAIR:
			continue
		if selected == null or link.length > selected.length + 0.001 \
				or (is_equal_approx(link.length, selected.length) \
				and String(link.stable_key) < String(selected.stable_key)):
			selected = link
	return selected


static func _longest_street(segments: Array[Dictionary]) -> Dictionary:
	var selected: Dictionary = segments[0]
	for candidate: Dictionary in segments:
		var candidate_length: float = (candidate.end as Vector2).distance_to(
			candidate.start as Vector2)
		var selected_length: float = (selected.end as Vector2).distance_to(
			selected.start as Vector2)
		if candidate_length > selected_length + 0.001 \
				or (is_equal_approx(candidate_length, selected_length) \
				and String(candidate.key) < String(selected.key)):
			selected = candidate
	return selected


static func _append_prop_views(out: Array[Dictionary], frame: VillageFrame,
		props: Array[Dictionary], program: VillageProgram) -> void:
	var seen_assets: Dictionary = {}
	for prop: Dictionary in props:
		var asset_id := StringName(prop.asset_id)
		if seen_assets.has(asset_id):
			continue
		seen_assets[asset_id] = true
		var spec := program.prop_spec_for_asset(asset_id)
		if spec == null:
			continue
		var transform := Transform3D(Basis(Vector3.UP, float(prop.yaw)),
			_array_v3(prop.origin))
		var facing_3d := transform.basis * Vector3(spec.facing_local.x,
			0.0, spec.facing_local.y)
		var facing := Vector2(facing_3d.x, facing_3d.z).normalized()
		var centre := transform * spec.measured_aabb.get_center()
		var camera_xz := Vector2(centre.x, centre.z) + facing \
			* maxf(4.0, spec.local_reach() + 2.0)
		_add_view(out, "prop_%s" % _safe_recipe_id(String(asset_id)),
			_terrain_eye(frame, camera_xz, 1.8), centre, 58.0,
			spec.local_reach() + 0.5)


static func _append_door_views(out: Array[Dictionary],
		buildings: Array[Dictionary], program: VillageProgram) -> void:
	var seen_specs: Dictionary = {}
	var representative_index := 0
	for building: Dictionary in buildings:
		var spec := program.spec_for_asset(StringName(building.asset_id))
		if spec == null or seen_specs.has(spec.asset_id):
			continue
		seen_specs[spec.asset_id] = true
		var transform := Transform3D(Basis(Vector3.UP, float(building.yaw)),
			_array_v3(building.origin))
		var entrance := spec.world_entrance(transform)
		var outward := spec.world_entrance_outward(transform)
		var floor_y := spec.world_entrance_floor_y(transform)
		var eye := floor_y + 1.65
		var prefix := "door" if representative_index == 0 \
			else "door_%s" % _safe_recipe_id(String(spec.asset_id))
		_add_view(out, "%s_outside" % prefix,
			Vector3(entrance.x, eye, entrance.y) + _xz(outward * 4.0, 0.0),
			Vector3(entrance.x, eye, entrance.y) - _xz(outward * 2.5, 0.0),
			64.0)
		if spec.has_enclosed_interior():
			_add_view(out, "%s_inside" % prefix,
				Vector3(entrance.x, eye, entrance.y) - _xz(outward * 1.25, 0.0),
				Vector3(entrance.x, eye, entrance.y) - _xz(outward * 5.0, 0.0),
				70.0)
		representative_index += 1


static func _append_foundation_view(out: Array[Dictionary], frame: VillageFrame,
		centre: Vector3, buildings: Array[Dictionary],
		foundations: Array[Dictionary], program: VillageProgram,
		structural_volumes: Array[VillageOccupancyVolume] = []) -> void:
	if not foundations.is_empty():
		var selected: Dictionary = foundations[0]
		for candidate: Dictionary in foundations:
			if float(candidate.origin[1]) > float(selected.origin[1]) + 0.001:
				break
			var candidate_point := Vector2(float(candidate.origin[0]),
				float(candidate.origin[2]))
			var selected_point := Vector2(float(selected.origin[0]),
				float(selected.origin[2]))
			if candidate_point.distance_squared_to(Vector2(centre.x, centre.z)) \
					> selected_point.distance_squared_to(Vector2(centre.x, centre.z)):
				selected = candidate
		var subject_id := _foundation_owner_id(selected, buildings)
		# Aim at the exposed vertical centre of the complete owning stack. The
		# former lowest-module target made every camera look sharply downward at
		# grass, cropping away the very foundation this recipe must verify.
		var target := _foundation_stack_target(selected, foundations,
			subject_id, program.foundation_module_height)
		var outward := Vector2(target.x - centre.x, target.z - centre.z).normalized()
		if outward.is_zero_approx():
			outward = Vector2.RIGHT
		var camera_xz := Vector2(target.x, target.z) + outward * 18.0
		var preferred := _terrain_eye(frame, camera_xz, 6.2)
		var camera := _safe_elevated_camera(frame, preferred, target,
			buildings, program, subject_id, structural_volumes)
		_add_view(out, "lowest_foundation_edge",
			camera, target, 58.0,
			maxf(program.foundation_module_width,
				program.foundation_module_depth) + 0.5)
		return
	var fallback_building: Dictionary = buildings[0]
	var spec := program.spec_for_asset(StringName(fallback_building.asset_id))
	var transform := Transform3D(Basis(Vector3.UP,
		float(fallback_building.yaw)), _array_v3(fallback_building.origin))
	var outward := spec.world_entrance_outward(transform)
	var floor_y := transform.origin.y + spec.measured_aabb.position.y
	var solid: Dictionary = spec.world_solid(transform)
	var axis_x := Vector2.RIGHT.rotated(float(solid.angle))
	var axis_z := Vector2.DOWN.rotated(float(solid.angle))
	var candidates: Array[Vector2] = [-outward, outward, axis_x, -axis_x,
		axis_z, -axis_z]
	var best_position := Vector3.ZERO
	var best_target := Vector3.ZERO
	var best_score := INF
	for direction: Vector2 in candidates:
		var boundary_distance := absf(direction.dot(axis_x)) \
			* float((solid.half_extents as Vector2).x) \
			+ absf(direction.dot(axis_z)) \
			* float((solid.half_extents as Vector2).y)
		var edge: Vector2 = solid.centre + direction * boundary_distance
		var target := Vector3(edge.x, floor_y + 0.8, edge.y)
		var position := _terrain_eye(frame, edge + direction * 14.0, 2.2)
		var score := _terrain_sightline_penalty(frame, position, target) \
			+ _building_sightline_penalty(position, target, buildings,
				fallback_building, program)
		if score < best_score:
			best_score = score
			best_position = position
			best_target = target
	_add_view(out, "foundation_absence_rear",
		best_position, best_target, 58.0,
		spec.local_reach() + 0.5)


static func _foundation_stack_target(selected: Dictionary,
		foundations: Array[Dictionary], owner_id: StringName,
		module_height: float) -> Vector3:
	var selected_origin := _array_v3(selected.origin)
	if owner_id.is_empty():
		return selected_origin + Vector3.UP * module_height * 0.5
	var prefix := "%s." % String(owner_id)
	var minimum_y := selected_origin.y
	var maximum_y := selected_origin.y
	for foundation: Dictionary in foundations:
		if not String(foundation.stable_id).begins_with(prefix):
			continue
		var y := float(foundation.origin[1])
		minimum_y = minf(minimum_y, y)
		maximum_y = maxf(maximum_y, y)
	selected_origin.y = (minimum_y + maximum_y + module_height) * 0.5
	return selected_origin


static func _terrain_sightline_penalty(frame: VillageFrame,
		position: Vector3, target: Vector3) -> float:
	# Authoring a camera above its own ground is not sufficient: the line to
	# the subject can still pass through a ridge or cliff lip. Prefer a view
	# whose complete segment clears the immutable terrain field, and retain a
	# deterministic least-obstructed fallback for pathological sites.
	var minimum_clearance := INF
	for index in 17:
		var t := float(index) / 16.0
		var point := position.lerp(target, t)
		var ground_y := TerrainSurfaceField.surface_y(frame.region,
			point.x, point.z)
		minimum_clearance = minf(minimum_clearance, point.y - ground_y)
	var obstruction := maxf(0.0, 0.35 - minimum_clearance)
	return obstruction * 1000.0 + absf(position.y - target.y)


static func _building_sightline_penalty(position: Vector3, target: Vector3,
		buildings: Array[Dictionary], subject: Dictionary,
		program: VillageProgram) -> float:
	var camera_xz := Vector2(position.x, position.z)
	if not _outside_buildings(camera_xz, buildings, program, 1.0):
		return 100000.0
	var sightline := FeatureGroundShape.capsule(camera_xz,
		Vector2(target.x, target.z), 0.25)
	for building: Dictionary in buildings:
		if String(building.stable_id) == String(subject.stable_id):
			continue
		var spec := program.spec_for_asset(StringName(building.asset_id))
		if spec == null:
			continue
		var transform := Transform3D(Basis(Vector3.UP, float(building.yaw)),
			_array_v3(building.origin))
		var solid: Dictionary = spec.world_solid(transform)
		var footprint := FeatureGroundShape.oriented_rect(solid.centre,
			solid.half_extents, solid.angle)
		if sightline.intersects(footprint, 0.5):
			return 10000.0
	return 0.0


## High review views orbit their semantic target at authoring time. The first
## valid candidate is deterministic and preserves the preferred composition;
## unlike the runtime fallback, this search may move far enough to avoid an
## entire unrelated building. Projected tests are intentionally conservative:
## a camera above a roof is still a poor roof/transition review angle.
static func _safe_elevated_camera(frame: VillageFrame,
		preferred: Vector3, target: Vector3,
		buildings: Array[Dictionary], program: VillageProgram,
		allowed_subject_id: StringName = &"",
		structural_volumes: Array[VillageOccupancyVolume] = []) -> Vector3:
	var delta := Vector2(preferred.x - target.x, preferred.z - target.z)
	var distance := maxf(delta.length(), 8.0)
	var preferred_direction := delta.normalized() \
		if not delta.is_zero_approx() else Vector2.RIGHT
	var directions: Array[Vector2] = []
	for angle: float in [0.0, PI * 0.25, -PI * 0.25,
			PI * 0.5, -PI * 0.5, PI * 0.75, -PI * 0.75, PI]:
		directions.append(preferred_direction.rotated(angle))
	var local_fallback := Vector3(INF, INF, INF)
	for lift: float in [0.0, 6.0, 12.0, 20.0, 32.0, 48.0]:
		for extra_distance: float in [0.0, 12.0, 24.0, 42.0]:
			for direction: Vector2 in directions:
				var candidate := Vector3(target.x, preferred.y + lift,
					target.z) + _xz(direction \
						* (distance + extra_distance), 0.0)
				if not local_fallback.is_finite() \
						and _elevated_camera_position_clear(frame, candidate,
							buildings, program, structural_volumes):
					local_fallback = candidate
				if _elevated_sightline_clear(frame, candidate, target,
						buildings, program, allowed_subject_id,
						structural_volumes):
					return candidate
	# A partially occluded local closeup is more falsifiable than a technically
	# clear skyline shot from outside the village. The capture runtime may still
	# apply its bounded three-metre adjustment around this authored position.
	return local_fallback if local_fallback.is_finite() else preferred


static func _elevated_camera_position_clear(frame: VillageFrame,
		position: Vector3, buildings: Array[Dictionary],
		program: VillageProgram,
		structural_volumes: Array[VillageOccupancyVolume] = []) -> bool:
	return _outside_buildings(Vector2(position.x, position.z),
		buildings, program, 2.0) and position.y >= \
		TerrainSurfaceField.surface_y(frame.region,
			position.x, position.z) + 0.5 \
		and not _inside_solid_volume(position, structural_volumes, 0.75)


static func _elevated_sightline_clear(frame: VillageFrame,
		position: Vector3, target: Vector3,
		buildings: Array[Dictionary], program: VillageProgram,
		allowed_subject_id: StringName = &"",
		structural_volumes: Array[VillageOccupancyVolume] = []) -> bool:
	if not _elevated_camera_position_clear(frame, position,
			buildings, program, structural_volumes):
		return false
	# Inspect the actual 3D sightline. Dense villages legitimately put roofs
	# beneath a high review camera; a projected capsule falsely classifies those
	# clear views as blocked and used to send the fallback camera into distant
	# terrain. The target itself may lie on a walk surface, so stop just short.
	# Circulation subjects have no opaque volume to excuse near the target, so
	# inspect almost the complete corridor. Building-overhang views deliberately
	# terminate inside their named subject and retain the shorter sample range.
	const SAMPLE_DENOMINATOR := 64
	var sample_count := 48 if not allowed_subject_id.is_empty() else 60
	for index in sample_count:
		var sample_t := float(index) / float(SAMPLE_DENOMINATOR)
		var point := position.lerp(target, sample_t)
		if point.y < TerrainSurfaceField.surface_y(frame.region,
				point.x, point.z) + 0.05:
			return false
		if _inside_solid_volume(point, structural_volumes, 0.35,
				allowed_subject_id, not allowed_subject_id.is_empty()):
			return false
		for building: Dictionary in buildings:
			if not allowed_subject_id.is_empty() \
					and StringName(building.stable_id) == allowed_subject_id:
				continue
			var spec := program.spec_for_asset(StringName(building.asset_id))
			if spec == null:
				continue
			var transform := Transform3D(
				Basis(Vector3.UP, float(building.yaw)),
				_array_v3(building.origin))
			var solid: Dictionary = spec.world_solid(transform)
			var solid_min_y := transform.origin.y \
				+ spec.measured_aabb.position.y
			var solid_max_y := transform.origin.y + spec.measured_aabb.end.y
			if point.y >= solid_min_y - 0.5 \
					and point.y <= solid_max_y + 0.5 \
					and FeatureGroundShape.oriented_rect(solid.centre,
						solid.half_extents + Vector2.ONE * 0.75,
						solid.angle).contains(Vector2(point.x, point.z)):
				return false
	return true


static func _inside_solid_volume(point: Vector3,
		volumes: Array[VillageOccupancyVolume], margin: float,
		allowed_owner_id: StringName = &"",
		allow_subject_contact: bool = false) -> bool:
	for volume: VillageOccupancyVolume in volumes:
		if volume.role != VillageOccupancy.Role.SOLID:
			continue
		if allow_subject_contact and not allowed_owner_id.is_empty() \
				and volume.owner_id == allowed_owner_id:
			continue
		if point.y < volume.y_range.x - margin \
				or point.y > volume.y_range.y + margin:
			continue
		var local := (Vector2(point.x, point.z) - volume.centre).rotated(
			-volume.angle)
		if absf(local.x) <= volume.half_extents.x + margin \
				and absf(local.y) <= volume.half_extents.y + margin:
			return true
	return false
static func _foundation_owner_id(foundation: Dictionary,
		buildings: Array[Dictionary]) -> StringName:
	var foundation_id := String(foundation.stable_id)
	for building: Dictionary in buildings:
		var building_id := String(building.stable_id)
		if foundation_id.begins_with("%s." % building_id):
			return StringName(building_id)
	return &""


static func _safe_recipe_id(value: String) -> String:
	return value.replace(".", "_").replace(":", "_").replace("/", "_")


static func _safe_orbit_position(frame: VillageFrame, preferred: Vector2,
		secondary: Vector2, minimum_distance: float, eye_height: float,
		buildings: Array[Dictionary], program: VillageProgram) -> Vector3:
	# A review camera inside opaque structure geometry cannot falsify the
	# village. Try a stable orbit sequence, then widen it; all choices remain
	# deterministic manifest data rather than runtime special cases.
	var directions: Array[Vector2] = [preferred, -preferred,
		(preferred + secondary).normalized(),
		(preferred - secondary).normalized(),
		(-preferred + secondary).normalized(),
		(-preferred - secondary).normalized()]
	for distance: float in [minimum_distance, minimum_distance + 18.0,
			minimum_distance + 36.0]:
		for direction: Vector2 in directions:
			var candidate_xz := frame.centre + direction * distance
			if _outside_buildings(candidate_xz, buildings,
					program, 2.0):
				return _terrain_eye(frame, candidate_xz, eye_height)
	# The compiled record contract puts every anchor inside 144 m, so this
	# final wide view is outside every current structural footprint.
	return _terrain_eye(frame, frame.centre + preferred * 180.0, eye_height)


static func _terrain_eye(frame: VillageFrame, point: Vector2,
		eye_height: float) -> Vector3:
	return Vector3(point.x,
		TerrainSurfaceField.surface_y(frame.region, point.x, point.y) + eye_height,
		point.y)


static func _outside_buildings(point: Vector2,
		buildings: Array[Dictionary], program: VillageProgram,
		margin: float) -> bool:
	for building: Dictionary in buildings:
		var spec := program.spec_for_asset(StringName(building.asset_id))
		if spec == null:
			continue
		var transform := Transform3D(Basis(Vector3.UP, float(building.yaw)),
			_array_v3(building.origin))
		var solid := spec.world_solid(transform)
		var local: Vector2 = (point - (solid.centre as Vector2)).rotated(
			-float(solid.angle))
		var half_extents: Vector2 = solid.half_extents
		if absf(local.x) <= half_extents.x + margin \
				and absf(local.y) <= half_extents.y + margin:
			return false
	return true


static func _main_approach(frame: VillageFrame) -> Vector2:
	var axis := Vector2(frame.dominant_axis)
	for direction: Vector2i in frame.incident_directions:
		if absf(Vector2(direction).dot(axis)) > 0.5:
			return Vector2(direction)
	return Vector2(frame.incident_directions[0])


static func _add_view(out: Array[Dictionary], name: String,
		position: Vector3, target: Vector3, fov: float,
		subject_radius: float = 0.0) -> void:
	assert(is_finite(subject_radius) and subject_radius >= 0.0)
	out.append({"recipe": name, "position": _v3(position),
		"target": _v3(target), "fov": fov,
		"subject_radius": subject_radius})


static func _coverage(selected: Array[Dictionary], counts: Dictionary,
		searched_radius: int) -> Dictionary:
	var assets: Dictionary = {}
	var foundation_villages := 0
	var natural_support_buildings := 0
	var retained_support_buildings := 0
	var urban_accepted := 0
	var urban_rejected := 0
	var maximum_urban_designs := 0
	var urban_view_complete := true
	var sectional_warrens := 0
	var sectional_route_signatures: Dictionary = {}
	var sectional_canonical_route_signatures: Dictionary = {}
	var sectional_construction_signatures: Dictionary = {}
	var outskirts_shelters := 0
	var outskirts_view_complete := true
	for entry: Dictionary in selected:
		for asset_id: String in entry.assets:
			assets[asset_id] = true
		if int(entry.foundation_instances) > 0:
			foundation_villages += 1
		natural_support_buildings += int(entry.urban_natural_building_count)
		retained_support_buildings += int(entry.urban_retained_building_count)
		if StringName(entry.urban_status) == &"accepted":
			urban_accepted += 1
			maximum_urban_designs = maxi(maximum_urban_designs,
				int(entry.urban_building_design_count))
			var recipes: Dictionary = {}
			for view: Dictionary in entry.views:
				recipes[String(view.recipe)] = true
			var is_warren := String(entry.get("generation_kind", "")) in [
				"sectional_warren", "volumetric_warren"]
			if is_warren:
				sectional_warrens += 1
				sectional_route_signatures[String(
					entry.maze_route_signature)] = true
				sectional_canonical_route_signatures[String(
					entry.maze_canonical_route_signature)] = true
				sectional_construction_signatures[String(
					entry.construction_signature)] = true
				urban_view_complete = urban_view_complete \
					and recipes.has("warren_network_above") \
					and recipes.has("warren_ground_entry") \
					and recipes.has("warren_ground_reverse") \
					and recipes.has("warren_skyline_ne") \
					and recipes.has("warren_skyline_sw")
			else:
				urban_view_complete = urban_view_complete \
					and recipes.has("urban_web_above") \
					and recipes.has("urban_lower_street")
			var overhang_views := 0
			var aerial_views := 0
			var platform_views := 0
			var stair_views := 0
			for recipe: String in recipes:
				if recipe.begins_with("urban_building_") \
						and recipe.ends_with("_overhang"):
					overhang_views += 1
				if recipe.begins_with("urban_aerial_"):
					aerial_views += 1
				if recipe.begins_with("urban_platform_"):
					platform_views += 1
				if recipe.begins_with("urban_stair_"):
					stair_views += 1
			if not is_warren:
				urban_view_complete = urban_view_complete \
					and overhang_views == int(entry.urban_building_count) \
					and aerial_views == int(entry.urban_aerial_link_count) * 2 \
					and platform_views == int(entry.urban_platform_count) * 2 \
					and (int(entry.urban_public_stair_count) == 0 \
						or stair_views >= 2)
		else:
			urban_rejected += 1
		outskirts_shelters += int(entry.outskirts_shelter_count)
		var outskirts_views := 0
		for view: Dictionary in entry.views:
			if String(view.recipe).begins_with("outskirts_"):
				outskirts_views += 1
		outskirts_view_complete = outskirts_view_complete \
			and outskirts_views == int(entry.outskirts_shelter_count)
	var unmet: Array[String] = []
	if not _quota_complete(counts):
		unmet.append("%d-village production tier/theme quota" \
			% (TIERS.size() * THEMES.size() * PER_TIER_THEME))
	if sectional_warrens == 0 and (natural_support_buildings == 0 \
			or retained_support_buildings == 0):
		unmet.append("both natural-perimeter and retained-rock support modes")
	if urban_rejected > 0:
		unmet.append("every production village has accepted dense urban fabric")
	if urban_accepted == 0 or not urban_view_complete:
		unmet.append("issue-seeking sectional skyline, ground-maze, and network views")
	if maximum_urban_designs < 4:
		unmet.append("expanded furnished-house designs in the production corpus")
	if sectional_warrens > 0 and (sectional_route_signatures.size() \
			!= sectional_warrens \
			or sectional_canonical_route_signatures.size() != sectional_warrens \
			or sectional_construction_signatures.size() != sectional_warrens):
		unmet.append("every captured warren has distinct maze and construction geometry")
	if sectional_warrens == 0 and (outskirts_shelters == 0 \
			or not outskirts_view_complete):
		unmet.append("sparse connected outskirts shelters and their review views")
	var asset_ids: Array = assets.keys()
	asset_ids.sort()
	return {
		"tier_theme_complete": _quota_complete(counts),
		"full_spec_complete": unmet.is_empty(),
		"counts": counts,
		"searched_radius": searched_radius,
		"assets": asset_ids,
		"foundation_villages": foundation_villages,
		"natural_support_buildings": natural_support_buildings,
		"retained_support_buildings": retained_support_buildings,
		"urban_accepted": urban_accepted,
		"urban_rejected": urban_rejected,
		"maximum_urban_building_designs": maximum_urban_designs,
		"urban_view_complete": urban_view_complete,
		"sectional_warrens": sectional_warrens,
		"unique_sectional_route_count": sectional_route_signatures.size(),
		"unique_sectional_canonical_route_count":
			sectional_canonical_route_signatures.size(),
		"unique_sectional_construction_count":
			sectional_construction_signatures.size(),
		"outskirts_shelters": outskirts_shelters,
		"outskirts_view_complete": outskirts_view_complete,
		"unmet": unmet,
	}


static func _xz(value: Vector2, y: float) -> Vector3:
	return Vector3(value.x, y, value.y)


static func _v3(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


static func _array_v3(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))
