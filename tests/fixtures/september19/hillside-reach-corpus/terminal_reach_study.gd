extends "res://tests/fixtures/september19/hillside-retained-network/reach_study.gd"
## Detached successor study; keep pass 110 reproducible.

func _target(current: RiverTrace, station: int) -> Dictionary:
	# The raw terminal is an existing planned basin, not another transit
	# station. Continuing from here discards the lake and can spend the
	# entire route budget wandering into an unrelated channel.
	if station == current.points.size()-1: return {}
	return super._target(current,station)
