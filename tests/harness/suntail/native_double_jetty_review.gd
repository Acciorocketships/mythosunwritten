extends "res://tests/harness/pure_village_lineup.gd"
const House = preload("res://scripts/terrain/features/villages/grammar/PureVillageStreetHouse.gd")


func _run() -> void:
	get_root().size = Vector2i(1400, 1100)
	for bays in [2, 3]:
		var stage := Node3D.new()
		root.add_child(stage)
		_light(stage)
		var house := House.instantiate(bays, House.sample(7, bays), true)
		stage.add_child(house)
		var target := _aabb(house).get_center()
		await _shoot(stage, target + Vector3(13, 7, -17), target, "double%d-rear" % bays)
		await _shoot(stage, target + Vector3(-13, 7, -17), target, "double%d-rear-other" % bays)
		await _shoot(stage, target + Vector3(13, 7, 17), target, "double%d-front" % bays)
		stage.queue_free()
		await process_frame
	quit()
