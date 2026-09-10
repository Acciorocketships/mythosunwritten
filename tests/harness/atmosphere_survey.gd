extends SceneTree
func _init() -> void:
	var best: Dictionary = {}
	var counts: Dictionary = {}
	for id: StringName in Helper.BIOME_NAMES:
		best[id] = {"score": -1.0}
		counts[id] = 0
	for z in range(-40, 41):
		for x in range(-40, 41):
			var p := Vector3(x * 96.0, 0, z * 96.0)
			var weights := Helper.biome_weights5(p, 2697992464)
			counts[Helper.biome_at(p, 2697992464)] += 1
			for id: StringName in weights:
				var score: float = weights[id] - p.length() * 0.000015
				if score > best[id].score:
					best[id] = {"score": score, "weight": weights[id], "x": p.x, "z": p.z}
	print(JSON.stringify({"sites": best, "counts": counts}))
	quit()
