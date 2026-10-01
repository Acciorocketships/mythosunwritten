extends GutTest
# Keys are lattice POINTS (12 m apart): a step of 3 storeys is a 12 m cliff over one
# point spacing, and "neighbour" means the cardinal point 12 m away.
const Plan := preload("res://scripts/terrain/heightfield/HeightfieldPlan.gd")

func test_default_step_is_one():
	# A spike of storey 9 surrounded by 0 clamps to 1 at the cardinal neighbour (step 1).
	var targets := {}
	for dz in range(-12, 13):
		for dx in range(-12, 13):
			targets[Vector2i(dx, dz)] = 9 if (dx == 0 and dz == 0) else 0
	var out := Plan.clamp_field(targets)            # default max_step = 1
	assert_eq(out[Vector2i(0, 0)], 1, "centre clamped to neighbour+1")

func test_step_three_allows_taller_cliffs():
	var targets := {}
	for dz in range(-12, 13):
		for dx in range(-12, 13):
			targets[Vector2i(dx, dz)] = 9 if (dx == 0 and dz == 0) else 0
	var out := Plan.clamp_field(targets, 3)         # max_step = 3
	assert_eq(out[Vector2i(0, 0)], 3, "centre clamped to neighbour+3 (a 12m cliff across one 12 m point step)")
	# never MORE than 3 above any cardinal neighbour
	for cell: Vector2i in out:
		for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			if out.has(cell + d):
				assert_lte(out[cell] - out[cell + d], 3)

func _spike_field(height: int) -> Dictionary:
	var targets := {}
	for dz in range(-12, 13):
		for dx in range(-12, 13):
			targets[Vector2i(dx, dz)] = height if (dx == 0 and dz == 0) else 0
	return targets

func test_step_three_fixpoint_is_order_independent() -> void:
	var a := _spike_field(9)
	a[Vector2i(3, 0)] = 9
	a[Vector2i(3, 1)] = 7
	var reversed := {}
	var keys: Array = a.keys()
	keys.reverse()
	for k in keys:
		reversed[k] = a[k]
	assert_eq(Plan.clamp_field(a, 3), Plan.clamp_field(reversed, 3),
		"the point clamp has a unique fixpoint regardless of key order")

func test_step_three_staircase_between_distant_points() -> void:
	# A tall plateau one point wide beside ground: each point further from the
	# ground may rise at most 3 storeys per 12 m point step.
	var targets := {}
	for x in range(0, 6):
		targets[Vector2i(x, 0)] = 12 if x > 0 else 0
	var out := Plan.clamp_field(targets, 3)
	assert_eq(out[Vector2i(0, 0)], 0)
	assert_eq(out[Vector2i(1, 0)], 3)
	assert_eq(out[Vector2i(2, 0)], 6)
	assert_eq(out[Vector2i(3, 0)], 9)
	assert_eq(out[Vector2i(4, 0)], 12)
