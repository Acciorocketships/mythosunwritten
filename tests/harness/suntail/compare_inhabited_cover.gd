extends SceneTree
## --before probe.json --after probe.json [--max-band 4] [--output comparison.json]
## Exit 1 on lost/raised ceilings, 2 on invalid input. Compare matching corpora.
const COMPARISON = preload("res://tests/fixtures/inhabited_cover_comparison.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var snapshots: Array[Dictionary] = []
	for flag: String in ["--before", "--after"]:
		var index := args.find(flag)
		if index < 0 or index + 1 >= args.size():
			push_error("Missing " + flag + " snapshot path")
			quit(2)
			return
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(args[index + 1]))
		if not data is Dictionary or data.is_empty():
			push_error("Invalid or empty " + flag + " snapshot")
			quit(2)
			return
		for record: Variant in data.values():
			if not record is Dictionary or not record.get("walks") is Dictionary:
				push_error("Missing walk data in " + flag + " snapshot")
				quit(2)
				return
		snapshots.append(data)
	var max_band := 4
	if args.has("--max-band"):
		var index := args.find("--max-band")
		if index + 1 >= args.size() or not args[index + 1].is_valid_int():
			quit(2)
			return
		max_band = int(args[index + 1])
	if max_band <= 0:
		quit(2)
		return
	var result := COMPARISON.compare(snapshots[0], snapshots[1], max_band)
	print(JSON.stringify(result, "\t"))
	if args.has("--output"):
		var index := args.find("--output")
		if index + 1 >= args.size():
			quit(2)
			return
		var file := FileAccess.open(args[index + 1], FileAccess.WRITE)
		if file == null:
			quit(2)
			return
		file.store_string(JSON.stringify(result, "\t"))
	quit(1 if result.lost_quarters > 0 else 0)
