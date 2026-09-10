class_name CameraVisibilityBubble
extends Node
## Render-space broad phase finds ALL nearby components, including visuals with
## no collision. Per-fragment coverage confines the fade inside large batches.

const INCLUDE := '\n#include "res://scripts/camera/visibility_bubble.gdshaderinc"\n'
const CUTOUT := '\n\ttactical_cutout(VERTEX, FRAGCOORD.xy, INV_VIEW_MATRIX);\n'
var _active: Dictionary = {}
var _materials: Dictionary = {}
var _shaders: Dictionary = {}
var _query_in := 0.0
var _last_eye := Vector3.INF

func update_bubble(camera: Camera3D, target: Node3D, feet: Vector3,
		radius: float, opacity: float, delta: float) -> void:
	_query_in -= delta
	if _query_in <= 0.0 or camera.global_position.distance_to(_last_eye) > 1.0:
		_query_in = 0.1
		_last_eye = camera.global_position
		_select(camera, target, feet, radius)
	_sync_source_parameters()
	for id: int in _active.keys():
		var state: Dictionary = _active[id]
		if not is_instance_id_valid(id):
			_active.erase(id)
			continue
		state.strength = move_toward(state.strength, 1.0 if state.wanted else 0.0, delta * 6.0)
		if state.strength <= 0.0:
			_restore(instance_from_id(id), state)
			_active.erase(id)
			continue
		# Each instance owns a wrapper, but all its surfaces share compiled shaders.
		for material: ShaderMaterial in state.materials:
			material.set_shader_parameter("tactical_eye", camera.global_position)
			material.set_shader_parameter("tactical_feet", feet)
			material.set_shader_parameter("tactical_floor_y", target.global_position.y)
			material.set_shader_parameter("tactical_radius", radius)
			material.set_shader_parameter("tactical_opacity", opacity)
			material.set_shader_parameter("tactical_strength", state.strength)

func _select(camera: Camera3D, target: Node3D, feet: Vector3, radius: float) -> void:
	for state: Dictionary in _active.values(): state.wanted = false
	var bounds := AABB(feet, Vector3.ZERO).expand(camera.global_position).grow(radius + 1.0)
	var ids := RenderingServer.instances_cull_aabb(bounds, camera.get_world_3d().scenario)
	for id: int in ids:
		var node := instance_from_id(id) as GeometryInstance3D
		if node == null or not node.is_visible_in_tree() or target == node or target.is_ancestor_of(node):
			continue
		if not (node is MeshInstance3D or node is MultiMeshInstance3D or node is CSGShape3D):
			continue
		if not _overlaps_corridor(node, camera.global_position, feet, radius): continue
		if _active.has(id):
			_active[id].wanted = true
		else:
			_active[id] = _install(node)
	# Compiled shader cache is bounded by currently nearby material sources.
	var used := {}
	for state: Dictionary in _active.values():
		for source_id: int in state.sources: used[source_id] = true
	for source_id: int in _materials.keys():
		if not used.has(source_id): _materials.erase(source_id)
	var used_shaders := {}
	for cached: Dictionary in _materials.values(): used_shaders[cached.shader] = true
	for code: String in _shaders.keys():
		if not used_shaders.has(_shaders[code]): _shaders.erase(code)

static func _overlaps_corridor(node: GeometryInstance3D, eye: Vector3, feet: Vector3, radius: float) -> bool:
	var world_bounds := node.global_transform * node.get_aabb()
	if world_bounds.end.y <= feet.y + 0.12: return false
	var focus := feet + Vector3.UP
	var basis := Basis.looking_at(eye - focus)
	var view := Transform3D(basis, focus).affine_inverse()
	var bounds := view * world_bounds
	if bounds.position.z > 0.5 or bounds.end.z < -eye.distance_to(focus) - 0.5: return false
	var x := clampf(0.0, bounds.position.x, bounds.end.x)
	var y := clampf(0.0, bounds.position.y, bounds.end.y)
	return x*x + y*y <= radius*radius

