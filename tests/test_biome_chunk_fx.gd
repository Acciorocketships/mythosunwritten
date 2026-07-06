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

func test_orbs_are_emissive_spheres_not_flat_quads() -> void:
	# Owner ask: orbs are floating glowing 3D spheres of light, not 2D squares.
	var marsh := BiomeRegistry.profile(&"twilight_marsh")
	var fx := BiomeChunkFx.build(marsh, [])
	var orb := fx.find_child("orbs", true, false) as GPUParticles3D
	assert_not_null(orb, "marsh has an orbs emitter")
	assert_true(orb.draw_pass_1 is SphereMesh, "orbs draw as a 3D sphere mesh")
	var mat := orb.draw_pass_1.material as StandardMaterial3D
	assert_true(mat.emission_enabled, "orb spheres glow (emission on)")
	fx.free()
