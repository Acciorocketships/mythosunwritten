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


func _new_generator() -> Variant:
	var Generator: Script = load("res://scripts/terrain/TerrainGenerator.gd")
	var g: Variant = Generator.new()
	_nodes_to_free.append(g)
	g.world_seed = 424242
	return g


func test_biome_fields_deterministic_and_varying() -> void:
	var world_seed: int = 99
	var pos: Vector3 = Vector3(300, 0, -120)
	assert_eq(
		Helper.biome_weights(pos, world_seed),
		Helper.biome_weights(pos, world_seed),
		"biome weights must be deterministic per position+seed"
	)
	assert_eq(
		Helper.biome_foliage_density(pos, world_seed),
		Helper.biome_foliage_density(pos, world_seed),
		"foliage density must be deterministic per position+seed"
	)
	# The fields must actually vary across the map (not constant).
	var min_forest: float = 1.0
	var max_forest: float = 0.0
	for i in range(64):
		var p: Vector3 = Vector3(i * 97.0, 0.0, i * -53.0)
		var f: float = Helper.biome_forest01(p, world_seed)
		min_forest = minf(min_forest, f)
		max_forest = maxf(max_forest, f)
	assert_gt(max_forest - min_forest, 0.5, "forest field should span a wide range across space")


func test_biome_weights_shape() -> void:
	var world_seed: int = 7
	# Find a strong forest position and a strong rocky position.
	var forest_pos: Vector3 = Vector3.INF
	var rocky_pos: Vector3 = Vector3.INF
	for i in range(4000):
		var p: Vector3 = Vector3((i % 64) * 53.0, 0.0, (i / 64) * 47.0)
		if forest_pos == Vector3.INF and Helper.biome_forest01(p, world_seed) > 0.9:
			if Helper.biome_rocky01(p, world_seed) < 0.3:
				forest_pos = p
		if rocky_pos == Vector3.INF and Helper.biome_rocky01(p, world_seed) > 0.9:
			if Helper.biome_forest01(p, world_seed) < 0.3:
				rocky_pos = p
		if forest_pos != Vector3.INF and rocky_pos != Vector3.INF:
			break
	assert_ne(forest_pos, Vector3.INF, "must find a forest core in the sample area")
	assert_ne(rocky_pos, Vector3.INF, "must find a rocky core in the sample area")

	var forest_weights: Dictionary = Helper.biome_weights(forest_pos, world_seed)
	var rocky_weights: Dictionary = Helper.biome_weights(rocky_pos, world_seed)
	assert_gt(forest_weights["tree"], rocky_weights["tree"], "forests favour trees")
	assert_gt(rocky_weights["rock"], forest_weights["rock"], "rocky biomes favour rocks")
	assert_gt(
		rocky_weights["cliff-base-side"], forest_weights["cliff-base-side"],
		"rocky biomes favour cliff seeds"
	)
	assert_almost_eq(
		rocky_weights["cliff-base-side"], rocky_weights["24x24x4"], 0.0001,
		"cliff tag and size weights must match so the size/tag rolls stay consistent"
	)
	assert_gt(
		Helper.biome_foliage_density(forest_pos, world_seed), 1.0,
		"forests should be denser than the neutral baseline"
	)


func test_biome_scaled_dist_preserves_unknown_tags_and_normalises() -> void:
	var density := TerrainDensity.new(424242)
	var dist: Distribution = Distribution.new({"ground-plain": 0.5, "unknown-tag": 0.5})
	var scaled: Distribution = density.biome_scaled_dist(dist, Vector3(500, 0, 500))
	# Neither tag is in the biome weights table, so the distribution is
	# returned untouched.
	assert_eq(scaled.dist, dist.dist, "distributions without biome tags pass through unchanged")

	var foliage: Distribution = Distribution.new(
		{"grass": 0.25, "rock": 0.25, "bush": 0.25, "tree": 0.25}
	)
	var foliage_scaled: Distribution = density.biome_scaled_dist(foliage, Vector3(500, 0, 500))
	var total: float = 0.0
	for tag in foliage_scaled.dist.keys():
		total += foliage_scaled.dist[tag]
	assert_almost_eq(total, 1.0, 0.0001, "scaled distribution must be renormalised")
	assert_eq(foliage_scaled.dist.size(), 4, "scaling must not add or drop tags")


func test_biome_scaled_dist_leaves_single_entry_untouched() -> void:
	var density := TerrainDensity.new(424242)
	var dist: Distribution = Distribution.new({"tree": 1.0})
	var scaled: Distribution = density.biome_scaled_dist(dist, Vector3(123, 0, 456))
	assert_eq(scaled.prob("tree"), 1.0, "single-entry distributions renormalise to themselves")


