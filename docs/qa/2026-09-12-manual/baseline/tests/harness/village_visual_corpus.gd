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
var _include_instances := false


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
				if _has_pinned_super_cell:
					print("[village_visual_corpus] pinned rejection volume=%s fabric=%s" \
						% [WarrenVolumetricSolver.last_failure,
							WarrenSpatialFabricCompiler.last_failure])
				continue
			var bucket := "%s/%s" % [record.tier, record.theme]
			if int(counts.get(bucket, 0)) >= PER_TIER_THEME:
				continue
			var entry := _entry(super_cell, frame, record,
				program.villages, selected.size(), _seed)
			if _include_instances:
				entry["instances"] = _payload_instances_json(record.payload,
					frame.region)
				entry["surface_meshes"] = _payload_surfaces_json(record.payload)
				var fabric := record.urban_fabric.fabric_plan
				if fabric != null:
					entry["solid_cells"] = _cell_set_json(
						fabric.transformed_cells(&"solid"))
					entry["terrain_bearing_cells"] = _cell_set_json(
						fabric.transformed_cells(&"terrain_bearing"))
					entry["retained_cells"] = _cell_set_json(
						fabric.retained_terrace_cells)
					entry["planned_plaza_cells"] = _cell_set_json(
						fabric.planned_plaza_cells)
					entry["public_surface_cells"] = _surface_cells_json(
						fabric.surface_plan)
					entry["public_entrances"] = _entrances_json(
						fabric.surface_plan)
					entry["public_guards"] = _guards_json(fabric.surface_plan)
					var ground_skin := SettlementFabricAssembler \
						.maze_ground_skin_transaction(fabric)
					entry["ground_skin_cap_owners"] = _cell_set_json(
						ground_skin.cap_owners as Dictionary)
					entry["ground_skin_cap_faces"] = _horizontal_faces_json(
						(ground_skin.shell as Dictionary).faces as Dictionary)
					var spatial := record.urban_fabric.volumetric_spatial
					if spatial != null and spatial.source_volume != null:
						entry["source_primary_itinerary"] = []
						for route_cell: Vector3i in \
								spatial.source_volume.primary_itinerary:
							(entry.source_primary_itinerary as Array).append([
								route_cell.x, route_cell.y, route_cell.z])
			selected.append(entry)
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
			"--include-instances":
				_include_instances = true
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


static func _payload_instances_json(payload: EnvironmentInstancePayload,
		region: HeightfieldRegion = null) \
		-> Array[Dictionary]:
	## Opt-in visual-falsification evidence. Stable IDs and origins let a close-up
	## be traced back to the procedural claim that produced it without inflating
	## the normal multi-village corpus manifest.
	var out: Array[Dictionary] = []
	for asset_id: StringName in payload.asset_ids():
		var batch := payload.batches[asset_id] as Dictionary
		var ids := batch.get("ids", []) as Array
		for index in batch.transforms.size():
			var transform := batch.transforms[index] as Transform3D
			var entry := {
				"asset_id": String(asset_id),
				"stable_id": String(ids[index]) if not ids.is_empty() else "",
				"origin": _v3(transform.origin),
				"yaw": transform.basis.get_euler().y,
			}
			if region != null:
				entry["terrain_y_at_origin"] = TerrainSurfaceField.surface_y(region,
					transform.origin.x, transform.origin.z)
			out.append(entry)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.stable_id) < String(b.stable_id))
	return out


static func _payload_surfaces_json(payload: EnvironmentInstancePayload) \
		-> Array[Dictionary]:
	## Meshes have no instance transform after the village adapter; publish their
	## exact finished bounds so a surface hidden by a retained cap can be
	## distinguished from a surface generated at the wrong elevation.
	var out: Array[Dictionary] = []
	for mesh: Dictionary in payload.surface_meshes:
		var vertices := mesh.vertices as PackedVector3Array
		if vertices.is_empty():
			continue
		var bounds := AABB(vertices[0], Vector3.ZERO)
		for index in range(1, vertices.size()):
			bounds = bounds.expand(vertices[index])
		var logical: Array[Array] = []
		var logical_sources := mesh.get("logical_cells", []) as Array
		var heights: Array[Dictionary] = []
		var color_summary: Dictionary = {}
		var vertices_per_cell := vertices.size() / logical_sources.size() \
			if not logical_sources.is_empty() else 0
		for logical_index in logical_sources.size():
			var cell_value: Variant = logical_sources[logical_index]
			var cell := cell_value as Vector3i
			logical.append([cell.x, cell.y, cell.z])
			if vertices_per_cell > 0:
				var minimum_y := INF
				var maximum_y := -INF
				for vertex_index in range(logical_index * vertices_per_cell,
						(logical_index + 1) * vertices_per_cell):
					minimum_y = minf(minimum_y, vertices[vertex_index].y)
					maximum_y = maxf(maximum_y, vertices[vertex_index].y)
				heights.append({"cell": [cell.x, cell.y, cell.z],
					"minimum_y": minimum_y, "maximum_y": maximum_y})
		if mesh.has("colors"):
			var colors := mesh.colors as PackedColorArray
			if not colors.is_empty():
				var minimum := Color(INF, INF, INF, INF)
				var maximum := Color(-INF, -INF, -INF, -INF)
				for color: Color in colors:
					minimum.r = minf(minimum.r, color.r)
					minimum.g = minf(minimum.g, color.g)
					minimum.b = minf(minimum.b, color.b)
					minimum.a = minf(minimum.a, color.a)
					maximum.r = maxf(maximum.r, color.r)
					maximum.g = maxf(maximum.g, color.g)
					maximum.b = maxf(maximum.b, color.b)
					maximum.a = maxf(maximum.a, color.a)
				color_summary = {
					"first": [colors[0].r, colors[0].g, colors[0].b,
						colors[0].a],
					"minimum": [minimum.r, minimum.g, minimum.b, minimum.a],
					"maximum": [maximum.r, maximum.g, maximum.b, maximum.a],
				}
		out.append({
			"stable_id": String(mesh.get("stable_id", "")),
			"terrain_ground": bool(mesh.get("terrain_ground", false)),
			"visual_only": bool(mesh.get("visual_only", false)),
			"bounds": _aabb_json(bounds),
			"logical_cells": logical,
			"logical_cell_heights": heights,
			"color_summary": color_summary,
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.stable_id) < String(b.stable_id))
	return out


