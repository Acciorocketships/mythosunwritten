extends Node3D

## Archetype gallery (spec 2026-10-02 §7): for each archetype and sample, force
## the archetype everywhere, mesh a 3x3-chunk site through the production
## TerrainChunkMesher (no water), and capture oblique, top and close views.
##   Godot --path . res://tests/harness/regime_gallery.tscn -- --output DIR \
##     [--archetype NAME|all] [--samples N] [--seed S]
const Mesher := preload("res://scripts/terrain/field/TerrainChunkMesher.gd")
const STYLE := preload("res://scripts/terrain/field/CliffRockStyle.gd")
const SPACING := 7168.0   # metres between samples: distinct regions per sample

var _output := "/tmp/regime_gallery"
var _archetypes: Array[StringName] = []
var _samples := 2
var _seed := 2697992464
var _camera := Camera3D.new()
var _terrain := Node3D.new()


func _ready() -> void:
	var only := "all"
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		var next := args[i + 1] if i + 1 < args.size() else ""
		match args[i]:
			"--output": _output = next
			"--archetype": only = next
			"--samples": _samples = int(next)
			"--seed": _seed = int(next)
	_archetypes = TerrainRegimeCatalog.ARCHETYPES.duplicate() if only == "all" else [StringName(only)]
	get_window().size = Vector2i(1600, 900)
	DirAccess.make_dir_recursive_absolute(_output)
	_environment()
	_camera.current = true
	_camera.far = 6000.0
	add_child(_camera)
	add_child(_terrain)
	_run.call_deferred()


func _environment() -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.27, 0.46, 0.75)
	sky_material.sky_horizon_color = Color(0.71, 0.82, 0.92)
	var sky := Sky.new()
	sky.sky_material = sky_material
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.transform = Transform3D(Basis.from_euler(Vector3(deg_to_rad(-42.0), deg_to_rad(-70.0), 0.0)), Vector3.ZERO)
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.5
	sun.directional_shadow_max_distance = 1500.0
	add_child(sun)


func _run() -> void:
	STYLE.apply("sheet_bedrock")
	var mesher := Mesher.new()
	mesher.set_seed(_seed)
	mesher.prepare_resources()
	for a: StringName in _archetypes:
		TerrainRegimeField.set_force_archetype(a)
		for k in _samples:
			var centre_chunk := Vector2i(int((k + 1) * SPACING / 192.0), 3)
			var plan := HeightfieldPlan.new(_seed, TerrainWorldTuning.HEIGHTFIELD_AMPLITUDE,
				TerrainWorldTuning.HEIGHTFIELD_MAX_STOREYS, "mean", TerrainWorldTuning.MAX_CLIFF_STEP)
			var centre_point := centre_chunk * Mesher.POINTS_PER_CHUNK + Vector2i(8, 8)
			var region := plan.compute_region(centre_point.x, centre_point.y, 36)
			for child in _terrain.get_children():
				child.queue_free()
			var top := -INF
			for dz in range(-1, 2):
				for dx in range(-1, 2):
					var node := mesher.commit_chunk(mesher.compute_chunk(centre_chunk + Vector2i(dx, dz), region))
					_terrain.add_child(node)
					await get_tree().process_frame
			for j in range(-24, 25, 4):
				for i in range(-24, 25, 4):
					top = maxf(top, region.surface_height(centre_point.x + i, centre_point.y + j))
			var focus := Vector3(centre_point.x * 12.0, top * 0.5, centre_point.y * 12.0)
			var name := "%s_%d" % [a, k]
			await _shoot("%s/%s_oblique.png" % [_output, name], focus + Vector3(-260, 230, 330), focus)
			await _shoot("%s/%s_top.png" % [_output, name], focus + Vector3(0, 700, 0.01), focus)
			# Low and close: smooth one-storey slopes only read from near the ground.
			var near := Vector3(focus.x, region.surface_height(centre_point.x, centre_point.y), focus.z)
			await _shoot("%s/%s_close.png" % [_output, name], near + Vector3(-110, 45, 140), near)
			print("[regime_gallery] %s" % name)
	TerrainRegimeField.set_force_archetype(&"")
	print("[regime_gallery] done -> ", _output)
	get_tree().quit(0)


func _shoot(path: String, from: Vector3, target: Vector3) -> void:
	_camera.fov = 50.0
	_camera.look_at_from_position(from, target, Vector3.UP)
	for unused in 8:
		await get_tree().process_frame
	RenderingServer.force_draw()
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(path)
