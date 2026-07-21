class_name MythosTaperedProgressBar
extends Control
## Hairline atlas-style progress bar with pointed, tapered ends.

@export_range(0.0, 1.0, 0.001) var progress: float = 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		queue_redraw()
@export_range(0.25, 3.0, 0.05) var track_thickness: float = 0.65
@export_range(0.25, 4.0, 0.05) var fill_thickness: float = 1.35
@export_range(1.0, 64.0, 1.0) var taper_length: float = 22.0
@export var track_color: Color = Color(0.25, 0.23, 0.27, 0.22)
@export var fill_color: Color = Color(0.73, 0.54, 0.25, 0.88)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var centre_y := size.y * 0.5
	draw_line(Vector2(0.0, centre_y), Vector2(size.x, centre_y),
		track_color, track_thickness, true)
	var fill_width := size.x * progress
	if fill_width <= 0.25:
		return
	var taper := minf(taper_length, fill_width * 0.5)
	var half_height := fill_thickness * 0.5
	var points := PackedVector2Array([
		Vector2(0.0, centre_y),
		Vector2(taper, centre_y - half_height),
		Vector2(maxf(taper, fill_width - taper), centre_y - half_height),
		Vector2(fill_width, centre_y),
		Vector2(maxf(taper, fill_width - taper), centre_y + half_height),
		Vector2(taper, centre_y + half_height),
	])
	draw_colored_polygon(points, fill_color)
