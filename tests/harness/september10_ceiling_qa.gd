extends "res://tests/harness/september10_reported_qa.gd"
func _spots() -> Array:
	var all := super._spots()
	return [all[3], all[7], all[8]]
