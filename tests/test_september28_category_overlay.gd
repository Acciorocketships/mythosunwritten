extends GutTest
## September 28 owner request: a diagnostic view that colour-codes the
## terrain's categories and shows where the levels are (F9).
const Plan := preload("res://scripts/terrain/heightfield/HeightfieldPlan.gd")
const OVERLAY := preload("res://scripts/terrain/tools/TerrainCategoryOverlay.gd")
const SHADER := preload("res://terrain/materials/debug/terrain_category_overlay.gdshader")


func test_cell_snapshot_carries_each_cells_surface_height_and_grade() -> void:
	var plan := Plan.new(0, 64.0, 12, "mean", 4)
	plan.set_raw_height_override(func(cx, cz): return 4.0 * float(cx) + float(cz % 3))
	var region: HeightfieldRegion = plan.compute_region(4, 4, 8)
	var values := FieldTerrainStreamer._cell_snapshot(Vector2i.ZERO, region)
	assert_eq(values.size(), 8 * 8 * 2)
	for z in 8:
		for x in 8:
			assert_eq(values[(z * 8 + x) * 2], region.surface_height(x, z),
				"cell (%d, %d) height" % [x, z])
			assert_eq(values[(z * 8 + x) * 2 + 1], 0.0, "no grade on natural ground")


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
	overlay.set_enabled(false)
	await wait_process_frames(1)
	assert_eq(world.find_children("*", "MeshInstance3D", false, false).size(), 0,
		"disabling removes it again")


func test_overlay_shader_declares_its_inputs() -> void:
	var names: Array[String] = []
	for uniform: Dictionary in SHADER.get_shader_uniform_list():
		names.append(String(uniform.name))
	for expected: String in ["cells", "origin_cell", "cells_size", "tile", "storey_height"]:
		assert_has(names, expected)
