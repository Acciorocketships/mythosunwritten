extends Node3D
## Teleport harness: boots the real world, teleports the character far from
## the origin, and measures how quickly decorations fill in around them.
## Reproduces the "trees only near spawn" report — the area around a far
## teleport must reach a deco density comparable to spawn within seconds.
##
## Run with: godot --path . res://tests/harness/teleport_deco_harness.tscn

const SHOT_DIR: String = "/tmp/terrain_shots"
const TELEPORT_POS: Vector3 = Vector3(600, 1.5, 600)
const SAMPLE_SECONDS: int = 25
const DECO_TAGS: Array[String] = ["tree", "bush", "grass", "rock"]

var world: Node3D
var character: CharacterBody3D
var terrain: Node3D
var cam: Camera3D


func _ready() -> void:
	get_window().always_on_top = true
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	world = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	character = world.get_node("Characters/Character")
	terrain = world.get_node("Terrain")
	cam = Camera3D.new()
	cam.far = 600.0
	add_child(cam)
	_run()


func _physics_process(_delta: float) -> void:
	# Keep the character pinned at the teleport target while the ground
	# beneath generates (it would otherwise fall into the void).
	if character != null and character.global_position.y < 0.0:
		character.global_position = TELEPORT_POS
		character.velocity = Vector3.ZERO


func _run() -> void:
	await get_tree().create_timer(3.0).timeout
	print("[teleport] spawn deco near origin: %d" % _deco_near(Vector3.ZERO))
	character.global_position = TELEPORT_POS
	character.velocity = Vector3.ZERO
	for second in range(SAMPLE_SECONDS + 1):
		print("[teleport] t=%02ds deco_near=%d queue=%d fps=%d" % [
			second, _deco_near(TELEPORT_POS), terrain.queue.heap.size(),
			Engine.get_frames_per_second(),
		])
		if second % 5 == 0:
			await _capture("teleport_%02ds" % second)
		await get_tree().create_timer(1.0).timeout
	get_tree().quit()


func _deco_near(center: Vector3, radius: float = 120.0) -> int:
	var count: int = 0
	for module in terrain.terrain_index.all_modules.keys():
		if not (module is TerrainModuleInstance):
			continue
		for tag in DECO_TAGS:
			if module.def.tags.has(tag):
				var o: Vector3 = module.transform.origin
				if Vector2(o.x - center.x, o.z - center.z).length() < radius:
					count += 1
				break
	return count


func _capture(shot_name: String) -> void:
	cam.global_position = character.global_position + Vector3(50, 40, 50)
	cam.look_at(character.global_position)
	cam.make_current()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [SHOT_DIR, shot_name])
