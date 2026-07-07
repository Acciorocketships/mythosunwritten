# Self-driving water QA: boots the real world (pinned review seed), walks a
# list of camera spots — teleport, let chunks stream, place the camera, save
# screenshot PAIRS a beat apart (swell/curtain motion shows as frame diffs) —
# then drops the character into a river with no input held to verify the
# entry-splash ripple rings. PNGs land in OUT. No MCP needed:
#   Godot --path . res://tests/harness/water_qa.tscn
extends Node3D

const OUT := "/private/tmp/claude-501/-Users-ryko-story/04fed697-7a32-4cb3-8153-ba1f64b6a94c/scratchpad/water_qa"

# [name, character pos (streams chunks), camera from, camera look-at]
const SPOTS: Array = [
	["ledge", Vector3(89.1, 20.0, -1114.7), Vector3(105, 26, -1095), Vector3(80, 12, -1120)],
	["fall", Vector3(34.0, 24.0, -1089.1), Vector3(20, 27, -1073), Vector3(55, 10, -1100)],
	["shoreline", Vector3(5.0, 20.0, -1074.0), Vector3(5, 21, -1058), Vector3(5, 13, -1082)],
	["meadow", Vector3(109.0, 12.0, -1212.0), Vector3(88, 9, -1196), Vector3(120, 3, -1218)],
	["channel", Vector3(-91.0, 30.0, -1000.0), Vector3(-40, 32, -960), Vector3(-95, 10, -1010)],
]

var _char: CharacterBody3D
var _cam: Camera3D


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var world: Node = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	_run.call_deferred()


func _shot(shot_name: String) -> void:
	# force_draw renders a frame even when macOS pauses an occluded window.
	RenderingServer.force_draw()
	get_viewport().get_texture().get_image().save_png(OUT + "/" + shot_name + ".png")
	print("[water_qa] shot ", shot_name)


## Poll until terrain collision exists under pos (chunk built), else time out.
func _wait_ground(pos: Vector3, max_s: float) -> void:
	var t0: float = float(Time.get_ticks_msec()) / 1000.0
	while float(Time.get_ticks_msec()) / 1000.0 - t0 < max_s:
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(pos + Vector3(0, 80, 0), pos + Vector3(0, -80, 0)))
		if not hit.is_empty():
			await get_tree().create_timer(2.5).timeout   # water/dressing settle
			return
		await get_tree().create_timer(1.0).timeout
	print("[water_qa] WARNING: ground never streamed at ", pos)


