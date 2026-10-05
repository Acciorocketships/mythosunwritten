class_name CanopyShadows
extends RefCounted

## A shadow-only view of the same instance population. The visible low-poly
## crown stays solid; only leaf-coloured atlas regions admit dappled sunlight.
static func attach(instance: MultiMeshInstance3D) -> MultiMeshInstance3D:
	assert(OS.get_thread_caller_id() == OS.get_main_thread_id())
	var existing := instance.get_node_or_null("CanopyShadow") as MultiMeshInstance3D
	if existing != null: return existing
	if instance.multimesh == null or instance.multimesh.mesh == null: return null
	var source: Material = instance.material_override
	if source == null and instance.multimesh.mesh.get_surface_count() > 0:
		source = instance.multimesh.mesh.surface_get_material(0)
	# Visibility adapters inline the canonical shader and lose its path.
	if not source is ShaderMaterial or source.shader == null or not "canopy_world" in source.shader.code:
		return null
	var material := ShaderMaterial.new()
	material.shader = preload("res://terrain/environment/materials/canopy_shadow.gdshader")
	material.set_shader_parameter("albedo_texture", source.get_shader_parameter("albedo_texture"))
	var color: Variant = source.get_shader_parameter("base_color")
	if color != null: material.set_shader_parameter("base_color", color)
	var proxy := MultiMeshInstance3D.new()
	proxy.name = "CanopyShadow"
	proxy.multimesh = instance.multimesh
	proxy.material_override = material
	proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	proxy.layers = instance.layers
	proxy.extra_cull_margin = instance.extra_cull_margin
	# Shadow-only geometry cannot obstruct the camera. Avoid installing a
	# second visibility adapter on the same population during camera travel.
	proxy.add_to_group("tactical_preserve_surface", true)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.add_child(proxy)
	return proxy