static func _cell_set_json(cells: Dictionary) -> Array[Array]:
	var ordered: Array[Vector3i] = []
	ordered.assign(cells.keys())
	ordered.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		return a.y < b.y if a.y != b.y else a.z < b.z \
			if a.z != b.z else a.x < b.x)
	var out: Array[Array] = []
	for cell: Vector3i in ordered:
		out.append([cell.x, cell.y, cell.z])
	return out


static func _horizontal_faces_json(faces: Dictionary) -> Array[Array]:
	var ordered: Array[Vector4i] = []
	for key_value: Variant in faces.keys():
		var key := key_value as Vector4i
		if key.w >= SettlementFabricAssembler.FACE_DIRECTIONS.size():
			ordered.append(key)
	ordered.sort_custom(func(a: Vector4i, b: Vector4i) -> bool:
		return a.y < b.y if a.y != b.y else a.z < b.z \
			if a.z != b.z else a.x < b.x if a.x != b.x else a.w < b.w)
	var out: Array[Array] = []
	for key: Vector4i in ordered:
		out.append([key.x, key.y, key.z, key.w])
	return out


static func _surface_cells_json(surface: PublicRealmSurfacePlan) -> Dictionary:
	var out: Dictionary = {}
	if surface == null:
		return out
	for kind_value: Variant in PublicRealmSurfacePlan.SurfaceKind.values():
		var kind := int(kind_value)
		var cells: Dictionary = {}
		for cell: Vector3i in surface.cells_for_kind(kind):
			cells[cell] = true
		out[str(kind)] = _cell_set_json(cells)
	return out


static func _entrances_json(surface: PublicRealmSurfacePlan) \
		-> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if surface == null:
		return out
	for entrance: Dictionary in surface.entrance_records:
		var threshold := entrance.threshold_cell as Vector3i
		var landing := entrance.landing_cell as Vector3i
		var facing := entrance.facing as Vector3i
		var openings: Array[Array] = []
		for cell_value: Variant in entrance.get("guard_opening_cells", []) as Array:
			var cell := cell_value as Vector3i
			openings.append([cell.x, cell.y, cell.z])
		out.append({"stable_id": String(entrance.stable_id),
			"threshold": [threshold.x, threshold.y, threshold.z],
			"landing": [landing.x, landing.y, landing.z],
			"facing": [facing.x, facing.y, facing.z],
			"served": bool(entrance.served), "guard_openings": openings})
	return out


