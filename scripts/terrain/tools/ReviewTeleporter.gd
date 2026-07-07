# scripts/terrain/tools/ReviewTeleporter.gd
# Debug review helper: F4 teleports the player through the spots listed in
# res://review_teleports.json, cycling in order. The file is RE-READ on every
# press, so the assistant can append new spots while the game is running —
# just press F4 to pick them up. Safe no-op when the file is missing/empty.
#
# JSON format: [{"name": "...", "pos": [x, y, z], "look": [x, z]}, ...]
# ("look" is optional — a world XZ point the character should face.)
class_name ReviewTeleporter
extends CanvasLayer

const PATH := "res://review_teleports.json"
const LABEL_SECS := 4.0

@export var player: Node3D

var _spots: Array = []
var _idx: int = -1
var _label: Label
var _label_until: float = 0.0
var _snap_pending := false   # lift the player onto the ground once it streams


func _ready() -> void:
	_label = Label.new()
	_label.position = Vector2(16, 96)
	_label.add_theme_font_size_override("font_size", 22)
	_label.modulate = Color(1.0, 0.9, 0.4)
	add_child(_label)


func _reload() -> void:
	_spots = []
	if FileAccess.file_exists(PATH):
		var data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if data is Array:
			_spots = data


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode != KEY_F4:
		return
	_reload()   # pick up newly-written spots without restarting
	if _spots.is_empty() or player == null:
		_label.text = "no review spots (%s missing/empty)" % PATH
		_label_until = Time.get_ticks_msec() / 1000.0 + LABEL_SECS
		return
	_idx = (_idx + 1) % _spots.size()
	var s: Dictionary = _spots[_idx]
	var p: Array = s.get("pos", [0.0, 10.0, 0.0])
	if player is CharacterBody3D:
		player.velocity = Vector3.ZERO
	player.global_position = Vector3(float(p[0]), float(p[1]), float(p[2]))
	if s.has("look"):
		var l: Array = s["look"]
		player.rotation.y = atan2(float(l[0]) - float(p[0]), float(l[1]) - float(p[2]))
	_snap_pending = true
	_label.text = "[%d/%d] %s" % [_idx + 1, _spots.size(), str(s.get("name", ""))]
	_label_until = Time.get_ticks_msec() / 1000.0 + LABEL_SECS


func _process(_delta: float) -> void:
	if _label.text != "" and Time.get_ticks_msec() / 1000.0 > _label_until:
		_label.text = ""
	if not _snap_pending or player == null:
		return
	# Spot heights go stale as the terrain evolves: once the chunk under the
	# target streams in, lift the player out of the ground if the recorded y
	# left them under it ("stuck underneath the terrain"). Water areas are not
	# in the ray mask, so submerged spots keep their in-water y.
	var pos: Vector3 = player.global_position
	var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(
			pos + Vector3(0, 160, 0), pos + Vector3(0, -160, 0)))
	if hit.is_empty():
		return   # chunk still streaming — keep waiting
	_snap_pending = false
	if pos.y < hit.position.y - 0.05:
		player.global_position.y = hit.position.y + 1.2
		if player is CharacterBody3D:
			player.velocity = Vector3.ZERO
