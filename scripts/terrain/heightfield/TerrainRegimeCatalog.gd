class_name TerrainRegimeCatalog
extends RefCounted

## Curated terrain archetypes (spec 2026-10-02 §5). Each parameter is a
## [min, max] range drawn once per region; an optional third element names a
## shared draw group. Suffixes: *_m metres (multiplied by the region's scale),
## *_st storeys (x STOREY m), anything else unitless. Values are a starting
## point for visual review, not a contract.

const STOREY := 4.0

const ARCHETYPES: Array[StringName] = [&"rolling_downs", &"ridge_and_pass",
	&"escarpment_country", &"terraced_valleys", &"karst_hollows", &"tableland",
	&"highland_massif", &"low_flats"]

const PARAMS := {
	&"rolling_downs": {
		"base_level_st": [1.0, 6.0], "relief_st": [1.0, 2.0], "hummock_wl_m": [60.0, 140.0],
		"knoll_spacing_m": [150.0, 300.0], "knoll_radius_m": [30.0, 60.0],
		"knoll_density": [0.3, 0.6], "knoll_st": [1.0, 2.0]},
	&"ridge_and_pass": {
		"base_level_st": [4.0, 12.0], "ridge_spacing_m": [60.0, 200.0], "ridge_st": [2.0, 5.0],
		"pass_spacing_m": [150.0, 400.0], "pass_depth": [0.5, 0.8],
		"gully_spacing_m": [30.0, 60.0], "gully_st": [0.5, 1.0]},
	&"escarpment_country": {
		"base_level_st": [2.0, 8.0], "relief_st": [0.5, 1.0], "hummock_wl_m": [80.0, 160.0],
		"tread_rise_st": [2.0, 3.0], "tread_depth_m": [40.0, 150.0], "riser_frac": [0.08, 0.18],
		"steps": [2.0, 4.0]},
	&"terraced_valleys": {
		"base_level_st": [1.0, 6.0], "valley_half_width_m": [40.0, 120.0], "treads": [3.0, 6.0],
		"tread_depth_m": [24.0, 60.0], "riser_frac": [0.2, 0.4], "relief_st": [0.25, 0.75],
		"hummock_wl_m": [60.0, 120.0]},
	&"karst_hollows": {
		"base_level_st": [2.0, 8.0], "relief_st": [0.5, 1.0], "hummock_wl_m": [80.0, 160.0],
		"sink_spacing_m": [60.0, 120.0], "sink_radius_m": [10.0, 30.0], "sink_density": [0.3, 0.6],
		"sink_st": [1.0, 3.0], "hollow_spacing_m": [150.0, 300.0], "hollow_radius_m": [40.0, 100.0],
		"hollow_density": [0.3, 0.6], "hollow_st": [1.0, 2.0], "knob_spacing_m": [100.0, 200.0],
		"knob_radius_m": [15.0, 30.0], "knob_st": [1.0, 2.0]},
	&"tableland": {
		"base_level_st": [4.0, 12.0], "cell_m": [80.0, 250.0], "channel_m": [15.0, 40.0],
		"rim_st": [2.0, 4.0]},
	&"highland_massif": {
		"base_level_st": [8.0, 18.0], "ridge_spacing_m": [120.0, 300.0], "ridge_st": [4.0, 8.0],
		"pass_spacing_m": [250.0, 600.0], "pass_depth": [0.3, 0.6],
		"gully_spacing_m": [40.0, 80.0], "gully_st": [0.75, 1.5]},
	&"low_flats": {
		"base_level_st": [0.0, 2.0], "relief_st": [0.0, 1.0], "hummock_wl_m": [80.0, 200.0],
		"mound_spacing_m": [120.0, 260.0], "mound_radius_m": [30.0, 80.0], "mound_st": [0.5, 1.0]},
}

