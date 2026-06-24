extends GutTest

## End-to-end: real cliff/slope variant scenes expose slope-categorized top
## sockets, and those sockets can never roll a hill size after gating.

func test_slope_sockets_cannot_roll_structures() -> void:
	var modules: Array[TerrainModule] = TerrainModuleDefinitions.load_cliff_variants()
	assert_gt(modules.size(), 0, "load_cliff_variants returned no modules")
	var slope_sockets_checked := 0
	for m: TerrainModule in modules:
		var inst := TerrainModuleInstance.new(m)
		var root := inst.create()
		if root == null:
			continue
		add_child_autofree(root)
		for socket_name: String in inst.sockets.keys():
			if inst.get_socket_category(socket_name) != "slope":
				continue
			if not m.socket_size.has(socket_name):
				continue
			var filtered := TerrainSpawnConfig.filter_for_category(
				m.socket_size[socket_name], "slope"
			)
			for size_key: String in filtered.dist.keys():
				assert_false(
					size_key in TerrainSpawnConfig.STRUCTURE_SIZES,
					"%s socket %s can still roll structure size %s" % [
						(m.tags.tags[0] if m.tags.size() > 0 else "<no_tag>"), socket_name, size_key]
				)
			slope_sockets_checked += 1
	assert_gt(slope_sockets_checked, 0,
		"expected at least one slope-categorized top socket across cliff variants")
