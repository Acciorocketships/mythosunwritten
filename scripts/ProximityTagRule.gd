class_name ProximityTagRule
extends Resource

@export var tag: String = ""
@export var radius: float = 0.0

# Base probability multiplier when at least one match is within radius:
# \(p *= (1 + boost)\)
@export var boost: float = 0.0

# Additional probability multiplier per match count within radius:
# \(p *= (1 + ... + per_count * count)\)
#
# Can be a small negative number to dampen runaway clustering.
@export var per_count: float = 0.0

static func init_rule(
	_tag: String,
	_radius: float,
	_boost: float = 0.0,
	_per_count: float = 0.0
) -> ProximityTagRule:
	var r: ProximityTagRule = ProximityTagRule.new()
	r.tag = _tag
	r.radius = _radius
	r.boost = _boost
	r.per_count = _per_count
	return r

