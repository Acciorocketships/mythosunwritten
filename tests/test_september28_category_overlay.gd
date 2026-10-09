extends GutTest
## September 28 owner request: a diagnostic view that colour-codes the
## terrain's categories and shows where the levels are (F9). Since the
## dual-grid terrain (2026-09-30) it reads 12 m lattice points and its shader
## carries a GPU port of TerrainTileField.
const Plan := preload("res://scripts/terrain/heightfield/HeightfieldPlan.gd")
const OVERLAY := preload("res://scripts/terrain/tools/TerrainCategoryOverlay.gd")
const SHADER := preload("res://terrain/materials/debug/terrain_category_overlay.gdshader")
const PROBE := preload("res://tests/fixtures/terrain_tile_kernel_probe.gdshader")
const PROBE_SIZE := 64
const PROBE_TILES := 8       # 8 x 8 tiles, 8 x 8 samples each = 64 x 64 pixels
const PROBE_ORIGIN := Vector2i(-3, 5)


func test_point_snapshot_carries_each_points_surface_height_and_grade() -> void:
	var plan := Plan.new(0, 64.0, 12, "mean", 4)
	plan.set_raw_height_override(func(cx, cz): return 2.0 * float(cx) + float(posmod(cz, 3)))
	for chunk: Vector2i in [Vector2i.ZERO, Vector2i(-1, 1)]:
		var first := chunk * 16
		var region: HeightfieldRegion = plan.compute_region(first.x + 8, first.y + 8, 16)
		var values := FieldTerrainStreamer._point_snapshot(chunk, region)
		assert_eq(values.size(), 16 * 16 * 2, "one (height, graded) pair per owned point")
		var storeys := FieldTerrainStreamer._storey_snapshot(chunk, region)
		assert_eq(storeys.size(), 16 * 16)
		for z in 16:
			for x in 16:
				var point := first + Vector2i(x, z)
				assert_eq(values[(z * 16 + x) * 2], region.surface_height(point.x, point.y),
					"point %s height" % point)
				assert_eq(values[(z * 16 + x) * 2 + 1], 0.0, "no grade on natural ground")
				assert_eq(storeys[z * 16 + x], region.storey_at(point.x, point.y),
					"point %s storey" % point)


func test_overlay_toggles_one_screen_quad_and_its_legend() -> void:
	var world := Node3D.new()
	add_child_autofree(world)
	var overlay: CanvasLayer = OVERLAY.new()
	world.add_child(overlay)
	await wait_process_frames(1)
	overlay.set_enabled(true)
	await wait_process_frames(2)
	var quads := world.find_children("*", "MeshInstance3D", false, false)
	assert_eq(quads.size(), 1, "enabling adds the screen-space overlay to the world")
	var material := (quads[0] as MeshInstance3D).material_override as ShaderMaterial
	assert_eq(material.shader, SHADER)
	assert_eq(material.get_shader_parameter("points_size"), 128)
	assert_eq(material.get_shader_parameter("spacing"), 12.0)
	overlay.set_enabled(false)
	await wait_process_frames(1)
	assert_eq(world.find_children("*", "MeshInstance3D", false, false).size(), 0,
		"disabling removes it again")


func test_overlay_reads_a_128_point_window() -> void:
	assert_eq(OVERLAY.SIZE, 128)
	var source := FileAccess.get_file_as_string("res://scripts/terrain/tools/TerrainCategoryOverlay.gd")
	assert_true(source.contains("loaded_point_at"))
	assert_false(source.contains("loaded_cell_at"))


func test_overlay_shader_declares_its_inputs() -> void:
	var names: Array[String] = []
	for uniform: Dictionary in SHADER.get_shader_uniform_list():
		names.append(String(uniform.name))
	for expected: String in ["points", "origin_point", "points_size", "spacing",
			"storey_height", "cliff_end", "chunk_points"]:
		assert_has(names, expected)


func test_legend_names_lattice_edges_tiles_and_wall_lines() -> void:
	var legend: String = OVERLAY.LEGEND
	for expected: String in ["lattice edge", "flat", "level", "slope", "cliff",
			"tile grid", "wall lines", "12 i + 6", "chunk border"]:
		assert_string_contains(legend, expected)
	assert_false(legend.contains("cell"), "no 24 m cells remain in the terrain field")
	assert_false(legend.contains("dying"), "no dying-cliff category (standard edges only)")


