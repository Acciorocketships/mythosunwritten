extends SceneTree

## Scans the bounded volumetric topology family for construction-feasible
## combinations of an occupied skywalk reservation and opposing alley fronts.


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seed := _argument_int(args, "--seed", 6046713720826375059)
	var envelope := WarrenVolumeEnvelope.build(seed)
	var program := SettlementFabricProgram.compile(
		EnvironmentCatalog.load_default())
	assert(envelope != null and program != null)
	var rows: Array[Dictionary] = []
	for attempt in WarrenPublicRealmCarver.MAX_ATTEMPTS:
		var volume := WarrenPublicRealmCarver.sealed_candidate(seed, attempt,
			envelope)
		if volume == null:
			continue
		var pair_count := _opposing_pair_count(volume, program)
		var realm := WarrenVolumePublicRealmAdapter.from_volume(volume)
		var parcels := WarrenParcelizer.solve(volume,
			Callable(WarrenAssetCompiler,
				"parcels_are_visually_compatible").bind(program),
			Callable(WarrenAssetCompiler, "skywalk_reservation").bind(program,
				realm.air_claims()),
			Callable(WarrenAssetCompiler,
				"parcel_preserves_skywalk_reservation").bind(program))
		if pair_count > 0 or parcels != null:
			rows.append({
				"attempt": attempt,
				"opposing_pair_count": pair_count,
				"parcel_plan": parcels != null,
				"parcel_count": 0 if parcels == null else parcels.parcels.size(),
				"two_sided": 0.0 if parcels == null else float(
					parcels.audit.two_sided_walk_ratio),
				"overpasses": 0 if parcels == null else int(
					parcels.audit.occupied_overpass_parcel_count),
			})
	print(JSON.stringify({"seed": seed, "rows": rows}, "  "))
	quit(0)


static func _opposing_pair_count(volume: WarrenVolumePlan,
		program: SettlementFabricProgram) -> int:
	var candidates: Array[Dictionary] = WarrenParcelizer._candidates(volume)
	var result := 0
	for left_index in candidates.size():
		var left := candidates[left_index].parcel as WarrenBuildingParcel
		for right_index in range(left_index + 1, candidates.size()):
			var right := candidates[right_index].parcel as WarrenBuildingParcel
			if left.address_walk_cell == right.address_walk_cell \
					and right.frontage_direction == -left.frontage_direction \
					and not _overlap(left, right) \
					and WarrenAssetCompiler.parcels_are_visually_compatible(
						left, right, program):
				result += 1
	return result


static func _overlap(left: WarrenBuildingParcel,
		right: WarrenBuildingParcel) -> bool:
	var occupied: Dictionary = {}
	for cell: Vector3i in left.occupied_cells():
		occupied[cell] = true
	for cell: Vector3i in right.occupied_cells():
		if occupied.has(cell):
			return true
	return false


static func _argument_int(args: PackedStringArray, key: String,
		fallback: int) -> int:
	var index := args.find(key)
	return fallback if index < 0 or index + 1 >= args.size() \
		else int(args[index + 1])
