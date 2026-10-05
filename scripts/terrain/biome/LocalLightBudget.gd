extends Node
## One budget per rendered world, across all streamed chunks and source types.
## Source visibility remains owned by the orb/lantern renderer.
## Runs every frame: it decides the whole selection first and then writes only
## lights whose energy or shadow flag actually changes (each write is a
## RenderingServer call, and a shadow toggle reallocates its atlas slot).
func update_lights(camera: Camera3D, quality: int) -> void:
	if camera == null or not camera.is_inside_tree(): return
	var candidates: Array = []
	var lights: Array[OmniLight3D] = []
	for node in get_tree().get_nodes_in_group("atmosphere_local_light"):
		var light := node as OmniLight3D
		if light == null or light.get_world_3d() != camera.get_world_3d(): continue
		if not light.has_meta("atmosphere_authored_energy"):
			light.set_meta("atmosphere_authored_energy", light.light_energy)
		lights.append(light)
		var distance := camera.global_position.distance_squared_to(light.global_position)
		# Keep incumbents until a challenger is appreciably closer.
		var score := distance * (0.8 if light.light_energy > 0.0 else 1.0)
		if light.is_visible_in_tree() and distance < 90.0 * 90.0:
			candidates.append([score, light.get_instance_id(), light])
	candidates.sort_custom(func(a: Array, b: Array) -> bool:
		return a[0] < b[0] if a[0] != b[0] else a[1] < b[1])
	var lit := {}
	var shadowed := {}
	var shadows: int = [0, 2, 4][clampi(quality, 0, 2)]
	for i in mini(candidates.size(), [8, 20, 32][clampi(quality, 0, 2)]):
		var light: OmniLight3D = candidates[i][2]
		lit[light] = true
		if shadows > 0 and light.get_meta("atmosphere_shadow_candidate", false):
			shadowed[light] = true
			shadows -= 1
	for light in lights:
		var energy := float(light.get_meta("atmosphere_authored_energy")) if lit.has(light) else 0.0
		if light.light_energy != energy:
			light.light_energy = energy
		var shadow := shadowed.has(light)
		if light.shadow_enabled != shadow:
			light.shadow_enabled = shadow
			if shadow:
				light.shadow_bias = 0.03
				light.shadow_normal_bias = 0.5
