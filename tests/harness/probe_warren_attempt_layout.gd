extends SceneTree

## Prints one exact asset-aware town attempt as macro-lattice slices. This is a
## fast structural diagnostic for platform depth and empty undercroft columns;
## it deliberately stops before optional markets, bays, and occupied links.
const DEFAULT_CITY_SEED := 6046713720826375059
const DEFAULT_ATTEMPT := 66


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var city_seed := _argument_int(args, "--seed", DEFAULT_CITY_SEED)
	var attempt := _argument_int(args, "--attempt", DEFAULT_ATTEMPT)
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var range_start := _argument_int(args, "--range-start", -1)
	var range_end := _argument_int(args, "--range-end", -1)
	var accepted_only := args.has("--accepted-only")
	var failure_contains := _argument_string(args, "--failure-contains", "")
	if args.has("--volume-stages"):
		var stage_envelope := WarrenVolumeEnvelope.build(city_seed)
		var primary := WarrenPublicRealmCarver.sealed_candidate(city_seed,
			attempt, stage_envelope)
		print("primary volume audit=%s" % [
			{} if primary == null else primary.audit])
		var arcade := WarrenGroundArcadeSolver.extend(primary) \
			if primary != null else null
		print("arcade volume audit=%s" % [
			{} if arcade == null else arcade.audit])
		if arcade == null:
			print("arcade failure=%s" % WarrenGroundArcadeSolver.last_failure)
		var gallery_variants: Array[WarrenVolumePlan] = \
			WarrenElevatedFrontageSolver.variants(arcade) \
			if arcade != null else [] as Array[WarrenVolumePlan]
		var gallery := null if gallery_variants.is_empty() \
			else gallery_variants[0]
		print("gallery volume audit=%s" % [
			{} if gallery == null else gallery.audit])
		if gallery == null:
			print("gallery failure=%s" % WarrenElevatedFrontageSolver.last_failure)
		if args.has("--gallery-parcel-diagnostics"):
			for variant_index in gallery_variants.size():
				var variant := gallery_variants[variant_index]
				var exact_realm := WarrenVolumePublicRealmAdapter.from_volume(
					variant)
				var realm_failure := WarrenVolumePublicRealmAdapter.last_failure
				var parcels := WarrenTownSolver._parcelize(variant, program)
				print("gallery_variant=%d gallery_cells=%d realm=%s realm_failure=%s parcels=%s failure=%s diagnostic=%s" % [
					variant_index,
					int(variant.audit.get("elevated_gallery_walk_cell_count", 0)),
					exact_realm != null,
					realm_failure,
					0 if parcels == null else int(parcels.audit.parcel_count),
					WarrenParcelizer.last_failure,
					WarrenParcelizer.last_diagnostic])
		quit(0)
		return
	if args.has("--volume-range") and range_start >= 0 and range_end > range_start:
		var envelope := WarrenVolumeEnvelope.build(city_seed)
		var volume_rows: Array[Dictionary] = []
		for candidate_attempt in range(range_start, range_end):
			var volume := WarrenPublicRealmCarver.diagnostic_candidate(city_seed,
				candidate_attempt) if args.has("--raw-volume-range") else \
				WarrenPublicRealmCarver.sealed_candidate(city_seed,
					candidate_attempt, envelope)
			if volume != null and not volume.is_sealed():
				continue
			var primary_audit := {} if volume == null else volume.audit.duplicate()
			if volume != null:
				volume = WarrenGroundArcadeSolver.extend(volume)
			var arcade_audit := {} if volume == null else volume.audit.duplicate()
			if volume != null:
				volume = WarrenElevatedFrontageSolver.extend(volume)
			if volume != null:
				if args.has("--volume-summary"):
					volume_rows.append({
						"attempt": candidate_attempt,
						"primary_interior": int(primary_audit.get(
							"exact_route_interior_cell_count", 0)),
						"primary_component": int(primary_audit.get(
							"max_exact_route_interior_component_size", 0)),
						"final_interior": int(volume.audit.get(
							"exact_route_interior_cell_count", 0)),
						"final_component": int(volume.audit.get(
							"max_exact_route_interior_component_size", 0)),
						"near_folds": int(volume.audit.get(
							"same_datum_route_near_fold_count", 0)),
						"crossovers": int(volume.audit.get(
							"route_crossover_count", 0)),
						"height_bands": int(volume.audit.get(
							"elevation_band_count", 0)),
					})
				else:
					volume_rows.append({"attempt": candidate_attempt,
						"primary_audit": primary_audit,
						"arcade_audit": arcade_audit, "audit": volume.audit})
		print(JSON.stringify({"seed": city_seed, "volumes": volume_rows}, "  "))
		quit(0)
		return
	if range_start >= 0 and range_end > range_start:
		var rows: Array[Dictionary] = []
		var failure_counts: Dictionary = {}
		for candidate_attempt in range(range_start, range_end):
			var candidate := WarrenTownSolver.solve_attempt(city_seed,
				candidate_attempt, {}, program)
			if candidate == null:
				var failure_key := "%s | parcel=%s" % [
					WarrenTownSolver.last_failure, WarrenParcelizer.last_failure]
				failure_counts[failure_key] = int(failure_counts.get(
					failure_key, 0)) + 1
			if accepted_only and candidate == null \
					and (failure_contains.is_empty() \
						or not WarrenTownSolver.last_failure.contains(
							failure_contains)):
				continue
			rows.append({
				"attempt": candidate_attempt,
				"accepted": candidate != null,
				"failure": WarrenTownSolver.last_failure,
				"audit": {} if candidate == null else candidate.audit,
			})
		print(JSON.stringify({"seed": city_seed, "attempts": rows,
			"failure_counts": failure_counts}, "  "))
		quit(0)
		return
	var town := WarrenTownSolver.solve_attempt(city_seed, attempt, {}, program)
	if town == null:
		print("rejected: %s" % WarrenTownSolver.last_failure)
		print("parcel failure=%s diagnostic=%s" % [
			WarrenParcelizer.last_failure, WarrenParcelizer.last_diagnostic])
		print("infill=%s" % WarrenPlatformInfillSolver.last_diagnostic)
		quit(1)
		return
	if args.has("--summary"):
		print(JSON.stringify({
			"seed": city_seed,
			"attempt": attempt,
			"town": {
				"parcel_count": int(town.audit.get("parcel_count", 0)),
				"base_bands": int(town.parcels.audit.get("base_band_count", 0)),
				"roof_bands": int(town.parcels.audit.get("roof_band_count", 0)),
				"largest_base_ratio": float(town.parcels.audit.get(
					"largest_base_band_ratio", 1.0)),
				"ground_primary_bounded": float(town.audit.get(
					"ground_primary_bounded_walk_ratio", 0.0)),
				"ground_primary_two_sided": float(town.audit.get(
					"ground_primary_two_sided_walk_ratio", 0.0)),
				"contact_component": int(town.audit.get(
					"largest_building_contact_component_count", 0)),
				"occupied_overpasses": int(town.audit.get(
					"occupied_overpass_parcel_count", 0)),
				"planned_skywalks": int(town.audit.get(
					"planned_skywalk_count", 0)),
			},
			"height": WarrenParcelizer.last_diagnostic.get("height", {}),
			"connection": {
				"local_rank": int((WarrenParcelizer.last_diagnostic.get(
					"connection", {}) as Dictionary).get("chosen_local_rank", -1)),
				"lower_route_cover": int((WarrenParcelizer.last_diagnostic.get(
					"connection", {}) as Dictionary).get(
					"chosen_lower_route_cover_count", 0)),
				"dry_ground_bounded": int((WarrenParcelizer.last_diagnostic.get(
					"connection", {}) as Dictionary).get(
					"chosen_ground_primary_bounded_count", 0)),
				"dry_ground_two_sided": int((WarrenParcelizer.last_diagnostic.get(
					"connection", {}) as Dictionary).get(
					"chosen_ground_primary_two_sided_count", 0)),
			},
		}, "  "))
		quit(0)
		return
	if args.has("--built"):
		var built := WarrenBuiltTownSolver.solve_attempt(city_seed, attempt,
			program)
		if built == null:
			print("built rejected: %s" % WarrenBuiltTownSolver.last_failure)
			quit(1)
			return
		print("built audit=%s" % built.audit)
		print("built infill variants=%s" % [
			WarrenBuiltTownSolver.last_infill_variant_diagnostic])
	if args.has("--assets"):
		var assets := WarrenAssetCompiler.solve(town, program)
		if assets == null:
			print("asset rejected: %s" % WarrenAssetCompiler.last_failure)
			quit(1)
			return
		var dormers := 0
		var roof_seams := 0
		for placement: Dictionary in assets.expanded_placements():
			var asset_id := StringName(placement.asset_id)
			dormers += int(asset_id == SettlementFabricProgram.ROOF_WINDOW_01 \
				or asset_id == SettlementFabricProgram.ROOF_WINDOW_02 \
				or asset_id == SettlementFabricProgram.ROOF_WINDOW_03 \
				or asset_id == SettlementFabricProgram.ROOF_WINDOW_04)
			roof_seams += int(asset_id == SettlementFabricProgram.ROOF_SEAM)
		print("asset audit=%s dormers=%d roof_seam_modules=%d" % [
			assets.audit, dormers, roof_seams])
		for proposal: Dictionary in assets.proposals:
			var roof_recipes := PackedStringArray()
			for component: Dictionary in \
					StaggeredFabricCompiler.proposal_components(proposal):
				if StringName(component.role) == &"roof":
					roof_recipes.append(String(component.recipe_id))
			print("proposal=%s kind=%s base=%d storeys=%d facade=%s roof=%s recipe=%s" % [
				StringName(proposal.stable_id), StringName(proposal.kind),
				(proposal.origin as Vector3i).y, int(proposal.storeys),
				StringName(proposal.get("theme", "")),
				StringName(proposal.get("roof_theme", "")),
				",".join(roof_recipes)])
	if args.has("--roof-pair-candidates"):
		_print_atomic_roof_pair_candidates(town.volume, town.parcels, program)
	if args.has("--opposing-frontage-candidates"):
		_print_opposing_frontage_candidates(town.volume, town.parcels, program)
	var route: Dictionary = {}
	for route_cell: Vector3i in town.volume.primary_itinerary:
		route[route_cell] = true
	var extension_cells: Dictionary = {}
	for node_value: PublicRealmNode in town.public_realm.nodes:
		for fine_cell: Vector3i in node_value.surface_cells:
			var macro_cell := Vector3i(floori(float(fine_cell.x) / 2.0),
				fine_cell.y, floori(float(fine_cell.z) / 2.0))
			if not route.has(macro_cell) and not town.volume.has_walk(macro_cell):
				extension_cells[macro_cell] = true
	var minimum := Vector2i(2147483647, 2147483647)
	var maximum := Vector2i(-2147483648, -2147483648)
	var minimum_y := 2147483647
	var maximum_y := -2147483648
	for column_value: Variant in town.parcels.urban_core_columns.keys():
		var column := column_value as Vector2i
		minimum = minimum.min(column)
		maximum = maximum.max(column)
		minimum_y = mini(minimum_y, town.volume.envelope.ground_at(column))
		maximum_y = maxi(maximum_y, town.volume.envelope.top_at(column) - 1)
	print("seed=%d attempt=%d bounds=%s..%s y=%d..%d audit=%s" % [
		city_seed, attempt, minimum, maximum, minimum_y, maximum_y, town.audit])
	print("volume audit=%s" % [town.volume.audit])
	if args.has("--dump-route-interior"):
		print("route interior=%s" % [
			town.volume._exact_route_interior_cells().values()])
	print("parcel=%s" % WarrenParcelizer.last_diagnostic)
	print("infill=%s" % WarrenPlatformInfillSolver.last_diagnostic)
	for y in range(maximum_y, minimum_y - 1, -1):
		print("y=%d  B=building R=route A=arcade P=infill g=ground .=air" % y)
		for z in range(minimum.y, maximum.y + 1):
			var line := ""
			for x in range(minimum.x, maximum.x + 1):
				var cell := Vector3i(x, y, z)
				var column := Vector2i(x, z)
				if town.pruning.building_cells.has(cell):
					line += "B"
				elif route.has(cell):
					line += "R"
				elif town.volume.has_walk(cell):
					line += "A"
				elif extension_cells.has(cell):
					line += "P"
				elif town.volume.envelope.ground_at(column) == y:
					line += "g"
				else:
					line += "."
			print(line)
	quit(0)


