extends GutTest

## Biome field and biome-aware sampling tests.

var _nodes_to_free: Array[Node] = []


func before_each() -> void:
	_nodes_to_free.clear()


func after_each() -> void:
	for n: Node in _nodes_to_free:
		if is_instance_valid(n):
			if n.get_parent() != null:
				n.get_parent().remove_child(n)
			n.free()
	_nodes_to_free.clear()


func test_biome_fields_deterministic_and_varying() -> void:
	var world_seed: int = 99
	var pos: Vector3 = Vector3(300, 0, -120)
	assert_eq(Helper.biome_weights5(pos, world_seed), Helper.biome_weights5(pos, world_seed))
	var min_forest: float = 1.0
	var max_forest: float = 0.0
	for i in range(64):
		var p: Vector3 = Vector3(i * 97.0, 0.0, i * -53.0)
		var f: float = Helper.biome_forest01(p, world_seed)
		min_forest = minf(min_forest, f)
		max_forest = maxf(max_forest, f)
	assert_gt(max_forest - min_forest, 0.5, "forest field should span a wide range")

func test_biome_composition_shifts_with_fields() -> void:
	var world_seed: int = 7
	var forest_pos: Vector3 = Vector3.INF
	var rocky_pos: Vector3 = Vector3.INF
	for i in range(4000):
		var p: Vector3 = Vector3((i % 64) * 53.0, 0.0, (i / 64) * 47.0)
		# Pockets (marsh/blossom) claim weight first by design — sample outside
		# them so the forest/rocky composition shift is what's measured.
		if Helper.biome_marsh_pocket01(p, world_seed) > 0.05 \
				or Helper.biome_blossom_pocket01(p, world_seed) > 0.05:
			continue
		if forest_pos == Vector3.INF and Helper.biome_forest01(p, world_seed) > 0.9 \
				and Helper.biome_rocky01(p, world_seed) < 0.3:
			forest_pos = p
		if rocky_pos == Vector3.INF and Helper.biome_rocky01(p, world_seed) > 0.9 \
				and Helper.biome_forest01(p, world_seed) < 0.3:
			rocky_pos = p
		if forest_pos != Vector3.INF and rocky_pos != Vector3.INF:
			break
	assert_ne(forest_pos, Vector3.INF)
	assert_ne(rocky_pos, Vector3.INF)
	var fw := BiomeRegistry.blended_tag_weights(Helper.biome_weights5(forest_pos, world_seed))
	var rw := BiomeRegistry.blended_tag_weights(Helper.biome_weights5(rocky_pos, world_seed))
	assert_gt(fw["tree"], rw["tree"], "forests favour trees")
	assert_gt(rw["rock"], fw["rock"], "highlands favour rocks")
	assert_gt(BiomeRegistry.blended_density(Helper.biome_weights5(forest_pos, world_seed)), 1.0)


func test_weights5_normalized_and_deterministic() -> void:
	var s := 991177
	for i in range(48):
		var p := Vector3(i * 311.0 - 7000.0, 0.0, i * -173.0 + 2000.0)
		var w := Helper.biome_weights5(p, s)
		assert_eq(w.size(), 5)
		var total := 0.0
		for k: StringName in w:
			assert_between(w[k], 0.0, 1.0, "weight %s in range" % k)
			total += w[k]
		assert_almost_eq(total, 1.0, 1e-5, "weights sum to 1")
		assert_eq(w, Helper.biome_weights5(p, s), "deterministic")


func test_biome_at_is_argmax() -> void:
	var s := 991177
	var p := Vector3(1234.0, 0.0, -987.0)
	var w := Helper.biome_weights5(p, s)
	var best: StringName = &""
	var best_w := -1.0
	for k: StringName in w:
		if w[k] > best_w:
			best_w = w[k]
			best = k
	assert_eq(Helper.biome_at(p, s), best)


func test_biomes_persist_over_a_running_stretch() -> void:
	# Owner: "the biomes are a bit too small, they change really fast when you
	# run". Walk 25 straight 100m hops on the pinned owner seed; the dominant
	# biome should survive most hops once wavelengths are ~2.5x longer.
	var s := 2697992464
	var changes := 0
	var prev: StringName = Helper.biome_at(Vector3.ZERO, s)
	for i in range(1, 26):
		var b := Helper.biome_at(Vector3(float(i) * 100.0, 0.0, 0.0), s)
		if b != prev:
			changes += 1
		prev = b
	assert_lt(changes, 8, "biome flips every ~100m — biomes too small (%d changes)" % changes)


func test_pocket_census() -> void:
	var s := 991177
	var marsh := 0
	var blossom := 0
	var n := 0
	for iz in range(60):
		for ix in range(60):
			var p := Vector3(ix * 210.0 - 6300.0, 0.0, iz * 210.0 - 6300.0)
			n += 1
			match Helper.biome_at(p, s):
				&"twilight_marsh": marsh += 1
				&"blossom_grove": blossom += 1
	assert_between(float(marsh) / float(n), 0.01, 0.06, "marsh pockets ~2-4%% of area")
	assert_between(float(blossom) / float(n), 0.02, 0.08, "blossom groves ~4-6%% of area")

