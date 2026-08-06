extends SceneTree

## CI/QA entry point for VillageVisualReviewGate. Example:
##   godot --headless --path /Users/ryko/story \
##     -s res://tests/harness/village_visual_review_gate.gd -- \
##     --capture-index <run>/index.json --report <run>/village_visual_review_report.json
## Add --require-closure only for the independent, full-spec closing pass.
const Gate = preload("res://tests/harness/VillageVisualReviewGate.gd")

var _capture_index_path := ""
var _report_path := ""
var _pins_path := "res://tests/harness/review_villages.json"
var _require_closure := false


func _init() -> void:
	_read_args()
	if _capture_index_path.is_empty() or _report_path.is_empty():
		push_error("Usage: --capture-index <index.json> --report <report.json> [--pins <review_villages.json>] [--require-closure]")
		quit(1)
		return
	var capture_index := _read_json(_capture_index_path)
	var report := _read_json(_report_path)
	var pins := _read_json(_pins_path)
	var errors := Gate.closure_errors(capture_index, report, pins) \
		if _require_closure else Gate.validate(capture_index, report, pins)
	if not errors.is_empty():
		for error: String in errors:
			push_error("Village visual review gate: %s" % error)
		quit(1)
		return
	print("[village_visual_review_gate] valid captures=%d findings=%d closure=%s" % [
		(capture_index.get("captures", []) as Array).size(),
		(report.get("findings", []) as Array).size(), _require_closure])
	quit()


func _read_args() -> void:
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		match args[index]:
			"--capture-index":
				if index + 1 < args.size():
					_capture_index_path = args[index + 1]
			"--report":
				if index + 1 < args.size():
					_report_path = args[index + 1]
			"--pins":
				if index + 1 < args.size():
					_pins_path = args[index + 1]
			"--require-closure":
				_require_closure = true


static func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}
