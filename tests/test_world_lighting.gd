extends GutTest
# Owner round 11 (seed 3960904676): a south-facing 1-storey wall read from above as a flat
# pale-blue strip — "skirt still a different color than the slop[e] from some angles". The
# sun sits low in the north (18° elevation), so every south-facing stone face is lit ONLY by
# ambient; with ambient_light_source = SKY that ambient is saturated sky-blue, and neutral-grey
# KayKit stone under pure blue light renders the exact colour of sky/water while the sunlit
# grass beside it stays green. (Round 7 killed the specular half of this; the ambient tint is
# the other half.) Shadow fill must come from a warm-neutral ambient COLOUR so unlit stone
# still reads as stone.

func test_world_ambient_is_a_neutral_colour_not_the_blue_sky() -> void:
	var packed: PackedScene = load("res://scenes/world.tscn")
	var world := packed.instantiate()
	var we: WorldEnvironment = world.get_node("WorldEnvironment")
	var env: Environment = we.environment
	assert_eq(env.ambient_light_source, Environment.AMBIENT_SOURCE_COLOR,
		"shadow ambient must be a fixed neutral colour, not the blue sky")
	var c := env.ambient_light_color
	assert_gt(c.r, 0.4, "ambient colour must actually fill the shadows (not near-black)")
	assert_true(c.r >= c.g and c.g >= c.b,
		"ambient colour must be warm-neutral — a blue-dominant fill recreates the water-blue cliff faces")
	world.free()
