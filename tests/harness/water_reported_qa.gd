# Focused, self-driving falsification harness for the owner's 2026-07-13
# screenshots.  A review site is defined ONLY by the two values printed by
# CoordOverlay: player world and crosshair world.  ReviewCam.solve_cam recovers
# the actual orbit pose from that pair; do not replace it with a hand-authored
# camera position/look-at (that was the exact reason the first harness missed
# the defects these sites expose).
extends Node3D

const OUT := "/tmp/mythos-water-reported-qa"

# [name, exact reported player position, exact reported crosshair position]
const SPOTS: Array = [
	["bank_62_exact", Vector3(62.5, 4.0, -1130.3),
		Vector3(62.4, 4.2, -1130.0)],
	["chute_52_exact", Vector3(52.2, 8.0, -1091.6),
		Vector3(52.4, 8.2, -1091.9)],
	["corner_134_exact", Vector3(134.2, 4.0, -1160.5),
		Vector3(134.2, 4.2, -1160.8)],
	["chute_53_exact", Vector3(53.6, 8.5, -1079.7),
		Vector3(53.9, 8.8, -1079.9)],
	["corner_151_exact", Vector3(150.9, 4.0, -1213.9),
		Vector3(151.0, 4.2, -1213.6)],
]

var _character: CharacterBody3D
var _camera: Camera3D
var _terrain_overrides: Dictionary = {}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var world: Node = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	_run.call_deferred()


func _shot(name: String) -> void:
	RenderingServer.force_draw()
	get_viewport().get_texture().get_image().save_png(OUT + "/" + name + ".png")
	print("[water_reported_qa] shot ", name)


func _probe_screen(label: String, pixels: Array[Vector2]) -> void:
	var space := get_world_3d().direct_space_state
	for px: Vector2 in pixels:
		var origin: Vector3 = _camera.project_ray_origin(px)
		var direction: Vector3 = _camera.project_ray_normal(px)
		var water_hit: Dictionary = _ray_water(origin, direction)
		var hit: Dictionary = space.intersect_ray(
			PhysicsRayQueryParameters3D.create(origin, origin + direction * 200.0))
		var collider: Object = hit.get("collider", null)
		var hp: Vector3 = hit.get("position", Vector3.INF)
		print("[water_reported_qa] probe %s px=%s water=%s hit=(%.9f, %.9f, %.9f) collider=%s" % [
			label, px, str(water_hit), hp.x, hp.y, hp.z,
			str(collider.get_path()) if collider is Node else str(collider)])


func _ray_water(origin: Vector3, direction: Vector3) -> Dictionary:
	var best := {"distance": INF}
	for mi: MeshInstance3D in find_children("WaterSheet", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		var arrays: Array = mi.mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for ti in range(0, idx.size(), 3):
			var a: Vector3 = mi.to_global(verts[idx[ti]])
			var b: Vector3 = mi.to_global(verts[idx[ti + 1]])
			var c: Vector3 = mi.to_global(verts[idx[ti + 2]])
			var hit: Variant = Geometry3D.ray_intersects_triangle(origin, direction, a, b, c)
			if hit == null:
				continue
			var p: Vector3 = hit
			var d: float = origin.distance_to(p)
			if d < best.distance:
				best = {"distance": d, "point": p, "triangle": ti / 3,
					"node": String(mi.get_path()), "verts": [a, b, c]}
	return best


func _probe_visual_terrain(label: String, pixels: Array[Vector2]) -> void:
	for px: Vector2 in pixels:
		var origin: Vector3 = _camera.project_ray_origin(px)
		var direction: Vector3 = _camera.project_ray_normal(px)
		var best := {"distance": INF}
		for mi: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
			if mi.name not in [&"Surface", &"Aprons", &"CliffFaces"] or mi.mesh == null:
				continue
			var arrays: Array = mi.mesh.surface_get_arrays(0)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var idx := PackedInt32Array()
			if arrays[Mesh.ARRAY_INDEX] != null:
				idx = arrays[Mesh.ARRAY_INDEX]
			else:
				idx.resize(verts.size())
				for vi in verts.size():
					idx[vi] = vi
			for ti in range(0, idx.size(), 3):
				var a: Vector3 = mi.to_global(verts[idx[ti]])
				var b: Vector3 = mi.to_global(verts[idx[ti + 1]])
				var c: Vector3 = mi.to_global(verts[idx[ti + 2]])
				var hit: Variant = Geometry3D.ray_intersects_triangle(origin, direction, a, b, c)
				if hit == null:
					continue
				var point: Vector3 = hit
				var distance: float = origin.distance_to(point)
				if distance < best.distance:
					best = {"distance": distance, "point": point,
						"triangle": ti / 3, "node": String(mi.get_path()),
						"verts": [a, b, c]}
		print("[water_reported_qa] visual-terrain %s px=%s hit=%s" % [
			label, px, str(best)])


func _highlight_terrain_owners() -> void:
	var colors := {
		"Surface": Color(1.0, 0.1, 0.1),
		"Aprons": Color(0.1, 0.3, 1.0),
		"CliffFaces": Color(1.0, 0.1, 1.0),
	}
	for n: Node in find_children("*", "GeometryInstance3D", true, false):
		var owner_name := String(n.name)
		if String(n.get_path()).contains("/Cliffs/"):
			owner_name = "Cliffs"
		var c: Color = colors.get(owner_name, Color(0.1, 1.0, 1.0) if owner_name == "Cliffs" else Color.TRANSPARENT)
		if c.a > 0.0:
			if not _terrain_overrides.has(n):
				_terrain_overrides[n] = n.get("material_override")
			n.set("material_override", ReviewCam._flat(c))
	for water: MeshInstance3D in find_children("WaterSheet", "MeshInstance3D", true, false):
		water.visible = false


func _restore_terrain_owners() -> void:
	for n: Node in _terrain_overrides:
		if is_instance_valid(n):
			n.set("material_override", _terrain_overrides[n])
	_terrain_overrides.clear()
	for water: MeshInstance3D in find_children("WaterSheet", "MeshInstance3D", true, false):
		water.visible = true


func _wait_ground(pos: Vector3, timeout_s: float) -> void:
	var started := Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - started) / 1000.0 < timeout_s:
		var query := PhysicsRayQueryParameters3D.create(
			pos + Vector3(0.0, 80.0, 0.0), pos + Vector3(0.0, -80.0, 0.0))
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			await get_tree().create_timer(2.5).timeout
			return
		await get_tree().create_timer(0.5).timeout
	push_warning("No streamed ground at reported water pin %s" % pos)


