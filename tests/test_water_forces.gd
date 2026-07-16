extends GutTest

const FORCES_PATH := "res://scripts/terrain/water/WaterForces.gd"


func _forces() -> Script:
	var script := load(FORCES_PATH) as Script
	assert_not_null(script,
		"water forces are a reusable pure helper, not character-only movement math")
	return script


func test_passive_buoyancy_has_a_stable_partly_submerged_equilibrium() -> void:
	var forces := _forces()
	if forces == null:
		return
	var gravity := Vector3(0.0, -18.0, 0.0)
	var buoyancy := 24.0
	var body_height := 1.4
	var equilibrium_fraction := absf(gravity.y) / buoyancy
	var bottom_y := -body_height * equilibrium_fraction
	var submerged: float = forces.call(
		"submerged_fraction", 0.0, bottom_y, body_height)
	var lift: Vector3 = forces.call(
		"buoyancy_acceleration", gravity, buoyancy, submerged)
	assert_almost_eq(submerged, equilibrium_fraction, 0.0001,
		"Archimedes fraction follows displaced body height")
	assert_almost_eq((gravity + lift).y, 0.0, 0.001,
		"idle body settles at the surface without holding jump")


func test_buoyancy_restores_from_both_sides_of_equilibrium() -> void:
	var forces := _forces()
	if forces == null:
		return
	var gravity := Vector3(0.0, -18.0, 0.0)
	var low_fraction: float = forces.call("submerged_fraction", 0.0, -1.2, 1.4)
	var high_fraction: float = forces.call("submerged_fraction", 0.0, -0.2, 1.4)
	var low_net: Vector3 = gravity + forces.call(
		"buoyancy_acceleration", gravity, 24.0, low_fraction)
	var high_net: Vector3 = gravity + forces.call(
		"buoyancy_acceleration", gravity, 24.0, high_fraction)
	assert_gt(low_net.y, 0.0, "a deeply submerged idle body rises")
	assert_lt(high_net.y, 0.0, "an over-high idle body falls back into the water")


func test_current_drag_pushes_downstream_and_converges_to_the_water_velocity() -> void:
	var forces := _forces()
	if forces == null:
		return
	var current := Vector2(4.0, -1.5)
	var from_rest: Vector2 = forces.call(
		"current_acceleration", current, Vector2.ZERO, 1.6)
	var matched: Vector2 = forces.call(
		"current_acceleration", current, current, 1.6)
	assert_gt(from_rest.dot(current), 0.0,
		"an idle body receives force in the downstream direction")
	assert_almost_eq(matched.length(), 0.0, 0.0001,
		"current force vanishes when the body moves with the water")


func test_character_consumes_the_same_sampler_current_as_water_simulation() -> void:
	var source := FileAccess.get_file_as_string("res://characters/character.gd")
	assert_true(source.contains("sampler.velocity_at(xz)"),
		"character reads the frozen continuous current field")
	assert_true(source.contains("WaterForces.current_acceleration"),
		"character drift is force coupling, reusable by future floating bodies")
	assert_true(source.contains("WaterForces.buoyancy_acceleration"),
		"character float uses the shared buoyancy force")
