extends Node3D
## Throwaway: boot world, find water, screenshot it (fast water-look iteration).
var world: Node3D
var terrain: Node3D
var cam: Camera3D

func _ready() -> void:
	get_window().always_on_top = true
	world = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	terrain = world.get_node("Terrain")
	cam = Camera3D.new()
	cam.far = 600.0
	add_child(cam)
	_run()

func _run() -> void:
	var water: Vector3 = Vector3.INF
	for _i in range(40):
		await get_tree().create_timer(1.0).timeout
		for module in terrain.terrain_index.all_modules.keys():
			if module is TerrainModuleInstance and module.def.tags.has("water"):
				water = module.transform.origin
				break
		if water != Vector3.INF:
			break
	if water == Vector3.INF:
		print("[dbgwater] no water")
		get_tree().quit()
		return
	await get_tree().create_timer(4.0).timeout
	var angles = [Vector3(16, 7, 16), Vector3(26, 4, 2), Vector3(0, 26, 1)]
	for k in range(angles.size()):
		cam.global_position = water + angles[k]
		cam.look_at(water)
		cam.make_current()
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/terrain_shots/dbgwater_%d.png" % k)
	print("[dbgwater] done at ", water)
	get_tree().quit()
