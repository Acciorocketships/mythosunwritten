extends SceneTree

## Worker-only parcelization corpus.  This deliberately runs before assets so
## failures identify mass/address geometry rather than mesh-specific symptoms.


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var first_seed := _argument_int(args, "--first-seed", 0)
	var seed_count := _argument_int(args, "--seed-count", 12)
	var failures := 0
	var signatures: Dictionary = {}
	for world_seed in range(first_seed, first_seed + seed_count):
		var volume := WarrenPublicRealmCarver.solve(world_seed)
		var parcels := WarrenParcelizer.solve(volume)
		if parcels == null:
			failures += 1
			var diagnostic := WarrenParcelizer.diagnostic_solve(volume)
			print("seed=%d REJECTED volume=%s diagnostic_parcels=%d" % [
				world_seed, volume != null,
				0 if diagnostic == null else int(diagnostic.audit.parcel_count)])
			continue
		signatures[parcels.deterministic_signature()] = true
		print(("seed=%d parcels=%d bounded=%.2f bases=%d roofs=%d half=%d " \
			+ "elevated=%d spans=%d overpasses=%d families=%d stacked=%d " \
			+ "gaussian_open=%.2f core_open=%.2f roof_steps=%d low=%d " \
			+ "descents=%d/%d max_base=%.2f same_base=%.2f repeated=%d") % [
			world_seed, int(parcels.audit.parcel_count),
			float(parcels.audit.bounded_walk_ratio),
			int(parcels.audit.base_band_count),
			int(parcels.audit.roof_band_count),
			int(parcels.audit.half_level_neighbor_pair_count),
			int(parcels.audit.elevated_parcel_count),
			int(parcels.audit.mixed_span_parcel_count),
			int(parcels.audit.occupied_overpass_parcel_count),
			int(parcels.audit.footprint_family_count),
			int(parcels.audit.stacked_parcel_column_count),
			float(parcels.audit.deep_open_column_ratio),
			float(parcels.audit.urban_core_open_column_ratio),
			int(parcels.audit.stepped_roof_neighbor_pair_count),
			int(parcels.audit.low_roof_terminal_count),
			int(parcels.audit.stepped_descent_tall_parcel_count),
			int(parcels.audit.tall_parcel_count),
			float(parcels.audit.largest_base_band_ratio),
			float(parcels.audit.same_base_neighbor_ratio),
			int(parcels.audit.repeated_row_neighbor_pair_count),
		])
		if args.has("--print-map"):
			_print_top_map(volume, parcels)
		if args.has("--print-candidates"):
			_print_candidate_summary(volume)
	print("summary seeds=%d failures=%d unique=%d" % [
		seed_count, failures, signatures.size()])
	quit(0 if failures == 0 and signatures.size() == seed_count else 1)


static func _argument_int(args: PackedStringArray, key: String,
		fallback: int) -> int:
	var index := args.find(key)
	if index < 0 or index + 1 >= args.size():
		return fallback
	return int(args[index + 1])


static func _print_top_map(volume: WarrenVolumePlan,
		parcels: WarrenParcelPlan) -> void:
	var parcel_columns: Dictionary = {}
	for parcel: WarrenBuildingParcel in parcels.parcels:
		for column: Vector2i in parcel.footprint:
			parcel_columns[column] = true
	var walk_columns: Dictionary = {}
	for walk: Vector3i in volume.walk_cells:
		walk_columns[Vector2i(walk.x, walk.z)] = true
	print("  top map: B=parcel W=walk X=both .=open source column")
	for z in range(-volume.envelope.radius_z - 2,
			volume.envelope.radius_z + 3):
		var row := ""
		for x in range(-volume.envelope.radius_x - 2,
				volume.envelope.radius_x + 3):
			var column := Vector2i(x, z)
			if not volume.envelope.contains_column(column):
				row += " "
			elif parcel_columns.has(column) and walk_columns.has(column):
				row += "X"
			elif parcel_columns.has(column):
				row += "B"
			elif walk_columns.has(column):
				row += "W"
			else:
				row += "."
		print("  %s" % row)


static func _print_candidate_summary(volume: WarrenVolumePlan) -> void:
	var base_counts: Dictionary = {}
	var half_pair_count := 0
	var candidates := WarrenParcelizer._candidates(volume)
	for candidate: Dictionary in candidates:
		var parcel := candidate.parcel as WarrenBuildingParcel
		base_counts[parcel.base_band] = int(base_counts.get(parcel.base_band, 0)) + 1
	for left_index in candidates.size():
		var left := candidates[left_index].parcel as WarrenBuildingParcel
		for right_index in range(left_index + 1, candidates.size()):
			var right := candidates[right_index].parcel as WarrenBuildingParcel
			if absi(left.base_band - right.base_band) == 1 \
					and WarrenParcelizer._footprints_neighbor(left, right):
				half_pair_count += 1
	print("  candidates=%d bases=%s half_band_candidate_pairs=%d" % [
		candidates.size(), base_counts, half_pair_count])
