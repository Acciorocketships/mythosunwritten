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


## Debug material swap: every water SHEET renders flat yellow, every FALL
## flat magenta, unshaded — a screenshot then labels each pixel's owner, so
## artifact attribution is read straight off the image instead of guessed
## (owner: "try highlighting the pieces so you can identify the correct
## piece"). Call highlight(false) to restore the real materials.
static func highlight(on: bool) -> void:
	var root: Node = (Engine.get_main_loop() as SceneTree).root
	var sheet_m: Material = _flat(Color(1.0, 0.9, 0.1)) if on \
		else WaterSurfaceBuilder.sheet_material()
	var fall_m: Material = _flat(Color(1.0, 0.15, 0.9)) if on \
		else WaterSurfaceBuilder.waterfall_material()
	for mi in root.find_children("WaterSheet", "MeshInstance3D", true, false):
		mi.material_override = sheet_m
	for mi in root.find_children("Waterfalls", "MeshInstance3D", true, false):
		mi.material_override = fall_m


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
## sheet vertex is SKIRT-class when NO swim volume covers its column —
## volumes span exactly the wet cells, so "no water below me" means this
## vertex is the land-connecting film, not pool surface. The probe point
## sits just above the physics ground so a volume is hit whenever one
## exists at any height. Skirt triangles render as a flat red unshaded
## overlay; the pools keep their normal look. Visible skirt vertices print
## as `SKIRT` log lines (position, ground height, proud metres — buried
## film is skipped in the log but still drawn, terrain occludes it);
## log_pool=true also prints deduped `POOL` lines for side-by-side
## reading. Returns the visible skirt vertex count. Run from a godot-MCP
## eval while the game is running:
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
	var pool_n: int = 0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tris: int = 0
	for mi: MeshInstance3D in root.find_children("WaterSheet", "MeshInstance3D", true, false):
		var aabb: AABB = mi.global_transform * mi.get_aabb()
		if aabb.position.distance_to(center) - aabb.size.length() > radius:
			continue
		var verts: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var xf: Transform3D = mi.global_transform
		var i: int = 0
		while i < verts.size():
			var w: Array = []
			for k in 3:
				w.append(xf * verts[i + k])
			i += 3
			if (w[0] as Vector3).distance_to(center) > radius:
				continue
			var tri_skirt: bool = false
			for k in 3:
				var p: Vector3 = w[k]
				var key: Vector3i = Vector3i((p * 4.0).round())
				var cls: int
				if seen.has(key):
					cls = seen[key]
				else:
					var ray := PhysicsRayQueryParameters3D.create(
						p + Vector3.UP * 30.0, p - Vector3.UP * 60.0)
					var hit: Dictionary = space.intersect_ray(ray)
					var ground: float = hit.position.y if not hit.is_empty() else -INF
					vol_q.position = Vector3(p.x, ground + 0.5, p.z)
					var over_water: bool = not space.intersect_point(vol_q, 1).is_empty()
					cls = 1 if not over_water else 0
					seen[key] = cls
					if cls == 1:
						if p.y > ground - 0.05:
							skirt_n += 1
							print("SKIRT (%.1f, %.2f, %.1f) ground %.2f proud %.2f" % [
								p.x, p.y, p.z, ground, p.y - ground])
					else:
						pool_n += 1
						if log_pool:
							print("POOL  (%.1f, %.2f, %.1f) ground %.2f" % [
								p.x, p.y, p.z, ground])
				if cls == 1:
					tri_skirt = true
			if tri_skirt:
				for k in 3:
					st.add_vertex((w[k] as Vector3) + Vector3.UP * 0.04)
				tris += 1
	if tris > 0:
		var mi := MeshInstance3D.new()
		mi.name = "SkirtDebugOverlay"
		mi.mesh = st.commit()
		mi.material_override = _flat(Color(1.0, 0.1, 0.1))
		root.add_child(mi)
	print("SKIRT DEBUG: %d visible skirt verts, %d pool verts, %d overlay tris" % [
		skirt_n, pool_n, tris])
	return skirt_n


static func clear_skirt_debug() -> void:
	var root: Node = (Engine.get_main_loop() as SceneTree).root
	for n in root.find_children("SkirtDebugOverlay", "MeshInstance3D", true, false):
		n.queue_free()


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
