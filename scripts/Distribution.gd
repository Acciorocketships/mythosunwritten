extends Resource
class_name Distribution

var dist: Dictionary[String, float]

var _iter_i := 0

func _init(dict: Dictionary[String, float] = {}):
	dist = dict

func sample() -> String:
	# dist: {"A": 0.2, "B": 0.5, "other": 0.3}
	# sample(dist) will return "A" with 0.2 probability, "B" with 0.5 probability, or "other" with 0.3 probability
	var t: float = randf()
	var cumprob: float = 0
	for key in dist.keys():
		cumprob += dist[key]
		if t <= cumprob:
			return key
	assert(false) # we can only reach this position if the probabilities dont sum to 1
	return ""

func prob(tag: String) -> float:
	return dist.get(tag, 0)

func set_prob(tag: String, p: float) -> void:
	dist[tag] = p

func normalise() -> void:
	var total_prob: float = 0
	for tag: String in dist.keys():
		total_prob += dist[tag]
	if total_prob > 0.0:
		for tag: String in dist.keys():
			dist[tag] = dist[tag] / total_prob

func copy() -> Distribution:
	return Distribution.new(dist.duplicate())

func remove(tag: String) -> void:
	dist.erase(tag)

func is_empty() -> bool:
	return dist.is_empty()

func _iter_init(_arg) -> bool:
	_iter_i = 0
	return dist.size() > 0

func _iter_next(_arg) -> bool:
	_iter_i += 1
	return _iter_i < dist.size()

func _iter_get(_arg):
	return dist.keys()[_iter_i]
