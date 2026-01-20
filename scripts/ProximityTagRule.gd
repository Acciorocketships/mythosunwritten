class_name ProximityTagRule
extends Resource

@export var tag: String = ""
@export var radius: float = 0.0

# If there is at least 1 match within `radius`, this is the **overall probability**
# of placing this tag at this socket:
#   P(place this tag) = fill_prob * P(tag)
#
# This is *not* a weight/multiplier; it's a probability in [0, 1].
@export var prob_if_any: float = 0.0

# If > 0, each additional match (beyond the first) moves the weight back toward the
# original/base weight by a constant step:
#   delta_per_extra = (prob_if_any - base_overall_prob) / n_to_return
# so after `n_to_return` extra matches, the probability is back at base_overall_prob.
@export var n_to_return: float = 0.0

static func init_rule(
	_tag: String,
	_radius: float,
	_prob_if_any: float = 0.0,
	_n_to_return: float = 0.0
) -> ProximityTagRule:
	var r: ProximityTagRule = ProximityTagRule.new()
	r.tag = _tag
	r.radius = _radius
	r.prob_if_any = _prob_if_any
	r.n_to_return = _n_to_return
	return r

