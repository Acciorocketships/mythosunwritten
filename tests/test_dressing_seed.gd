extends GutTest

func test_face_noise_depends_on_world_seed() -> void:
	var differs := 0
	for x in 64:
		var face := Vector4i(x, 2, 3, 0)
		if SettlementFabricAssembler._face_noise(face, 11, 1) != SettlementFabricAssembler._face_noise(face, 11, 2):
			differs += 1
	assert_gt(differs, 50)


func _strip() -> Array:
	var garden: Dictionary = {}
	var walked: Dictionary = {}
	for x in 12:
		for z in 2:
			garden[Vector3i(x, 0, z)] = true
		walked[Vector3i(x, 1, -1)] = true
	return [garden, walked]


func _origins(sites: Array[Dictionary]) -> Array:
	var out: Array = []
	for site: Dictionary in sites:
		out.append(site.origin)
	return out


func test_lamp_stations_depend_on_world_seed() -> void:
	var g := _strip()
	var seen: Dictionary = {}
	for seed_value in [1, 2, 3, 4, 5, 6]:
		var sites := SettlementFabricAssembler.maze_garden_lamp_sites(g[0], {}, {},
			{}, {}, [] as Array[AABB], g[1], seed_value)
		assert_gt(sites.size(), 0)
		seen[str(_origins(sites))] = true
	assert_gt(seen.size(), 1, "lamp stations differ between world seeds")


func test_furniture_stations_depend_on_world_seed() -> void:
	var g := _strip()
	var seen: Dictionary = {}
	for seed_value in [1, 2, 3, 4, 5, 6]:
		var sites := SettlementFabricAssembler.maze_garden_furniture_sites(g[0], {}, {},
			{}, {}, [] as Array[AABB], g[1], {}, seed_value)
		assert_gt(sites.size(), 0)
		seen[str(_origins(sites))] = true
	assert_gt(seen.size(), 1, "furniture stations differ between world seeds")


func test_plaza_centre_pick_depends_on_world_seed() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var bounds := {}
	for asset: StringName in SettlementFabricAssembler.PLAZA_WIDE_FEATURES + SettlementFabricAssembler.PLAZA_COURT_TREES:
		bounds[asset] = catalog.descriptor(asset).measured_aabb
	var bed := {}
	for x in 6:
		for z in 6:
			bed[Vector3i(x, 0, z)] = true
	var seen: Dictionary = {}
	for seed_value in range(1, 13):
		var f := SettlementFabricAssembler.maze_plaza_centre_feature(bed, {},
			{"asset_bounds": bounds}, [] as Array[AABB], {}, true, seed_value)
		assert_false(f.is_empty())
		seen["%s/%s" % [f.get("asset", &""), f.get("quarter", 0)]] = true
	assert_gt(seen.size(), 1, "the centre piece or its turn differs between seeds")


func test_garden_dressing_differs_between_world_seeds() -> void:
	var g := _strip()
	var seen: Dictionary = {}
	for seed_value in [1, 2, 3, 4, 5, 6]:
		var sites := SettlementFabricAssembler.maze_garden_planting_sites(g[0], {}, {},
			{}, {}, {}, [] as Array[AABB], g[1], seed_value)
		var key: Array = []
		for site: Dictionary in sites:
			key.append([site.asset, site.origin])
		seen[str(key)] = true
	assert_gt(seen.size(), 1, "the garden planting differs between world seeds")


func test_facade_module_depends_on_world_seed() -> void:
	var differs := 0
	for x in 32:
		var key := Vector4i(x, 1, 2, 0)
		if SettlementFabricAssembler.maze_facade_module(key, 1) != SettlementFabricAssembler.maze_facade_module(key, 2):
			differs += 1
	assert_gt(differs, 0)
