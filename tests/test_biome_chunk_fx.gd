extends GutTest
## BiomeChunkFx builds render-only pocket fog + particles + orb lights from a profile.

func test_marsh_builds_fog_two_emitters_and_orbs() -> void:
	var marsh := BiomeRegistry.profile(&"twilight_marsh")
	var orbs := [Vector3(10, 3, 10), Vector3(20, 3, 40)]
	var fx := BiomeChunkFx.build(marsh, orbs)
	assert_not_null(fx.find_child("PocketFog", true, false), "marsh has a pocket FogVolume")
	var emitters := 0
	var lights := 0
	for c in fx.get_children():
		if c is GPUParticles3D:
			emitters += 1
		if c is OmniLight3D:
			lights += 1
	assert_eq(emitters, marsh.particles.size(), "one emitter per particle recipe (orbs+fireflies=2)")
	assert_eq(lights, orbs.size(), "one omni light per orb point")
	fx.free()

func test_meadow_no_fog_no_orbs_one_emitter() -> void:
	var meadow := BiomeRegistry.profile(&"meadow")
	var fx := BiomeChunkFx.build(meadow, [])
	assert_null(fx.find_child("PocketFog", true, false), "meadow has no pocket fog")
	var emitters := 0
	for c in fx.get_children():
		if c is GPUParticles3D:
			emitters += 1
	assert_eq(emitters, 1, "meadow emits motes only")
	fx.free()
