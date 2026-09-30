# scripts/terrain/tools/TerrainCategoryOverlay.gd
# Debug view (F9): colour-codes the terrain field's own categories on every
# rendered surface, so a screenshot shows which cell edges are slopes, level
# steps or cliffs, where the storey/level contours run, and
# where the rendered ground departs from the standard slope kernel (the
# rounded cliff envelope, bedrock, rocks, road/water cuts, town grade).
# Main-thread only: reads the immutable per-chunk cell snapshots published by
# FieldTerrainStreamer and draws one full-screen deferred-decal quad.
extends CanvasLayer

const SHADER := preload("res://terrain/materials/debug/terrain_category_overlay.gdshader")
const SIZE := 64                 # cells per side of the data window (1.5 km)
const REFRESH_SECONDS := 0.5

@export var enabled := false

var _quad: MeshInstance3D
var _material: ShaderMaterial
var _legend: Label
var _image: Image
var _texture: ImageTexture
var _origin := Vector2i(1 << 30, 0)
var _refresh := 0.0


func _ready() -> void:
	layer = 101
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.render_priority = 100
	var mesh := QuadMesh.new()
	mesh.size = Vector2(2, 2)
	_quad = MeshInstance3D.new()
	_quad.mesh = mesh
	_quad.material_override = _material
	_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_quad.custom_aabb = AABB(Vector3.ONE * -1e6, Vector3.ONE * 2e6)
	_image = Image.create(SIZE, SIZE, false, Image.FORMAT_RGF)
	_texture = ImageTexture.create_from_image(_image)
	_material.set_shader_parameter("cells", _texture)
	_material.set_shader_parameter("cells_size", SIZE)
	_material.set_shader_parameter("tile", TerrainSurfaceField.TILE)
	_material.set_shader_parameter("storey_height", HeightfieldRegion.STOREY_HEIGHT)
	_legend = Label.new()
	_legend.add_theme_font_size_override("font_size", 15)
	_legend.add_theme_color_override("font_outline_color", Color.BLACK)
	_legend.add_theme_constant_override("outline_size", 6)
	_legend.text = "\n".join([
		"TERRAIN CATEGORIES (F9)",
		"grey    flat plateau (cell centre)",
		"green   slope edge: 1 storey (4 m) apart",
		"blue    level edge: same storey, 1-3 m apart",
		"red     cliff edge: 2+ storeys (wall)",
		"magenta rendered ABOVE the slope kernel (cliff envelope, bedrock, rocks)",
		"cyan    rendered BELOW the kernel (road/water cut, recess)",
		"yellow stripes  town grade (native controls moved by a town, its streets or its road ramps)",
		"thin dark lines: 1 m contours   white: 4 m storey contours   black: cell grid   blue: chunk border",
	])
	_legend.anchor_top = 1.0
	_legend.anchor_bottom = 1.0
	_legend.offset_left = 10.0
	_legend.offset_top = -210.0
	add_child(_legend)
	_apply()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F9:
		enabled = not enabled
		_apply()


func set_enabled(value: bool) -> void:
	enabled = value
	_apply()


func _apply() -> void:
	if _legend == null:
		return
	_legend.visible = enabled
	if enabled and _quad.get_parent() == null:
		# A 3D sibling in the world: the canvas layer only hosts the legend.
		get_parent().add_child.call_deferred(_quad)
	elif not enabled and _quad.get_parent() != null:
		_quad.get_parent().remove_child(_quad)
	# Grass blades stand above the ground and would read as envelope lift.
	var streamer := _streamer()
	if streamer != null and streamer._grass_root != null:
		streamer._grass_root.visible = not enabled
	_origin = Vector2i(1 << 30, 0)
	_refresh = 0.0


func _exit_tree() -> void:
	if is_instance_valid(_quad) and _quad.get_parent() == null:
		_quad.free()


func _process(delta: float) -> void:
	if not enabled:
		return
	var camera := get_viewport().get_camera_3d()
	var streamer := _streamer()
	if camera == null or streamer == null:
		return
	var tile := TerrainSurfaceField.TILE
	var centre := Vector2i(roundi(camera.global_position.x / tile), roundi(camera.global_position.z / tile))
	var origin := centre - Vector2i.ONE * (SIZE / 2)
	_refresh -= delta
	if origin == _origin and _refresh > 0.0:
		return
	_origin = origin
	_refresh = REFRESH_SECONDS
	for z in SIZE:
		for x in SIZE:
			var value: Variant = streamer.loaded_cell_at(origin + Vector2i(x, z))
			var v: Vector2 = value if value != null else Vector2(-1e7, 0.0)
			_image.set_pixel(x, z, Color(v.x, v.y, 0.0))
	_texture.update(_image)
	_material.set_shader_parameter("origin_cell", origin)


func _streamer() -> FieldTerrainStreamer:
	var world := get_parent()
	return world.get_node_or_null("FieldTerrain") as FieldTerrainStreamer if world != null else null
