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
	["refraction_crossing_21_exact", Vector3(20.8, 12.5, -1037.2),
		Vector3(21.1, 12.7, -1037.3)],
	["underwater_cliff_slope_33_exact", Vector3(33.2, 12.0, -1034.6),
		Vector3(33.5, 12.2, -1034.5)],
	["bank_refraction_plane_223_exact", Vector3(223.3, 4.0, -1166.7),
		Vector3(223.0, 4.2, -1166.5)],
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
	["look_river_34_1105_exact", Vector3(34.8, 8.0, -1105.2),
		Vector3(34.9, 8.2, -1105.5)],
	["swim_ripple_36_exact", Vector3(36.4, 2.8, -1108.7),
		Vector3(36.5, 3.0, -1109.0)],
	["corner_181_exact", Vector3(180.9, 4.0, -1184.4),
		Vector3(180.6, 4.2, -1184.7)],
]

var _character: CharacterBody3D
var _camera: Camera3D
var _terrain_overrides: Dictionary = {}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var world: Node = load("res://scenes/world.tscn").instantiate()
	# A focused run must start streaming at the reported site. Teleporting only
	# after the spawn queue is populated leaves dozens of now-stale chunks ahead
	# of the neighbouring review chunks, and the old single-ray wait could then
	# photograph water over an incomplete terrain neighbourhood.
	var initial_spot: Array = _requested_spot()
	if not initial_spot.is_empty():
		var initial_character := world.find_child("Character", true, false) as CharacterBody3D
		initial_character.position = Vector3(initial_spot[1]) + Vector3.UP * 8.0
	add_child(world)
	_run.call_deferred()


func _requested_spot() -> Array:
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	if user_args.size() < 2 or user_args[0] != "--spot":
		return []
	for spot: Array in SPOTS:
		if spot[0] == user_args[1]:
			return spot
	return []


func _shot(name: String) -> void:
	RenderingServer.force_draw()
	get_viewport().get_texture().get_image().save_png(OUT + "/" + name + ".png")
	print("[water_reported_qa] shot ", name)


func _frame_delta(a_name: String, b_name: String, rect: Rect2i) -> Dictionary:
	var a := Image.load_from_file(OUT + "/" + a_name + ".png")
	var b := Image.load_from_file(OUT + "/" + b_name + ".png")
	var total := 0.0
	var changed := 0
	var samples := 0
	for y in range(rect.position.y, mini(rect.end.y, a.get_height()), 2):
		for x in range(rect.position.x, mini(rect.end.x, a.get_width()), 2):
			var ca: Color = a.get_pixel(x, y)
			var cb: Color = b.get_pixel(x, y)
			var d: float = (absf(ca.r - cb.r) + absf(ca.g - cb.g)
				+ absf(ca.b - cb.b)) / 3.0
			total += d
			changed += 1 if d > 2.0 / 255.0 else 0
			samples += 1
	return {"mean": total / maxf(float(samples), 1.0),
		"changed_fraction": float(changed) / maxf(float(samples), 1.0),
		"samples": samples}


func _water_surface_near(center: Vector2, radius: float) -> Dictionary:
	var samplers: Array[WaterSampler] = []
	var seen: Dictionary = {}
	for node: Node in get_tree().get_nodes_in_group("water_volume"):
		if not node.has_meta("sampler"):
			continue
		var sampler: WaterSampler = node.get_meta("sampler")
		if seen.has(sampler.get_instance_id()):
			continue
		seen[sampler.get_instance_id()] = true
		samplers.append(sampler)
	var best: Dictionary = {}
	var best_score := -INF
	for dz in range(-int(radius), int(radius) + 1, 3):
		for dx in range(-int(radius), int(radius) + 1, 3):
			var p := center + Vector2(dx, dz)
			for sampler: WaterSampler in samplers:
				var level: float = sampler.level_at(p)
				if is_nan(level):
					continue
				var scale: float = sampler.wave_scale_at(p)
				var speed: float = sampler.velocity_at(p).length()
				var score: float = scale * 2.0 + speed - p.distance_to(center) * 0.015
				if scale >= 0.65 and score > best_score:
					best_score = score
					best = {"p": p, "level": level, "sampler": sampler}
	return best


