extends RefCounted
## Experimental tile constructor, used only by review harnesses.
static func make(width: float) -> GDScript:
	var original := FileAccess.get_file_as_string("res://scripts/terrain/field/TerrainTileField.gd").replace("class_name TerrainTileField", "")
	var source := GDScript.new()
	var text := original
	var start := text.find("static func _corner_profile(")
	var stop := text.find("\n\n## Profile of one direction", start)
	text = text.substr(0, start) + """static func _corner_profile(t: float, k: float, _s: float, _corner_t: float, _mixed: bool, _side: int, _side_s: int, _ends: bool, _mode: int) -> float:
	return SlopeProfile.smootherstep(t) if k <= 0.0 else _step(t, 0)
""" + text.substr(stop)
	start = text.find("static func _profile(")
	stop = text.find("\n\nstatic func _step(", start)
	text = text.substr(0, start) + """static func _profile(t: float, k0: float, k1: float, s: float, _side: int, _side_s: int, _ends: bool, _mode: int) -> float:
	return lerpf(SlopeProfile.smootherstep(t), _step(t, 0), lerpf(k0, k1, SlopeProfile.smootherstep(s)))
""" + text.substr(stop)
	start = text.find("static func _step(")
	stop = text.find("\n\n# --- world-space", start)
	text = text.substr(0, start) + "static func _step(t: float, _side: int) -> float:\n\treturn SlopeProfile.smootherstep(clampf((t - %s) / %s, 0.0, 1.0))\n" % [(1.0 - width) * 0.5, width] + text.substr(stop)
	source.source_code = text
	assert(source.reload() == OK)
	return source
