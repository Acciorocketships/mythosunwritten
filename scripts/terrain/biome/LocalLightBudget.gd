extends Node
## One budget per rendered world, across all streamed chunks and source types.
## Source visibility remains owned by the orb/lantern renderer.
func update_lights(camera: Camera3D, quality: int) -> void:
	if camera == null or not camera.is_inside_tree(): return
	var candidates: Array = []
	for node in get_tree().get_nodes_in_group("atmosphere_local_light"):
		var light := node as OmniLight3D
		if light == null or light.get_world_3d() != camera.get_world_3d(): continue
		if not light.has_meta("atmosphere_authored_energy"):
			light.set_meta("atmosphere_authored_energy", light.light_energy)
		var distance := camera.global_position.distance_squared_to(light.global_position)
		# Keep incumbents until a challenger is appreciably closer.
		var score := distance * (0.8 if light.light_energy > 0.0 else 1.0)
		light.light_energy = 0.0
		light.shadow_enabled = false
		if light.is_visible_in_tree() and distance < 90.0 * 90.0:
			candidates.append([score, light.get_instance_id(), light])
	candidates.sort_custom(func(a: Array, b: Array) -> bool:
		return a[0] < b[0] if a[0] != b[0] else a[1] < b[1])
	var shadows: int = [0, 2, 4][clampi(quality, 0, 2)]
	for i in mini(candidates.size(), [8, 20, 32][clampi(quality, 0, 2)]):
		var light: OmniLight3D = candidates[i][2]
		light.light_energy = float(light.get_meta("atmosphere_authored_energy"))
		if shadows > 0 and light.get_meta("atmosphere_shadow_candidate", false):
			light.shadow_enabled = true
			light.shadow_bias = 0.03
			light.shadow_normal_bias = 0.5
			shadows -= 1
