extends RefCounted

## Main-thread-only sharing of byte-identical atlases baked under several pack
## paths. The catalogue test proves dimensions, format and every mip byte equal.
## Keep original assets/references so individual packs can still be rebaked.
static var _aliases: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
	"res://terrain/environment/texture_aliases.json"))

static func prepare(visual: EnvironmentVisual, sources: Dictionary = {}) -> void:
	assert(OS.get_thread_caller_id() == OS.get_main_thread_id())
	for piece: EnvironmentVisualPiece in visual.pieces:
		_material(piece.material_override, sources)
		for mesh: Mesh in [piece.mesh, piece.shadow_mesh]:
			if mesh == null: continue
			for surface in mesh.get_surface_count():
				_material(mesh.surface_get_material(surface), sources)

static func _material(material: Material, sources: Dictionary = {}) -> void:
	if material == null or material.has_meta(&"environment_textures_shared"): return
	if material is ShaderMaterial:
		if material.shader != null:
			for uniform: Dictionary in material.shader.get_shader_uniform_list():
				var value: Variant = material.get_shader_parameter(uniform.name)
				if value is Texture2D and _aliases.has(value.resource_path):
					sources[value.resource_path] = value
					material.set_shader_parameter(uniform.name, load(_aliases[value.resource_path]))
	elif material is StandardMaterial3D:
		for property: Dictionary in material.get_property_list():
			if property.type != TYPE_OBJECT or not (int(property.usage) & PROPERTY_USAGE_STORAGE): continue
			var value: Variant = material.get(property.name)
			if value is Texture2D and _aliases.has(value.resource_path):
				sources[value.resource_path] = value
				material.set(property.name, load(_aliases[value.resource_path]))
	material.set_meta(&"environment_textures_shared", true)
