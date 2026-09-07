extends SceneTree
func _init() -> void:
	var results: Array = []
	for z in range(-16, 17):
		for x in range(-16, 17):
			var p := Vector3(x * 48.0, 0, z * 48.0)
			var w := Helper.biome_weights5(p, 2697992464)
			var distant := p + Vector3(-144, 0, -144)
			var next := Helper.biome_weights5(distant, 2697992464)
			var contrast: float = w[&"meadow"] * (next[&"deep_forest"] + next[&"twilight_marsh"])
			if contrast > 0.55:
				results.append({"contrast": contrast, "x": p.x, "z": p.z, "ahead": String(Helper.biome_at(distant,2697992464))})
	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.contrast > b.contrast)
	print(JSON.stringify(results.slice(0, 8)))
	quit()
