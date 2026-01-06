extends Resource
class_name Distribution

var dist: Dictionary[String, float]

func _init(dict: Dictionary[String, float] = {}):
	dist = dict
	
func _get(key: StringName) -> Variant:
	return dist.get(key, 0.0)

func _set(key: StringName, value: Variant) -> bool:
	dist[key] = value
	return true

func sample() -> String:
	# dist: {"A": 0.2, "B": 0.5}
	# sample(dist) will return "A" with 0.2 probability, "B" with 0.5 probability, or "other" with 0.3 probability
	var t: float = randf()
	var cumprob: float = 0
	for key in dist.keys():
		cumprob += dist[key]
		if t <= cumprob:
			return key
	return "other"
