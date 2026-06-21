extends GutTest

## Regression: _ensure_seed_under_player must NOT seed a duplicate ground tile at
## y=0 when the player is standing on ELEVATED heightfield terrain.
##
## The void-probe historically checked only a thin band at the base level
## (y in [-1, +2]). A player on elevated terrain (storey >= 1, surface y >= 4)
## has their real ground tile ABOVE that band, so the probe saw "genuine void"
## and seeded a spurious ground tile at y=0 — underground. That seed then expanded
## via the socket queue into a whole section of base-level tiles (with foliage)
## sitting below the real terrain, punching the reported gaps in the ground.
## Near spawn the height falloff keeps terrain flat at y=0, so the bug only shows
## up after travelling onto raised ground.


func _make_generator() -> Node:
	return preload("res://scripts/terrain/TerrainGenerator.gd").new()


func _spawn_ground(lib: TerrainModuleLibrary) -> TerrainModuleInstance:
	return lib.get_random(lib.get_by_tags(TagList.new(["ground-plain"])), true).spawn()


func test_no_underground_seed_when_player_on_elevated_terrain() -> void:
	var gen = _make_generator()
	add_child_autofree(gen)
	gen.init_for_test()

	# A real ground tile already covers cell (0,0), raised two storeys (surface y = 8).
	var elevated_y: float = 8.0
	var tile: TerrainModuleInstance = _spawn_ground(gen.library)
	tile.set_transform(Transform3D(Basis.IDENTITY, Vector3(0.0, elevated_y, 0.0)))
	tile.create()
	gen.terrain_parent.add_child(tile.root)
	gen.register_piece(tile, "")

	# Player stands ON that elevated tile.
	gen.player.global_position = Vector3(0.0, elevated_y + 0.5, 0.0)

	var before: int = gen.terrain_parent.get_child_count()
	gen._ensure_seed_under_player()
	assert_eq(gen.terrain_parent.get_child_count(), before,
		"no duplicate tile seeded when elevated terrain already covers the cell")

	# Nothing must exist in the base-level band where the spurious seed would land.
	var low_box: AABB = AABB(Vector3(-1.0, -2.0, -1.0), Vector3(2.0, 4.0, 2.0))  # y in [-2, +2]
	var low_hits: int = 0
	for hit in gen.terrain_index.query_box(low_box):
		if hit is TerrainModuleInstance:
			low_hits += 1
	assert_eq(low_hits, 0, "no ground tile seeded at the base level under elevated terrain")


func test_still_seeds_into_genuine_void() -> void:
	# The fix must keep the original behaviour: a player over true void (no tile at
	# any height in the cell) still gets a fresh ground tile seeded beneath them.
	var gen = _make_generator()
	add_child_autofree(gen)
	gen.init_for_test()
	gen.player.global_position = Vector3(1000.0 * 24.0, 0.0, 1000.0 * 24.0)

	var before: int = gen.terrain_parent.get_child_count()
	gen._ensure_seed_under_player()
	assert_gt(gen.terrain_parent.get_child_count(), before,
		"a player over genuine void still gets a seed tile")
