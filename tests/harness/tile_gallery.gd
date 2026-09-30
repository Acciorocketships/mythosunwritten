extends Node3D

## Dual-grid terrain tile gallery (spec 2026-09-30 sections 5 and 8; plan Task 11).
## Every corner case of the TerrainTileField kernel on one synthetic point
## heightfield, meshed by the production TerrainChunkMesher (compute_chunk +
## commit_chunk: sheet, rock skirts, the `sheet_bedrock` cliff sheet and its
## rocks), one labelled island per case on a flat base. The mixed cliff-end
## island is built twice, E1 and E2, in neighbouring chunks meshed with
## TerrainTileField.cliff_end set accordingly (pure slope/cliff layers are
## identical under both rules, so only the mixed-end chunks care).
##
## Output (then exits):
##   <case>.png         oblique close-up of one case
##   <case>_lines.png   same view: lattice points (white), level edges (blue),
##                      slope edges (green), wall_segments (red: top, bottom, ends)
##   <case>_f9.png      same view with the production F9 TerrainCategoryOverlay
##                      (fed by a stand-in streamer holding the gallery's point
##                      snapshots; skipped if the overlay cannot load)
##   overview.png, overview_lines.png, plan.png, plan_lines.png,
##   e1_vs_e2(_lines,_f9).png, mixed_e1_end / mixed_e2_end (+_lines, _f9): the
##   south cliff end of each mixed island up close
##
##   Godot --path . res://tests/harness/tile_gallery.tscn -- --output DIR [--only case,case]
const Mesher := preload("res://scripts/terrain/field/TerrainChunkMesher.gd")
const STYLE := preload("res://scripts/terrain/field/CliffRockStyle.gd")
const OVERLAY_PATH := "res://scripts/terrain/tools/TerrainCategoryOverlay.gd"
const SEED := 2697992464
const S := 12.0                      # lattice pitch (TerrainTileField.SPACING)
const E1 := TerrainTileField.CliffEnd.E1
const E2 := TerrainTileField.CliffEnd.E2
## Chunks meshed (the gallery is chunks (0..2, 0..1); the rest is flat margin).
const CHUNKS_X := Vector2i(-1, 3)
const CHUNKS_Z := Vector2i(-1, 2)
## Chunk (1,1) holds the E1 mixed island (and only pure-layer cases).
const E1_CHUNKS := [Vector2i(1, 1)]

## id, label, centre point, azimuth (deg, 0 = camera on +z), view radius (m).
## Offsets (dx, dz) in each case's height function are relative to the centre.
const CASES := [
	{"id": "flat", "label": "flat", "c": Vector2i(4, 4), "az": 20.0, "r": 26.0},
	{"id": "slope_straight", "label": "slope straight\n(1 storey over 12 m)", "c": Vector2i(12, 4), "az": 0.0, "r": 28.0, "el": 28.0},
	{"id": "slope_outer", "label": "slope outer corner", "c": Vector2i(4, 12), "az": 45.0, "r": 26.0, "el": 28.0},
	{"id": "slope_inner", "label": "slope inner corner", "c": Vector2i(12, 12), "az": 45.0, "r": 30.0, "el": 28.0},
	{"id": "slope_saddle", "label": "slope saddle", "c": Vector2i(20, 4), "az": 135.0, "r": 32.0, "el": 28.0},
	{"id": "level_steps", "label": "level steps 1-3 m", "c": Vector2i(28, 4), "az": 30.0, "r": 24.0, "el": 26.0},
	{"id": "cliff_straight", "label": "cliff straight (8 m)", "c": Vector2i(20, 12), "az": 0.0, "r": 38.0},
	{"id": "cliff_outer", "label": "cliff outer corner", "c": Vector2i(28, 12), "az": 45.0, "r": 32.0},
	{"id": "cliff_inner", "label": "cliff inner corner", "c": Vector2i(4, 20), "az": 45.0, "r": 38.0},
	{"id": "cliff_3storey", "label": "3-storey cliff (12 m)", "c": Vector2i(4, 28), "az": 60.0, "r": 38.0},
	{"id": "mixed_e2", "label": "cliff end E2\n(wall to centre, then ramp)", "c": Vector2i(11, 26), "az": 20.0, "r": 40.0},
	{"id": "mixed_e1", "label": "cliff end E1\n(blend inside tile)", "c": Vector2i(21, 26), "az": 20.0, "r": 40.0},
	{"id": "cliff_saddle", "label": "cliff saddle", "c": Vector2i(27, 19), "az": 135.0, "r": 40.0},
	{"id": "terrace_hill", "label": "terrace hill", "c": Vector2i(40, 16), "az": 20.0, "r": 75.0},
]