static func _guards_json(surface: PublicRealmSurfacePlan) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if surface == null:
		return out
	for segment: Dictionary in surface.guard_segments:
		out.append({"stable_key": String(segment.stable_key),
			"a": _v3(segment.a as Vector3), "b": _v3(segment.b as Vector3)})
	return out


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
	var views := _sectional_views(frame, record, program, buildings,
		centre_y) if sectional \
		else _views(frame, record, program, buildings, props, foundations,
			centre_y)
	var block_local := Vector2(fposmod(frame.centre.x,
		TerrainChunkMesher.CHUNK_WORLD), fposmod(frame.centre.y,
		TerrainChunkMesher.CHUNK_WORLD))
	if sectional:
		return _sectional_entry(super_cell, frame, record, index, world_seed,
			program, assets, foundation_count, buildings, props, foundations,
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
		program: VillageProgram, assets: Array[String], foundation_count: int,
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
	var outskirts_count := record.outskirts.placements.size() \
		if record.outskirts != null else 0
	var outskirts_route_stair_count := record.outskirts.route_stair_count \
		if record.outskirts != null else 0
	var outskirts_houses := _outskirts_shelters_json(record.outskirts,
		program, record.stable_id) if record.outskirts != null else []
	var outskirts_audit := record.outskirts.audit \
		if record.outskirts != null else []
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
		# Visual review needs the same sealed construction evidence as the tests.
		# Keep these counts beside each image target so a distant or occluded feature
		# cannot satisfy the town's richness contract invisibly.
		"sectional_feature_audit": {
			"lattice_world_transform": _transform_json(
				record.urban_fabric.world_transform),
			"scale_profile_id": String(audit.get("scale_profile_id", "")),
			"enclosed_skywalk_count": int(audit.get(
				"enclosed_skywalk_count", 0)),
			"maze_skywalk_span_count": int(audit.get(
				"maze_skywalk_span_count", 0)),
			"maze_enclosed_skywalk_span_count": int(audit.get(
				"maze_enclosed_skywalk_span_count", 0)),
			"maze_skywalk_candidate_count": int(audit.get(
				"maze_skywalk_candidate_count", 0)),
			"maze_facade_bay_count": int(audit.get(
				"maze_facade_bay_count", 0)),
			"maze_facade_bump_out_count": int(audit.get(
				"maze_facade_bump_out_count", 0)),
			"maze_facade_outcrop_bracket_count": int(audit.get(
				"maze_facade_outcrop_bracket_count", 0)),
			"facade_bay_count": int(audit.get("facade_bay_count", 0)),
			"dormered_roof_unit_count": int(audit.get(
				"dormered_roof_unit_count", 0)),
			"continuous_roof_component_count": int(
				record.urban_fabric.fabric_plan.audit.get(
					"continuous_roof_component_count", 0)),
			"continuous_roof_eligible_run_count": int(
				record.urban_fabric.fabric_plan.audit.get(
					"continuous_roof_eligible_run_count", 0)),
			"continuous_roof_joined_run_count": int(
				record.urban_fabric.fabric_plan.audit.get(
					"continuous_roof_joined_run_count", 0)),
			"continuous_roof_internal_gable_count": int(
				record.urban_fabric.fabric_plan.audit.get(
					"continuous_roof_internal_gable_count", 0)),
			"continuous_roof_normalized_repeat_count": int(
				record.urban_fabric.fabric_plan.audit.get(
					"continuous_roof_normalized_repeat_count", 0)),
			"roof_neighborhood_join_count": int(audit.get(
				"roof_neighborhood_join_count", 0)),
			"continuous_ridge_join_count": int(audit.get(
				"continuous_ridge_join_count", 0)),
			"maze_retained_rock_cells": int(audit.get(
				"maze_retained_rock_cells", 0)),
			"maze_retained_rock_stone_roof_cells": int(audit.get(
				"maze_retained_rock_stone_roof_cells", 0)),
			"maze_retained_unroomed_plot_stone_cells": int(audit.get(
				"maze_retained_unroomed_plot_stone_cells", 0)),
			"maze_released_singleton_roof_band_cells": int(audit.get(
				"maze_released_singleton_roof_band_cells", 0)),
			"maze_released_required_roof_envelope_cells": int(record.urban_fabric \
				.volumetric_spatial.audit.get(
				"maze_released_required_roof_envelope_cells", 0)),
			"maze_released_required_roof_derived_cells": int(record.urban_fabric \
				.volumetric_spatial.audit.get(
				"maze_released_required_roof_derived_cells", 0)),
			"maze_released_required_roof_unroomed_plot_cells": int(record \
				.urban_fabric.volumetric_spatial.audit.get(
				"maze_released_required_roof_unroomed_plot_cells", 0)),
			"maze_released_required_roof_band_cells": int(record.urban_fabric \
				.volumetric_spatial.audit.get(
				"maze_released_required_roof_band_cells", 0)),
			"maze_stone_withdrawn_for_roof_cells": int(record.urban_fabric \
				.fabric_plan.audit.get(
				"maze_stone_withdrawn_for_roof_cells", 0)),
			"maze_stone_withdrawn_for_roof_cell_keys": record.urban_fabric \
				.fabric_plan.audit.get(
				"maze_stone_withdrawn_for_roof_cell_keys", []),
			"maze_unsupported_stone_cells_removed": int(record.urban_fabric \
				.fabric_plan.audit.get(
				"maze_unsupported_stone_cells_removed", 0)),
			"maze_unsupported_stone_components_removed": int(record.urban_fabric \
				.fabric_plan.audit.get(
				"maze_unsupported_stone_components_removed", 0)),
			"maze_unsupported_stone_cell_keys": record.urban_fabric \
				.fabric_plan.audit.get(
				"maze_unsupported_stone_cell_keys", []),
			"spatial_feature_kinds": _spatial_feature_kind_counts(
				record.urban_fabric.volumetric_spatial),
			"room_projection_features": _room_projection_feature_audit(
				record.urban_fabric.volumetric_spatial),
			"roof_alignment": _roof_alignment_audit(
				record.urban_fabric.fabric_plan),
			"connected_roof_conflicts": record.urban_fabric.fabric_plan \
				.connected_visual_envelope_conflicts(),
			"roof_units": _roof_unit_geometry_audit(
				record.urban_fabric.fabric_plan),
			"retained_top_courses": _retained_top_course_audit(
				record.urban_fabric.fabric_plan,
				record.urban_fabric.volumetric_spatial),
			"continuous_roof_runs": _continuous_roof_run_audit(
				record.urban_fabric.fabric_plan),
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
		# These schema keys retain their historical names so old capture indexes
		# remain readable; every current entry is a reviewed complete house.
		"outskirts_shelter_count": outskirts_count,
		"outskirts_route_stair_count": outskirts_route_stair_count,
		"outskirts_shelters": outskirts_houses,
		"outskirts_audit": outskirts_audit,
		"assets": assets,
		"buildings": buildings,
		"props": props,
		"foundations": foundations,
		"urban_placements": urban_placements,
		"views": views,
	}


static func _roof_alignment_audit(plan: SettlementFabricPlan) -> Dictionary:
	## Compare each complete pitched crown's measured visual centre and bearing
	## plane with the lattice footprint it claims. This is review evidence, not a
	## visual heuristic: a roof that is horizontally displaced or vertically
	## floating cannot hide behind a valid socket bond.
	var out := {"audited_count": 0, "misaligned_count": 0,
		"max_horizontal_offset": 0.0, "max_bearing_offset": 0.0,
		"details": [] as Array[Dictionary]}
	if plan == null:
		return out
	for unit: FabricUnit in plan.units:
		var recipe := plan.recipe(unit.recipe_id)
		if recipe == null:
			continue
		# Compact runs include occupied bridge-house crowns. Audit the exact roof
		# subassembly rather than the recipe's merged room+roof box, so an internal
		# crown cannot pass merely because the complete building remains centred.
		if not recipe.compact_roof_runs.is_empty():
			var placement_index_by_id: Dictionary = {}
			for index in recipe.placements.size():
				placement_index_by_id[StringName(recipe.placements[index].id)] = index
			for run: Dictionary in recipe.compact_roof_runs:
				var roof_bounds := AABB()
				var has_roof_bounds := false
				for bay: Dictionary in run.bays as Array:
					for placement_value: Variant in bay.placement_ids as Array:
						var placement_id := StringName(placement_value)
						var placement_index := int(placement_index_by_id.get(
							placement_id, -1))
						if placement_index < 0:
							continue
						var bounds := recipe.placement_bounds[placement_index]
						roof_bounds = bounds if not has_roof_bounds \
							else roof_bounds.merge(bounds)
						has_roof_bounds = true
				if not has_roof_bounds:
					continue
				var start := run.local_start as Vector3
				var end := run.local_end as Vector3
				var axis_x := absf(end.x - start.x) > absf(end.z - start.z)
				var expected_local := (start + end) * 0.5
				if axis_x:
					expected_local.z = (float(run.cross_min) \
						+ float(run.cross_max)) * 0.5
				else:
					expected_local.x = (float(run.cross_min) \
						+ float(run.cross_max)) * 0.5
				var expected := unit.transform() * expected_local
				var visual := unit.transform() * roof_bounds
				_record_roof_alignment(out, unit, expected,
					visual, StringName(run.id))
			continue
		if not recipe.has_tag(&"roof") or not recipe.has_tag(&"pitched_roof") \
				or recipe.solid_cells.is_empty():
			continue
		var local_min := Vector3(INF, INF, INF)
		var local_max := Vector3(-INF, -INF, -INF)
		for cell: Vector3i in recipe.solid_cells:
			var centre := Vector3(cell) * FabricRecipe.CELL_SIZE
			local_min = local_min.min(centre - Vector3.ONE \
				* FabricRecipe.CELL_SIZE * 0.5)
			local_max = local_max.max(centre + Vector3.ONE \
				* FabricRecipe.CELL_SIZE * 0.5)
		var logical := unit.transform() * AABB(local_min, local_max - local_min)
		var visual := unit.transform() * recipe.local_bounds
		# Roof solids name the band whose centre is the wall-top bearing plane;
		# subtracting half a cell here would report every correctly seated crown as
		# floating by exactly 0.75 m.
		var bearing_y := unit.transform().origin.y + float(local_min.y \
			+ FabricRecipe.CELL_SIZE * 0.5)
		_record_roof_alignment(out, unit, Vector3(logical.get_center().x,
			bearing_y, logical.get_center().z), visual)
	return out


static func _record_roof_alignment(out: Dictionary, unit: FabricUnit,
		expected: Vector3, visual: AABB, run_id: StringName = &"") -> void:
	var horizontal_offset := Vector2(visual.get_center().x,
		visual.get_center().z).distance_to(Vector2(expected.x, expected.z))
	var bearing_offset := absf(visual.position.y - expected.y)
	out.audited_count = int(out.audited_count) + 1
	out.max_horizontal_offset = maxf(float(out.max_horizontal_offset),
		horizontal_offset)
	out.max_bearing_offset = maxf(float(out.max_bearing_offset),
		bearing_offset)
	if horizontal_offset <= 0.01 and bearing_offset <= 0.01:
		return
	out.misaligned_count = int(out.misaligned_count) + 1
	if (out.details as Array).size() < 24:
		(out.details as Array).append({"unit_id": String(unit.stable_id),
			"recipe_id": String(unit.recipe_id), "run_id": String(run_id),
			"horizontal_offset": horizontal_offset,
			"bearing_offset": bearing_offset})


static func _roof_unit_geometry_audit(plan: SettlementFabricPlan) -> Array[Dictionary]:
	## Compact machine-readable roof census for fixed-seed visual review. It
	## records the sealed construction contracts, not a screenshot inference, so
	## an apparent seam can be traced back to the exact recipe and placement.
	var out: Array[Dictionary] = []
	if plan == null:
		return out
	for unit: FabricUnit in plan.units:
		var recipe_value := plan.recipe(unit.recipe_id)
		if recipe_value == null or not recipe_value.has_tag(&"roof") \
				and not recipe_value.has_tag(&"integrated_pitched_roof"):
			continue
		var roof_placements: Array[Dictionary] = []
		for index in recipe_value.placements.size():
			var placement := recipe_value.placements[index] as Dictionary
			if not String(placement.id).begins_with("roof") \
					and not String(placement.id).begins_with("gable") \
					and not String(placement.asset_id).contains(".roof.") \
					and StringName(placement.asset_id) != SettlementFabricProgram.GABLE:
				continue
			var pose := unit.transform() * (placement.transform as Transform3D)
			var bounds := unit.transform() * recipe_value.placement_bounds[index]
			roof_placements.append({
				"placement_id": String(placement.id),
				"asset_id": String(placement.asset_id),
				"origin": [pose.origin.x, pose.origin.y, pose.origin.z],
				"bounds_position": [bounds.position.x, bounds.position.y,
					bounds.position.z],
				"bounds_size": [bounds.size.x, bounds.size.y, bounds.size.z],
			})
		out.append({
			"unit_id": String(unit.stable_id),
			"recipe_id": String(unit.recipe_id),
			"parent_ids": Array(unit.parent_ids).map(
				func(value: StringName) -> String: return String(value)),
			"lattice_origin": [unit.lattice_origin.x, unit.lattice_origin.y,
				unit.lattice_origin.z],
			"yaw_quarters": unit.yaw_quarters,
			"unit_bounds": _aabb_json(unit.bounds),
			"parent_bounds": _roof_parent_bounds_json(plan, unit),
			"parent_placements": _roof_parent_placements_json(plan, unit),
			"construction_run_count": recipe_value.construction_runs.size(),
			"placements": roof_placements,
		})
	return out


static func _roof_parent_bounds_json(plan: SettlementFabricPlan,
		unit: FabricUnit) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for parent_id: StringName in unit.parent_ids:
		var parent := plan.unit(parent_id)
		if parent == null:
			continue
		out.append({"unit_id": String(parent.stable_id),
			"recipe_id": String(parent.recipe_id),
			"bounds": _aabb_json(parent.bounds)})
	return out


static func _roof_parent_placements_json(plan: SettlementFabricPlan,
		unit: FabricUnit) -> Array[Dictionary]:
	## Keep visual review tied to the construction below the roof. A roof can be
	## centred on its logical plate while an authored floor/eave placement in its
	## parent protrudes beyond that plate; publishing the exact per-placement
	## bounds makes that category distinguishable from a displaced crown.
	var out: Array[Dictionary] = []
	for parent_id: StringName in unit.parent_ids:
		var parent := plan.unit(parent_id)
		if parent == null:
			continue
		var parent_recipe := plan.recipe(parent.recipe_id)
		if parent_recipe == null:
			continue
		for index in parent_recipe.placements.size():
			var placement := parent_recipe.placements[index] as Dictionary
			if parent.suppressed_placement_ids.has(StringName(placement.id)):
				continue
			var pose := parent.transform() * (placement.transform as Transform3D)
			var bounds := parent.transform() \
				* parent_recipe.placement_bounds[index]
			out.append({
				"parent_unit_id": String(parent.stable_id),
				"placement_id": String(placement.id),
				"asset_id": String(placement.asset_id),
				"origin": [pose.origin.x, pose.origin.y, pose.origin.z],
				"bounds_position": [bounds.position.x, bounds.position.y,
					bounds.position.z],
				"bounds_size": [bounds.size.x, bounds.size.y, bounds.size.z],
			})
	return out


static func _room_projection_feature_audit(spatial: WarrenSpatialPlan) \
		-> Array[Dictionary]:
	## Publish the producer facts behind exposed upper floorplates. This keeps a
	## visual floor-edge complaint traceable to its exact lower/upper bearing pair
	## and support course instead of guessing from the rendered plank colour.
	var out: Array[Dictionary] = []
	if spatial == null:
		return out
	for feature: WarrenFeatureReservation in spatial.features:
		if feature.kind not in [&"room_outcropping", &"room_overhang_support",
				&"arcade_overhang_support", &"frontier_gateway_support"]:
			continue
		out.append({
			"feature_id": String(feature.stable_id),
			"kind": String(feature.kind),
			"audit_text": str(feature.audit),
			"construction_records_text": str(feature.construction_records),
		})
	return out


static func _retained_top_course_audit(plan: SettlementFabricPlan,
		spatial: WarrenSpatialPlan = null) \
		-> Array[Dictionary]:
	## Publish exposed retained-stone crowns on the same authored macro lattice
	## the erosion pass reasons about. This is diagnostic evidence for visual
	## review: it cannot alter which stone survives or infer a repair from a mesh.
	var retained := plan.retained_terrace_cells
	var macros: Dictionary = {}
	for cell_value: Variant in retained.keys():
		var cell := cell_value as Vector3i
		if retained.has(cell + Vector3i.UP):
			continue
		var macro := Vector3i(floori(float(cell.x) * 0.5), cell.y,
			floori(float(cell.z) * 0.5))
		macros[macro] = int(macros.get(macro, 0)) + 1
	var ordered: Array[Vector3i] = []
	ordered.assign(macros.keys())
	ordered.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		return a.y > b.y if a.y != b.y else str(a) < str(b))
	var out: Array[Dictionary] = []
	for macro: Vector3i in ordered:
		var neighbours := 0
		for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT,
				Vector2i.UP, Vector2i.DOWN]:
			neighbours += int(macros.has(Vector3i(macro.x + direction.x,
				macro.y, macro.z + direction.y)))
		var above_owners: Dictionary = {}
		var above_uses: Dictionary = {}
		if spatial != null:
			for fine: Vector3i in WarrenVolumetricSolver._fine_square(
					macro + Vector3i.UP):
				var use := spatial.grid.use_at(fine)
				above_uses[use] = int(above_uses.get(use, 0)) + 1
				var owner := spatial.grid.owner_name_at(fine)
				if not owner.is_empty():
					above_owners[owner] = int(above_owners.get(owner, 0)) + 1
		out.append({"macro": [macro.x, macro.y, macro.z],
			"fine_cell_count": int(macros[macro]),
			"same_height_neighbour_count": neighbours,
			"above_uses": above_uses,
			"above_owners": above_owners})
	return out


