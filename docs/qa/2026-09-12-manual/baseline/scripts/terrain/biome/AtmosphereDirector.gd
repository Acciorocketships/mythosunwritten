class_name AtmosphereDirector
extends Node

## A continuous biome mood changes the shared sky and lighting gradually.
## Local mist still follows the world-space terrain and biome field.
@export var environment_node: WorldEnvironment
@export var sun: DirectionalLight3D
@export var camera: Camera3D
@export var streamer: FieldTerrainStreamer
@export var player: Node3D

var _ground_map := BiomeGroundMap.new()
var _mood_weights: Dictionary = {}
const MOOD_RESPONSE_SECONDS := 3.0

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
	# Wide PCF preserves softened contact shadows without the per-fragment
	# blocker search of angular PCSS across the dense grass carpet.
	sun.light_angular_distance = 0.0
	sun.shadow_blur = 2.0
	sun.light_volumetric_fog_energy = 1.1
	# Leave the scene sharp until the camera redesign establishes a focus model.
	camera.attributes = null

func _process(dt: float) -> void:
	if not Helper.is_headless() and streamer != null and player != null:
		_ground_map.update(player.global_position, streamer.world_seed)
		_update_mood(dt, Helper.biome_weights5(player.global_position,streamer.world_seed))

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
	env.fog_density = float(mood[&"fog_density"])*0.035
	var sky := env.sky.sky_material as ProceduralSkyMaterial
	sky.sky_top_color = mood[&"sky_top"]
	sky.sky_horizon_color = mood[&"sky_horizon"]
	sky.ground_horizon_color = mood[&"sky_horizon"]
	sky.ground_bottom_color = mood[&"ambient_color"] * 0.5
	sun.light_color = mood[&"sun_color"]
	sun.light_energy = mood[&"sun_energy"]
