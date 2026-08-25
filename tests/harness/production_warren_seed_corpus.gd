extends SceneTree

## Production-record corpus on a canonical flat terrain fixture.  Unlike the
## review-planner corpus, this crosses VillagePlan, terrain adaptation, payload
## materialization, collision-bearing surface tiling, record validation, and
## feature asset demand exactly as the streamed game does.
const DEFAULT_SEEDS: Array[int] = [4242, 991177, 3046246887, 2697992464]
## TASK F1. Lived on the searched town solver until that solver died with the
## searched pipeline; the value is unchanged.
const MAX_UNCOVERED_ROUTE_COMPONENT_SIZE := 16
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
	&"visually_short_parcel_count",
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
		if record == null or not record.validate(program) or record.is_empty() \
				or not record.urban_fabric.accepted:
			seed_failures.append("production record rejected")
		else:
			_audit_record(record, catalog, route_signatures,
				canonical_route_signatures, construction_signatures, world_seed,
				seed_failures)
		for issue: String in seed_failures:
			failures.append("seed %d: %s" % [world_seed, issue])
		var audit: Dictionary = record.urban_fabric.fabric_audit \
			if record != null and record.urban_fabric != null else {}
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
		"schema_version": 1,
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
		route_signatures: Dictionary, canonical_route_signatures: Dictionary,
		construction_signatures: Dictionary, world_seed: int,
		failures: Array[String]) -> void:
	var urban := record.urban_fabric
	var audit := urban.fabric_audit
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
	if int(audit.get("max_uncovered_route_component_size", 2147483647)) \
			> MAX_UNCOVERED_ROUTE_COMPONENT_SIZE:
		failures.append("max_uncovered_route_component_size=%s" % audit.get(
			"max_uncovered_route_component_size"))
	for metric: StringName in [
			&"building_stack_count", &"market_count", &"skywalk_link_count"]:
		var minimum := 7 if metric == &"building_stack_count" \
			else 2 if metric == &"market_count" else 1
		if int(audit.get(metric, 0)) < minimum:
			failures.append("%s below %d" % [metric, minimum])
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
	if urban.volumetric_town == null:
		failures.append("missing volumetric source lineage")
	else:
		for parcel: WarrenBuildingParcel in \
				urban.volumetric_town.assets.town.parcels.parcels:
			if parcel.width_cells > parcel.depth_cells:
				failures.append("building wider than deep: %s" % parcel.stable_id)
			var proposal := WarrenParcelConstruction.proposal(parcel)
			if parcel.width_cells > 1 and int(proposal.storeys) == 1:
				failures.append("visually short wide building: %s" % parcel.stable_id)
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
	if stocked_count < 2:
		failures.append("stocked market count=%d" % stocked_count)


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
