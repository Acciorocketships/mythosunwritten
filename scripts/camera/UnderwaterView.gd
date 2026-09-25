extends Node
## A camera below committed water sees distance extinction through that medium.
## The late transparent pass also covers background pixels and water undersides.
const IMMERSION = preload("res://scripts/terrain/water/WaterImmersion.gd")
const MEDIUM = preload("res://terrain/water/underwater_medium.gdshader")
var camera: Camera3D
var world_seed: int
var _original: Environment
var _underwater: Environment
var _overlay: MeshInstance3D
var _material: ShaderMaterial
var depth := 0.0
var _air_exposure := 1.0

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
		_air_exposure = source.tonemap_exposure
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
	var blend := smoothstep(0.0, .5, depth)
	var tint := BiomeRegistry.water_tint_at(camera.global_position, world_seed).linear_to_srgb()
	_material.set_shader_parameter("medium_color", Color(.10,.28,.31).lerp(tint,.35))
	_material.set_shader_parameter("immersion", blend)
	_material.set_shader_parameter("owner_eye", camera.global_position)
	_underwater.tonemap_exposure = _air_exposure * lerpf(1.0,.78,blend)

func clear() -> void:
	if is_instance_valid(_overlay): _overlay.free()
	_overlay = null
	_material = null
	if _underwater != null:
		if is_instance_valid(camera) and camera.environment == _underwater:
			camera.environment = _original
		_underwater = null
		_original = null

func _exit_tree() -> void:
	clear()
