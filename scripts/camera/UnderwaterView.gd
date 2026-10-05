extends Node
## A camera below committed water sees distance extinction through that medium.
## The late transparent pass also covers background pixels and water undersides.
const IMMERSION = preload("res://scripts/terrain/water/WaterImmersion.gd")
const MEDIUM = preload("res://terrain/water/underwater_medium.gdshader")
var camera: Camera3D
var world_seed: int
var light_gain := 1.0
var _original: Environment
var _underwater: Environment
var _overlay: MeshInstance3D
var _material: ShaderMaterial
var depth := 0.0
var _air: Environment
var _surface_properties: Array[StringName] = []
const SURFACE_PREFIXES := ["ambient_", "glow_", "tonemap_", "ssao_", "ssil_", "sdfgi_",
	"adjustment_", "background_", "sky"]

func update_view() -> void:
	if not is_instance_valid(camera): return
	var water := IMMERSION.sample(get_tree().get_nodes_in_group("water_surface"), camera.global_position)
	depth = float(water.get("depth", -INF))
	if depth <= 0.0 or not is_finite(depth):
		clear()
		return
	if _underwater == null:
		_original = camera.environment
		var source := _original if _original != null else camera.get_world_3d().environment
		if source == null: return
		_air = source
		_surface_properties.clear()
		for property: Dictionary in source.get_property_list():
			var name := String(property.name)
			if name == "tonemap_exposure": continue
			for prefix: String in SURFACE_PREFIXES:
				if name.begins_with(prefix):
					_surface_properties.append(StringName(name))
					break
		_underwater = source.duplicate()
		_underwater.fog_enabled = false
		_underwater.volumetric_fog_enabled = false
		camera.environment = _underwater
		_material = ShaderMaterial.new()
		_material.shader = MEDIUM
		_material.render_priority = 127
		_overlay = MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(2, 2)
		_overlay.mesh = quad
		_overlay.material_override = _material
		_overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_overlay.extra_cull_margin = 16384
		_overlay.ignore_occlusion_culling = true
		camera.add_child(_overlay)
		_overlay.position.z = -0.1
	# Copy only changed surface settings, retaining one environment throughout
	# immersion. Fog belongs to the underwater medium, exposure to water depth.
	for property: StringName in _surface_properties:
		var value: Variant = _air.get(property)
		if _underwater.get(property) != value:
			_underwater.set(property, value)
	var blend := smoothstep(0.0, .5, depth)
	var tint := BiomeRegistry.water_tint_at(camera.global_position, world_seed).linear_to_srgb()
	var medium := Color(.10,.28,.31).lerp(tint,.35).srgb_to_linear()
	medium = Color(medium.r * light_gain, medium.g * light_gain, medium.b * light_gain, 1.0)
	_material.set_shader_parameter("medium_color", medium.linear_to_srgb())
	_material.set_shader_parameter("immersion", blend)
	_material.set_shader_parameter("owner_eye", camera.global_position)
	_underwater.tonemap_exposure = _air.tonemap_exposure * lerpf(1.0,.78,blend)

func clear() -> void:
	if is_instance_valid(_overlay): _overlay.free()
	_overlay = null
	_material = null
	if _underwater != null:
		if is_instance_valid(camera) and camera.environment == _underwater:
			camera.environment = _original
		_underwater = null
		_original = null
		_air = null
		_surface_properties.clear()

func _exit_tree() -> void:
	clear()
