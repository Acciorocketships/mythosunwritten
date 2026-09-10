extends SceneTree

## Production-record corpus on a canonical flat terrain fixture.  Unlike the
## review-planner corpus, this crosses VillagePlan, terrain adaptation, payload
## materialization, collision-bearing surface tiling, record validation, and
## feature asset demand exactly as the streamed game does.
const DEFAULT_SEEDS: Array[int] = [4242, 991177, 3046246887, 2697992464]
const ZERO_METRICS: Array[StringName] = [
	&"stair_endpoint_gap_count",
	&"stair_endpoint_missing_landing_count",
	&"stair_to_stair_edge_count",
	&"platform_dead_end_count",
	&"isolated_platform_count",
	&"unsupported_platform_count",
	&"unsupported_stair_count",
	&"unserved_entrance_count",
	&"detached_building_stack_count",
	&"visual_envelope_overlap_count",
	&"uncovered_core_column_count",
	&"max_uncovered_core_component_size",
]

var _seeds: Array[int] = DEFAULT_SEEDS.duplicate()
var _output := "/tmp/mythos-production-warren-seed-corpus.json"


func _init() -> void:
	_read_args()
	var catalog := EnvironmentCatalog.load_default()
	var program := VillageProgram.compile({}, catalog)
	assert(program != null and program.settlement_fabric_program != null)
	var frame := _flat_frame()
	var route_signatures: Dictionary = {}
	var canonical_route_signatures: Dictionary = {}
	var construction_signatures: Dictionary = {}
	var failures: Array[String] = []
	var rows: Array[Dictionary] = []
	var started := Time.get_ticks_msec()
	for world_seed: int in _seeds:
		var seed_started := Time.get_ticks_msec()
		var village_plan := VillagePlan.new(world_seed, program)
		var city_seed := village_plan._warren_seed(frame)
		var record := village_plan.record_for(frame)
		var seed_failures: Array[String] = []
		var audit: Dictionary = {}
		if record == null or not record.validate(program) or record.is_empty() \
				or not record.urban_fabric.accepted:
			seed_failures.append("production record rejected")
		else:
			audit = record.urban_fabric.construction_diagnostics(program)
			var source := record.urban_fabric.volumetric_spatial.source_volume.mass_context[&"maze_source_plan"] as WarrenMazeSourcePlan
			audit["maze_route_signature"] = _route_signature(source.excavation.route, false)
			audit["maze_canonical_route_signature"] = _route_signature(source.excavation.route, true)
			_audit_record(record, catalog, audit, route_signatures,
				canonical_route_signatures, construction_signatures, world_seed,
				seed_failures)
		for issue: String in seed_failures:
			failures.append("seed %d: %s" % [world_seed, issue])
		rows.append({
			"seed": world_seed,
			"city_seed": city_seed,
			"accepted": seed_failures.is_empty(),
			"urban_reason": String(record.urban_fabric.reason) \
				if record != null and record.urban_fabric != null else "missing",
			"failures": seed_failures,
			"elapsed_ms": Time.get_ticks_msec() - seed_started,
			"route_signature": audit.get("maze_route_signature", ""),
			"canonical_route_signature": audit.get(
				"maze_canonical_route_signature", ""),
			"construction_signature": audit.get("construction_signature", ""),
			"building_stack_count": audit.get("building_stack_count", 0),
			"market_count": audit.get("market_count", 0),
			"skywalk_link_count": audit.get("skywalk_link_count", 0),
			"outcropping_count": audit.get("outcropping_count", 0),
			"stair_count": audit.get("stair_count", 0),
			"infill_lightwell_count": audit.get("infill_lightwell_count", 0),
			"uncovered_core_column_count": audit.get(
				"uncovered_core_column_count", -1),
			"frontage_ratio": audit.get("frontage_ratio", 0.0),
			"overhead_route_ratio": audit.get("overhead_route_ratio", 0.0),
			"max_uncovered_route_component_size": audit.get(
				"max_uncovered_route_component_size", -1),
			"through_sightline_count": audit.get(
				"through_sightline_count", -1),
			"visual_quality_target_met": audit.get(
				"visual_quality_target_met", false),
			"visual_quality_fallback_count": audit.get(
				"visual_quality_fallback_count", 0),
			"payload_instances": record.payload.instance_count \
				if record != null else 0,
			"occupancy_volume_count": record.occupancy.size() \
				if record != null else 0,
			"entrance_lift_m": record.urban_fabric.terrain_entrance_lift_m \
				if record != null else -1.0,
			"terrain_relief_m": record.urban_fabric.terrain_relief_m \
				if record != null else -1.0,
		})
		print(("[production_warren_seed_corpus] seed=%d city_seed=%d accepted=%s " \
			+ "route=%s build=%s instances=%d issues=%d elapsed_ms=%d") % [
			world_seed, city_seed, seed_failures.is_empty(),
			String(audit.get("maze_route_signature", "")).left(10),
			String(audit.get("construction_signature", "")).left(10),
			record.payload.instance_count if record != null else 0,
			seed_failures.size(), Time.get_ticks_msec() - seed_started])
	var outcrop_seed_count := 0
	for row: Dictionary in rows:
		if int(row.get("outcropping_count", 0)) > 0:
			outcrop_seed_count += 1
	if _seeds.size() >= 4:
		var minimum_outcrop_seeds := ceili(float(_seeds.size()) * 0.5)
		if outcrop_seed_count < minimum_outcrop_seeds:
			failures.append("outcroppings appear in only %d/%d seeds; expected at least %d" % [
				outcrop_seed_count, _seeds.size(), minimum_outcrop_seeds])
	var report := {
		"schema_version": 2,
		"inspection": "Current spatial construction, required feature realization, occupancy and source route; legacy fixed-size richness metrics are informational.",
		"seeds": _seeds,
		"accepted": failures.is_empty(),
		"elapsed_ms": Time.get_ticks_msec() - started,
		"unique_route_signature_count": route_signatures.size(),
		"unique_canonical_route_signature_count":
			canonical_route_signatures.size(),
		"unique_construction_signature_count": construction_signatures.size(),
		"outcrop_seed_count": outcrop_seed_count,
		"failures": failures,
		"per_seed": rows,
	}
	DirAccess.make_dir_recursive_absolute(_output.get_base_dir())
	var file := FileAccess.open(_output, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("[production_warren_seed_corpus] accepted=%s seeds=%d output=%s" % [
		failures.is_empty(), _seeds.size(), _output])
	quit(0 if failures.is_empty() else 1)


static func _audit_record(record: VillageRecord, catalog: EnvironmentCatalog,
		audit: Dictionary,
		route_signatures: Dictionary, canonical_route_signatures: Dictionary,
		construction_signatures: Dictionary, world_seed: int,
		failures: Array[String]) -> void:
	var urban := record.urban_fabric
	if urban.generation_kind \
			!= VillageUrbanFabricPlan.GenerationKind.VOLUMETRIC_WARREN:
		failures.append("record did not use volumetric production")
	var occupancy_roles: Dictionary = {}
	for volume: VillageOccupancyVolume in record.occupancy:
		occupancy_roles[volume.role] = true
	for required_role in [VillageOccupancy.Role.SOLID,
			VillageOccupancy.Role.WALK_SURFACE,
			VillageOccupancy.Role.HEADROOM,
			VillageOccupancy.Role.WALK_GUARD,
			VillageOccupancy.Role.GROUND_EXCLUSIVE]:
		if not occupancy_roles.has(required_role):
			failures.append("missing typed occupancy role %d" % required_role)
	if record.occupancy.size() <= 10:
		failures.append("volumetric occupancy collapsed to broad proxies")
	for metric: StringName in ZERO_METRICS:
		if int(audit.get(metric, -1)) != 0:
			failures.append("%s=%s" % [metric, audit.get(metric)])
	# Legacy richness thresholds assumed identical town sizes and two freestanding
	# stalls. Current profiles publish explicit feature reservations. Measure the
	# built result against those reservations below; keep coverage/richness in the
	# report for review without pretending they are structural failures.
	if int(audit.get("building_stack_count", 0)) < 1:
		failures.append("town has no inhabited building")
	var route_signature := String(audit.get("maze_route_signature", ""))
	var canonical_route_signature := String(audit.get(
		"maze_canonical_route_signature", ""))
	var construction_signature := String(audit.get(
		"construction_signature", ""))
	if route_signatures.has(route_signature):
		failures.append("route repeats seed %d" % int(
			route_signatures[route_signature]))
	if canonical_route_signature.is_empty():
		failures.append("missing canonical route signature")
	elif canonical_route_signatures.has(canonical_route_signature):
		failures.append("route repeats seed %d after rotation normalization" % int(
			canonical_route_signatures[canonical_route_signature]))
	if construction_signatures.has(construction_signature):
		failures.append("construction repeats seed %d" % int(
			construction_signatures[construction_signature]))
	route_signatures[route_signature] = world_seed
	canonical_route_signatures[canonical_route_signature] = world_seed
	construction_signatures[construction_signature] = world_seed
	var spatial := urban.volumetric_spatial
	if spatial == null:
		failures.append("missing volumetric source lineage")
	else:
		# Inspect the actual room/air/structural partition and its bearing graph.
		# The retired parcel model cannot describe offset upper floors or bridges.
		var source := spatial.source_volume.mass_context[&"maze_source_plan"] as WarrenMazeSourcePlan
		if not source.validate_construction():
			failures.append("source construction: " + source.last_rejection)
		if not spatial.validate_construction():
			failures.append("spatial construction: " + spatial.last_rejection)
		for issue: String in WarrenSpatialFabricCompiler.validation_errors(urban.fabric_plan):
			failures.append("fabric construction: " + issue)
	var stocked_count := 0
	for asset_id: StringName in record.payload.asset_ids():
		if String(asset_id).contains(".tent."):
			failures.append("empty/free tent family leaked into production: %s" %
				String(asset_id))
		if SettlementFabricProgram.MARKET_STALLS.has(asset_id):
			var descriptor := catalog.descriptor(asset_id)
			if descriptor == null or not descriptor.tags.has(&"stocked_market"):
				failures.append("market is not a stocked prefab: %s" % asset_id)
			else:
				stocked_count += int((record.payload.batches[asset_id] \
					as Dictionary).transforms.size())
	# Every planned stocked stall must survive the production payload projection.
	var planned_stocked_count := 0
	for placement: Dictionary in urban.fabric_plan.expanded_placements():
		if SettlementFabricProgram.MARKET_STALLS.has(StringName(placement.asset_id)):
			planned_stocked_count += 1
	if stocked_count != planned_stocked_count:
		failures.append("stocked market realization=%d expected=%d" % [
			stocked_count, planned_stocked_count])


static func _route_signature(route: Array[Vector3i], normalize_rotation: bool) -> String:
	var alternatives: Array[String] = []
	for yaw in range(4 if normalize_rotation else 1):
		var parts: Array[String] = []
		for point: Vector3i in route:
			var relative := point - route[0]
			for turn in yaw:
				relative = Vector3i(-relative.z, relative.y, relative.x)
			parts.append("%d,%d,%d" % [relative.x, relative.y, relative.z])
		alternatives.append(";".join(parts))
	alternatives.sort()
	return alternatives[0].sha256_text()


static func _flat_frame() -> VillageFrame:
	var storeys: Dictionary = {}
	var levels: Dictionary = {}
	for z in range(-28, 29):
		for x in range(-28, 29):
			storeys[Vector2i(x, z)] = 0
			levels[Vector2i(x, z)] = 0
	var region := HeightfieldRegion.new(storeys, levels)
	var water := WaterFieldContext.new()
	water._ctx = {"ponds": [], "rivers": [], "buckets": {}, "region": region}
	water._region = region
	water._coverage = Rect2(-Vector2.ONE * 768.0, Vector2.ONE * 1536.0)
	water._shore_limit = 0.0
	return VillageFrame.from_mask({
		"id": &"settlement.production.corpus",
		"cell": Vector2i.ZERO,
	}, 1, region, water)


func _read_args() -> void:
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		if args[index] == "--output" and index + 1 < args.size():
			_output = args[index + 1]
		elif args[index] == "--seeds" and index + 1 < args.size():
			_seeds.clear()
			for value: String in args[index + 1].split(",", false):
				_seeds.append(int(value))
	assert(not _seeds.is_empty())
