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
		var want := BiomeRegistry.blended_ground_tint(
			Helper.biome_weights5(transforms[i].origin, OWNER_SEED))
		assert_almost_eq(tints[i].r, want.r, 0.001, "tint %d tracks the biome field (r)" % i)
		assert_almost_eq(tints[i].g, want.g, 0.001, "tint %d tracks the biome field (g)" % i)
		assert_almost_eq(tints[i].b, want.b, 0.001, "tint %d tracks the biome field (b)" % i)
	# Marsh ground is far darker than white — the untinted-piece bug reads instantly.
	assert_lt(tints[0].g, 0.8, "marsh tint must actually darken (untinted pieces glow)")


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