func _install(node: GeometryInstance3D) -> Dictionary:
	var state := {"wanted": true, "strength": 0.0, "override": node.material_override,
		"overlay": node.material_overlay, "surfaces": [], "multimesh": null,
		"materials": [], "sources": []}
	if node.material_overlay != null:
		node.material_overlay = _adapt(node.material_overlay, state)
	if node.material_override != null:
		node.material_override = _adapt(node.material_override, state)
	elif node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh != null:
			for surface in mesh_node.mesh.get_surface_count():
				state.surfaces.append(mesh_node.get_surface_override_material(surface))
				mesh_node.set_surface_override_material(surface, _adapt(mesh_node.get_active_material(surface), state))
	elif node is MultiMeshInstance3D:
		var batch := node as MultiMeshInstance3D
		if batch.multimesh != null and batch.multimesh.mesh != null:
			state.multimesh = batch.multimesh
			var copy := MultiMesh.new()
			copy.transform_format = batch.multimesh.transform_format
			copy.use_colors = batch.multimesh.use_colors
			copy.use_custom_data = batch.multimesh.use_custom_data
			copy.instance_count = batch.multimesh.instance_count
			copy.visible_instance_count = batch.multimesh.visible_instance_count
			copy.custom_aabb = batch.multimesh.custom_aabb
			# Set the format BEFORE allocating/copying the packed instance buffer.
			# Resource.duplicate() writes these properties in the wrong order.
			var buffer := batch.multimesh.buffer
			if not buffer.is_empty(): copy.buffer = buffer
			copy.mesh = batch.multimesh.mesh.duplicate() as Mesh
			for surface in copy.mesh.get_surface_count():
				copy.mesh.surface_set_material(surface, _adapt(copy.mesh.surface_get_material(surface), state))
			batch.multimesh = copy
	else:
		# CSG's generated surfaces are available after the shape enters the tree.
		var meshes: Array = (node as CSGShape3D).get_meshes()
		if meshes.size() > 1:
			var mesh := meshes[1] as Mesh
			if mesh.get_surface_count() > 0:
				node.material_override = _adapt(mesh.surface_get_material(0), state)
	return state

func _adapt(source: Material, state: Dictionary) -> ShaderMaterial:
	if source == null: source = StandardMaterial3D.new()
	var id := source.get_instance_id()
	state.sources.append(id)
	var native := source as BaseMaterial3D
	var custom := source as ShaderMaterial
	var shader: Shader
	if _materials.has(id):
		shader = _materials[id].shader
	else:
		var code: String
		if custom != null and custom.shader != null:
			code = custom.shader.code
		else:
			code = (load("res://scripts/camera/tactical_standard.gdshader") as Shader).code
			if native != null:
				var features := {"vertex_color_albedo": native.vertex_color_use_as_albedo,
					"normal_enabled": native.normal_enabled, "emission_enabled": native.emission_enabled,
					"ao_enabled": native.ao_enabled}
				for feature: String in features:
					code = code.replace("uniform bool " + feature + " = false;", "")
					for line in code.split("\n"):
						if line.strip_edges().begins_with("if (" + feature + ")"):
							code = code.replace(line, line.replace("if (" + feature + ")", "") if features[feature] else "")
				var filters := ["filter_nearest", "filter_linear", "filter_nearest_mipmap", "filter_linear_mipmap", "filter_nearest_mipmap_anisotropic", "filter_linear_mipmap_anisotropic"]
				var sampling: String = filters[clampi(native.texture_filter, 0, filters.size()-1)]
				sampling += ", repeat_enable" if native.texture_repeat else ", repeat_disable"
				for line in code.split("\n"):
					if line.begins_with("uniform sampler2D "):
						code = code.replace(line, line.replace(";", ", " + sampling + ";"))
				if native.cull_mode == BaseMaterial3D.CULL_DISABLED: code = code.replace("cull_back", "cull_disabled")
				elif native.cull_mode == BaseMaterial3D.CULL_FRONT: code = code.replace("cull_back", "cull_front")
				if native.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED: code = code.replace("render_mode ", "render_mode unshaded, ")
				if native.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
					code = code.replace("ALBEDO = base.rgb;", "ALBEDO = base.rgb; ALPHA = base.a;")
				if native.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
					code = code.replace("ALPHA = base.a;", "ALPHA = base.a; ALPHA_SCISSOR_THRESHOLD = %s;" % native.alpha_scissor_threshold)
		var wrapped_code := instrument(code)
		if _shaders.has(wrapped_code):
			shader = _shaders[wrapped_code]
		else:
			shader = Shader.new()
			shader.code = wrapped_code
			_shaders[wrapped_code] = shader
		var parameters := {}
		var uniforms := custom.shader.get_shader_uniform_list() if custom != null and custom.shader != null else shader.get_shader_uniform_list()
		for uniform: Dictionary in uniforms:
			if not String(uniform.name).begins_with("tactical_"):
				parameters[uniform.name] = _source_parameter(source, uniform.name)
		_materials[id] = {"shader": shader, "source": source, "parameters": parameters}
	var material := ShaderMaterial.new()
	material.shader = shader
	material.render_priority = source.render_priority
	for name: StringName in _materials[id].parameters:
		var value: Variant = _source_parameter(source, name)
		if custom != null: material.set_shader_parameter(name, value)
		else: RenderingServer.material_set_param(material.get_rid(), name, value)
	state.materials.append(material)
	if source.next_pass != null: material.next_pass = _adapt(source.next_pass, state)
	return material

