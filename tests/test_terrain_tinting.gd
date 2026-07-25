extends GutTest
# Every terrain surface must pull albedo from THE shared material and modulate
# it by the SAME biome ground tint — lips/aprons/skirt may never drift from the
# sheet (owner: "they really should be pulling from the exact same colour/
# material so that we cant see the seams between them, and so if we want to
# change the grass colour in the future we don't run into issues").

const Dress := preload("res://scripts/terrain/field/CliffDressing.gd")
const Mesher := preload("res://scripts/terrain/field/TerrainChunkMesher.gd")
const Plan := preload("res://scripts/terrain/heightfield/HeightfieldPlan.gd")

const OWNER_SEED := 2697992464


func test_shared_material_reads_vertex_colour() -> void:
	var mat := Dress.shared_material() as StandardMaterial3D
	assert_not_null(mat, "shared material is the KayKit standard material")
	assert_eq(mat.resource_path, Dress.GROUND_PALETTE,
		"global ground colour has one stable runtime editing point")
	assert_true(mat.vertex_color_use_as_albedo,
		"shared material must modulate by COLOR so vertex/instance tints apply")


func test_sheet_and_dressing_share_one_material_instance() -> void:
	# "pulling from the exact same colour/material": not equal-looking — the SAME
	# Material object, so a future palette change can never split them again.
	var mesher := Mesher.new()
	assert_eq(mesher._ground_tinted_mat(), Dress.shared_material(),
		"walkable sheet and dressing pieces share one Material instance")


func test_dressing_tints_track_the_biome_field() -> void:
	# compute_tints is the pure core build() uses for per-instance colours: each
	# piece samples the blended ground tint at its own origin — identical source
	# to the sheet's corner-tint lattice.
	var transforms := [
		Transform3D(Basis.IDENTITY, Vector3(-24.0, 24.0, -792.0)),   # twilight-marsh core (probe-verified)
		Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 0.0)),
	]
	var tints := Dress.compute_tints(transforms, OWNER_SEED)
	assert_eq(tints.size(), transforms.size())
	for i in transforms.size():
		var want := BiomeRegistry.ground_tint_at(
			transforms[i].origin, OWNER_SEED)
		assert_almost_eq(tints[i].r, want.r, 0.001, "tint %d tracks the biome field (r)" % i)
		assert_almost_eq(tints[i].g, want.g, 0.001, "tint %d tracks the biome field (g)" % i)
		assert_almost_eq(tints[i].b, want.b, 0.001, "tint %d tracks the biome field (b)" % i)
	# Marsh ground is far darker than white — the untinted-piece bug reads instantly.
	assert_lt(tints[0].g, 0.8, "marsh tint must actually darken (untinted pieces glow)")


func test_ground_patch_field_is_subtle_continuous_and_not_biome_locked() -> void:
	var a := BiomeRegistry.ground_patch_tint(Vector3(12.0, 0.0, 18.0), OWNER_SEED)
	var nearby := BiomeRegistry.ground_patch_tint(
		Vector3(12.01, 0.0, 18.01), OWNER_SEED)
	var other := BiomeRegistry.ground_patch_tint(
		Vector3(132.0, 0.0, 18.0), OWNER_SEED)
	assert_lt(Vector3(a.r, a.g, a.b).distance_to(
		Vector3(nearby.r, nearby.g, nearby.b)), 0.001,
		"world patches vary continuously rather than per cell")
	assert_gt(Vector3(a.r, a.g, a.b).distance_to(
		Vector3(other.r, other.g, other.b)), 0.001,
		"the patch field can vary colour inside one biome")
	for channel: float in [a.r, a.g, a.b, other.r, other.g, other.b]:
		assert_between(channel, 0.92, 1.08,
			"patches remain subtle multipliers over the biome tint")


func test_dense_grass_and_terrain_expose_one_live_palette_binding() -> void:
	var material := Dress.shared_material() as StandardMaterial3D
	assert_same(Dress.ground_texture(), material.albedo_texture,
		"the ground palette is one texture object, not copied colours")
	assert_true(Dress.ground_uv().x >= 0.0 and Dress.ground_uv().x <= 1.0)
	assert_true(Dress.ground_uv().y >= 0.0 and Dress.ground_uv().y <= 1.0)


func test_every_lip_grass_face_samples_the_ground_sheets_exact_texel() -> void:
	# A shared material is insufficient: the imported straight lip used five
	# different grass texels, which stayed visibly brighter than the sheet even
	# in an unshaded texture-only render. All upward grass faces must use the
	# sheet's one interior atlas texel. The bevel keeps its authored geometry and
	# normals, but its grass albedo may not form a bright triangular run-end flare.
	Dress._ensure_loaded()
	var want := Dress.ground_uv()
	for key in ["lip", "outer_lip", "inner_lip"]:
		var mesh := Dress._pieces[key][0] as Mesh
		var arrays := mesh.surface_get_arrays(0)
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var matched := 0
		for i in uvs.size():
			if uvs[i].x >= 0.15 or uvs[i].y >= 0.15:
				continue
			assert_almost_eq(uvs[i].x, want.x, 0.000001,
				"%s top uv.x matches the terrain sheet" % key)
			assert_almost_eq(uvs[i].y, want.y, 0.000001,
				"%s top uv.y matches the terrain sheet" % key)
			matched += 1
		assert_gt(matched, 0, "%s has a grass face under test" % key)


func test_seed_zero_keeps_dressing_untinted_white() -> void:
	# Headless piece tests build without a seed — they must stay palette-true.
	var tints := Dress.compute_tints([Transform3D.IDENTITY], 0)
	assert_eq(tints[0], Color(1, 1, 1), "seed 0 (tests) = identity tint")


func test_built_dressing_multimeshes_carry_instance_colours() -> void:
	# A marsh chunk with cliffs (cell -1,-33 -> chunk -1,-5; probe-verified
	# relief 3) builds with per-instance colours enabled on every piece MultiMesh.
	var plan := Plan.new(OWNER_SEED, 22.0, 8, "mean", 3)
	plan.set_water_plan(WaterPlan.new(OWNER_SEED, 22.0, 8))
	var region = plan.compute_region(-4, -36, 8)
	var dressing := Dress.build(region, -8, -40, 8, OWNER_SEED)
	var any := false
	for child in dressing.get_children():
		var mm: MultiMesh = (child as MultiMeshInstance3D).multimesh
		if mm.instance_count == 0:
			continue
		assert_true(mm.use_colors, "%s must use per-instance colours" % child.name)
		any = true
	assert_true(any, "the marsh chunk should place at least one dressing piece")
	dressing.free()
