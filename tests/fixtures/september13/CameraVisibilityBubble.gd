extends Node
## Render-space broad phase finds ALL nearby components, including visuals with
## no collision. Per-fragment coverage confines the fade inside large batches.

const INCLUDE := '\n#include "res://tests/fixtures/september13/visibility_bubble.gdshaderinc"\n'
const CUTOUT := '\n\ttactical_cutout(VERTEX, NORMAL, FRAGCOORD.xy, SCREEN_UV, INV_VIEW_MATRIX, FRONT_FACING, UV);\n'
const SHADER_CACHE_LIMIT := 32
var _active: Dictionary = {}
var _materials: Dictionary = {}
var _shaders: Dictionary = {}
var _mesh_bindings: Dictionary = {}
var _query_in := 0.0
var _last_eye := Vector3.INF
var _receivers: Node

static func screen_radius(camera: Camera3D, feet: Vector3, screen_diameter := 0.5) -> float:
	var size := camera.get_viewport().get_visible_rect().size
	var aspect := size.x / maxf(size.y,1.0) if camera.keep_aspect == Camera3D.KEEP_HEIGHT else 1.0
	return camera.global_position.distance_to(feet+Vector3.UP) * tan(deg_to_rad(camera.fov)*.5) * aspect * screen_diameter

func update_bubble(camera: Camera3D, target: Node3D, feet: Vector3,
		radius: float, opacity: float, delta: float) -> void:
	_query_in -= delta
	if _query_in <= 0.0 or camera.global_position.distance_to(_last_eye) > 1.0:
		_query_in = 0.1
		_last_eye = camera.global_position
		_select(camera, target, feet, radius)
	if _receivers == null:
		_receivers = preload("res://tests/fixtures/september13/VisibilityGroundDepth.gd").new()
		add_child(_receivers)
	_receivers.update_view(camera, feet, radius)
	_sync_source_parameters()
	for cached: Dictionary in _materials.values():
		var material: ShaderMaterial = cached.material
		material.set_shader_parameter("tactical_eye", camera.global_position)
		material.set_shader_parameter("tactical_feet", feet)
		material.set_shader_parameter("tactical_floor_y", target.global_position.y)
		material.set_shader_parameter("tactical_radius", radius)
		material.set_shader_parameter("tactical_opacity", opacity)
		material.set_shader_parameter("tactical_ground_depth", _receivers.texture())
		material.set_shader_parameter("tactical_receiver_texel", Vector2.ONE / Vector2(_receivers.view_size()))
	for id: int in _active.keys():
		var state: Dictionary = _active[id]
		if not is_instance_id_valid(id):
			_release_mesh_binding(state)
			_active.erase(id)
			continue
		state.strength = move_toward(state.strength, 1.0 if state.wanted else 0.0, delta * 6.0)
		if state.strength <= 0.0:
			_restore(instance_from_id(id), state)
			_active.erase(id)
			continue
		# Strength belongs to the geometry instance; one shared material serves
		# every component using this source without flattening their fade times.
		instance_from_id(id).set_instance_shader_parameter("tactical_strength", state.strength)

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
	# Retain source material owners only while selected geometry uses them.
	var used := {}
	for state: Dictionary in _active.values():
		for source_id: int in state.sources: used[source_id] = true
	for source_id: int in _materials.keys():
		if not used.has(source_id): _materials.erase(source_id)
	# Keep a bounded set of compiled programs across turns into empty space.
	# Source materials still leave immediately; shader code owns no scene data.

static func _overlaps_corridor(node: GeometryInstance3D, eye: Vector3, feet: Vector3, radius: float) -> bool:
	var world_bounds := node.global_transform * node.get_aabb()
	var focus := feet + Vector3.UP
	var basis := Basis.looking_at(eye - focus)
	var view := Transform3D(basis, focus).affine_inverse()
	var bounds := view * world_bounds
	var rear_extent := radius if node.is_in_group("tactical_closed_shell") or node.is_in_group("tactical_solid_earth") else 0.5
	if bounds.position.z > rear_extent or bounds.end.z < -eye.distance_to(focus) - 0.5: return false
	var x := clampf(0.0, bounds.position.x, bounds.end.x)
	var y := clampf(0.0, bounds.position.y, bounds.end.y)
	return x*x + y*y <= radius*radius