## Visual biome -> archetype weights; every archetype also gets AFFINITY_FLOOR.
const AFFINITY_FLOOR := 0.03
const AFFINITY := {
	&"meadow": {&"rolling_downs": 0.45, &"terraced_valleys": 0.25, &"escarpment_country": 0.20},
	&"deep_forest": {&"rolling_downs": 0.35, &"karst_hollows": 0.30, &"ridge_and_pass": 0.25},
	&"highland": {&"highland_massif": 0.40, &"ridge_and_pass": 0.25, &"tableland": 0.20,
		&"escarpment_country": 0.15},
	&"blossom_grove": {&"terraced_valleys": 0.45, &"rolling_downs": 0.35},
	&"twilight_marsh": {&"low_flats": 0.65, &"karst_hollows": 0.25},
	&"amber_heath": {&"tableland": 0.45, &"escarpment_country": 0.35},
	&"jade_wetlands": {&"low_flats": 0.50, &"terraced_valleys": 0.30},
}

## Probability that a 512 m set-piece cell in this archetype hosts each kind.
const SETPIECE_DENSITY := {
	&"rolling_downs": {&"escarpment": 0.05},
	&"ridge_and_pass": {&"big_ridge": 0.25},
	&"escarpment_country": {&"escarpment": 0.35, &"cleft": 0.10},
	&"terraced_valleys": {&"amphitheatre": 0.20},
	&"karst_hollows": {&"cleft": 0.15},
	&"tableland": {&"mesa": 0.30, &"cleft": 0.10},
	&"highland_massif": {&"hanging_valley": 0.20, &"big_ridge": 0.20},
	&"low_flats": {},
}

const SETPIECE_PARAMS := {
	&"escarpment": {"length_m": [400.0, 840.0], "rise_st": [2.0, 4.0], "face_m": [16.0, 32.0],
		"back_m": [120.0, 200.0]},
	&"amphitheatre": {"radius_m": [100.0, 240.0], "wall_st": [2.0, 4.0]},
	&"mesa": {"radius_m": [60.0, 200.0], "height_st": [3.0, 6.0], "face_m": [12.0, 24.0]},
	&"big_ridge": {"length_m": [500.0, 840.0], "height_st": [3.0, 5.0],
		"half_width_m": [40.0, 90.0], "pass_frac": [0.5, 0.75]},
	&"cleft": {"length_m": [200.0, 600.0], "slot_m": [24.0, 40.0], "shoulder_st": [2.0, 4.0],
		"shoulder_m": [60.0, 120.0]},
	&"hanging_valley": {"length_m": [300.0, 800.0], "trunk_half_m": [40.0, 80.0],
		"trunk_st": [3.0, 5.0], "trib_half_m": [16.0, 30.0], "lip_st": [2.0, 3.0]},
}


## Draw every parameter of spec for one key. Each parameter (or group) uses its
## own hash stream; *_m values are multiplied by scale.
static func draw(seed: int, key: Vector2i, salt: int, spec: Dictionary, scale: float) -> Dictionary:
	var out := {}
	for name: String in spec:
		var r: Array = spec[name]
		var group: String = String(r[2]) if r.size() > 2 else name
		var u := Helper._cell_hash01(seed + salt + (group.hash() & 0xFFFF), key.x, key.y)
		var v := lerpf(float(r[0]), float(r[1]), u)
		if name.ends_with("_m"):
			v *= scale
		out[name] = v
	return out


## Pick an archetype for biome weights with a uniform draw u in [0, 1).
static func choose(weights: Dictionary, u: float) -> StringName:
	var scores: Array[float] = []
	var total := 0.0
	for a: StringName in ARCHETYPES:
		var s := 0.0
		for biome: StringName in weights:
			var table: Dictionary = AFFINITY.get(biome, {})
			s += float(weights[biome]) * maxf(AFFINITY_FLOOR, float(table.get(a, 0.0)))
		scores.append(s)
		total += s
	var t := u * total
	for i in ARCHETYPES.size():
		t -= scores[i]
		if t < 0.0:
			return ARCHETYPES[i]
	return ARCHETYPES[ARCHETYPES.size() - 1]
