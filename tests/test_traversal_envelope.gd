extends GutTest

const CharacterScript := preload("res://characters/character.gd")

func test_live_player_capsule_matches_the_shared_contract() -> void:
	var character := (load("res://characters/character.tscn") as PackedScene).instantiate()
	var collision := character.get_node("CollisionShape3D") as CollisionShape3D
	var capsule := collision.shape as CapsuleShape3D
	assert_not_null(capsule)
	assert_almost_eq(capsule.radius, TraversalEnvelope.CAPSULE_RADIUS, 0.000001,
		"changing the player radius requires a traversal-contract update")
	assert_almost_eq(capsule.height, TraversalEnvelope.CAPSULE_HEIGHT, 0.000001,
		"changing the player height requires a traversal-contract update")
	assert_almost_eq(CharacterScript.DEFAULT_MAX_STEP_HEIGHT,
		TraversalEnvelope.MAX_FINISHED_STEP, 0.000001,
		"the structural and controller step limits must remain coupled")
	character.free()

func test_aperture_and_headroom_include_real_capsule_margin() -> void:
	assert_gt(TraversalEnvelope.MIN_APERTURE_WIDTH,
		TraversalEnvelope.capsule_diameter())
	assert_gt(TraversalEnvelope.MIN_HEADROOM, TraversalEnvelope.CAPSULE_HEIGHT)
	assert_true(TraversalEnvelope.fits_passage(1.0, 2.4))
	assert_false(TraversalEnvelope.fits_passage(0.99, 2.4))
	assert_false(TraversalEnvelope.fits_passage(1.0, 2.39))

func test_planning_step_retains_tolerance_below_physics_limit() -> void:
	assert_lt(TraversalEnvelope.MAX_PLANNED_STEP,
		TraversalEnvelope.MAX_FINISHED_STEP)
	assert_true(TraversalEnvelope.step_is_legal(0.48))
	assert_false(TraversalEnvelope.step_is_legal(0.49))
	assert_true(TraversalEnvelope.step_is_legal(0.5, false))
