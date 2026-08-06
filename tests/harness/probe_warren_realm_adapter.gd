extends SceneTree


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var world_seed := 0
	var seed_index := args.find("--seed")
	if seed_index >= 0 and seed_index + 1 < args.size():
		world_seed = int(args[seed_index + 1])
	var volume := WarrenPublicRealmCarver.solve(world_seed)
	var realm := WarrenVolumePublicRealmAdapter.from_volume(volume)
	if realm == null:
		print("seed=%d rejected: %s" % [world_seed,
			WarrenVolumePublicRealmAdapter.last_failure])
		quit(1)
		return
	print("seed=%d nodes=%d edges=%d audit=%s" % [world_seed,
		realm.nodes.size(), realm.edges.size(), realm.audit])
	quit(0)