static func _continuous_roof_run_audit(plan: SettlementFabricPlan) \
		-> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if plan == null or plan.continuous_roof_plan == null:
		return out
	for run: Dictionary in plan.continuous_roof_plan.compiled_runs:
		out.append({
			"unit_id": String(run.get("unit_id", "")),
			"run_id": String(run.get("run_id", "")),
			"kind": String(run.get("kind", "")),
			"start": _v3(run.start as Vector3),
			"end": _v3(run.end as Vector3),
			"axis_x": bool(run.axis_x),
			"cross_min": float(run.cross_min),
			"cross_max": float(run.cross_max),
			"base_y": float(run.base_y),
			"peak_y": float(run.peak_y),
			"repeat_pitch": float(run.repeat_pitch),
			"seam_profile": String(run.seam_profile),
			"authored_material": String(run.get("authored_material", "")),
		})
	return out


static func _aabb_json(bounds: AABB) -> Dictionary:
	return {"position": _v3(bounds.position), "size": _v3(bounds.size)}


static func _transform_json(transform: Transform3D) -> Dictionary:
	return {"origin": _v3(transform.origin),
		"basis_x": _v3(transform.basis.x),
		"basis_y": _v3(transform.basis.y),
		"basis_z": _v3(transform.basis.z)}


static func _spatial_feature_kind_counts(plan: WarrenSpatialPlan) -> Dictionary:
	var out: Dictionary = {}
	if plan == null:
		return out
	for feature: WarrenFeatureReservation in plan.features:
		var key := String(feature.kind)
		out[key] = int(out.get(key, 0)) + 1
	return out

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
		program: VillageProgram, buildings: Array[Dictionary],
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
	_append_sectional_feature_views(out, record)
	_append_outskirts_views(out, frame, record, buildings, program)
	return out


