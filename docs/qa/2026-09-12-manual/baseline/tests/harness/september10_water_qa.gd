extends "res://tests/harness/september10_reported_qa.gd"
func _spots() -> Array:
	var all := super._spots()
	return [all[14],all[15],all[17],all[18]]
