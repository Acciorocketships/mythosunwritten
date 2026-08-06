extends SceneTree

## Fast tuning probe for the asset-aware stage before exact building assembly.
## It makes route-budget changes measurable without weakening the final common
## fabric transaction or waiting for every market/skywalk trial.


func _init() -> void:
	var program := SettlementFabricProgram.compile(
		EnvironmentCatalog.load_default())
	assert(program != null)
	var requested_seed := -1
	var requested_attempt := -1
	var build_exact := false
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		if args[index] == "--seed" and index + 1 < args.size():
			requested_seed = int(args[index + 1])
		elif args[index] == "--attempt" and index + 1 < args.size():
			requested_attempt = int(args[index + 1])
		elif args[index] == "--built":
			build_exact = true
	var rows: Array[Dictionary] = []
	var seeds: Array[int] = []
	if requested_seed >= 0:
		seeds.append(requested_seed)
	else:
		seeds.assign([0, 1, 2, 3])
	for seed_value: int in seeds:
		if build_exact:
			var built := WarrenBuiltTownSolver.solve_attempt(seed_value,
				requested_attempt, program) if requested_attempt >= 0 \
				else WarrenBuiltTownSolver.solve(seed_value, program)
			var selected_infill := _selected_infill_diagnostic(built)
			rows.append({"seed": seed_value, "built": built != null,
				"failure": WarrenBuiltTownSolver.last_failure,
				"audit": {} if built == null else built.audit,
				"parcel_layout": [] if built == null else _parcel_layout(built),
				"open_core_columns": [] if built == null \
					else _open_core_columns(built),
				"primary_walk": [] if built == null else _walk_cells(built, true),
				"arcade_walk": [] if built == null else _walk_cells(built, false),
				"selection": WarrenBuiltTownSolver.last_selection_diagnostic,
				"candidate_failures":
					WarrenBuiltTownSolver.last_candidate_failure_diagnostic,
				"platform_terminals": _platform_terminal_diagnostic(built),
				"timing": WarrenTownSolver.last_timing_diagnostic,
				"parcel_diagnostic": WarrenParcelizer.last_diagnostic,
				"infill_diagnostic": selected_infill})
			continue
		var plans := WarrenTownSolver.ranked_candidates(seed_value, {}, program,
			WarrenTownSolver.COMPOSED_PLAN_FRONTIER)
		var candidates: Array[Dictionary] = []
		for plan: WarrenTownPlan in plans:
			candidates.append({
				"attempt": int(plan.audit.route_attempt),
				"walk": int(plan.audit.walk_cell_count),
				"parcels": int(plan.audit.parcel_count),
				"grounded_parcels": int(plan.audit.grounded_parcel_count),
				"tall_parcels": int(plan.audit.get("tall_parcel_count", 0)),
				"unstepped_tall_parcels": int(plan.audit.get(
					"unstepped_tall_parcel_count", 0)),
				"open_core_ratio": float(plan.audit.urban_core_open_column_ratio),
				"bounded": float(plan.audit.bounded_walk_ratio),
				"ground_primary_bounded": float(plan.audit.get(
					"ground_primary_bounded_walk_ratio", 0.0)),
				"ground_primary_two_sided": float(plan.audit.get(
					"ground_primary_two_sided_walk_ratio", 0.0)),
				"composed": float(plan.audit.composed_walk_enclosure_ratio),
				"overpasses": int(plan.audit.occupied_overpass_parcel_count),
			})
		rows.append({"seed": seed_value, "candidates": candidates,
			"failure": WarrenTownSolver.last_failure,
			"timing": WarrenTownSolver.last_timing_diagnostic,
			"parcel_diagnostic": WarrenParcelizer.last_diagnostic,
			"infill_diagnostic": WarrenPlatformInfillSolver.last_diagnostic})
	print(JSON.stringify({
		"route_cells": [WarrenPublicRealmCarver.MIN_ROUTE_CELLS,
			WarrenPublicRealmCarver.MAX_ROUTE_CELLS],
		"compact_attempts": WarrenPublicRealmCarver.COMPACT_ROUTE_ATTEMPTS,
		"max_attempts": WarrenPublicRealmCarver.MAX_ATTEMPTS,
		"rows": rows,
	}, "  "))
	quit(0)