static func _append_sectional_feature_views(out: Array[Dictionary],
		record: VillageRecord) -> void:
	## Whole-town orbits can hide a valid bridge behind one of its endpoint
	## buildings. Frame sealed feature records themselves so every occupied
	## skywalk is judged as a two-ended span, then sample the facade-relief pass
	## from below/oblique where its depth and connected bearers are legible.
	var urban := record.urban_fabric
	if urban == null or urban.fabric_plan == null:
		return
	var world_from_lattice := urban.world_transform
	var fabric := urban.fabric_plan
	var skywalk_index := 0
	if urban.volumetric_spatial != null:
		for feature: WarrenFeatureReservation in urban.volumetric_spatial.features:
			if feature.kind not in [&"enclosed_skywalk", &"public_skybridge"] \
					or feature.reserved_cells.is_empty():
				continue
			var local_target := Vector3.ZERO
			for cell: Vector3i in feature.reserved_cells:
				local_target += Vector3(cell) * FabricRecipe.CELL_SIZE
			local_target /= float(feature.reserved_cells.size())
			var local_along := Vector3.FORWARD
			if feature.endpoints.size() >= 2:
				var first := (feature.endpoints[0] as Dictionary).cell as Vector3i
				var last := (feature.endpoints[-1] as Dictionary).cell as Vector3i
				local_along = Vector3(last.x - first.x, 0.0,
					last.z - first.z).normalized()
			var target := world_from_lattice * local_target
			var along := (world_from_lattice.basis * local_along).normalized()
			var outward := Vector3(-along.z, 0.0, along.x).normalized()
			_add_view(out, "warren_skywalk_%02d" % skywalk_index,
				target + outward * 9.0 - along * 2.5 + Vector3.UP * 1.5,
				target + Vector3.UP * 0.35, 58.0, 7.0)
			skywalk_index += 1
	# Occupied bridge-houses are incorporated into the ordinary FabricUnit DAG
	# after their source reservation commits. The exact `spatial.maze_bridge.NN`
	# owner and measured recipe bounds survive there even though the transient
	# reservation is no longer copied into `spatial.features`.
	for unit: FabricUnit in fabric.units:
		if not String(unit.stable_id).contains("spatial.maze_bridge."):
			continue
		var recipe := fabric.recipe(unit.recipe_id)
		if recipe == null:
			continue
		var local_bounds := unit.transform() * recipe.local_bounds
		var local_target := local_bounds.get_center()
		var local_along := Vector3.RIGHT if local_bounds.size.x \
			>= local_bounds.size.z else Vector3.FORWARD
		if unit.parent_ids.size() >= 2:
			var first_parent := fabric.unit(unit.parent_ids[0])
			var second_parent := fabric.unit(unit.parent_ids[1])
			if first_parent != null and second_parent != null:
				var parent_delta := second_parent.bounds.get_center() \
					- first_parent.bounds.get_center()
				parent_delta.y = 0.0
				if parent_delta.length_squared() > 0.01:
					local_along = parent_delta.normalized()
		var target := world_from_lattice * local_target
		var along := (world_from_lattice.basis * local_along).normalized()
		var outward := Vector3(-along.z, 0.0, along.x).normalized()
		var world_scale := maxf(world_from_lattice.basis.x.length(),
			world_from_lattice.basis.z.length())
		var subject_span := maxf(local_bounds.size.x,
			local_bounds.size.z) * world_scale
		var orbit := maxf(22.0, subject_span * 2.5)
		_add_view(out, "warren_skywalk_%02d" % skywalk_index,
			target + outward * orbit - along * orbit * 0.2 \
				+ Vector3.UP * maxf(4.0, subject_span * 0.35),
			target, 52.0, maxf(8.0, subject_span))
		skywalk_index += 1
	# Integrated bridge-house crowns used to escape the roof audit because the
	# roof is part of a room recipe. Give every such crown its own bounds-derived
	# side view. This keeps the highest roofs inside the frame and makes either an
	# offset crown or a roof buried in an endpoint solid impossible to miss.
	var integrated_roof_index := 0
	for unit: FabricUnit in fabric.units:
		var recipe := fabric.recipe(unit.recipe_id)
		if recipe == null or not recipe.has_tag(&"integrated_pitched_roof"):
			continue
		var roof_bounds := _unit_roof_placement_bounds(unit, recipe)
		if roof_bounds.size == Vector3.ZERO:
			continue
		_append_roof_detail_view(out, world_from_lattice, roof_bounds,
			"warren_integrated_roof_%02d" % integrated_roof_index)
		integrated_roof_index += 1
	# A terminal low bay is two tiled slopes meeting at one shared ridge. Close
	# views of the exact low subassembly falsify the former inverted-valley bug;
	# inspecting only the recipe's complete logical box would conceal it.
	var shallow_gable_index := 0
	for unit: FabricUnit in fabric.units:
		var recipe := fabric.recipe(unit.recipe_id)
		if recipe == null or not recipe.has_tag(&"terminal_step_gable"):
			continue
		var low_bounds := _unit_roof_placement_bounds(unit, recipe, true)
		if low_bounds.size == Vector3.ZERO:
			continue
		_append_roof_detail_view(out, world_from_lattice, low_bounds,
			"warren_shallow_gable_%02d" % shallow_gable_index)
		shallow_gable_index += 1
	# A whole-town orbit can conceal the exact seam this pass is meant to judge.
	# Frame every derived continuous crown from its transverse side so the two
	# exterior ends, all internal bays, and the shared ridge datum are visible in
	# one fixed-seed image.
	if fabric.continuous_roof_plan != null:
		for roof_index in fabric.continuous_roof_plan.components.size():
			var component := fabric.continuous_roof_plan.components[roof_index]
			var local_start := component.start as Vector3
			var local_end := component.end as Vector3
			var local_along := (local_end - local_start).normalized()
			var local_outward := Vector3(-local_along.z, 0.0,
				local_along.x).normalized()
			var local_target := (local_start + local_end) * 0.5
			local_target.y = lerpf(float(component.base_y),
				float(component.peak_y), 0.52)
			var target := world_from_lattice * local_target
			var outward := (world_from_lattice.basis * local_outward).normalized()
			var world_scale := maxf(world_from_lattice.basis.x.length(),
				world_from_lattice.basis.z.length())
			var run_span := local_start.distance_to(local_end) * world_scale
			var orbit := maxf(18.0, run_span * 1.15)
			_add_view(out, "warren_roof_run_%02d" % roof_index,
				target + outward * orbit + Vector3.UP * maxf(2.0,
					run_span * 0.12), target, 48.0, maxf(7.0, run_span))
	var retained := fabric.retained_terrace_cells
	var solids := fabric.transformed_cells(&"solid")
	var paved := SettlementFabricAssembler.public_floor_cells(
		fabric.surface_plan)
	var walked := SettlementFabricAssembler.walked_floor_cells(
		fabric.surface_plan)
	var plinths := SettlementFabricAssembler.plinth_faces(retained, solids,
		fabric.transformed_cells(&"terrain_bearing"))
	var spans := SettlementFabricAssembler.maze_skywalk_spans(fabric)
	var kinds := SettlementFabricAssembler.maze_facade_outcrop_kinds(retained,
		solids, paved, plinths, walked, {},
		SettlementFabricAssembler.maze_skywalk_cells(spans))
	var feature_index := 0
	for key_value: Variant in kinds.keys():
		if feature_index >= 8:
			break
		var key := key_value as Vector4i
		var local_outward := Vector3(
			SettlementFabricAssembler.STONE_FACE_DIRECTIONS[key.w])
		var local_cross := Vector3(-local_outward.z, 0.0, local_outward.x)
		var reach := FabricRecipe.CELL_SIZE if int(kinds[key]) \
			== SettlementFabricAssembler.FacadeOutcrop.BAY \
			else SettlementFabricAssembler.FACADE_BUMP_REACH
		var local_boundary := Vector3(key.x, 0.0, key.z) \
			* FabricRecipe.CELL_SIZE + local_outward \
			* (FabricRecipe.CELL_SIZE * 0.5) + local_cross \
			* (FabricRecipe.CELL_SIZE * 0.5)
		local_boundary.y = float(key.y + 1) * FabricRecipe.CELL_SIZE \
			- SettlementFabricAssembler.STONE_MODULE_HEIGHT
		var target := world_from_lattice * (local_boundary \
			+ local_outward * reach * 0.5)
		var outward := (world_from_lattice.basis * local_outward).normalized()
		var cross := (world_from_lattice.basis * local_cross).normalized()
		var kind_name := "bay" if int(kinds[key]) \
			== SettlementFabricAssembler.FacadeOutcrop.BAY else "bump"
		_add_view(out, "warren_outcrop_%s_%02d" % [kind_name, feature_index],
			target + outward * 16.0 + cross * 5.0 + Vector3.UP * 1.5,
			target - Vector3.UP * 0.25, 52.0, 7.0)
		feature_index += 1


