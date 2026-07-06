# scripts/terrain/biome/AtmosphereDirector.gd
# Applies the fixed-time global grade once, then continuously eases fog/sky/
# ambient toward the biome blend at the player position. Master §11.9 / spec §3+§6.
class_name AtmosphereDirector
extends Node

@export var environment_node: WorldEnvironment
@export var sun: DirectionalLight3D
@export var camera: Camera3D
@export var streamer: FieldTerrainStreamer
@export var player: Node3D

const SAMPLE_INTERVAL := 0.2
const EASE_SPEED := 1.5          # fraction of remaining distance per second

# — the global grade, one place to tune —
const SUN_COLOR := Color("ffeacc")
const SUN_ENERGY := 1.3
const SUN_ANGLE_DEG := Vector3(-35.0, 40.0, 0.0)   # low golden hour
const GLOW_BLOOM := 0.15
const GLOW_HDR_THRESHOLD := 1.05
const DOF_FAR_DISTANCE := 220.0
const DOF_FAR_TRANSITION := 120.0
const DOF_NEAR_DISTANCE := 6.0
const DOF_NEAR_TRANSITION := 4.0
const DOF_AMOUNT := 0.08

var _accum := SAMPLE_INTERVAL   # sample immediately on first frame
var _target: Dictionary = {}

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		set_process(false)
		return
	_apply_grade()

func _apply_grade() -> void:
	var env := environment_node.environment
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_bloom = GLOW_BLOOM
	env.glow_hdr_threshold = GLOW_HDR_THRESHOLD
	env.fog_enabled = true
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.0    # pockets only (FogVolumes, Task 12)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	sun.light_color = SUN_COLOR
	sun.light_energy = SUN_ENERGY
	sun.rotation_degrees = SUN_ANGLE_DEG
	var attrs := CameraAttributesPractical.new()
	attrs.dof_blur_far_enabled = true
	attrs.dof_blur_far_distance = DOF_FAR_DISTANCE
	attrs.dof_blur_far_transition = DOF_FAR_TRANSITION
	attrs.dof_blur_near_enabled = true
	attrs.dof_blur_near_distance = DOF_NEAR_DISTANCE
	attrs.dof_blur_near_transition = DOF_NEAR_TRANSITION
	attrs.dof_blur_amount = DOF_AMOUNT
	camera.attributes = attrs

func _process(dt: float) -> void:
	if streamer == null or streamer.world_seed == 0 or player == null:
		return
	_accum += dt
	if _accum >= SAMPLE_INTERVAL:
		_accum = 0.0
		_target = BiomeRegistry.blend_atmosphere(
				Helper.biome_weights5(player.global_position, streamer.world_seed))
	if _target.is_empty():
		return
	var k := clampf(EASE_SPEED * dt, 0.0, 1.0)
	var env := environment_node.environment
	env.fog_light_color = env.fog_light_color.lerp(_target[&"fog_color"], k)
	env.fog_density = lerpf(env.fog_density, _target[&"fog_density"], k)
	env.ambient_light_color = env.ambient_light_color.lerp(_target[&"ambient_color"], k)
	env.ambient_light_energy = lerpf(env.ambient_light_energy, _target[&"ambient_energy"], k)
	var sky_mat := env.sky.sky_material as ProceduralSkyMaterial
	sky_mat.sky_top_color = sky_mat.sky_top_color.lerp(_target[&"sky_top"], k)
	sky_mat.sky_horizon_color = sky_mat.sky_horizon_color.lerp(_target[&"sky_horizon"], k)
