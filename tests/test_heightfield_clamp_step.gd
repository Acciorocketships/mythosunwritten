extends GutTest
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
	assert_eq(out[Vector2i(0, 0)], 3, "centre clamped to neighbour+3 (a 12m cliff)")
	# never MORE than 3 above any cardinal neighbour
	for cell: Vector2i in out:
		for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			if out.has(cell + d):
				assert_lte(out[cell] - out[cell + d], 3)
