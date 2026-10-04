extends Node3D

## Fast landform preview (terrain regimes iteration). Samples the production
## kernel (HeightfieldPlan -> HeightfieldRegion -> TerrainTileField.surface_y)
## on a regular grid over a square area and draws it as one mesh with an
## elevation colour ramp, rock on steep faces and faint storey contours, lit by a
## low sun. No cliff sheet, grass or water: it exists to judge landform
## structure quickly; confirm finished looks with regime_gallery or the game.
##   Godot --path . res://tests/harness/terrain_preview.tscn -- --output DIR
##     [--archetype NAME|all|world] [--samples N] [--size M] [--step M]
##     [--seed S] [--center X,Z] [--yaw DEG]
## --yaw turns the oblique/low/ground cameras round the centre (0 = from the
## south-west); the ground shot stands 0.45 size out, 25 m above the terrain.
## `world` renders the unforced world at --center; an archetype forces it
## everywhere and renders `samples` sites spaced far apart.

const SPACING := 7168.0

var _output := "/tmp/terrain_preview"
var _which := "all"
var _samples := 2
var _size := 1536.0
var _step := 4.0
var _seed := 2697992464
var _center := Vector2(6000, -3000)
var _yaw := 0.0
var _heights := PackedFloat32Array()
var _origin := Vector2.ZERO
var _n := 0
var _camera := Camera3D.new()
var _terrain := MeshInstance3D.new()


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		var next := args[i + 1] if i + 1 < args.size() else ""
		match args[i]:
			"--output": _output = next
			"--archetype": _which = next
			"--samples": _samples = int(next)
			"--size": _size = float(next)
			"--step": _step = float(next)
			"--seed": _seed = int(next)
			"--yaw": _yaw = deg_to_rad(float(next))
			"--center":
				var parts := next.split(",")
				_center = Vector2(float(parts[0]), float(parts[1]))
	get_window().size = Vector2i(1600, 900)
	DirAccess.make_dir_recursive_absolute(_output)
	_environment()
	_camera.current = true
	_camera.far = 12000.0
	add_child(_camera)
	_terrain.material_override = _material()
	add_child(_terrain)
	_run.call_deferred()


func _environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.32, 0.5, 0.78)
	sky_material.sky_horizon_color = Color(0.74, 0.83, 0.92)
	sky_material.ground_horizon_color = Color(0.74, 0.83, 0.92)
	var sky := Sky.new()
	sky.sky_material = sky_material
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.transform = Transform3D(Basis.from_euler(Vector3(deg_to_rad(-28.0), deg_to_rad(-60.0), 0.0)), Vector3.ZERO)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 4000.0
	add_child(sun)


func _material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
varying vec3 world_pos;
varying vec3 world_normal;
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	float h = world_pos.y;
	vec3 low = vec3(0.20, 0.34, 0.13);
	vec3 mid = vec3(0.34, 0.40, 0.18);
	vec3 high = vec3(0.45, 0.40, 0.28);
	vec3 peak = vec3(0.55, 0.53, 0.50);
	vec3 c = mix(low, mid, smoothstep(0.0, 80.0, h));
	c = mix(c, high, smoothstep(80.0, 180.0, h));
	c = mix(c, peak, smoothstep(200.0, 300.0, h));
	float steep = 1.0 - smoothstep(0.55, 0.8, world_normal.y);
	c = mix(c, vec3(0.33, 0.30, 0.28), steep);
	float band = abs(fract(h / 4.0 + 0.5) - 0.5) * 4.0;
	c *= mix(0.85, 1.0, smoothstep(0.0, 0.12, band));
	ALBEDO = c;
	ROUGHNESS = 0.95;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