var _output := "/tmp/tile_gallery"
var _only: PackedStringArray = []
var _region: HeightfieldRegion
var _camera := Camera3D.new()
var _terrain := Node3D.new()
var _lines := Node3D.new()
var _labels := Node3D.new()
var _overlay: Node = null


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		var next := args[index + 1] if index + 1 < args.size() else ""
		match args[index]:
			"--output": _output = next
			"--only": _only = next.split(",", false)
	get_window().size = Vector2i(1600, 900)
	DirAccess.make_dir_recursive_absolute(_output)
	_environment()
	_camera.current = true
	_camera.far = 4000.0
	add_child(_camera)
	_terrain.name = "Terrain"
	add_child(_terrain)
	_labels.name = "Labels"
	add_child(_labels)
	_lines.name = "Lines"
	_lines.visible = false
	add_child(_lines)
	_run.call_deferred()


func _environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.27, 0.46, 0.75)
	sky_material.sky_horizon_color = Color(0.71, 0.82, 0.92)
	sky_material.ground_bottom_color = Color(0.42, 0.5, 0.56)
	sky_material.ground_horizon_color = Color(0.68, 0.78, 0.86)
	var sky := Sky.new()
	sky.sky_material = sky_material
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color(0.62, 0.6, 0.55)
	env.ambient_light_sky_contribution = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	# A low sun from the west (travelling +x, slightly -z): the gallery cameras
	# look -z, so relief is side-lit instead of flattened by a sun behind them.
	sun.transform = Transform3D(Basis.from_euler(Vector3(deg_to_rad(-42.0), deg_to_rad(-70.0), 0.0)), Vector3.ZERO)
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.5
	sun.directional_shadow_max_distance = 900.0
	add_child(sun)


func _run() -> void:
	var started := Time.get_ticks_msec()
	_region = _build_region()
	STYLE.apply("sheet_bedrock")
	var mesher := Mesher.new()
	mesher.set_seed(SEED)
	mesher.prepare_resources()
	var saved: int = TerrainTileField.cliff_end
	for cz in range(CHUNKS_Z.x, CHUNKS_Z.y + 1):
		for cx in range(CHUNKS_X.x, CHUNKS_X.y + 1):
			var chunk := Vector2i(cx, cz)
			TerrainTileField.cliff_end = E1 if E1_CHUNKS.has(chunk) else E2
			var t := Time.get_ticks_msec()
			var node := mesher.commit_chunk(mesher.compute_chunk(chunk, _region))
			_terrain.add_child(node)
			print("[tile_gallery] chunk %s end=%s ms=%d" % [chunk, "E1" if TerrainTileField.cliff_end == E1 else "E2", Time.get_ticks_msec() - t])
			await get_tree().process_frame
	TerrainTileField.cliff_end = saved
	_add_labels()
	_build_lines()
	_install_overlay()
	print("[tile_gallery] built in %d ms" % (Time.get_ticks_msec() - started))
	for unused in 20:
		await get_tree().process_frame
	for view: Dictionary in _views():
		if not _only.is_empty() and not _only.has(String(view.id)):
			continue
		await _shoot(view)
	print("[tile_gallery] done -> ", _output)
	get_tree().quit(0)


# --- the heightfield ---------------------------------------------------------------

## Height (m) of lattice point (i, j): the flat base (0) plus every case island.
static func height_at(i: int, j: int) -> float:
	for case: Dictionary in CASES:
		var c: Vector2i = case.c
		var h := _case_height(String(case.id), i - c.x, j - c.y)
		if h != 0.0:
			return h
	return 0.0


