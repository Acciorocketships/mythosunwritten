extends Node
## Shared-world actor depth keeps skinning and source materials in one place.
## Render layer 20 is reserved for this actor-only camera; the main camera
## excludes its depth-copy quad. Layer 1 owns the main-camera composite.
const ACTOR_LAYER := 1 << 19
const MARKER_SHADER := preload("res://scripts/camera/occluded_actor.gdshader")
const DEPTH_SHADER := preload("res://scripts/camera/actor_depth.gdshader")
var _target: Node3D
var _camera: Camera3D
var _camera_mask := 0
var _owners: Array[Dictionary] = []
var _view: SubViewport
var _depth_camera: Camera3D
var _copy: MeshInstance3D
var _marker: MeshInstance3D
var _material: ShaderMaterial

func _quad(shader: Shader) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = QuadMesh.new()
	node.mesh.size = Vector2(2,2)
	node.material_override = ShaderMaterial.new()
	node.material_override.shader = shader
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.extra_cull_margin = 16384
	node.ignore_occlusion_culling = true
	node.add_to_group("tactical_camera_pass")
	return node

func update_actor(camera: Camera3D, actor: Node3D) -> void:
	if actor != _target or camera != _camera:
		clear()
		_target = actor
		_camera = camera
		_camera_mask = camera.cull_mask
		camera.cull_mask &= ~ACTOR_LAYER
		for node: Node in actor.find_children("*", "MeshInstance3D", true, false):
			_owners.append({"node": weakref(node), "layers": node.layers})
			node.layers |= ACTOR_LAYER
		_view = SubViewport.new()
		_view.world_3d = camera.get_world_3d()
		_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(_view)
		_depth_camera = Camera3D.new()
		_depth_camera.cull_mask = ACTOR_LAYER
		_depth_camera.environment = Environment.new()
		_depth_camera.environment.background_mode = Environment.BG_COLOR
		_depth_camera.environment.background_color = Color.BLACK
		_view.add_child(_depth_camera)
		_copy = _quad(DEPTH_SHADER)
		_copy.layers = ACTOR_LAYER
		_view.add_child(_copy)
		_marker = _quad(MARKER_SHADER)
		_marker.layers = 1
		camera.add_child(_marker)
		_material = _marker.material_override
		_material.set_shader_parameter("actor_depth", _view.get_texture())
	_view.size = camera.get_viewport().get_visible_rect().size
	_depth_camera.global_transform = camera.global_transform
	_depth_camera.projection = camera.projection
	_depth_camera.keep_aspect = camera.keep_aspect
	_depth_camera.fov = camera.fov
	_depth_camera.size = camera.size
	_depth_camera.near = camera.near
	_depth_camera.far = camera.far
	_depth_camera.h_offset = camera.h_offset
	_depth_camera.v_offset = camera.v_offset
	_depth_camera.frustum_offset = camera.frustum_offset
	_copy.global_position = camera.global_position
	_material.set_shader_parameter("view_eye", camera.global_position)
	var focus := actor.global_position + Vector3.UP * 1.8
	var body := actor.find_child("CollisionShape3D", true, false) as CollisionShape3D
	if body != null and body.shape is CapsuleShape3D:
		focus = body.global_position + Vector3.UP * body.shape.height * 0.4
	_material.set_shader_parameter("actor_focus_uv", camera.unproject_position(focus) / Vector2(_view.size))

func clear(deferred := false) -> void:
	for owner: Dictionary in _owners:
		var node: MeshInstance3D = owner.node.get_ref()
		if node != null: node.layers = (node.layers & ~ACTOR_LAYER) | (owner.layers & ACTOR_LAYER)
	_owners.clear()
	if is_instance_valid(_camera): _camera.cull_mask = (_camera.cull_mask & ~ACTOR_LAYER) | (_camera_mask & ACTOR_LAYER)
	if is_instance_valid(_marker):
		_marker.hide()
		if deferred: _marker.queue_free()
		else: _marker.free()
	if is_instance_valid(_view):
		_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		if deferred: _view.queue_free()
		else: _view.free()
	_marker = null
	_view = null
	_target = null
	_camera = null
	_material = null

func _exit_tree() -> void:
	# Tree removal is already traversing these children. Release their render
	# work immediately, and let deletion happen after that traversal completes.
	clear(true)