static func _source_parameter(source: Material, name: StringName) -> Variant:
	if source is ShaderMaterial:
		var value: Variant = source.get_shader_parameter(name)
		if value == null and source.shader != null:
			value = source.shader.get_default_texture_parameter(name)
		return value
	return RenderingServer.material_get_param(source.get_rid(), name)

func _sync_source_parameters() -> void:
	# Read each shared source once. Water ping-pongs textures and other effects
	# change uniforms while visible; wrapping must not freeze their live state.
	var changes := {}
	for id: int in _materials:
		var cached: Dictionary = _materials[id]
		var changed := {}
		for name: StringName in cached.parameters:
			var value: Variant = _source_parameter(cached.source, name)
			if typeof(value) != typeof(cached.parameters[name]) or value != cached.parameters[name]:
				cached.parameters[name] = value
				changed[name] = value
		if not changed.is_empty(): changes[id] = changed
	for state: Dictionary in _active.values():
		for index in state.sources.size():
			var id: int = state.sources[index]
			if not changes.has(id): continue
			var material: ShaderMaterial = state.materials[index]
			for name: StringName in changes[id]:
				if _materials[id].source is ShaderMaterial:
					material.set_shader_parameter(name, changes[id][name])
				else:
					RenderingServer.material_set_param(material.get_rid(), name, changes[id][name])

## Insert at fragment entry so early returns cannot bypass visibility. Search
## without comments, retaining byte positions in the original shader source.
static func instrument(code: String) -> String:
	var comments := RegEx.new()
	comments.compile("(?s)/\\*.*?\\*/|//[^\\n]*")
	var searchable := code
	for comment: RegExMatch in comments.search_all(code):
		searchable = searchable.left(comment.get_start()) + " ".repeat(comment.get_end() - comment.get_start()) + searchable.substr(comment.get_end())
	var expression := RegEx.new()
	expression.compile("void\\s+fragment\\s*\\(\\s*\\)\\s*\\{")
	var found := expression.search(searchable)
	if found == null:
		return code + INCLUDE + "\nvoid fragment() {" + CUTOUT + "}\n"
	return code.left(found.get_start()) + INCLUDE \
		+ code.substr(found.get_start(), found.get_end() - found.get_start()) \
		+ CUTOUT + code.substr(found.get_end())

func _restore(node: GeometryInstance3D, state: Dictionary) -> void:
	node.material_override = state.override
	node.material_overlay = state.overlay
	if node is MeshInstance3D:
		for surface in state.surfaces.size():
			(node as MeshInstance3D).set_surface_override_material(surface, state.surfaces[surface])
	elif state.multimesh != null and node is MultiMeshInstance3D:
		(node as MultiMeshInstance3D).multimesh = state.multimesh

func clear() -> void:
	for id: int in _active:
		if is_instance_id_valid(id): _restore(instance_from_id(id), _active[id])
	_active.clear()
	_materials.clear()
	_shaders.clear()
	_query_in = 0.0
	_last_eye = Vector3.INF

func _exit_tree() -> void:
	clear()