func _run() -> void:
	var sites: Array = []
	if _which == "world":
		sites.append([&"", _center, "world_%d_%d" % [int(_center.x), int(_center.y)]])
	else:
		var names: Array = TerrainRegimeCatalog.ARCHETYPES if _which == "all" else [StringName(_which)]
		for a: StringName in names:
			for k in _samples:
				sites.append([a, Vector2((k + 1) * SPACING, 600.0), "%s_%d" % [a, k]])
	for site: Array in sites:
		TerrainRegimeField.set_force_archetype(site[0])
		var started := Time.get_ticks_msec()
		var top := _build(site[1])
		print("[terrain_preview] %s built in %d ms, top %.1f m" % [site[2], Time.get_ticks_msec() - started, top])
		var c: Vector2 = site[1]
		var focus := Vector3(c.x, top * 0.35, c.y)
		await _shoot("%s/%s_oblique.png" % [_output, site[2]], focus + Vector3(-0.62, 0.48, 0.62).rotated(Vector3.UP, _yaw) * _size * 0.95, focus)
		await _shoot("%s/%s_low.png" % [_output, site[2]], focus + Vector3(-0.55, 0.16, 0.55).rotated(Vector3.UP, _yaw) * _size * 0.75, focus)
		var out := Vector2(-0.707, 0.707).rotated(-_yaw) * _size * 0.45
		var eye := Vector3(c.x + out.x, _height_at(c + out) + 25.0, c.y + out.y)
		await _shoot("%s/%s_ground.png" % [_output, site[2]], eye, Vector3(c.x, _height_at(c) + 10.0, c.y))
		await _shoot("%s/%s_top.png" % [_output, site[2]], Vector3(c.x, _size * 1.25, c.y + 0.01), Vector3(c.x, 0, c.y))
	TerrainRegimeField.set_force_archetype(&"")
	print("[terrain_preview] done -> ", _output)
	get_tree().quit(0)


## Samples the kernel over the square and commits one mesh; returns the top.
func _build(c: Vector2) -> float:
	var plan := HeightfieldPlan.new(_seed, TerrainWorldTuning.HEIGHTFIELD_AMPLITUDE,
		TerrainWorldTuning.HEIGHTFIELD_MAX_STOREYS, "mean", TerrainWorldTuning.MAX_CLIFF_STEP)
	var half := _size * 0.5
	var lo := Vector2i(floori((c.x - half) / 12.0) - 2, floori((c.y - half) / 12.0) - 2)
	var count := int(_size / 12.0) + 5
	var region := plan.compute_rect_region(Rect2i(lo, Vector2i(count, count)))
	var n := int(_size / _step) + 1
	var heights := PackedFloat32Array()
	heights.resize(n * n)
	var top := -INF
	for j in n:
		for i in n:
			var x := c.x - half + i * _step
			var z := c.y - half + j * _step
			var h := TerrainTileField.surface_y(region, x, z)
			heights[j * n + i] = h
			top = maxf(top, h)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	verts.resize(n * n)
	normals.resize(n * n)
	for j in n:
		for i in n:
			var h := heights[j * n + i]
			verts[j * n + i] = Vector3(c.x - half + i * _step, h, c.y - half + j * _step)
			var hx := heights[j * n + mini(i + 1, n - 1)] - heights[j * n + maxi(i - 1, 0)]
			var hz := heights[mini(j + 1, n - 1) * n + i] - heights[maxi(j - 1, 0) * n + i]
			normals[j * n + i] = Vector3(-hx, 2.0 * _step, -hz).normalized()
	var indices := PackedInt32Array()
	for j in n - 1:
		for i in n - 1:
			var a := j * n + i
			indices.append_array([a, a + 1, a + n, a + 1, a + n + 1, a + n])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_terrain.mesh = mesh
	_heights = heights
	_origin = c - Vector2(half, half)
	_n = n
	return top


func _height_at(p: Vector2) -> float:
	var i := clampi(roundi((p.x - _origin.x) / _step), 0, _n - 1)
	var j := clampi(roundi((p.y - _origin.y) / _step), 0, _n - 1)
	return _heights[j * _n + i]


func _shoot(path: String, from: Vector3, target: Vector3) -> void:
	_camera.fov = 50.0
	_camera.look_at_from_position(from, target, Vector3.UP if absf(from.x - target.x) + absf(from.z - target.z) > 1.0 else Vector3.FORWARD)
	for unused in 6:
		await get_tree().process_frame
	RenderingServer.force_draw()
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(path)
