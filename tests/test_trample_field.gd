extends GutTest

func _field() -> TrampleField:
	var field := TrampleField.new()
	field._initialize(Vector2.ZERO)
	return field

func test_stamp_direction_and_slow_recovery_round_trip() -> void:
	var field := _field()
	field.stamp(Vector3.ZERO, Vector2.RIGHT, 0.45, 1.0)
	var stored := field.sample(Vector2.ZERO)
	assert_almost_eq(stored.r, 1.0, 0.002)
	assert_almost_eq(stored.g, 0.5, 0.002)
	assert_almost_eq(stored.b, 1.0, 0.002)
	field._now = TrampleField.RECOVERY_SECONDS * 0.5
	assert_almost_eq(field.effective_strength(Vector2.ZERO), 0.75, 0.002)
	field._now = TrampleField.RECOVERY_SECONDS
	assert_almost_eq(field.effective_strength(Vector2.ZERO), 0.0, 0.002)
	field.free()

func test_player_wake_is_wide_and_strong_enough_for_collection_5() -> void:
	assert_gte(TrampleField.PLAYER_RADIUS, 1.0,
		"the moving footprint reaches many roots in a 2.6 m patch")
	assert_gte(TrampleField.MIN_MOVING_STRENGTH, 0.7,
		"ordinary walking produces a readable bend instead of a faint hint")
	assert_gte(TrampleField.RECOVERY_SECONDS, 10.0,
		"the parted wake remains visible long enough to look back at it")

func test_rewalking_merges_direction_and_refreshes_strength() -> void:
	var field := _field()
	field.stamp(Vector3.ZERO, Vector2.RIGHT, 0.45, 0.8)
	field._now = 3.0
	field.stamp(Vector3.ZERO, Vector2.DOWN, 0.45, 1.0)
	var stored := field.sample(Vector2.ZERO)
	var direction := (Vector2(stored.r, stored.g) * 2.0 - Vector2.ONE).normalized()
	assert_gt(direction.x, 0.0)
	assert_gt(direction.y, 0.0)
	assert_almost_eq(stored.b, 1.0, 0.002)
	assert_almost_eq(stored.a, 3.0, 0.01)
	field.free()

func test_static_footprint_uses_the_asset_outline_instead_of_its_radius() -> void:
	var field := _field()
	field.set_static_stamps([{
		"position": Vector3.ZERO,
		"points": PackedVector2Array([
			Vector2(-2.0, -0.5), Vector2(2.0, -0.5),
			Vector2(2.0, 0.5), Vector2(-2.0, 0.5),
		]),
		"radius": Vector2(2.0, 0.5).length(),
	}])
	assert_gt(field.static_strength(Vector2(1.0, 0.0)), 0.99)
	assert_eq(field.static_strength(Vector2(0.0, 1.25)), 0.0,
		"a point inside the old circular radius but outside the rock stays upright")
	var right_side := field.static_sample(Vector2(1.0, 0.0))
	assert_gt(right_side.r, 0.9,
		"static leaves spread radially out from the asset instead of due right everywhere")
	field.free()

func test_player_trail_recovers_without_changing_the_persistent_crush() -> void:
	var field := _field()
	field.set_static_stamps([{
		"position": Vector3.ZERO,
		"points": PackedVector2Array([
			Vector2(-1.0, -1.0), Vector2(1.0, -1.0),
			Vector2(1.0, 1.0), Vector2(-1.0, 1.0),
		]),
	}])
	field.stamp(Vector3.ZERO, Vector2.UP, 0.45, 1.0)
	field._now = TrampleField.RECOVERY_SECONDS * 0.5
	assert_almost_eq(field.effective_strength(Vector2.ZERO), 0.75, 0.002)
	assert_gt(field.static_strength(Vector2.ZERO), 0.99,
		"time changes only the player overlay; the rock layer cannot re-stamp or jump")
	field._now = TrampleField.RECOVERY_SECONDS
	assert_eq(field.effective_strength(Vector2.ZERO), 0.0)
	assert_gt(field.static_strength(Vector2.ZERO), 0.99)
	field.free()

func test_shader_blends_dynamic_direction_back_to_static_vertical_crush() -> void:
	var shader := load("res://terrain/grass/grass.gdshader") as Shader
	assert_not_null(shader)
	assert_true(shader.code.contains("grass_static_trample_texture"))
	assert_true(shader.code.contains("static_flatten * (1.0 - dynamic_flatten)"),
		"the static direction returns continuously as the player trail recovers")
	assert_true(shader.code.contains("max(STATIC_DROP * static_flatten"),
		"an asset keeps leaves pressed vertically while direction blends")

func test_epoch_rebase_preserves_effective_flatten() -> void:
	var field := _field()
	field._now = 59.0
	field.stamp(Vector3.ZERO, Vector2.RIGHT, 0.45, 1.0)
	field._now = 61.0
	var before := field.effective_strength(Vector2.ZERO)
	field._update_time(0.0)
	assert_almost_eq(field.effective_strength(Vector2.ZERO), before, 0.002)
	field.free()

func test_scrolling_preserves_world_anchored_trail_and_clears_new_border() -> void:
	var field := _field()
	field.stamp(Vector3.ZERO, Vector2.RIGHT, 0.45, 1.0)
	field._scroll_if_needed(Vector2(9.0, 0.0))
	assert_gt(field.sample(Vector2.ZERO).b, 0.99)
	assert_eq(field.sample(Vector2(40.0, 0.0)).b, 0.0)
	field.free()

func test_scroll_origin_is_published_atomically_with_shifted_texture() -> void:
	var field := _field()
	var uploaded_origin := field._texture_origin
	field._scroll_if_needed(Vector2(9.0, 0.0))
	assert_ne(field._origin, uploaded_origin)
	assert_eq(field._texture_origin, uploaded_origin,
		"old texture pixels keep their old world origin before the upload")
	field._upload_if_due(TrampleField.UPLOAD_INTERVAL)
	assert_eq(field._texture_origin, field._origin,
		"the shifted pixels and their new origin become one render snapshot")
	field.free()

func test_segment_rasterization_leaves_no_fast_movement_gaps() -> void:
	var field := _field()
	field.stamp_segment(Vector3(-5.0, 0.0, 0.0), Vector3(5.0, 0.0, 0.0),
		0.3, 1.0)
	for step in 41:
		var x := -5.0 + float(step) * 0.25
		assert_gt(field.sample(Vector2(x, 0.0)).b, 0.9)
	field.free()

func test_uploads_coalesce_and_obey_thirty_hertz_ceiling() -> void:
	var field := _field()
	field.stamp(Vector3.ZERO, Vector2.RIGHT, 0.45, 1.0)
	field._process(0.01)
	field._process(0.01)
	field._process(0.01)
	assert_eq(field.upload_count, 0)
	field._process(0.01)
	assert_eq(field.upload_count, 1)
	field.stamp(Vector3.ZERO, Vector2.UP, 0.45, 1.0)
	field._process(0.01)
	assert_eq(field.upload_count, 1)
	field.free()
