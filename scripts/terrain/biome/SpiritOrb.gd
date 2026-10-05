class_name SpiritOrb
extends Node3D

## Both sizes use this motion, spherical core, halo and ground-light palette.
## Small instances batch their geometry through SmallSpiritOrbs.
const LARGE_HALO := 1.8
const SMALL_HALO := 1.1
const LARGE_DIAMETER := 0.36
const SMALL_DIAMETER := 0.22

var anchor := Vector3.ZERO
var phase := 0.0
var elapsed := 0.0

static func offset_at(seconds: float, at_phase: float) -> Vector3:
	return Vector3(sin(seconds * 0.12 + at_phase) * 1.5,
		sin(seconds * 0.25 + at_phase) * 0.4, cos(seconds * 0.09 + at_phase) * 1.5)

static func phase_at(point: Vector3) -> float:
	return fposmod(point.x * 0.37 + point.z * 0.71, TAU)

static func color_at(at_phase: float) -> Color:
	return Color("ffbf73").lerp(Color("ffe0a3"), (sin(at_phase) + 1.0) * 0.5)

static func core_mesh(diameter: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = diameter * 0.5
	mesh.height = diameter
	mesh.radial_segments = 20
	mesh.rings = 12
	var material := ShaderMaterial.new()
	material.shader = load("res://terrain/materials/spirit_orb_core.gdshader")
	mesh.material = material
	return mesh

static func halo_mesh(size: float) -> QuadMesh:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(size,size)
	var material := ShaderMaterial.new()
	material.shader = load("res://terrain/materials/spirit_orb.gdshader")
	mesh.material = material
	return mesh

static func configure_light(light: OmniLight3D, small: bool) -> void:
	light.light_energy = 2.4 if small else 3.5
	light.omni_range = 7.5 if small else 11.0
	light.shadow_enabled = false
	light.light_volumetric_fog_energy = 1.6 if small else 2.2
	light.add_to_group("atmosphere_local_light")
	light.set_meta("atmosphere_shadow_candidate", false)
	light.distance_fade_enabled = true
	light.distance_fade_begin = 35.0 if small else 60.0
	light.distance_fade_length = 15.0 if small else 20.0

static func create(point: Vector3) -> SpiritOrb:
	var orb := SpiritOrb.new()
	orb.name = "SpiritOrb"
	orb.anchor = point
	orb.phase = phase_at(point)
	var color := color_at(orb.phase)
	var halo := MeshInstance3D.new()
	halo.name = "Halo"
	halo.mesh = halo_mesh(LARGE_HALO)
	halo.mesh.material.set_shader_parameter("glow_color",color)
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	orb.add_child(halo)
	var light := OmniLight3D.new()
	light.name = "Light"
	configure_light(light,false)
	light.light_color = color
	orb.add_child(light)
	var core := MeshInstance3D.new()
	core.name = "Core"
	core.mesh = core_mesh(LARGE_DIAMETER)
	core.mesh.material.set_shader_parameter("glow_color",color)
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	orb.add_child(core)
	orb._process(0.0)
	return orb

func _process(dt: float) -> void:
	elapsed += dt
	position = anchor + offset_at(elapsed,phase)
