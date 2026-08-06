extends SceneTree

## Worker-only integration probe for public surface, entrance, lightwell, and
## guard derivation across genuinely different volumetric towns.


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var first_seed := _argument_int(args, "--first-seed", 0)
	var seed_count := _argument_int(args, "--seed-count", 12)
	var failures := 0
	for world_seed in range(first_seed, first_seed + seed_count):
		var volume := WarrenPublicRealmCarver.solve(world_seed)
		var parcels := WarrenParcelizer.solve(volume)
		var pruning := WarrenMassPruner.solve(volume, parcels)
		var realm := WarrenVolumePublicRealmAdapter.from_volume(volume)
		var surfaces := WarrenVolumeSurfaceCompiler.solve(volume, realm,
			parcels, pruning)
		if surfaces == null:
			failures += 1
			print("seed=%d REJECTED: %s" % [world_seed,
				WarrenVolumeSurfaceCompiler.last_failure])
			continue
		var audit := surfaces.audit()
		print(("seed=%d cells=%d patches=%d stairs=%d meshes=%d tris=%d " \
			+ "entrances=%d/%d guards=%d lightwell=%d unbounded=%d") % [world_seed,
			int(audit.surface_cell_count), int(audit.surface_patch_count),
			int(audit.stair_surface_cell_count),
			int(audit.transition_mesh_count), int(audit.transition_triangle_count),
			int(audit.served_entrance_count), int(audit.entrance_count),
			int(audit.derived_guard_segment_count),
			int(audit.daylight_void_guard_segment_count),
			int(audit.daylight_void_unbounded_edge_count)])
	print("summary seeds=%d failures=%d" % [seed_count, failures])
	quit(0 if failures == 0 else 1)


static func _argument_int(args: PackedStringArray, key: String,
		fallback: int) -> int:
	var index := args.find(key)
	if index < 0 or index + 1 >= args.size():
		return fallback
	return int(args[index + 1])
