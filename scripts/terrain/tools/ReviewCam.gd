# Reproduce the owner's screenshot camera EXACTLY from the two F3-overlay
# readouts he includes in every screenshot: the player world position and the
# crosshair world position. The orbit camera (scripts/camera/camera.gd) sits
# at player + UP*HEIGHT + horizontal(DIST, azimuth) and always looks at the
# player origin; the crosshair is the first hit along that centre ray, so the
# unknown azimuth is recovered by scanning for the ray that passes closest to
# the crosshair point. Drive it from a godot-MCP eval in two steps (chunks
# need a few seconds to stream between them):
#   var RC = load("res://scripts/terrain/tools/ReviewCam.gd")
#   RC.pose(Vector3(px, py, pz))                  # teleport + freeze player
#   ... wait ~8s ...
#   RC.shoot(Vector3(px, py, pz), Vector3(cx, cy, cz), "/path/shot.png")
# The player is frozen (physics off) so gravity/water can't drift the pose
# between the two steps — the frame matches the owner's pixel-for-pixel.
class_name ReviewCam
extends Object

const DIST := 8.0
const HEIGHT := 5.0
# skirt_debug's STEEP threshold — r3 Task 7 CUSTOM0 migration. The mesh's
# CUSTOM0 layout changed at Task 6 from (flow.x, shore, flow.y, steep) to
# (s, d, slope, shore_dist); this threshold used to read the old `steep`
# lane (index 3), which is GONE — under the new layout, index 3 is
# shore_dist (0..8m), and reading it as a steepness signal would misclassify
# nearly every nearby vertex as STEEP. Index 2 (slope) is the real steepness
# signal now: the nearest-trace profile slope at that vertex's own projected
# point (WaterSkin._flow_frame_at). The trigger-box gate itself
# (WaterSkin._triggers) suppresses a whole 24m TILE's trigger on max
# |grade_at| > STEEP_UNSWIMMABLE (0.45, WaterSkin.gd) — that constant's own
# docstring derives the legal (non-fall, swimmable) reach ceiling as
# FALL_DROP_MIN/TRACE_STEP = 0.3333; 0.35 sits just past that same ceiling,
# so a vertex whose own baked slope already clears it is reading the SAME
# "steeper than any ordinary swimmable reach" signal the trigger gate uses,
# read off CUSTOM0 instead of a fresh WaterField.grade_at call. See
# skirt_debug's own docstring.
const STEEP_ATTR_THRESHOLD := 0.35


## The orbit-camera position whose centre ray (toward the player origin)
## passes closest to the crosshair hit point.
static func solve_cam(player: Vector3, crosshair: Vector3) -> Vector3:
	var best_cam: Vector3 = player + Vector3(DIST, HEIGHT, 0.0)
	var best_d: float = INF
	var th: float = 0.0
	while th < TAU:
		var cam: Vector3 = player + Vector3(cos(th) * DIST, HEIGHT, sin(th) * DIST)
		var dir: Vector3 = (player - cam).normalized()
		var t: float = (crosshair - cam).dot(dir)
		var d: float = (cam + dir * maxf(t, 0.0)).distance_to(crosshair)
		if d < best_d:
			best_d = d
			best_cam = cam
		th += 0.002
	return best_cam


## Step 1: put the frozen player at the owner's position (streams chunks).
static func pose(player: Vector3) -> void:
	var root: Node = (Engine.get_main_loop() as SceneTree).root
	var ch: Node3D = root.get_node("World/Characters/Character")
	ch.set("velocity", Vector3.ZERO)
	ch.global_position = player
	ch.set_physics_process(false)


## Debug material swap: every water SHEET renders flat yellow, unshaded — a
## screenshot then labels each pixel's owner, so artifact attribution is read
## straight off the image instead of guessed (owner: "try highlighting the
## pieces so you can identify the correct piece"). Call highlight(false) to
## restore the real material. Phase 2b: falls are no longer a separate
## "Waterfalls" node/material (see WaterSurfaceBuilder.build_chunk) — the
## sheet highlight alone now covers every water surface, falls included.
static func highlight(on: bool) -> void:
	var root: Node = (Engine.get_main_loop() as SceneTree).root
	var sheet_m: Material = _flat(Color(1.0, 0.9, 0.1)) if on \
		else WaterSurfaceBuilder.sheet_material()
	for mi in root.find_children("WaterSheet", "MeshInstance3D", true, false):
		mi.material_override = sheet_m


