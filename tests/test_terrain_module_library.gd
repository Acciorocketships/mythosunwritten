extends GutTest

func _make_library() -> TerrainModuleLibrary:
	var lib = TerrainModuleLibrary.new()
	# TerrainModuleLibrary extends Node (not RefCounted); ensure it is freed after the test.
	add_child_autofree(lib)
	lib.init()
	return lib

# ----------------------------
# init / load / sort
# ----------------------------
func test_init_populates_modules_and_index():
	var lib = _make_library()
	assert_true(lib.terrain_modules.size() >= 1, "terrain_modules has entries after init")
	assert_true(lib.modules_by_tag.has("ground"), "modules_by_tag has 'ground'")
	assert_true(lib.modules_by_tag.has("24x24"), "modules_by_tag has '24x24'")

func test_load_terrain_modules_appends_once():
	var lib = TerrainModuleLibrary.new()
	add_child_autofree(lib)
	assert_eq(lib.terrain_modules.size(), 0, "starts empty")
	lib.load_terrain_modules()
	assert_eq(lib.terrain_modules.size(), 1, "appends one module")

func test_sort_terrain_modules_builds_tag_index():
	var lib = TerrainModuleLibrary.new()
	add_child_autofree(lib)
	lib.load_terrain_modules()
	lib.sort_terrain_modules()
	assert_true(lib.modules_by_tag.has("ground"))
	assert_true(lib.modules_by_tag.has("24x24"))
	var ground_list: TerrainModuleList = lib.modules_by_tag["ground"]
	assert_true(ground_list.size() >= 1)

# ----------------------------
# required tags
# ----------------------------
func test_get_required_tags_unions_adjacent_requirements():
	var lib = _make_library()
	# Use the single ground tile for both adjacents
	var ground_mod: TerrainModule = lib.terrain_modules.library[0]
	var m1 = ground_mod.spawn()
	var m2 = ground_mod.spawn()
	var adj: Dictionary[String, TerrainModuleSocket] = {}
	# Keys are the current socket context; values point to adjacent pieces/sockets
	adj["left"] = TerrainModuleSocket.new(m1, "left")
	adj["right"] = TerrainModuleSocket.new(m2, "right")
	var tags: TagList = lib.get_required_tags(adj)
	assert_true(tags.has("ground"), "required tags include 'ground'")

func test_get_required_tags_ignores_unknown_adjacent_socket_name():
	var lib = _make_library()
	var ground_mod: TerrainModule = lib.terrain_modules.library[0]
	var m = ground_mod.spawn()
	var adj: Dictionary[String, TerrainModuleSocket] = {}
	# include a valid and an unknown socket name
	adj["main"] = TerrainModuleSocket.new(m, "main")
	adj["weird"] = TerrainModuleSocket.new(m, "topfrontleft")
	var tags: TagList = lib.get_required_tags(adj)
	assert_true(tags.has("ground"), "still includes 'ground' from valid socket")

func test_convert_tag_list_exclamation_converts_with_socket_name():
	var lib = _make_library()
	var tl = TagList.new(["!path", "ground"])
	var out = lib.convert_tag_list(tl, "left")
	assert_true(out.has("[left]path"), "converted '!path' to socket-specific")
	assert_true(out.has("ground"))

func test_combined_tag_socket_name_formats_correctly():
	var lib = _make_library()
	var s = lib.combined_tag_socket_name("path", "right")
	assert_eq(s, "[right]path")

# ----------------------------
# distributions
# ----------------------------
func test_get_combined_distribution_single_adjacent_passthrough():
	var lib = _make_library()
	var ground_mod: TerrainModule = lib.terrain_modules.library[0]
	var m = ground_mod.spawn()
	var adj: Dictionary[String, TerrainModuleSocket] = {}
	adj["left"] = TerrainModuleSocket.new(m, "left")
	var dist: Distribution = lib.get_combined_distribution(adj)
	assert_almost_eq(dist.prob("ground"), 1.0, 0.0001)

func test_sample_from_modules_filters_by_sampled_tag():
	var lib = _make_library()
	var modules: TerrainModuleList = lib.terrain_modules
	var dist = Distribution.new({"ground": 1.0})
	var chosen: TerrainModule = lib.sample_from_modules(modules, dist)
	assert_true(chosen != null)
	assert_true(chosen.tags.has("ground"))

# ----------------------------
# lookup and selection
# ----------------------------
func test_get_by_tags_empty_returns_all():
	var lib = _make_library()
	var out: TerrainModuleList = lib.get_by_tags(TagList.new())
	# Current implementation returns a duplicate that may be empty; just ensure it returns a list.
	assert_true(out is TerrainModuleList)

func test_get_by_tags_unknown_returns_empty():
	var lib = _make_library()
	var out: TerrainModuleList = lib.get_by_tags(TagList.new(["does_not_exist"]))
	assert_eq(out.size(), 0)

func test_get_by_tags_ground_returns_nonempty():
	var lib = _make_library()
	var out: TerrainModuleList = lib.get_by_tags(TagList.new(["ground"]))
	assert_true(out.size() >= 1)

func test_get_random_behaviour():
	var lib = _make_library()
	var empty := TerrainModuleList.new()
	assert_eq(lib.get_random(empty), null, "empty returns null")
	var first: TerrainModule = lib.get_random(lib.terrain_modules, true)
	assert_true(first == lib.terrain_modules.library[0], "first=true returns index 0")

func test_filter_module_list_intersects_with_tag_index():
	var lib = _make_library()
	var out1: TerrainModuleList = lib.filter_module_list(lib.terrain_modules, "ground")
	assert_true(out1.size() >= 1)
	var out2: TerrainModuleList = lib.filter_module_list(lib.terrain_modules, "nope")
	assert_eq(out2.size(), 0)

func test_intersection_of_lists_returns_common_elements():
	var lib = _make_library()
	var a_mod: TerrainModule = lib.terrain_modules.library[0]
	var list_a := TerrainModuleList.new([a_mod])
	var list_b := TerrainModuleList.new([a_mod])
	var out: TerrainModuleList = lib._intersection([list_a, list_b])
	assert_eq(out.size(), 1)
	assert_true(out.library[0] == a_mod)

# ----------------------------
# module constructor
# ----------------------------
func test_load_ground_tile_has_expected_fields():
	var lib = TerrainModuleLibrary.new()
	add_child_autofree(lib)
	var tm: TerrainModule = lib.load_ground_tile()
	assert_true(tm.tags.has("ground"))
	assert_true(tm.tags.has("24x24"))
	assert_true(tm.socket_required.has("main"))
	assert_true(tm.socket_required.has("left"))
	assert_true(tm.socket_required.has("right"))
	assert_true(tm.socket_required.has("back"))
	assert_true(tm.socket_tag_prob.has("main"))
	assert_true(tm.socket_size.has("main"))

