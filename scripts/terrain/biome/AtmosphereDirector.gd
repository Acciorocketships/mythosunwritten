class_name AtmosphereDirector
extends Node

## A continuous biome mood changes the shared sky and lighting gradually.
## Local mist still follows the world-space terrain and biome field.
@export var environment_node: WorldEnvironment
@export var sun: DirectionalLight3D
@export var camera: Camera3D
@export var streamer: FieldTerrainStreamer
@export var player: Node3D
## High adds screen-space bounce; SDFGI is an explicit review experiment.
@export_enum("Economical", "Standard", "High") var quality: int = 1

var _light_budget: Node
var _underwater:Node
var _frontier: Node

var _ground_map := BiomeGroundMap.new()
var _mood_weights: Dictionary = {}
const MOOD_RESPONSE_SECONDS := 3.0

const SUN_COLOR := Color("ffe3be")
const SUN_ENERGY := 1.2
const SUN_ANGLE_DEG := Vector3(-32.0, -110.0, 0.0)
const SUN_SHADOW_DISTANCE := 60.0
const SUN_SHADOW_OPACITY := 0.82
const GLOW_BLOOM := 0.0
const GLOW_HDR_THRESHOLD := 1.4
const ECONOMICAL_GRASS_DENSITY := 0.65

func _ready() -> void:
	process_priority = 100
	_light_budget = preload("res://scripts/terrain/biome/LocalLightBudget.gd").new()
	add_child(_light_budget)
	_underwater=preload("res://scripts/camera/UnderwaterView.gd").new()
	add_child(_underwater)
	_frontier = preload("res://scripts/terrain/diagnostics/LoadingFrontierFog.gd").new()
	add_child(_frontier)
	set_process(not Helper.is_headless())
	if not Helper.is_headless():
		_apply_grade()
		if streamer != null and player != null:
			_update_mood(0.0, Helper.biome_weights5(player.global_position,streamer.world_seed))

func _apply_grade() -> void:
	var env := environment_node.environment
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_bloom = GLOW_BLOOM
	env.glow_hdr_threshold = GLOW_HDR_THRESHOLD
	env.glow_intensity = 0.8
	env.glow_strength = 1.1
	env.glow_normalized = false
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	for i in 7: env.set_glow_level(i, [0.4, 0.9, 0.65, 0.3, 0.12, 0.0, 0.0][i])
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.10
	env.adjustment_contrast = 1.025
	env.fog_enabled = true
	env.fog_density = 0.00035
	env.fog_light_color = Color("b4c9d1")
	env.fog_sky_affect = 0.12
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.0
	env.volumetric_fog_length = 144.0
	env.volumetric_fog_anisotropy = 0.45
	env.volumetric_fog_detail_spread = 0.65
	env.volumetric_fog_ambient_inject = 0.20
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("bacede")
	env.ambient_light_energy = 0.65
	env.ssao_enabled = true
	env.ssao_radius = 2.0
	env.ssao_intensity = 1.1
	env.ssao_light_affect = 0.2
	env.ssao_ao_channel_affect = 0.0
	var sky := env.sky.sky_material as ProceduralSkyMaterial
	sky.sky_top_color = Color("739bb9")
	sky.sky_horizon_color = Color("e5d8c6")
	sky.ground_horizon_color = sky.sky_horizon_color
	sky.ground_bottom_color = Color("697c8c")
	sun.light_color = SUN_COLOR
	sun.light_energy = SUN_ENERGY
	sun.rotation_degrees = SUN_ANGLE_DEG
	RenderingServer.global_shader_parameter_set("atmosphere_sun_ray", -sun.basis.z)
	sun.shadow_opacity = SUN_SHADOW_OPACITY
	# Wide PCF preserves softened contact shadows without the per-fragment
	# blocker search of angular PCSS across the dense grass carpet.
	sun.light_angular_distance = 0.0
	sun.shadow_blur = 1.5
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_split_1 = 0.08
	sun.directional_shadow_split_2 = 0.22
	sun.directional_shadow_split_3 = 0.5
	# Shadows end at SUN_SHADOW_DISTANCE (Godot's default was 100 m). Every
	# cascade redraws the casters in its slice; past ~60 m the close view's
	# shadows are a few pixels, but the cliff sheets and rocks there cost
	# millions of triangles a frame (October 6 frame-rate pass).
	sun.directional_shadow_max_distance = SUN_SHADOW_DISTANCE
	sun.light_volumetric_fog_energy = 1.1
	# Leave the scene sharp until the camera redesign establishes a focus model.
	camera.attributes = null
	set_quality(quality)