static func _flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# The real water materials are cull_disabled and the sheet winds facing
	# DOWN — with default backface culling the debug view hid every sheet
	# seen from above and mimicked "missing water" (a full debugging detour).
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Isolate the SKIRT from the pools (owner's definition: "the thin piece of
## water that sits on the edge of a pool to connect it to the land"). A
## sheet vertex with NO swim trigger under its column is either SKIRT (the
## land-connecting film) or STEEP (a fall/chute face — WaterSkin's own
## STEEP_UNSWIMMABLE gate deliberately gives these tiles no trigger at all,
## see WaterSkin._triggers; that is expected, not a false "skirt"). The two
## are told apart by the mesh's own baked CUSTOM0 `slope` lane (index 2 of
## (s, d, slope, shore_dist) — see WaterSkin._custom0/_flow_frame_at):
## past STEEP_ATTR_THRESHOLD means this vertex reads a slope steeper than
## any ordinary swimmable reach, so it is classed STEEP even though it has
## no trigger below it. Triggers still span exactly every wet, SWIMMABLE
## tile, so "no trigger AND not steep" is the actual land-connecting film.
## The probe point sits just above the physics ground so a trigger is hit
## whenever one exists at any height. Skirt triangles render as a flat red
## unshaded overlay, steep triangles as a flat blue one; the pools keep
## their normal look. Visible skirt vertices print as `SKIRT` log lines,
## visible steep vertices as `STEEP` log lines (both: position, ground
## height, proud metres — buried film is skipped in the log but still
## drawn, terrain occludes it); log_pool=true also prints deduped `POOL`
## lines for side-by-side reading. Returns the visible skirt vertex count
## only (STEEP verts are expected-absent-trigger, not skirt, and are
## excluded — read the printed summary line for the steep count). Run from
## a godot-MCP eval
## while the game is running:
##   var RC = load("res://scripts/terrain/tools/ReviewCam.gd")
##   RC.skirt_debug(Vector3(33.9, 8.0, -1097.4), 40.0)
##   RC.skirt_debug(Vector3(33.9, 8.0, -1097.4), 40.0, true)  # + POOL lines
##   RC.clear_skirt_debug()
static func skirt_debug(center: Vector3, radius: float, log_pool := false) -> int:
	clear_skirt_debug()
	var root: Node = (Engine.get_main_loop() as SceneTree).root
	var space := root.get_viewport().get_world_3d().direct_space_state
	var vol_q := PhysicsPointQueryParameters3D.new()
	vol_q.collide_with_areas = true
	vol_q.collide_with_bodies = false
	vol_q.collision_mask = 1 << 7
	var seen: Dictionary = {}
	var skirt_n: int = 0
	var steep_n: int = 0
	var pool_n: int = 0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tris: int = 0
	var st_steep := SurfaceTool.new()
	st_steep.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steep_tris: int = 0
	# cls values: 0 = pool (trigger present), 1 = skirt (no trigger, not steep),
	# 2 = steep (no trigger, CUSTOM0 slope lane past threshold — expected).
	for mi: MeshInstance3D in root.find_children("WaterSheet", "MeshInstance3D", true, false):
		var aabb: AABB = mi.global_transform * mi.get_aabb()
		if aabb.position.distance_to(center) - aabb.size.length() > radius:
			continue
		var arrays: Array = mi.mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		# CUSTOM0 (see WaterSkin._custom0): a flat PackedFloat32Array, 4 floats
		# per vertex in the SAME index space as ARRAY_VERTEX — (s, d, slope,
		# shore_dist); slope is float index 2 of each vertex's group of 4.
		var custom0: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM0]
		# The boundary mesh is INDEXED; legacy soups have no index buffer.
		var midx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if midx.is_empty():
			midx = PackedInt32Array(range(verts.size()))
		var xf: Transform3D = mi.global_transform
		var i: int = 0
		while i < midx.size():
			var w: Array = []       # [Vector3 world pos, int raw vertex index]
			for k in 3:
				var vidx: int = midx[i + k]
				w.append([xf * verts[vidx], vidx])
			i += 3
			if (w[0][0] as Vector3).distance_to(center) > radius:
				continue
			var tri_skirt: bool = false
			var tri_steep: bool = false
			for k in 3:
				var p: Vector3 = w[k][0]
				var vidx: int = w[k][1]
				var key: Vector3i = Vector3i((p * 4.0).round())
				var cls: int
				if seen.has(key):
					cls = seen[key]
				else:
					var ray := PhysicsRayQueryParameters3D.create(
						p + Vector3.UP * 30.0, p - Vector3.UP * 60.0)
					var hit: Dictionary = space.intersect_ray(ray)
					var ground: float = hit.position.y if not hit.is_empty() else -INF
					# Point queries are exclusive on box faces, and swim boxes
					# tile at exact 24m cell lines — a vert ON the line misses
					# both neighbours. Probe nudged into each side.
					var over_water := false
					for nud in [Vector3(0.11, 0.5, 0.11), Vector3(-0.11, 0.5, -0.11),
							Vector3(0.11, 0.5, -0.11), Vector3(-0.11, 0.5, 0.11)]:
						vol_q.position = Vector3(p.x, ground, p.z) + nud
						if not space.intersect_point(vol_q, 1).is_empty():
							over_water = true
							break
					if over_water:
						cls = 0
					else:
						var slope_attr: float = custom0[vidx * 4 + 2]
						cls = 2 if slope_attr > STEEP_ATTR_THRESHOLD else 1
					seen[key] = cls
					if cls == 1:
						if p.y > ground - 0.05:
							skirt_n += 1
							print("SKIRT (%.1f, %.2f, %.1f) ground %.2f proud %.2f" % [
								p.x, p.y, p.z, ground, p.y - ground])
					elif cls == 2:
						if p.y > ground - 0.05:
							steep_n += 1
							print("STEEP (%.1f, %.2f, %.1f) ground %.2f proud %.2f" % [
								p.x, p.y, p.z, ground, p.y - ground])
					else:
						pool_n += 1
						if log_pool:
							print("POOL  (%.1f, %.2f, %.1f) ground %.2f" % [
								p.x, p.y, p.z, ground])
				if cls == 1:
					tri_skirt = true
				elif cls == 2:
					tri_steep = true
			if tri_skirt:
				for k in 3:
					st.add_vertex((w[k][0] as Vector3) + Vector3.UP * 0.04)
				tris += 1
			if tri_steep:
				for k in 3:
					st_steep.add_vertex((w[k][0] as Vector3) + Vector3.UP * 0.04)
				steep_tris += 1
	if tris > 0:
		var mi := MeshInstance3D.new()
		mi.name = "SkirtDebugOverlay"
		mi.mesh = st.commit()
		mi.material_override = _flat(Color(1.0, 0.1, 0.1))
		root.add_child(mi)
	if steep_tris > 0:
		var mi_s := MeshInstance3D.new()
		mi_s.name = "SteepDebugOverlay"
		mi_s.mesh = st_steep.commit()
		mi_s.material_override = _flat(Color(0.1, 0.3, 1.0))
		root.add_child(mi_s)
	print("SKIRT DEBUG: %d visible skirt verts, %d visible steep verts, %d pool verts, %d skirt tris, %d steep tris" % [
		skirt_n, steep_n, pool_n, tris, steep_tris])
	return skirt_n