static func _unit_roof_placement_bounds(unit: FabricUnit,
		recipe: FabricRecipe, low_only: bool = false) -> AABB:
	var out := AABB()
	var has_bounds := false
	for index in recipe.placements.size():
		var placement := recipe.placements[index] as Dictionary
		var placement_id := String(placement.id)
		var asset_id := String(placement.asset_id)
		var is_roof := placement_id.begins_with("roof") \
			or placement_id.begins_with("gable") \
			or asset_id.contains(".roof.")
		if not is_roof or low_only and not placement_id.contains(".low."):
			continue
		var bounds := unit.transform() * recipe.placement_bounds[index]
		out = bounds if not has_bounds else out.merge(bounds)
		has_bounds = true
	return out


static func _append_roof_detail_view(out: Array[Dictionary],
		world_from_lattice: Transform3D, local_bounds: AABB,
		view_name: String) -> void:
	var along := Vector3.RIGHT if local_bounds.size.x >= local_bounds.size.z \
		else Vector3.FORWARD
	var outward := Vector3(-along.z, 0.0, along.x)
	var local_target := local_bounds.get_center() - Vector3.UP * maxf(1.25,
		local_bounds.size.y * 0.62)
	var target := world_from_lattice * local_target
	var world_along := (world_from_lattice.basis * along).normalized()
	var world_outward := (world_from_lattice.basis * outward).normalized()
	var world_scale := maxf(world_from_lattice.basis.x.length(),
		world_from_lattice.basis.z.length())
	var subject_span := maxf(local_bounds.size.x,
		local_bounds.size.z) * world_scale
	var orbit := maxf(18.0, subject_span * 2.15)
	_add_view(out, view_name,
		target + world_outward * orbit + world_along * orbit * 0.14 \
			+ Vector3.UP * maxf(3.0, subject_span * 0.24),
		target + Vector3.UP * maxf(0.5, subject_span * 0.06), 50.0,
		maxf(7.0, subject_span))

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
	var structural_volumes: Array[VillageOccupancyVolume] = []
	if record.urban_fabric != null and record.urban_fabric.accepted:
		structural_volumes = record.urban_fabric.volumes
	for placement: VillageMassingPlacement in record.outskirts.placements:
		var house_centre := placement.solid_centre
		var away := house_centre - frame.centre
		away = away.normalized() if not away.is_zero_approx() \
			else -placement.entrance_outward
		var side := Vector2(-away.y, away.x)
		# Review the relationship, not an isolated facade. Looking inward from
		# outside the parcel keeps the prefab, its doorstep lane, and the dense
		# town in one frame. The old front-on closeup looked away from the city and
		# could fall back against the subject wall or into a nearby cliff.
		var preferred_xz := house_centre + away * 24.0 + side * 8.0
		var preferred := _terrain_eye(frame, preferred_xz, 7.0)
		var context_target := house_centre - away * 7.0
		var target := Vector3(context_target.x,
			placement.floor_y + 3.0, context_target.y)
		var stable_id := StringName("%s.%s" % [record.stable_id,
			placement.stable_key])
		_add_view(out, "outskirts_%s" % _safe_recipe_id(
			String(placement.stable_key)),
			_safe_elevated_camera(frame, preferred, target, buildings,
				program, stable_id, structural_volumes), target, 64.0, 18.0)


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
