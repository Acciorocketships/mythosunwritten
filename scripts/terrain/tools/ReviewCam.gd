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