static func clear_skirt_debug() -> void:
	# free() (immediate), not queue_free(): a force_draw + save_png later in
	# the same or a stale frame can still render a deferred-freed overlay —
	# one battery frame (r4_I2) caught the red/blue tris 60m away at the
	# horizon. These are plain root-owned MeshInstances; immediate free is safe.
	var root: Node = (Engine.get_main_loop() as SceneTree).root
	for n in root.find_children("SkirtDebugOverlay", "MeshInstance3D", true, false):
		n.free()
	for n in root.find_children("SteepDebugOverlay", "MeshInstance3D", true, false):
		n.free()


## Step 2: place the camera on the solved orbit pose and save the frame.
static func shoot(player: Vector3, crosshair: Vector3, path: String) -> void:
	var root: Node = (Engine.get_main_loop() as SceneTree).root
	var cam: Camera3D = root.get_viewport().get_camera_3d()
	cam.set_physics_process(false)
	cam.set_process(false)
	cam.global_position = solve_cam(player, crosshair)
	cam.look_at(player, Vector3.UP)
	cam.force_update_transform()
	RenderingServer.force_draw()
	root.get_viewport().get_texture().get_image().save_png(path)
	print("MEAS ReviewCam shot -> ", path, " cam ", cam.global_position)


## Motion-pair capture: two frames dt apart from the SAME fixed camera pose
## (solved once, per solve_cam — the camera itself never moves between the
## two shots), with real wall-clock time allowed to pass between them via a
## SceneTree timer. Water motion (travelling pond swells, fragment-side
## refraction-distortion advection — r3 Task 13; no foam/film exists any
## more) reads directly off the pixel delta between path_a and path_b, isolated
## from any camera-motion confound a re-solved or drifting pose would add.
## static func CAN await in Godot 4.5 (confirmed) — the await itself suspends
## on the SceneTree timer's own timeout signal, same mechanism a Node's
## `await get_tree().create_timer(dt).timeout` uses.
## Usage from a godot-MCP eval (same battery pattern as shoot() itself):
##   var RC = load("res://scripts/terrain/tools/ReviewCam.gd")
##   await RC.shoot_pair(Vector3(px, py, pz), Vector3(cx, cy, cz), "/path/a.png", "/path/b.png")
static func shoot_pair(player: Vector3, crosshair: Vector3, path_a: String, path_b: String, dt := 0.7) -> void:
	var root: Node = (Engine.get_main_loop() as SceneTree).root
	var cam: Camera3D = root.get_viewport().get_camera_3d()
	cam.set_physics_process(false)
	cam.set_process(false)
	cam.global_position = solve_cam(player, crosshair)   # solved ONCE, held fixed across both frames
	cam.look_at(player, Vector3.UP)
	cam.force_update_transform()

	RenderingServer.force_draw()
	root.get_viewport().get_texture().get_image().save_png(path_a)
	print("MEAS ReviewCam shot_pair frame A -> ", path_a, " cam ", cam.global_position)

	await (Engine.get_main_loop() as SceneTree).create_timer(dt).timeout

	RenderingServer.force_draw()
	root.get_viewport().get_texture().get_image().save_png(path_b)
	print("MEAS ReviewCam shot_pair frame B -> ", path_b, " cam ", cam.global_position, " dt ", dt)
