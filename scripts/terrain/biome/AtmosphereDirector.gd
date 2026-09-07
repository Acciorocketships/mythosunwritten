class_name AtmosphereDirector
extends Node

## One coherent sky and sun. Local biome mood belongs to world-space fog,
## vegetation and ground, so walking cannot relight distant scenery.
@export var environment_node: WorldEnvironment
@export var sun: DirectionalLight3D
@export var camera: Camera3D
@export var streamer: FieldTerrainStreamer
@export var player: Node3D
@export_range(0.0, 0.3) var focus_softness := 0.12

var _ground_map := BiomeGroundMap.new()

const SUN_COLOR := Color("ffe3be")
const SUN_ENERGY := 1.2
const SUN_ANGLE_DEG := Vector3(-32.0, -28.0, 0.0)
const SUN_SHADOW_OPACITY := 0.65
const GLOW_BLOOM := 0.035
const GLOW_HDR_THRESHOLD := 1.15

func _ready() -> void:
	set_process(not Helper.is_headless())
	if not Helper.is_headless():
		_apply_grade()

func _apply_grade() -> void:
	var env := environment_node.environment
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_bloom = GLOW_BLOOM
	env.glow_hdr_threshold = GLOW_HDR_THRESHOLD
	env.glow_intensity = 0.8
	env.glow_strength = 1.1
	env.glow_normalized = true
	env.fog_enabled = true
	env.fog_density = 0.00035
	env.fog_light_color = Color("b4c9d1")
	env.fog_sky_affect = 0.12
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.0
	env.volumetric_fog_length = 512.0
	env.volumetric_fog_detail_spread = 0.65
	env.volumetric_fog_ambient_inject = 0.45
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
	sun.shadow_opacity = SUN_SHADOW_OPACITY
	sun.light_angular_distance = 2.5
	sun.light_volumetric_fog_energy = 1.1
	var attrs := CameraAttributesPractical.new()
	attrs.dof_blur_far_enabled = true
	attrs.dof_blur_far_distance = 190.0
	attrs.dof_blur_far_transition = 180.0
	attrs.dof_blur_near_enabled = true
	attrs.dof_blur_near_distance = 7.0
	attrs.dof_blur_near_transition = 5.0
	attrs.dof_blur_amount = focus_softness
	camera.attributes = attrs

func _process(_dt: float) -> void:
	# Only scroll the deterministic substrate lookup; lighting never changes.
	if not Helper.is_headless() and streamer != null and player != null:
		_ground_map.update(player.global_position, streamer.world_seed)
