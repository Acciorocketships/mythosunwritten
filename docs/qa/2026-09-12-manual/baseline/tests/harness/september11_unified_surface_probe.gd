extends SceneTree

func _init() -> void:
	var data: Dictionary = FileAccess.open("res://docs/qa/2026-09-11-manual/10-unified-city/proposal1-payload.bin", FileAccess.READ).get_var()
	var skin: Dictionary = data.skin
	print("SKIN_KEYS ", skin.keys())
	print("SUSPENDED ", skin.suspended_plaza.keys())
	var unsupported: Array[Vector3i] = []
	for cell: Vector3i in skin.capped_ground:
		var below := cell + Vector3i.DOWN
		if cell.y > 0 and not skin.retained.has(below) and not skin.solids.has(below):
			unsupported.append(cell)
	print("UNBORNE_GARDEN ", unsupported)
	print("ALL_GARDEN ", skin.capped_ground.keys())
	quit()
