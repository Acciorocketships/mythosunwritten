extends "res://tests/harness/september10_reported_qa.gd"
func _spots() -> Array:
	var all := super._spots()
	if OS.get_cmdline_user_args().has("--skywalk-town"):
		return [all[0],all[2]]
	return [all[6],all[11],all[16],all[1]]
