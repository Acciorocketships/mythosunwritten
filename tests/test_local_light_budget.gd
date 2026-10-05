extends GutTest
const Budget = preload("res://scripts/terrain/biome/LocalLightBudget.gd")
func test_budget_is_shared_and_respects_viewports_and_source_visibility() -> void:
	var view := SubViewport.new()
	add_child_autofree(view)
	var camera := Camera3D.new()
	view.own_world_3d = true
	view.add_child(camera)
	var budget := Budget.new()
	view.add_child(budget)
	var lights: Array[OmniLight3D] = []
	for i in 30:
		var light := OmniLight3D.new()
		light.light_energy = 3.0
		light.position = Vector3(i, 0, 0)
		light.add_to_group("atmosphere_local_light")
		light.set_meta("atmosphere_shadow_candidate", true)
		view.add_child(light)
		lights.append(light)
	var foreign_view := SubViewport.new()
	foreign_view.own_world_3d = true
	add_child_autofree(foreign_view)
	var foreign := OmniLight3D.new()
	foreign.light_energy = 7.0
	foreign.add_to_group("atmosphere_local_light")
	foreign_view.add_child(foreign)
	lights[0].visible = false
	budget.update_lights(camera, 1)
	var active := 0
	var shadows := 0
	for light in lights:
		if light.light_energy > 0: active += 1
		if light.shadow_enabled: shadows += 1
	assert_eq(foreign.light_energy, 7.0, "A preview world must not steal lights from another viewport")
	assert_eq(active, 20)
	assert_eq(shadows, 2)
	assert_false(lights[0].visible)
	assert_eq(lights[0].light_energy, 0.0)
	camera.position = Vector3(29, 0, 0)
	budget.update_lights(camera, 0)
	assert_eq(lights[29].light_energy, 3.0, "Suppressed lights restore authored energy when selected")
	for light in lights: assert_false(light.shadow_enabled)
