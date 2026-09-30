# scripts/terrain/tools/TerrainCategoryOverlay.gd
# Debug view (F9): colour-codes the terrain field's own categories on every
# rendered surface, so a screenshot shows which 12 m lattice edges are flat,
# level steps, slopes or cliffs, where the storey/level contours and the walls
# (dual-cell borders) run, and where the rendered ground departs from the tile
# kernel (the rounded cliff envelope, bedrock, rocks, road/water cuts, town
# grade). The shader carries a GPU port of TerrainTileField, including the
# selected cliff-end rule.
# Main-thread only: reads the immutable per-chunk point snapshots published by
# FieldTerrainStreamer and draws one full-screen deferred-decal quad.
extends CanvasLayer

const SHADER := preload("res://terrain/materials/debug/terrain_category_overlay.gdshader")
const SIZE := 128                # lattice points per side of the data window (1.5 km)
const REFRESH_SECONDS := 0.5

const LEGEND := "TERRAIN CATEGORIES (F9)\n" \
	+ "each 12 m lattice edge colours the diamond around its midpoint:\n" \
	+ "grey    flat edge: same height\n" \
	+ "blue    level edge: same storey, 1-3 m apart (slope)\n" \
	+ "green   slope edge: 1 storey (4 m) apart\n" \
	+ "red     cliff edge: 2+ storeys (wall on the tile midline)\n" \
	+ "magenta rendered ABOVE the tile kernel (cliff envelope, bedrock, rocks)\n" \
	+ "cyan    rendered BELOW the tile kernel (road/water cut, recess)\n" \
	+ "yellow stripes  town grade (points a town, its streets or its road ramps moved)\n" \
	+ "thin dark lines: 1 m contours   white: 4 m storey contours\n" \
	+ "black: tile grid (points, 12 m)   faint orange: wall lines (12 i + 6)   blue: chunk border (192 m)"

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
	_material.set_shader_parameter("points", _texture)
	_material.set_shader_parameter("points_size", SIZE)
	_material.set_shader_parameter("spacing", TerrainTileField.SPACING)
	_material.set_shader_parameter("storey_height", HeightfieldRegion.STOREY_HEIGHT)
	_material.set_shader_parameter("chunk_points", float(TerrainChunkMesher.POINTS_PER_CHUNK))
	_legend = Label.new()
	_legend.add_theme_font_size_override("font_size", 15)
	_legend.add_theme_color_override("font_outline_color", Color.BLACK)
	_legend.add_theme_constant_override("outline_size", 6)
	_legend.text = LEGEND
	_legend.anchor_top = 1.0
	_legend.anchor_bottom = 1.0
	_legend.offset_left = 10.0
	_legend.offset_top = -250.0
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
	var spacing := TerrainTileField.SPACING
	var centre := Vector2i(roundi(camera.global_position.x / spacing),
		roundi(camera.global_position.z / spacing))
	var origin := centre - Vector2i.ONE * (SIZE / 2)
	_refresh -= delta
	if origin == _origin and _refresh > 0.0:
		return
	_origin = origin
	_refresh = REFRESH_SECONDS
	var data := PackedFloat32Array()
	data.resize(SIZE * SIZE * 2)
	for z in SIZE:
		for x in SIZE:
			var value: Variant = streamer.loaded_point_at(origin + Vector2i(x, z))
			var v: Vector2 = value if value != null else Vector2(-1e7, 0.0)
			data[(z * SIZE + x) * 2] = v.x
			data[(z * SIZE + x) * 2 + 1] = v.y
	_image.set_data(SIZE, SIZE, false, Image.FORMAT_RGF, data.to_byte_array())
	_texture.update(_image)
	_material.set_shader_parameter("origin_point", origin)
	_material.set_shader_parameter("cliff_end", TerrainTileField.cliff_end)


func _streamer() -> FieldTerrainStreamer:
	var world := get_parent()
	return world.get_node_or_null("FieldTerrain") as FieldTerrainStreamer if world != null else null