func _run() -> void:
	await get_tree().create_timer(12.0).timeout
	_character = find_child("Character", true, false) as CharacterBody3D
	_camera = get_viewport().get_camera_3d()
	_camera.set("target", null)
	_camera.set_physics_process(false)
	_camera.set_process(false)
	var only_spot := ""
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	if user_args.size() >= 2 and user_args[0] == "--spot":
		only_spot = user_args[1]
	for spot: Array in SPOTS:
		if not only_spot.is_empty() and spot[0] != only_spot:
			continue
		_character.velocity = Vector3.ZERO
		_character.global_position = spot[1] + Vector3.UP * 8.0
		_character.set_physics_process(false)
		await _wait_ground(spot[1], 45.0)
		_character.global_position = spot[1]
		_camera.global_position = ReviewCam.solve_cam(spot[1], spot[2])
		_camera.look_at(spot[1], Vector3.UP)
		_camera.force_update_transform()
		await get_tree().create_timer(0.8).timeout
		_shot(spot[0] + "_real_a")
		await get_tree().create_timer(1.8).timeout
		_shot(spot[0] + "_real_b")
		ReviewCam.highlight(true)
		await get_tree().process_frame
		_shot(spot[0] + "_water_owner")
		if spot[0] == "corner_134_exact":
			_probe_screen(spot[0], [Vector2(1160, 790), Vector2(1200, 815),
				Vector2(1240, 835), Vector2(1280, 850)])
			_highlight_terrain_owners()
			await get_tree().process_frame
			_shot(spot[0] + "_all_owners")
		elif spot[0] == "chute_53_exact":
			_probe_screen(spot[0], [Vector2(1260, 220), Vector2(1420, 360),
				Vector2(1550, 520), Vector2(1650, 650), Vector2(1450, 680)])
			_highlight_terrain_owners()
			await get_tree().process_frame
			_shot(spot[0] + "_all_owners")
		elif spot[0] == "corner_151_exact":
			_probe_screen(spot[0], [Vector2(520, 560), Vector2(680, 680),
				Vector2(980, 820), Vector2(1180, 850), Vector2(1360, 880)])
			_probe_visual_terrain(spot[0], [Vector2(1360, 740),
				Vector2(1390, 760), Vector2(1420, 780)])
			_highlight_terrain_owners()
			await get_tree().process_frame
			_shot(spot[0] + "_all_owners")
		_restore_terrain_owners()
		ReviewCam.highlight(false)
		await get_tree().process_frame
		# Exact-pose proof is necessary but not sufficient: a corner defect can
		# hide behind its wall from one ray. After the required solve_cam frames,
		# orbit the SAME solved camera radius/height by +/-8 degrees and try to
		# expose a residual notch or overlapping miter from either side.
		if spot[0] == "corner_151_exact":
			var exact_camera: Vector3 = ReviewCam.solve_cam(spot[1], spot[2])
			var relative: Vector3 = exact_camera - Vector3(spot[1])
			for entry: Array in [["near_left", -deg_to_rad(8.0)],
				["near_right", deg_to_rad(8.0)]]:
				_camera.global_position = Vector3(spot[1]) \
					+ relative.rotated(Vector3.UP, float(entry[1]))
				_camera.look_at(Vector3(spot[1]), Vector3.UP)
				_camera.force_update_transform()
				await get_tree().process_frame
				_shot(spot[0] + "_" + String(entry[0]))
			_camera.global_position = exact_camera
			_camera.look_at(Vector3(spot[1]), Vector3.UP)
			_camera.force_update_transform()
	print("[water_reported_qa] done: ", OUT)
	get_tree().quit()
