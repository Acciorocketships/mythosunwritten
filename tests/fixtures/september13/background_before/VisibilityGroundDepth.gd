extends Node
## A private depth-only world shares the actual ground meshes. No new surfaces
## enter the game world; sky, walls, grass and house interiors cannot be receivers.
var _view: SubViewport
var _camera: Camera3D
var _material: ShaderMaterial
var _native_material: ShaderMaterial
var _owners: Dictionary = {}

func update_view(source: Camera3D, feet: Vector3, radius: float) -> void:
	if _view == null:
		_view = SubViewport.new()
		_view.own_world_3d = true
		_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(_view)
		_camera = Camera3D.new()
		_camera.environment = Environment.new()
		_camera.environment.background_mode = Environment.BG_COLOR
		_camera.environment.background_color = Color.BLACK
		_view.add_child(_camera)
		_material = ShaderMaterial.new()
		_material.shader = preload("res://tests/fixtures/september13/background_before/ground_receiver_depth.gdshader")
		_native_material = _material.duplicate()
		_native_material.set_shader_parameter("receiver_native_turf", true)
		_native_material.set_shader_parameter("receiver_palette", CliffDressing.ground_texture())
	_view.size = Vector2i(source.get_viewport().get_visible_rect().size)
	_camera.global_transform = source.global_transform
	_camera.projection = source.projection
	_camera.keep_aspect = source.keep_aspect
	_camera.fov = source.fov
	_camera.size = source.size
	_camera.near = source.near
	_camera.far = source.far
	_camera.h_offset = source.h_offset
	_camera.v_offset = source.v_offset
	_camera.frustum_offset = source.frustum_offset
	_material.set_shader_parameter("tactical_eye", source.global_position)
	_material.set_shader_parameter("tactical_feet", feet)
	_material.set_shader_parameter("tactical_floor_y", feet.y)
	_material.set_shader_parameter("tactical_radius", radius)
	for key: String in ["tactical_eye", "tactical_feet", "tactical_floor_y", "tactical_radius"]:
		_native_material.set_shader_parameter(key, _material.get_shader_parameter(key))
	# Existing main-thread ground owners are resource-backed and do not animate.
	# Sharing their meshes avoids triangle extraction or GPU-buffer readbacks.
	var wanted := {}
	for node: Node in get_tree().get_nodes_in_group("tactical_solid_earth"):
		if not (node is MeshInstance3D or node is MultiMeshInstance3D) or not node.is_visible_in_tree() or node.get_world_3d() != source.get_world_3d(): continue
		var id := node.get_instance_id()
		wanted[id] = true
		if not _owners.has(id):
			var copy: GeometryInstance3D = MeshInstance3D.new() if node is MeshInstance3D else MultiMeshInstance3D.new()
			copy.material_override = _native_material if node is MultiMeshInstance3D else _material
			copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_view.add_child(copy)
			_owners[id] = copy
		var copy: GeometryInstance3D = _owners[id]
		if copy is MeshInstance3D: copy.mesh = node.mesh
		else: copy.multimesh = node.multimesh
		copy.global_transform = node.global_transform
	for id: int in _owners.keys():
		if not wanted.has(id):
			_owners[id].free()
			_owners.erase(id)

func texture() -> ViewportTexture:
	return _view.get_texture()

func view_size() -> Vector2i:
	return _view.size
