# scripts/terrain/tools/CoordOverlay.gd
# Debug HUD: a screen-centre crosshair + a readout of world/cell coordinates so a screenshot
# alone pins down exactly where a terrain issue is. Shows the seed, the player's cell, the cell
# the crosshair is aimed at (raycast onto the terrain), and the 3×3 grid of storey heights
# around that cell (so cliff/corner configs are legible at a glance). Toggle with F3.
extends CanvasLayer

const TILE := 24.0

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

func _cell_of(v: float) -> int:
	return int(round(v / TILE))

func _process(_dt: float) -> void:
	if not _enabled:
		return
	var cam := get_viewport().get_camera_3d()
	var ft := get_node_or_null("/root/World/FieldTerrain")
	var player := get_node_or_null("/root/World/Characters/Character")
	if cam == null or ft == null:
		return
	var lines: Array[String] = []
	var plan = ft.get("_plan")
	var wseed = ft.get("world_seed")
	lines.append("seed %s   (F3 to toggle)" % str(wseed))
	if player != null:
		var pp: Vector3 = player.global_position
		lines.append("player  world (%.1f, %.1f, %.1f)  cell (%d, %d)" % [pp.x, pp.y, pp.z, _cell_of(pp.x), _cell_of(pp.z)])
		if wseed != null and int(wseed) != 0:
			var w5 := Helper.biome_weights5(pp, int(wseed))
			var parts: Array[String] = []
			for k: StringName in w5:
				if w5[k] >= 0.05:
					parts.append("%s %.2f" % [k, w5[k]])
			lines.append("biome %s   (%s)" % [Helper.biome_at(pp, int(wseed)), ", ".join(parts)])
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
		var cx := _cell_of(wp.x)
		var cz := _cell_of(wp.z)
		lines.append("crosshair world (%.1f, %.1f, %.1f)  cell (%d, %d)" % [wp.x, wp.y, wp.z, cx, cz])
		if plan != null:
			lines.append("storeys (3×3 around crosshair cell, +z down):")
			for dz in [-1, 0, 1]:
				var row := "  "
				for dx in [-1, 0, 1]:
					var s: int = plan.storey_at(cx + dx, cz + dz)
					row += ("[%2d]" % s) if (dx == 0 and dz == 0) else (" %2d " % s)
				lines.append(row)
	_label.text = "\n".join(lines)
