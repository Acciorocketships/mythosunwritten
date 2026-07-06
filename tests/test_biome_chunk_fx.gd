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

func test_glow_recipes_are_soft_billboards() -> void:
	# Owner (round 2, superseding the sphere ask): "much more glowy so you cant
	# see a hard outline of their shape" + "particles that are just tiny 2d
	# squares ... move to the floating orb version". Every glow recipe renders
	# as a billboard with the shared radial-falloff texture, additive-blended.
	for recipe: StringName in [&"orbs", &"fireflies", &"motes"]:
		var e := BiomeChunkFx._emitter(recipe, 0.5, 0.0, 24.0)
		var mesh := e.draw_pass_1 as QuadMesh
		assert_not_null(mesh, "%s must be a billboard quad" % recipe)
		var mat := mesh.material as StandardMaterial3D
		assert_not_null(mat.albedo_texture, "%s needs the radial soft-glow texture (no hard outline)" % recipe)
		assert_eq(mat.blend_mode, BaseMaterial3D.BLEND_MODE_ADD, "%s must be additive (soft edges)" % recipe)
		assert_true(mat.emission_enabled, "%s must bloom" % recipe)
		e.free()

func test_petals_keep_alpha_but_get_the_soft_texture() -> void:
	var e := BiomeChunkFx._emitter(&"petals", 0.5, 0.0, 24.0)
	var mat := (e.draw_pass_1 as QuadMesh).material as StandardMaterial3D
	assert_not_null(mat.albedo_texture, "petals lose their hard square edge too")
	assert_eq(mat.blend_mode, BaseMaterial3D.BLEND_MODE_MIX, "petals stay alpha-blended, not additive")
	e.free()

func test_emitter_aabb_contains_emission_box() -> void:
	# Owner: "when you walk too close, they disappear" — the emission box was
	# world-space centred on the chunk CORNER while the visibility AABB spanned
	# the chunk; 3/4 of the particles sat outside it and the whole system
	# frustum-culled once the in-AABB quadrant left view.
	var e := BiomeChunkFx._emitter(&"orbs", 0.5, 4.0, 28.0)
	var m := e.process_material as ParticleProcessMaterial
	var lo := m.emission_shape_offset - m.emission_box_extents
	var hi := m.emission_shape_offset + m.emission_box_extents
	assert_true(e.visibility_aabb.has_point(lo) and e.visibility_aabb.has_point(hi),
		"visibility AABB %s must contain emission box %s..%s" % [e.visibility_aabb, lo, hi])
	assert_true(e.local_coords, "local coords: AABB and emission share the node's space")
	e.free()

func test_emission_band_follows_surface_heights() -> void:
	# Particles hover over the chunk's actual ground band, not around y=0.
	var e := BiomeChunkFx._emitter(&"orbs", 0.5, 8.0, 20.0)
	var m := e.process_material as ParticleProcessMaterial
	assert_between(m.emission_shape_offset.y, 8.0, 20.0 + 10.0, "emission band sits over the surface range")
	e.free()