static func _platform_terminal_diagnostic(
		built: WarrenBuiltTownPlan) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if built == null:
		return out
	var incident: Dictionary = {}
	for node_value: PublicRealmNode in built.fabric.public_realm.nodes:
		incident[node_value.stable_id] = 0
	for edge_value: PublicRealmEdge in built.fabric.public_realm.edges:
		incident[edge_value.from_node_id] = int(
			incident.get(edge_value.from_node_id, 0)) + 1
		incident[edge_value.to_node_id] = int(
			incident.get(edge_value.to_node_id, 0)) + 1
	var served_landings: Dictionary = {}
	for entrance: Dictionary in built.fabric.surface_plan.entrance_records:
		if bool(entrance.served):
			served_landings[entrance.landing_cell as Vector3i] = true
	var journey_terminal := StringName()
	if not built.fabric.public_realm.primary_itinerary.is_empty():
		journey_terminal = built.fabric.public_realm.primary_itinerary.back()
	for node_value: PublicRealmNode in built.fabric.public_realm.nodes:
		if node_value.surface_kind != \
				PublicRealmSurfacePlan.SurfaceKind.STRUCTURAL_COURT \
				or int(incident.get(node_value.stable_id, 0)) >= 2:
			continue
		var addressed_cells := PackedStringArray()
		for cell: Vector3i in node_value.surface_cells:
			if served_landings.has(cell):
				addressed_cells.append("%d:%d:%d" % [cell.x, cell.y, cell.z])
		out.append({
			"node": String(node_value.stable_id),
			"incident": int(incident.get(node_value.stable_id, 0)),
			"journey_terminal": node_value.stable_id == journey_terminal,
			"addressed_cells": addressed_cells,
			"surfaces": node_value.surface_cells,
		})
	return out


static func _selected_infill_diagnostic(built: WarrenBuiltTownPlan) -> Dictionary:
	if built == null:
		return {}
	var town := built.assets.town
	var result := WarrenPlatformInfillSolver.solve(
		town.volume, town.parcels, town.pruning)
	var diagnostic := WarrenPlatformInfillSolver.last_diagnostic.duplicate(true)
	diagnostic["patch_count"] = int(result.patch_count)
	diagnostic["optional_patch_count"] = int(result.optional_patch_count)
	diagnostic["over_route_patch_count"] = int(result.over_route_patch_count)
	return diagnostic
static func _parcel_layout(built: WarrenBuiltTownPlan) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for parcel: WarrenBuildingParcel in built.assets.town.parcels.parcels:
		var footprint := PackedStringArray()
		for column: Vector2i in parcel.footprint:
			footprint.append("%d:%d" % [column.x, column.y])
		footprint.sort()
		out.append({"id": String(parcel.stable_id), "footprint": footprint,
			"base": parcel.base_band, "top": parcel.top_band,
			"grounded": parcel.base_band == built.assets.town.volume.envelope \
				.ground_at(parcel.threshold_column),
			"address": "%d:%d:%d" % [parcel.address_walk_cell.x,
				parcel.address_walk_cell.y, parcel.address_walk_cell.z]})
	return out


static func _open_core_columns(built: WarrenBuiltTownPlan) -> PackedStringArray:
	var out := PackedStringArray()
	for column_value: Variant in built.assets.town.pruning.daylight_void_columns:
		var column := column_value as Vector2i
		out.append("%d:%d" % [column.x, column.y])
	out.sort()
	return out


static func _walk_cells(built: WarrenBuiltTownPlan,
		primary: bool) -> PackedStringArray:
	var out := PackedStringArray()
	var source := built.assets.town.volume
	for cell: Vector3i in source.walk_cells:
		if source.primary_itinerary.has(cell) != primary:
			continue
		out.append("%d:%d:%d" % [cell.x, cell.y, cell.z])
	out.sort()
	return out
