extends Node
## A private depth-only world shares the actual ground meshes. No new surfaces
## enter the game world; sky, walls, grass and house interiors cannot be receivers.
var _view: SubViewport
var _camera: Camera3D
var _material: ShaderMaterial
var _native_material: ShaderMaterial
var _owners: Dictionary = {}
var _front_view: SubViewport
var _front_camera: Camera3D
var _front_material: ShaderMaterial
var _front_owners: Dictionary = {}
var _terrain_view: SubViewport
var _terrain_camera: Camera3D
var _terrain_owners: Dictionary = {}

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
		_material.shader = preload("res://scripts/camera/ground_receiver_depth.gdshader")
		_native_material = _material.duplicate()
		_native_material.set_shader_parameter("receiver_native_turf", true)
		_native_material.set_shader_parameter("receiver_palette", CliffDressing.ground_texture())
		_front_view = SubViewport.new()
		_front_view.own_world_3d = true
		_front_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(_front_view)
		_front_camera = Camera3D.new()
		_front_camera.environment = _camera.environment
		_front_view.add_child(_front_camera)
		_front_material = _material.duplicate()
		_front_material.set_shader_parameter("receiver_first_surface",true)
		_material.set_shader_parameter("tactical_front_depth",_front_view.get_texture())
		_native_material.set_shader_parameter("tactical_front_depth",_front_view.get_texture())
		# The complete physical heightfield proves burial even where the visual
		# sheet is recessed under native lips. Arches and decks are not solid earth.
		_terrain_view = SubViewport.new()
		_terrain_view.own_world_3d = true
		_terrain_view.size = Vector2i(2048,2048)
		_terrain_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(_terrain_view)
		_terrain_camera = Camera3D.new()
		_terrain_camera.environment = _camera.environment
		_terrain_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		_terrain_camera.rotation.x = -PI/2
		_terrain_view.add_child(_terrain_camera)
		_native_material.set_shader_parameter("receiver_terrain_depth",_terrain_view.get_texture())
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
	_front_view.size = _view.size
	_front_camera.global_transform = _camera.global_transform
	_front_camera.projection = _camera.projection
	_front_camera.keep_aspect = _camera.keep_aspect
	_front_camera.fov = _camera.fov
	_front_camera.size = _camera.size
	_front_camera.near = _camera.near
	_front_camera.far = _camera.far
	_front_camera.h_offset = _camera.h_offset
	_front_camera.v_offset = _camera.v_offset
	_front_camera.frustum_offset = _camera.frustum_offset
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
			var front: GeometryInstance3D = MeshInstance3D.new() if node is MeshInstance3D else MultiMeshInstance3D.new()
			front.material_override = _front_material
			front.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_front_view.add_child(front)
			_front_owners[id] = front
		var copy: GeometryInstance3D = _owners[id]
		if copy is MeshInstance3D: copy.mesh = node.mesh
		else: copy.multimesh = node.multimesh
		copy.global_transform = node.global_transform
		var front: GeometryInstance3D = _front_owners[id]
		if front is MeshInstance3D: front.mesh = node.mesh
		else: front.multimesh = node.multimesh
		front.global_transform = node.global_transform
	for id: int in _owners.keys():
		if not wanted.has(id):
			_owners[id].free()
			_owners.erase(id)
			_front_owners[id].free()
			_front_owners.erase(id)
	_update_terrain_volume(source,feet,radius)

func _update_terrain_volume(source: Camera3D, feet: Vector3, radius: float) -> void:
	var wanted := {}
	var terrain_low := feet.y
	var terrain_high := feet.y
	for shape: CollisionShape3D in get_tree().get_nodes_in_group("tactical_terrain_volume"):
		# Terrain chunks attach their complete sheet as metadata (their physics
		# uses heightmap tiles plus a residual trimesh); other owners keep the
		# trimesh itself.
		var meta_faces: Variant = shape.get_meta(&"terrain_faces", null)
		if shape.disabled or (meta_faces == null and not shape.shape is ConcavePolygonShape3D) \
				or shape.get_world_3d() != source.get_world_3d(): continue
		var id := shape.get_instance_id()
		wanted[id] = true
		if not _terrain_owners.has(id):
			var arrays: Array = []
			arrays.resize(Mesh.ARRAY_MAX)
			# CPU collision data is read once per committed owner, never from a GPU
			# mesh and never per frame. Removal releases the private proof mesh.
			arrays[Mesh.ARRAY_VERTEX] = meta_faces if meta_faces != null \
				else (shape.shape as ConcavePolygonShape3D).get_faces()
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			var copy := MeshInstance3D.new()
			copy.mesh = mesh
			copy.material_override = _front_material
			copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_terrain_view.add_child(copy)
			_terrain_owners[id] = copy
		var copy: MeshInstance3D = _terrain_owners[id]
		copy.global_transform = shape.global_transform
		var bounds: AABB = shape.global_transform*copy.get_aabb()
		terrain_low = minf(terrain_low,bounds.position.y)
		terrain_high = maxf(terrain_high,bounds.end.y)
	for id: int in _terrain_owners.keys():
		if not wanted.has(id):
			_terrain_owners[id].free()
			_terrain_owners.erase(id)

	var center := (source.global_position+feet)*.5
	var delta := source.global_position-feet
	var span := maxf(64.0,maxf(absf(delta.x),absf(delta.z))+radius*4.0)
	_terrain_camera.position = Vector3(center.x,terrain_high+1.0,center.z)
	_terrain_camera.size = span
	_terrain_camera.near = .01
	_terrain_camera.far = terrain_high-terrain_low+2.0
	_native_material.set_shader_parameter("receiver_terrain_bounds",Vector4(center.x-span*.5,center.z-span*.5,span,terrain_high+1.0))

func texture() -> ViewportTexture:
	return _view.get_texture()

func view_size() -> Vector2i:
	return _view.size

func front_texture() -> ViewportTexture:
	return _front_view.get_texture()