## The shader's kernel is a port of TerrainTileField: render it on the GPU at
## 4096 sample positions over random lattice fields (flat, level, slope, cliff,
## saddles, cliff ends, three-layer tiles) and compare with the CPU kernel,
## under every cliff-end rule. Needs a rendering device: run windowed
## (Godot --path . -s addons/gut/gut_cmdln.gd -gtest=<this file> -gexit).
func test_gpu_kernel_matches_terrain_tile_field() -> void:
	if DisplayServer.get_name() == "headless":
		pending("GPU kernel comparison needs a rendering device (run this file windowed)")
		return
	var saved: int = TerrainTileField.cliff_end
	for rule: int in [TerrainTileField.CliffEnd.E1, TerrainTileField.CliffEnd.E2,
			TerrainTileField.CliffEnd.E3, TerrainTileField.CliffEnd.SHARED_PROFILE]:
		for field_seed: int in [11, 29]:
			TerrainTileField.cliff_end = rule
			var result: Dictionary = await _render_probe(_random_region(field_seed), rule)
			assert_eq(result.mapped, PROBE_SIZE * PROBE_SIZE, "probe pixels map to their samples")
			assert_eq(result.mismatches, [], "rule %d field %d: GPU kernel == TerrainTileField"
				% [rule, field_seed])
	TerrainTileField.cliff_end = saved


func _random_region(field_seed: int) -> HeightfieldRegion:
	var rng := RandomNumberGenerator.new()
	rng.seed = field_seed
	var storeys: Dictionary = {}
	var levels: Dictionary = {}
	for z in range(PROBE_ORIGIN.y, PROBE_ORIGIN.y + PROBE_TILES + 1):
		for x in range(PROBE_ORIGIN.x, PROBE_ORIGIN.x + PROBE_TILES + 1):
			storeys[Vector2i(x, z)] = rng.randi_range(0, 3)
			levels[Vector2i(x, z)] = rng.randi_range(0, 3) if rng.randf() < 0.5 else 0
	return HeightfieldRegion.new(storeys, levels)


func _render_probe(region: HeightfieldRegion, rule: int) -> Dictionary:
	var side := PROBE_TILES + 1
	var point_data := PackedFloat32Array()
	point_data.resize(side * side * 2)
	for z in side:
		for x in side:
			var p := PROBE_ORIGIN + Vector2i(x, z)
			point_data[(z * side + x) * 2] = region.surface_height(p.x, p.y)
	var points := ImageTexture.create_from_image(Image.create_from_data(side, side, false,
		Image.FORMAT_RGF, point_data.to_byte_array()))
	var sample_data := PackedFloat32Array()
	sample_data.resize(PROBE_SIZE * PROBE_SIZE * 4)
	var expected: Array[Vector3] = []
	for py in PROBE_SIZE:
		for px in PROBE_SIZE:
			var tile := PROBE_ORIGIN + Vector2i(px / 8, py / 8)
			var u := (float(px % 8) + 0.37) / 8.0
			var v := (float(py % 8) + 0.37) / 8.0
			var x := (float(tile.x) + u) * TerrainTileField.SPACING
			var z := (float(tile.y) + v) * TerrainTileField.SPACING
			var h := TerrainTileField.eval_params(TerrainTileField.tile_params(region, tile), u, v)
			var i := (py * PROBE_SIZE + px) * 4
			sample_data[i] = x
			sample_data[i + 1] = z
			sample_data[i + 2] = h
			expected.append(Vector3(x, z, h))
	var samples := ImageTexture.create_from_image(Image.create_from_data(PROBE_SIZE, PROBE_SIZE,
		false, Image.FORMAT_RGBAF, sample_data.to_byte_array()))
	var material := ShaderMaterial.new()
	material.shader = PROBE
	material.set_shader_parameter("points", points)
	material.set_shader_parameter("origin_point", PROBE_ORIGIN)
	material.set_shader_parameter("points_size", side)
	material.set_shader_parameter("spacing", TerrainTileField.SPACING)
	material.set_shader_parameter("storey_height", HeightfieldRegion.STOREY_HEIGHT)
	material.set_shader_parameter("cliff_end", rule)
	material.set_shader_parameter("samples", samples)
	material.set_shader_parameter("probe_size", PROBE_SIZE)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(PROBE_SIZE, PROBE_SIZE)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var rect := ColorRect.new()
	rect.size = Vector2(PROBE_SIZE, PROBE_SIZE)
	rect.material = material
	viewport.add_child(rect)
	add_child_autofree(viewport)
	for _i in 4:
		await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	var mapped := 0
	var mismatches: Array = []
	for py in PROBE_SIZE:
		for px in PROBE_SIZE:
			var c := image.get_pixel(px, py)
			if roundi(c.g) == px % 2 and roundi(c.b) == py % 2:
				mapped += 1
			if c.r < 0.5 and mismatches.size() < 8:
				var e: Vector3 = expected[py * PROBE_SIZE + px]
				mismatches.append("pixel (%d, %d) world (%.2f, %.2f) cpu %.3f" % [px, py, e.x, e.y, e.z])
	viewport.queue_free()
	return {"mapped": mapped, "mismatches": mismatches}