func _run() -> void:
	print("[water_qa] booting (spawn build)…")
	await get_tree().create_timer(14.0).timeout
	_char = get_node("World/Characters/Character") if has_node("World/Characters/Character") \
		else find_child("Character", true, false)
	_cam = get_viewport().get_camera_3d()
	_cam.set("target", null)
	_cam.set_physics_process(false)
	_cam.set_process(false)
	for s in SPOTS:
		_char.velocity = Vector3.ZERO
		_char.global_position = s[1]
		_char.set_physics_process(false)
		print("[water_qa] streaming ", s[0], "…")
		await _wait_ground(s[1], 60.0)
		_cam.look_at_from_position(s[2], s[3])
		await get_tree().create_timer(0.6).timeout
		_shot(s[0] + "_a")
		await get_tree().create_timer(1.8).timeout
		_shot(s[0] + "_b")
	# Waterfall slab close-up: aim at a REAL curtain mesh (scene query, no
	# coordinate guessing) from two angles — thickness + horizontal exit.
	var fall_mi: MeshInstance3D = null
	var fall_d: float = INF
	for mi in get_tree().root.find_children("Waterfalls", "MeshInstance3D", true, false):
		var d: float = mi.global_position.distance_to(Vector3(58, 12, -1096))
		if d < fall_d:
			fall_d = d
			fall_mi = mi
	if fall_mi != null:
		var aabb: AABB = fall_mi.mesh.get_aabb()
		var c: Vector3 = fall_mi.global_transform * aabb.get_center()
		print("[water_qa] slab at ", c)
		# The curtain's ACROSS axis is its long horizontal AABB axis; the flow
		# tangent is the short one. Shoot from the tangent side whose ground
		# drops farthest (the open plunge pool, not the cliff wall).
		var t_dir: Vector3 = Vector3(1, 0, 0) if aabb.size.z > aabb.size.x else Vector3(0, 0, 1)
		var best: Vector3 = t_dir
		var best_drop: float = -INF
		for s in [1.0, -1.0]:
			var probe: Vector3 = c + t_dir * s * 10.0 + Vector3(0, 8, 0)
			var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(
				PhysicsRayQueryParameters3D.create(probe, probe + Vector3(0, -60, 0)))
			var drop: float = probe.y - (hit.position.y if not hit.is_empty() else probe.y - 60.0)
			if drop > best_drop:
				best_drop = drop
				best = t_dir * s
		var a_dir: Vector3 = Vector3(0, 0, 1) if absf(t_dir.x) > 0.5 else Vector3(1, 0, 0)
		_cam.look_at_from_position(c + best * 11.0 + Vector3(0, 2.5, 0), c)
		await get_tree().create_timer(0.6).timeout
		_shot("slab_front")
		_cam.look_at_from_position(c + best * 6.0 + a_dir * 10.0 + Vector3(0, 1.5, 0), c)
		await get_tree().create_timer(0.6).timeout
		_shot("slab_side")
	# Entry-splash ripples: drop into REAL water (probe the swim-volume layer
	# — never a guessed shoreline), NO input held — rings must appear on
	# impact and keep expanding across the frames.
	var wet: Vector3 = _find_water_near(Vector3(110, 0, -1215), 70.0)
	if wet == Vector3.ZERO:
		print("[water_qa] WARNING: no swim volume found for the splash test")
	else:
		print("[water_qa] splash drop at ", wet)
		_char.global_position = wet
		_char.velocity = Vector3.ZERO
		_char.set_physics_process(true)
		var look: Vector3 = Vector3(wet.x, wet.y - 6.0, wet.z)
		_cam.look_at_from_position(wet + Vector3(-13, -2.0, 9), look)
		await get_tree().create_timer(1.2).timeout
		_shot("splash_a")
		await get_tree().create_timer(1.0).timeout
		_shot("splash_b")
		await get_tree().create_timer(1.5).timeout
		_shot("splash_c")
	print("[water_qa] done")
	get_tree().quit()


## Scan a grid around `center` for a point inside a swim volume (water layer
## 1<<7), probing several plausible surface heights; returns a drop position
## ~4m above the found surface, or ZERO when nothing is wet in range.
func _find_water_near(center: Vector3, r: float) -> Vector3:
	for dz in range(-int(r), int(r) + 1, 12):
		for dx in range(-int(r), int(r) + 1, 12):
			for y in [2.2, 3.0, 5.0, 7.0, 11.0, 15.0]:
				var q: PhysicsPointQueryParameters3D = PhysicsPointQueryParameters3D.new()
				q.position = Vector3(center.x + dx, y - 0.6, center.z + dz)
				q.collide_with_areas = true
				q.collide_with_bodies = false
				q.collision_mask = 1 << 7
				if get_world_3d().direct_space_state.intersect_point(q, 1).is_empty():
					continue
				# Swim boxes overlap the banks slightly — require the ground
				# under the point to sit well below the surface (submerged).
				var ray: Dictionary = get_world_3d().direct_space_state.intersect_ray(
					PhysicsRayQueryParameters3D.create(
						Vector3(center.x + dx, y + 20.0, center.z + dz),
						Vector3(center.x + dx, y - 20.0, center.z + dz)))
				if not ray.is_empty() and ray.position.y <= y - 1.2:
					return Vector3(center.x + dx, y + 4.0, center.z + dz)
	return Vector3.ZERO
