# scripts/terrain/tools/CoordOverlay.gd
# Debug HUD: a screen-centre crosshair + a readout of world/lattice coordinates so a screenshot
# alone pins down exactly where a terrain issue is. Shows the seed, the player's 12 m lattice
# point, and for the crosshair (raycast onto the terrain) its point, the 12 m tile under it with
# its 2×2 corner storeys/levels and its four lattice-edge categories (so cliff/slope/saddle
# configs are legible at a glance). Reads only the streamer's committed snapshots. Toggle F3.
extends CanvasLayer

const EDGE_NAMES := ["flat", "level", "slope", "cliff"]   # TerrainTileField.EdgeCategory

var _label: Label
var _cross: Control
var _enabled := true

func _ready() -> void:
	layer = 100
	_label = Label.new()
	_label.position = Vector2(10, 8)
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_label.add_theme_constant_override("outline_size", 6)
	add_child(_label)
	_cross = Control.new()
	_cross.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cross.draw.connect(_draw_cross)
	add_child(_cross)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F3:
		_enabled = not _enabled
		_label.visible = _enabled
		_cross.visible = _enabled

func _draw_cross() -> void:
	var c := _cross.size * 0.5
	var col := Color(1, 1, 0)
	_cross.draw_line(c - Vector2(10, 0), c + Vector2(10, 0), col, 2.0)
	_cross.draw_line(c - Vector2(0, 10), c + Vector2(0, 10), col, 2.0)

## Committed-snapshot view with the region API TerrainTileField.edge_category reads.
class LoadedPoints extends RefCounted:
	var source
	func _init(p_source) -> void:
		source = p_source
	func storey_at(i: int, j: int) -> int:
		return int(source.loaded_storey_at(Vector2i(i, j)))
	func surface_height(i: int, j: int) -> float:
		return (source.loaded_point_at(Vector2i(i, j)) as Vector2).x


## The tile under world xz: its index floor(v / 12), its corners a (-x -z),
## b (+x -z), d (-x +z), c (+x +z) as storey/level, and its four lattice-edge
## categories. `source` answers loaded_storey_at / loaded_point_at by point.
## The terrain regimes blended at a world position (TerrainRegimeField), nearest
## first with weights, and the nearest region's site.
static func regime_line(seed: int, world: Vector3) -> String:
	var regimes := TerrainRegimeField.sample(seed, Vector2(world.x, world.z))
	var parts: Array[String] = []
	for pair: Array in regimes:
		parts.append("%s %.2f" % [pair[0].archetype, pair[1]])
	var site: Vector2 = regimes[0][0].site
	return "terrain %s   (site %.0f, %.0f)" % [", ".join(parts), site.x, site.y]


static func tile_lines(source, world_xz: Vector2) -> Array[String]:
	var s := TerrainTileField.SPACING
	var tile := Vector2i(floori(world_xz.x / s), floori(world_xz.y / s))
	var lines: Array[String] = ["tile (%d, %d)  corners storey/level (+z down):" % [tile.x, tile.y]]
	for dz in 2:
		var row := " "
		for dx in 2:
			var p := tile + Vector2i(dx, dz)
			var storey: Variant = source.loaded_storey_at(p)
			var point: Variant = source.loaded_point_at(p)
			var label: String = ["a", "b", "d", "c"][dz * 2 + dx]
			if storey == null or point == null:
				row += "  %s --/-" % label
			else:
				var level := roundi((point as Vector2).x - float(storey) * HeightfieldRegion.STOREY_HEIGHT)
				row += "  %s s%d/l%d" % [label, int(storey), level]
		lines.append(row)
	for dz in 2:
		for dx in 2:
			if source.loaded_storey_at(tile + Vector2i(dx, dz)) == null \
					or source.loaded_point_at(tile + Vector2i(dx, dz)) == null:
				lines.append("  edges: (corners not loaded)")
				return lines
	var view := LoadedPoints.new(source)
	var edges := [["-z a-b", tile, Vector2i(1, 0)], ["+x b-c", tile + Vector2i(1, 0), Vector2i(0, 1)],
		["+z d-c", tile + Vector2i(0, 1), Vector2i(1, 0)], ["-x a-d", tile, Vector2i(0, 1)]]
	var parts: Array[String] = []
	for edge: Array in edges:
		parts.append("%s %s" % [edge[0], EDGE_NAMES[TerrainTileField.edge_category(view, edge[1], edge[2])]])
	lines.append("  edges: " + "   ".join(parts))
	return lines

func _process(_dt: float) -> void:
	if not _enabled:
		return
	var cam := get_viewport().get_camera_3d()
	var ft := get_node_or_null("/root/World/FieldTerrain") as FieldTerrainStreamer
	var player := get_node_or_null("/root/World/Characters/Character")
	if cam == null or ft == null:
		return
	var lines: Array[String] = []
	var wseed := ft.world_seed
	lines.append("seed %s   (F3 to toggle)" % str(wseed))
	if player != null:
		var pp: Vector3 = player.global_position
		lines.append("player  world (%.1f, %.1f, %.1f)  point (%d, %d)" % [pp.x, pp.y, pp.z,
			TerrainTileField.point_of(pp.x), TerrainTileField.point_of(pp.z)])
		if wseed != 0:
			var w5 := Helper.biome_weights5(pp, int(wseed))
			var parts: Array[String] = []
			var dominant: StringName = &""
			var best := -1.0
			for k: StringName in w5:
				if w5[k] > best:
					best = w5[k]
					dominant = k
				if w5[k] >= 0.05:
					parts.append("%s %.2f" % [k, w5[k]])
			lines.append("biome %s   (%s)" % [BiomeRegistry.profile(dominant).display_name, ", ".join(parts)])
			lines.append(regime_line(int(wseed), pp))
	# Raycast from screen centre onto the terrain.
	var vp := get_viewport().get_visible_rect().size
	var centre := vp * 0.5
	var from := cam.project_ray_origin(centre)
	var dir := cam.project_ray_normal(centre)
	var space := cam.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 4000.0)
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		lines.append("crosshair: (no terrain hit)")
	else:
		var wp: Vector3 = hit.position
		lines.append("crosshair world (%.1f, %.1f, %.1f)  point (%d, %d)" % [wp.x, wp.y, wp.z,
			TerrainTileField.point_of(wp.x), TerrainTileField.point_of(wp.z)])
		lines.append_array(tile_lines(ft, Vector2(wp.x, wp.z)))
	_label.text = "\n".join(lines)