func _install(node: GeometryInstance3D) -> Dictionary:
	node.set_instance_shader_parameter("tactical_ground_owner", 1.0 if node.is_in_group("tactical_solid_earth") else 0.0)
	node.set_instance_shader_parameter("tactical_shell", 2.0 if node.is_in_group("tactical_deck_surface") else (1.0 if node.is_in_group("tactical_closed_shell") else 0.0))
	node.set_instance_shader_parameter("tactical_native_turf", 1.0 if node is MultiMeshInstance3D and node.is_in_group("tactical_solid_earth") else 0.0)
	var state := {"wanted": true, "strength": 0.0, "override": node.material_override,
		"overlay": node.material_overlay, "surfaces": [], "multimesh": null,
		"materials": [], "sources": [], "mesh_binding": {}}
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
			# The normal terrain/building batch has one surface. Override its
			# material on the instance, retaining the producer's live MultiMesh.
			# Reading .buffer here otherwise synchronizes with the render server
			# and copies every placement whenever the camera turns onto a batch.
			if batch.multimesh.mesh.get_surface_count() == 1:
				batch.material_override = _adapt(batch.multimesh.mesh.surface_get_material(0), state)
				return state
			# MultiMesh has no per-surface instance overrides. Bind the adapter
			# on its existing render mesh instead of reading/copying GPU geometry.
			# Resource materials remain original; unselected instances have zero
			# fade strength. The last user of a shared mesh restores its bindings.
			var mesh := batch.multimesh.mesh
			var id := mesh.get_instance_id()
			var owner: Dictionary = _mesh_bindings.get(id,{})
			if owner.is_empty():
				var materials := {"materials": [], "sources": []}
				for surface in mesh.get_surface_count():
					var adapted := _adapt(mesh.surface_get_material(surface), materials)
					RenderingServer.mesh_surface_set_material(mesh.get_rid(),surface,adapted.get_rid())
				owner = {"mesh": mesh,
					"users": 0, "materials": materials.materials, "sources": materials.sources}
				_mesh_bindings[id] = owner
			owner.users += 1
			state.mesh_binding = owner
			state.materials.append_array(owner.materials)
			state.sources.append_array(owner.sources)
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
	if _materials.has(id):
		var shared: ShaderMaterial = _materials[id].material
		state.materials.append(shared)
		if source.next_pass != null: shared.next_pass = _adapt(source.next_pass, state)
		return shared
	var native := source as BaseMaterial3D
	var custom := source as ShaderMaterial
	var shader: Shader
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
		_shaders.erase(wrapped_code)
		_shaders[wrapped_code] = shader
	else:
		shader = Shader.new()
		shader.code = wrapped_code
		if _shaders.size() >= SHADER_CACHE_LIMIT:
			_shaders.erase(_shaders.keys()[0])
		_shaders[wrapped_code] = shader
	var parameters := {}
	var uniforms := custom.shader.get_shader_uniform_list() if custom != null and custom.shader != null else shader.get_shader_uniform_list()
	for uniform: Dictionary in uniforms:
		if not String(uniform.name).begins_with("tactical_"):
			parameters[uniform.name] = _source_parameter(source, uniform.name)
	_materials[id] = {"shader": shader, "source": source, "parameters": parameters}
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("tactical_receiver_palette", CliffDressing.ground_texture())
	_materials[id].material = material
	material.render_priority = source.render_priority
	for name: StringName in _materials[id].parameters:
		# _sync_source_parameters refreshes each shared source after selection
		# in this same update. Re-reading here synchronizes with the renderer
		# once per new component instead of once per source.
		var value: Variant = _materials[id].parameters[name]
		if custom != null: material.set_shader_parameter(name, value)
		else: RenderingServer.material_set_param(material.get_rid(), name, value)
	state.materials.append(material)
	if source.next_pass != null: material.next_pass = _adapt(source.next_pass, state)
	return material

func _source_parameter(source: Material, name: StringName) -> Variant:
	if source is ShaderMaterial:
		var value: Variant = source.get_shader_parameter(name)
		if value == null and source.shader != null:
			value = source.shader.get_default_texture_parameter(name)
		return value
	return RenderingServer.material_get_param(source.get_rid(), name)

func _sync_source_parameters() -> void:
	# Read each shared source once. Water ping-pongs textures and other effects
	# change uniforms while visible; wrapping must not freeze their live state.
	for id: int in _materials:
		var cached: Dictionary = _materials[id]
		for name: StringName in cached.parameters:
			var value: Variant = _source_parameter(cached.source, name)
			if typeof(value) != typeof(cached.parameters[name]) or value != cached.parameters[name]:
				cached.parameters[name] = value
				if cached.source is ShaderMaterial:
					cached.material.set_shader_parameter(name, value)
				else:
					RenderingServer.material_set_param(cached.material.get_rid(), name, value)

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
	_release_mesh_binding(state)
	# The adapter owns this private instance uniform; remove its override.
	node.set_instance_shader_parameter("tactical_strength", null)
	node.set_instance_shader_parameter("tactical_shell", null)
	node.set_instance_shader_parameter("tactical_ground_owner", null)
	node.set_instance_shader_parameter("tactical_native_turf", null)
	node.material_override = state.override
	node.material_overlay = state.overlay
	if node is MeshInstance3D:
		for surface in state.surfaces.size():
			(node as MeshInstance3D).set_surface_override_material(surface, state.surfaces[surface])
	elif state.multimesh != null and node is MultiMeshInstance3D:
		(node as MultiMeshInstance3D).multimesh = state.multimesh

func _release_mesh_binding(state: Dictionary) -> void:
	var owner: Dictionary = state.get("mesh_binding",{})
	if owner.is_empty(): return
	state.mesh_binding = {}
	owner.users -= 1
	if owner.users > 0: return
	var mesh: Mesh = owner.mesh
	for surface in mesh.get_surface_count():
		# Read the resource's current source, so an author's material replacement
		# during selection is not overwritten with the old material on release.
		var source := mesh.surface_get_material(surface)
		RenderingServer.mesh_surface_set_material(mesh.get_rid(),surface,source.get_rid() if source != null else RID())
	_mesh_bindings.erase(mesh.get_instance_id())

func clear() -> void:
	for id: int in _active:
		if is_instance_id_valid(id): _restore(instance_from_id(id), _active[id])
		else: _release_mesh_binding(_active[id])
	_active.clear()
	_materials.clear()
	_shaders.clear()
	if is_instance_valid(_receivers): _receivers.free()
	_receivers = null
	_query_in = 0.0
	_last_eye = Vector3.INF

func _exit_tree() -> void:
	clear()
