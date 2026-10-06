extends GutTest

## October 5: the world.tscn spawn (y 24) sat 56 m under its hill after the
## October 4 terrain amplification, and the player fell through the world on
## release. A held player is released onto the ground, never inside it.

func _corners(a: float, b: float, c: float, d: float) -> PackedFloat32Array:
	return PackedFloat32Array([a, b, c, d])

func test_buried_player_lifts_to_the_surface_hit() -> void:
	# The reported spawn: feet at 24, tile corners 75.8-88.0.
	var corners := _corners(75.84, 79.84, 75.86, 88.0)
	assert_almost_eq(FieldTerrainStreamer.release_height(24.0, corners, 79.84), 79.84, 0.0001)

func test_buried_player_without_a_hit_goes_to_the_highest_corner() -> void:
	var corners := _corners(75.84, 79.84, 75.86, 88.0)
	assert_almost_eq(FieldTerrainStreamer.release_height(24.0, corners, NAN), 88.0, 0.0001)

func test_player_on_or_above_the_ground_is_left_alone() -> void:
	var corners := _corners(75.84, 79.84, 75.86, 88.0)
	assert_true(is_nan(FieldTerrainStreamer.release_height(76.0, corners, 79.0)))
	assert_true(is_nan(FieldTerrainStreamer.release_height(120.0, corners, 79.0)))

func test_unknown_ground_is_left_alone() -> void:
	assert_true(is_nan(FieldTerrainStreamer.release_height(24.0, PackedFloat32Array(), NAN)))