static func _print_atomic_roof_pair_candidates(volume: WarrenVolumePlan,
		selected: WarrenParcelPlan, program: SettlementFabricProgram) -> void:
	## Diagnose the difference between a legal cross-gable in the complete
	## candidate vocabulary and one retained by horizontal packing.  This stays in
	## the worker-only harness: production consumes only the classifier/table.
	var candidates := WarrenParcelizer._candidates(volume)
	var compatible_count := 0
	var selected_count := 0
	var examples: Array[Dictionary] = []
	var selected_slots: Dictionary = {}
	for parcel: WarrenBuildingParcel in selected.parcels:
		selected_slots[parcel.slot_signature()] = true
	var cache: Dictionary = {&"enabled": true}
	for left_index in candidates.size():
		var left := candidates[left_index].parcel as WarrenBuildingParcel
		for right_index in range(left_index + 1, candidates.size()):
			var right := candidates[right_index].parcel as WarrenBuildingParcel
			if left.slot_signature() == right.slot_signature() \
					or not WarrenParcelizer._pair_has_atomic_perpendicular_roof(
						left, right):
				continue
			if not WarrenAssetCompiler.parcels_are_visually_compatible(left,
					right, program, cache):
				continue
			compatible_count += 1
			var retained := selected_slots.has(left.slot_signature()) \
				and selected_slots.has(right.slot_signature())
			selected_count += int(retained)
			if examples.size() < 12:
				examples.append({
					"left": left.slot_signature(),
					"right": right.slot_signature(),
					"retained": retained,
				})
	print("atomic_roof_pairs=%d retained=%d examples=%s" % [
		compatible_count, selected_count, examples])