static func _case_height(id: String, dx: int, dz: int) -> float:
	var box := func(x0: int, x1: int, z0: int, z1: int) -> bool:
		return dx >= x0 and dx <= x1 and dz >= z0 and dz <= z1
	match id:
		"slope_straight":
			return 4.0 if box.call(-3, 3, -3, 0) else 0.0
		"slope_outer":
			return 4.0 if box.call(-1, 1, -1, 1) else 0.0
		"slope_inner":
			return 4.0 if box.call(-2, 2, -2, 2) and not box.call(1, 2, 1, 2) else 0.0
		"slope_saddle":
			return 4.0 if box.call(-2, 0, -2, 0) or box.call(1, 3, 1, 3) else 0.0
		"level_steps":
			if dx == 0 and dz == 0: return 3.0
			if box.call(-1, 1, -1, 1): return 2.0
			if box.call(-2, 2, -2, 2): return 1.0
			return 0.0
		"cliff_straight":
			return 8.0 if box.call(-3, 3, -3, 0) else 0.0
		"cliff_outer":
			return 8.0 if box.call(-1, 1, -1, 1) else 0.0
		"cliff_inner":
			return 8.0 if box.call(-2, 2, -2, 2) and not box.call(1, 2, 1, 2) else 0.0
		"cliff_saddle":
			return 8.0 if box.call(-2, 0, -2, 0) or box.call(1, 3, 1, 3) else 0.0
		"cliff_3storey":
			return 12.0 if box.call(-1, 1, -2, 1) else 0.0
		"mixed_e1", "mixed_e2":
			# An 8 m plateau: its west side walls straight down to 0 (cliff); its
			# east side steps 8 -> 4 -> 0 over a one-storey ring (slopes). The
			# north and south walls end where the ring turns from 0 to 4.
			if box.call(-1, 1, -1, 1): return 8.0
			if box.call(0, 2, -2, 2): return 4.0
			return 0.0
		"terrace_hill":
			# Concentric one-storey terraces (slopes) up to 16 m; the west flank
			# drops 12 -> 4 in one cliff (cliff ends where it meets the east
			# slopes), a level step rings the north foot.
			if absi(dx) > 6 or absi(dz) > 9:
				return 0.0
			var r := sqrt(pow(float(dx) * 8.0 / 6.0, 2.0) + float(dz * dz))
			var h := 0.0
			if r < 2.0: h = 16.0
			elif r < 3.5: h = 12.0
			elif r < 5.5: h = 4.0 if dx < 0 else 8.0
			elif r < 7.0: h = 4.0
			elif r < 8.5 and dz < 0: h = 2.0
			return h
	return 0.0


static func _build_region() -> HeightfieldRegion:
	var storeys := {}
	var levels := {}
	var lo := Vector2i(CHUNKS_X.x, CHUNKS_Z.x) * Mesher.POINTS_PER_CHUNK - Vector2i.ONE * 12
	var hi := Vector2i(CHUNKS_X.y + 1, CHUNKS_Z.y + 1) * Mesher.POINTS_PER_CHUNK + Vector2i.ONE * 12
	for j in range(lo.y, hi.y + 1):
		for i in range(lo.x, hi.x + 1):
			var h := height_at(i, j)
			storeys[Vector2i(i, j)] = floori(h / 4.0)
			levels[Vector2i(i, j)] = floori(fposmod(h, 4.0))
	return HeightfieldRegion.new(storeys, levels)


static func _case(id: String) -> Dictionary:
	for case: Dictionary in CASES:
		if case.id == id:
			return case
	return {}


static func _case_top(case: Dictionary) -> float:
	var c: Vector2i = case.c
	var top := 0.0
	for dz in range(-10, 11):
		for dx in range(-10, 11):
			top = maxf(top, _case_height(String(case.id), dx, dz))
	return top


# --- labels ---------------------------------------------------------------------------

func _add_labels() -> void:
	for case: Dictionary in CASES:
		var c: Vector2i = case.c
		var label := Label3D.new()
		label.text = String(case.label)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		label.no_depth_test = true
		label.fixed_size = false
		label.pixel_size = 0.03 if case.id != "terrace_hill" else 0.06
		label.set_meta("pixel_size", label.pixel_size)
		label.font_size = 96
		label.outline_size = 24
		label.modulate = Color(1.0, 1.0, 0.9)
		label.outline_modulate = Color(0.0, 0.0, 0.0)
		label.position = Vector3(float(c.x) * S, _case_top(case) + 12.0 * (1.0 if case.id != "terrace_hill" else 1.8), float(c.y) * S)
		_labels.add_child(label)


# --- lattice / wall / edge lines -----------------------------------------------------

