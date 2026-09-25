extends Node

## A late transparent atmosphere pass also covers sky/void pixels, buildings,
## water and native materials. No terrain mesh or material is replaced.
const SHADER = preload("res://scripts/terrain/diagnostics/loading_frontier.gdshader")
var _overlay: MeshInstance3D
var _material: ShaderMaterial
var _keys: Array = []
var _camera: Camera3D
var _coverage_center := Vector2i(2147483647,2147483647)

func update_view(camera: Camera3D, loaded: Dictionary, color: Color) -> void:
	if not is_instance_valid(camera): return
	if _camera != camera:
		clear()
		_camera = camera
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = SHADER
		_material.render_priority = 126 # Underwater medium remains last.
		_overlay = MeshInstance3D.new()
		_overlay.name = "LoadingFrontierFog"
		var quad := QuadMesh.new()
		quad.size = Vector2(2,2)
		_overlay.mesh = quad
		_overlay.material_override = _material
		_overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_overlay.extra_cull_margin = 16384
		_overlay.ignore_occlusion_culling = true
		_overlay.add_to_group("tactical_preserve_surface")
		camera.add_child(_overlay)
		_overlay.position.z = -0.1
	var keys := loaded.keys()
	keys.sort()
	var center := Vector2i((Vector2(camera.global_position.x,camera.global_position.z)/192.0).floor())
	if keys != _keys or center != _coverage_center or _material.get_shader_parameter("loaded_cells") == null:
		_keys = keys
		_coverage_center = center
		_publish_coverage()
	_material.set_shader_parameter("owner_eye",camera.global_position)
	_material.set_shader_parameter("fog_color",color)

func _publish_coverage() -> void:
	var lo := Vector2i.ZERO
	var hi := Vector2i.ZERO
	if not _keys.is_empty():
		lo = _keys[0]
		hi = lo
		for cell: Vector2i in _keys:
			lo = lo.min(cell)
			hi = hi.max(cell)
	var size := hi-lo+Vector2i.ONE
	# A teleport may briefly retain distant old residents. Restrict the view
	# map, never stretch it across an unbounded gap or treat that gap as ready.
	if size.x>32 or size.y>32:
		lo = _coverage_center-Vector2i(16,16)
		size = Vector2i(32,32)
	var coverage := Image.create_empty(size.x,size.y,false,Image.FORMAT_R8)
	for cell: Vector2i in _keys:
		var p := cell-lo
		if p.x>=0 and p.y>=0 and p.x<size.x and p.y<size.y:
			coverage.set_pixel(p.x,p.y,Color.WHITE)
	_material.set_shader_parameter("loaded_cells",ImageTexture.create_from_image(coverage))
	_material.set_shader_parameter("first_cell",Vector2(lo))
	_material.set_shader_parameter("cell_count",Vector2(size))

func clear() -> void:
	if is_instance_valid(_overlay): _overlay.free()
	_overlay = null
	_material = null
	_camera = null
	_keys.clear()

func _exit_tree() -> void:
	clear()