func _process(dt: float) -> void:
	if is_instance_valid(_light_budget): _light_budget.update_lights(camera, quality)
	for wisp in get_tree().get_nodes_in_group("atmosphere_mist_wisp"):
		if camera != null and wisp.get_world_3d() == camera.get_world_3d():
			wisp.visible = quality >= 1
	if not Helper.is_headless() and streamer != null and player != null:
		_underwater.camera=camera
		_underwater.world_seed=streamer.world_seed
		_ground_map.update(player.global_position, streamer.world_seed)
		# Grass may be created after the director's initial grade. The setter is
		# idempotent and changes only draw counts, never worker-generated payloads.
		if streamer._grass_streamer != null:
			streamer._grass_streamer.set_density_scale(ECONOMICAL_GRASS_DENSITY if quality == 0 else 1.0)
		_update_mood(dt, Helper.biome_weights5(player.global_position,streamer.world_seed))
		_underwater.update_view()
		_frontier.update_view(camera, streamer._built, environment_node.environment.fog_light_color)

func _update_mood(dt: float, target: Dictionary) -> void:
	if _mood_weights.is_empty():
		_mood_weights = target.duplicate()
	else:
		var amount := 1.0-exp(-maxf(dt,0.0)/MOOD_RESPONSE_SECONDS)
		for id: StringName in BiomeRegistry.biome_ids():
			_mood_weights[id] = lerpf(float(_mood_weights.get(id,0.0)),float(target.get(id,0.0)),amount)
	_apply_mood(BiomeRegistry.blend_atmosphere(_mood_weights))

func _apply_mood(mood: Dictionary) -> void:
	var env := environment_node.environment
	env.ambient_light_color = mood[&"ambient_color"]
	env.ambient_light_energy = mood[&"ambient_energy"]
	env.glow_intensity = mood[&"glow_intensity"]
	env.fog_light_color = mood[&"fog_color"]
	env.fog_density = float(mood[&"haze_density"])
	var sky := env.sky.sky_material as ProceduralSkyMaterial
	sky.sky_top_color = mood[&"sky_top"]
	sky.sky_horizon_color = mood[&"sky_horizon"]
	sky.ground_horizon_color = mood[&"sky_horizon"]
	sky.ground_bottom_color = mood[&"ambient_color"] * 0.5
	sun.light_color = mood[&"sun_color"]
	sun.light_energy = mood[&"sun_energy"]
	sun.light_volumetric_fog_energy = mood[&"sun_scattering"]
	var top := (mood[&"sky_top"] as Color).srgb_to_linear()
	var horizon := (mood[&"sky_horizon"] as Color).srgb_to_linear()
	RenderingServer.global_shader_parameter_set("atmosphere_sky_top", Vector4(top.r, top.g, top.b, 1.0))
	RenderingServer.global_shader_parameter_set("atmosphere_sky_horizon", Vector4(horizon.r, horizon.g, horizon.b, 1.0))
	var gain := water_light_gain(mood)
	RenderingServer.global_shader_parameter_set("atmosphere_water_gain", gain)
	if is_instance_valid(_underwater):
		_underwater.light_gain = gain

func set_quality(level: int) -> void:
	quality = clampi(level, 0, 2)
	RenderingServer.global_shader_parameter_set("canopy_shadow_detail", 1.0 if quality >= 1 else 0.0)
	var grass_density := ECONOMICAL_GRASS_DENSITY if quality == 0 else 1.0
	RenderingServer.global_shader_parameter_set(&"grass_density_scale", grass_density)
	if streamer != null and streamer._grass_streamer != null:
		streamer._grass_streamer.set_density_scale(grass_density)
	if environment_node == null or environment_node.environment == null:
		return
	var env := environment_node.environment
	env.volumetric_fog_enabled = quality >= 1
	env.ssao_enabled = quality >= 1
	env.ssil_enabled = quality >= 2
	env.ssil_intensity = 0.45
	env.ssil_radius = 3.0
	env.sdfgi_enabled = false
	if camera != null and camera.is_inside_tree():
		camera.get_viewport().msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][quality]
		camera.get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if quality == 0 else Viewport.SCREEN_SPACE_AA_DISABLED

static func water_light_gain(mood: Dictionary) -> float:
	# Only water's authored scattering/foam is lit here. Its screen transmission
	# already contains scene lighting and must never be multiplied a second time.
	return clampf((float(mood[&"ambient_energy"]) + float(mood[&"sun_energy"]) * 0.3) / 1.1, 0.08, 1.5)

func _exit_tree() -> void:
	RenderingServer.global_shader_parameter_set("canopy_shadow_detail", 0.0)
	RenderingServer.global_shader_parameter_set(&"grass_density_scale", 1.0)
	RenderingServer.global_shader_parameter_set("atmosphere_sky_top", Vector4.ZERO)
	RenderingServer.global_shader_parameter_set("atmosphere_sky_horizon", Vector4.ZERO)
	RenderingServer.global_shader_parameter_set("atmosphere_water_gain", 1.0)