func _build_lines() -> void:
	var rect := Rect2(Vector2(-2.0, -2.0) * S, Vector2(50.0, 36.0) * S)
	var red: Array[Transform3D] = []
	var green: Array[Transform3D] = []
	var blue: Array[Transform3D] = []
	var dots: Array[Transform3D] = []
	for wall: Dictionary in TerrainTileField.wall_segments(_region, rect):
		var a: Vector2 = wall.a
		var b: Vector2 = wall.b
		var top: Vector2 = wall.top
		var bottom: Vector2 = wall.bottom
		red.append(_bar(Vector3(a.x, top.x + 0.15, a.y), Vector3(b.x, top.y + 0.15, b.y), 0.3))
		red.append(_bar(Vector3(a.x, bottom.x + 0.15, a.y), Vector3(b.x, bottom.y + 0.15, b.y), 0.3))
		red.append(_bar(Vector3(a.x, bottom.x, a.y), Vector3(a.x, top.x, a.y), 0.2))
		red.append(_bar(Vector3(b.x, bottom.y, b.y), Vector3(b.x, top.y, b.y), 0.2))
	var i0 := floori(rect.position.x / S)
	var j0 := floori(rect.position.y / S)
	var i1 := ceili(rect.end.x / S)
	var j1 := ceili(rect.end.y / S)
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var p := Vector2i(i, j)
			dots.append(Transform3D(Basis().scaled(Vector3.ONE * 0.9),
				Vector3(float(i) * S, _region.surface_height(i, j) + 0.3, float(j) * S)))
			for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
				var category := TerrainTileField.edge_category(_region, p, d)
				if category != TerrainTileField.EdgeCategory.SLOPE and category != TerrainTileField.EdgeCategory.LEVEL:
					continue
				var target: Array[Transform3D] = green if category == TerrainTileField.EdgeCategory.SLOPE else blue
				# The lattice edge lies on a tile border (never a wall line):
				# follow the surface along it, sampled every metre.
				var steps := 12
				var previous := Vector3.ZERO
				for k in steps + 1:
					var w := Vector2(p) * S + Vector2(d) * S * float(k) / float(steps)
					var point := Vector3(w.x, TerrainTileField.surface_y(_region, w.x, w.y) + 0.35, w.y)
					if k > 0:
						target.append(_bar(previous, point, 0.25))
					previous = point
	_lines.add_child(_multimesh(red, Color(1.0, 0.1, 0.1), BoxMesh.new()))
	_lines.add_child(_multimesh(green, Color(0.1, 0.95, 0.2), BoxMesh.new()))
	_lines.add_child(_multimesh(blue, Color(0.2, 0.5, 1.0), BoxMesh.new()))
	var sphere := SphereMesh.new()
	sphere.radial_segments = 8
	sphere.rings = 4
	_lines.add_child(_multimesh(dots, Color(0.95, 0.95, 0.95), sphere))