static func _print_opposing_frontage_candidates(volume: WarrenVolumePlan,
		selected: WarrenParcelPlan, program: SettlementFabricProgram) -> void:
	## A topology score cannot select a canyon pair which the measured construction
	## vocabulary cannot build. Keep this distinction visible in the diagnostic
	## harness so production never grows attempt-specific placement exceptions.
	var candidates := WarrenParcelizer._candidates(volume)
	var selected_slots: Dictionary = {}
	for parcel: WarrenBuildingParcel in selected.parcels:
		selected_slots[parcel.slot_signature()] = true
	var compatible_by_role: Dictionary = {
		"ground_primary": 0,
		"ground_arcade": 0,
		"elevated_gallery": 0,
		"other": 0,
	}
	var retained_by_role := compatible_by_role.duplicate()
	var examples: Array[Dictionary] = []
	var cache: Dictionary = {&"enabled": true}
	for left_index in candidates.size():
		var left_candidate := candidates[left_index]
		var left := left_candidate.parcel as WarrenBuildingParcel
		for right_index in range(left_index + 1, candidates.size()):
			var right_candidate := candidates[right_index]
			var right := right_candidate.parcel as WarrenBuildingParcel
			if left.address_walk_cell != right.address_walk_cell \
					or left.frontage_direction != -right.frontage_direction \
					or left.slot_signature() == right.slot_signature() \
					or WarrenParcelizer._parcels_overlap(left, right):
				continue
			if not WarrenAssetCompiler.parcels_are_visually_compatible(left,
					right, program, cache):
				continue
			var role := "other"
			if bool(left_candidate.get("is_ground_primary", false)):
				role = "ground_primary"
			elif bool(left_candidate.get("is_ground_arcade", false)):
				role = "ground_arcade"
			elif bool(left_candidate.get("is_elevated_gallery", false)):
				role = "elevated_gallery"
			compatible_by_role[role] = int(compatible_by_role[role]) + 1
			var retained := selected_slots.has(left.slot_signature()) \
				and selected_slots.has(right.slot_signature())
			retained_by_role[role] = int(retained_by_role[role]) + int(retained)
			if examples.size() < 12:
				examples.append({
					"role": role,
					"walk": left.address_walk_cell,
					"left": left.slot_signature(),
					"right": right.slot_signature(),
					"retained": retained,
				})
	print("opposing_frontage_pairs=%s retained=%s examples=%s" % [
		compatible_by_role, retained_by_role, examples])


static func _argument_int(args: PackedStringArray, key: String,
		fallback: int) -> int:
	var index := args.find(key)
	return fallback if index < 0 or index + 1 >= args.size() \
		else int(args[index + 1])


static func _argument_string(args: PackedStringArray, key: String,
		fallback: String) -> String:
	var index := args.find(key)
	return fallback if index < 0 or index + 1 >= args.size() \
		else args[index + 1]