func _probe_screen(label: String, pixels: Array[Vector2]) -> void:
	var space := get_world_3d().direct_space_state
	for px: Vector2 in pixels:
		var origin: Vector3 = _camera.project_ray_origin(px)
		var direction: Vector3 = _camera.project_ray_normal(px)
		var water_hit: Dictionary = _ray_water(origin, direction)
		var water_plane := Vector3.INF
		if absf(direction.y) > 0.000001:
			water_plane = origin + direction * ((3.0 - origin.y) / direction.y)
		var hit: Dictionary = space.intersect_ray(
			PhysicsRayQueryParameters3D.create(origin, origin + direction * 200.0))
		var collider: Object = hit.get("collider", null)
		var hp: Vector3 = hit.get("position", Vector3.INF)
		print("[water_reported_qa] probe %s px=%s origin=%s dir=%s plane_y3=%s water=%s hit=(%.9f, %.9f, %.9f) collider=%s" % [
			label, px, str(origin), str(direction), str(water_plane), str(water_hit), hp.x, hp.y, hp.z,
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


func _wait_ground_neighbourhood(pos: Vector3, timeout_s: float) -> void:
	var streamer := find_child("FieldTerrain", true, false) as FieldTerrainStreamer
	var centre := FieldTerrainStreamer.chunk_of(pos)
	var started := Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - started) / 1000.0 < timeout_s:
		var built: Dictionary = streamer.get("_built")
		var complete := true
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				if not built.has(centre + Vector2i(dx, dz)):
					complete = false
		if complete:
			# Give the physics server and renderer one synchronization interval
			# after the ninth surrounding chunk has entered the scene tree.
			await get_tree().create_timer(1.0).timeout
			return
		await get_tree().create_timer(0.5).timeout
	push_warning("Incomplete 3x3 terrain neighbourhood at reported water pin %s" % pos)


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
		await _wait_ground_neighbourhood(spot[1], 90.0)
		_character.global_position = spot[1]
		_camera.global_position = ReviewCam.solve_cam(spot[1], spot[2])
		_camera.look_at(spot[1], Vector3.UP)
		_camera.force_update_transform()
		if spot[0] == "swim_ripple_36_exact":
			# Find a real current-bearing patch near the historical I4 pin, then
			# frame its surface from above. The old reported camera was solved for a
			# character standing eight metres up on the bank; reusing that camera
			# after lowering the character into the river looked through the water
			# from below and could not review the surface ring at all.
			var wet: Dictionary = _water_surface_near(Vector2(spot[1].x, spot[1].z), 30.0)
			if wet.is_empty():
				push_error("No reviewable water surface near swim-ripple pin")
				continue
			var p: Vector2 = wet.p
			var level: float = wet.level
			_character.global_position = Vector3(p.x, level - 0.45, p.y)
			_camera.look_at_from_position(Vector3(p.x - 10.0, level + 8.0, p.y + 8.0),
				Vector3(p.x, level, p.y))
			_camera.force_update_transform()
			_character.set("in_water", false)
			await get_tree().process_frame
			_character.velocity = Vector3(2.4, -4.0, 0.0)
			_character.set("in_water", true)
		await get_tree().create_timer(0.8).timeout
		_shot(spot[0] + "_real_a")
		if spot[0] == "swim_ripple_36_exact":
			var swim_sim: WaterRippleSim = find_child("WaterRipples", true, false)
			swim_sim.save_debug_images(OUT + "/" + String(spot[0]))
			for swim_frame in 6:
				await get_tree().create_timer(0.20).timeout
				_shot(spot[0] + "_motion_%02d" % swim_frame)
		var dynamic_a: Dictionary = {}
		if spot[0] == "look_river_34_1105_exact":
			var sim_a: WaterRippleSim = find_child("WaterRipples", true, false)
			dynamic_a = sim_a.debug_state()
		await get_tree().create_timer(1.8).timeout
		_shot(spot[0] + "_real_b")
		if spot[0] in ["look_river_34_1105_exact",
				"underwater_cliff_slope_33_exact", "bank_refraction_plane_223_exact"]:
			# Refraction can make valid terrain look like detached geometry. Keep
			# an identical-pose opaque-scene truth frame for every reported
			# underwater terrain artifact so the two causes cannot be confused.
			var frame_delta: Dictionary = _frame_delta(
				spot[0] + "_real_a", spot[0] + "_real_b", Rect2i(0, 0, 760, 1080))
			if spot[0] == "look_river_34_1105_exact":
				print("[water_reported_qa] left-water paired-frame delta=", frame_delta)
				if frame_delta.mean < 0.002 or frame_delta.changed_fraction < 0.08:
					push_error("Exact river beauty frames remain visually static: %s" % frame_delta)
				var sim: WaterRippleSim = find_child("WaterRipples", true, false)
				var dynamic_b: Dictionary = sim.debug_state()
				var a_by_id: Dictionary = {}
				for i in dynamic_a.ids.size():
					a_by_id[dynamic_a.ids[i]] = dynamic_a.positions[i]
				var travel := PackedFloat32Array()
				for i in dynamic_b.ids.size():
					if a_by_id.has(dynamic_b.ids[i]):
						travel.append(a_by_id[dynamic_b.ids[i]].distance_to(dynamic_b.positions[i]))
				print("[water_reported_qa] dynamic state ", dynamic_b,
					" packet_travel_1.8s=", travel)
				sim.save_debug_images(OUT + "/" + String(spot[0]))
				for frame in 8:
					await get_tree().create_timer(0.25).timeout
					_shot(spot[0] + "_motion_%02d" % frame)
			for water: MeshInstance3D in find_children("WaterSheet", "MeshInstance3D", true, false):
				water.visible = false
			await get_tree().process_frame
			_shot(spot[0] + "_bottom_truth")
			for water: MeshInstance3D in find_children("WaterSheet", "MeshInstance3D", true, false):
				water.visible = true
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
		elif spot[0] == "corner_181_exact":
			_probe_screen(spot[0], [Vector2(650, 690), Vector2(820, 650),
				Vector2(930, 790), Vector2(1050, 600), Vector2(1260, 470)])
			_probe_visual_terrain(spot[0], [Vector2(650, 690),
				Vector2(820, 650), Vector2(930, 790), Vector2(1050, 600)])
			_highlight_terrain_owners()
			await get_tree().process_frame
			_shot(spot[0] + "_all_owners")
		elif spot[0] == "underwater_cliff_slope_33_exact":
			_probe_screen(spot[0], [Vector2(850, 735), Vector2(1050, 735),
				Vector2(1300, 735), Vector2(1400, 740), Vector2(1480, 740),
				Vector2(1510, 715), Vector2(1500, 680)])
			_probe_visual_terrain(spot[0], [Vector2(850, 735),
				Vector2(1050, 735), Vector2(1300, 735), Vector2(1400, 740),
				Vector2(1480, 740), Vector2(1510, 715), Vector2(1500, 680)])
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
