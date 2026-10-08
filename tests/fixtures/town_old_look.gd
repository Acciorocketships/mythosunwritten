extends RefCounted
## The town-table values before the October 7 taste defaults. Tests that pin
## pre-taste behaviour (clearings, rings, furnishing) merge these under their own
## overrides so they do not depend on the shipped defaults.
const VALUES := {
	&"clearing_lobe_bias": 0.0, &"clearing_enclosure_bias": 0.0,
	&"plaza_ring_chance": 1.0, &"clearing_ring_chance": 1.0,
	&"clearing_deco_density": 0.0, &"well_scale": 1.0,
	&"satellite_reach_scale": 1.0, &"suburb_house_count": 0.0,
	&"lone_house_path_chance": 1.0,
}

static func merge(overrides: Dictionary = {}) -> Dictionary:
	var out := VALUES.duplicate()
	out.merge(overrides, true)
	return out