static func _bar(a: Vector3, b: Vector3, width: float) -> Transform3D:
	var along := b - a
	if along.length() < 1e-4:
		along = Vector3.UP * 1e-3
	var x := along
	var helper := Vector3.UP if absf(along.normalized().dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
	var z := x.cross(helper).normalized() * width
	var y := z.cross(x).normalized() * width
	return Transform3D(Basis(x, y, z), (a + b) * 0.5)


static func _multimesh(transforms: Array[Transform3D], color: Color, mesh: Mesh) -> MultiMeshInstance3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.no_depth_test = true
	material.render_priority = 10
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for index in transforms.size():
		mm.set_instance_transform(index, transforms[index])
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


# --- F9 overlay ------------------------------------------------------------------------

## The production overlay reads the streamer's per-chunk point snapshots
## (`loaded_point_at`). A stand-in streamer subclass (no worker, no streaming)
## holds the gallery's snapshots; built at runtime so the harness still runs
## when the overlay or streamer script is mid-edit.
func _install_overlay() -> void:
	var stand_in := GDScript.new()
	stand_in.source_code = "extends FieldTerrainStreamer\n" \
		+ "func _ready() -> void:\n\tpass\n" \
		+ "func _process(_delta: float) -> void:\n\tpass\n" \
		+ "func _exit_tree() -> void:\n\tpass\n"
	if stand_in.reload() != OK:
		push_warning("[tile_gallery] no stand-in streamer: F9 views skipped")
		return
	var overlay_script := load(OVERLAY_PATH) as Script
	if overlay_script == null:
		push_warning("[tile_gallery] overlay script failed to load: F9 views skipped")
		return
	var streamer = stand_in.new()
	streamer.name = "FieldTerrain"
	add_child(streamer)
	for cz in range(CHUNKS_Z.x, CHUNKS_Z.y + 1):
		for cx in range(CHUNKS_X.x, CHUNKS_X.y + 1):
			var chunk := Vector2i(cx, cz)
			streamer._point_snapshots[chunk] = FieldTerrainStreamer._point_snapshot(chunk, _region)
	_overlay = CanvasLayer.new()
	_overlay.set_script(overlay_script)
	_overlay.name = "TerrainCategoryOverlay"
	add_child(_overlay)


# --- views -----------------------------------------------------------------------------

func _views() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for case: Dictionary in CASES:
		var c: Vector2i = case.c
		var top := _case_top(case)
		var focus := Vector3(float(c.x) * S, top * 0.4, float(c.y) * S)
		out.append(_orbit(String(case.id), focus, float(case.az), float(case.get("el", 34.0)), float(case.r)))
	var e1: Vector2i = _case("mixed_e1").c
	var e2: Vector2i = _case("mixed_e2").c
	var mid := (Vector3(float(e1.x), 0.0, float(e1.y)) + Vector3(float(e2.x), 0.0, float(e2.y))) * 0.5 * S
	out.append(_orbit("e1_vs_e2", mid + Vector3.UP * 3.0, 0.0, 30.0, 80.0))
	# Close-ups of each mixed island's south cliff end: the tile between the
	# plateau row dz = 1 and the ring row dz = 2 where the ring turns 0 -> 4.
	for id: String in ["mixed_e2", "mixed_e1"]:
		var c: Vector2i = _case(id).c
		var end := Vector3((float(c.x) - 0.5) * S, 3.0, (float(c.y) + 1.5) * S)
		out.append(_orbit(id + "_end", end, -35.0, 28.0, 16.0))
	var overview := _orbit("overview", Vector3(21.5 * S, 0.0, 17.0 * S), 10.0, 42.0, 215.0)
	overview["labels"] = 3.0
	out.append(overview)
	out.append({"id": "plan", "position": Vector3(23.0 * S, 470.0, 16.0 * S + 0.01),
		"target": Vector3(23.0 * S, 0.0, 16.0 * S), "fov": 50.0, "up": Vector3.FORWARD, "labels": 3.0})
	return out


## A camera `radius`-fitting distance from `focus`, at `azimuth` (0 = on +z)
## and `elevation` degrees.
static func _orbit(id: String, focus: Vector3, azimuth: float, elevation: float, radius: float) -> Dictionary:
	var fov := 50.0
	var distance := maxf(30.0, radius / tan(deg_to_rad(fov * 0.5)))
	var az := deg_to_rad(azimuth)
	var el := deg_to_rad(elevation)
	var direction := Vector3(sin(az) * cos(el), sin(el), cos(az) * cos(el))
	return {"id": id, "position": focus + direction * distance, "target": focus, "fov": fov, "up": Vector3.UP}


func _shoot(view: Dictionary) -> void:
	_camera.fov = float(view.fov)
	_camera.look_at_from_position(view.position, view.target, view.up)
	_camera.force_update_transform()
	var label_scale: float = view.get("labels", 1.0)
	for label: Label3D in _labels.get_children():
		label.pixel_size = float(label.get_meta("pixel_size")) * label_scale
	await _save("%s/%s.png" % [_output, view.id])
	_lines.visible = true
	await _save("%s/%s_lines.png" % [_output, view.id])
	_lines.visible = false
	var is_overview: bool = view.id == "overview" or view.id == "plan"
	if _overlay != null and not is_overview:
		# The overlay's kernel follows the global cliff-end rule: the E1
		# island's views compare against E1 (e1_vs_e2 shows both, under E2).
		var saved: int = TerrainTileField.cliff_end
		if String(view.id).begins_with("mixed_e1"):
			TerrainTileField.cliff_end = TerrainTileField.CliffEnd.E1
		_overlay.set_enabled(true)
		for unused in 3:
			await get_tree().process_frame
		await _save("%s/%s_f9.png" % [_output, view.id])
		_overlay.set_enabled(false)
		TerrainTileField.cliff_end = saved


func _save(path: String) -> void:
	for unused in 5:
		await get_tree().process_frame
	RenderingServer.force_draw()
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(path)
