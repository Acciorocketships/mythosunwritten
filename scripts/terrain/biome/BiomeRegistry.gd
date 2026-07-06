# scripts/terrain/biome/BiomeRegistry.gd
# Profile lookup + pure blending helpers (unit-testable, no scene tree).
class_name BiomeRegistry
extends RefCounted

static var _profiles: Dictionary = {}

static func profile(name: StringName) -> BiomeProfile:
	_ensure()
	return _profiles.get(name)

static func blend_atmosphere(w: Dictionary) -> Dictionary:
	_ensure()
	var fog := Color(0, 0, 0, 0)
	var sky_t := Color(0, 0, 0, 0)
	var sky_h := Color(0, 0, 0, 0)
	var amb := Color(0, 0, 0, 0)
	var fd := 0.0
	var ae := 0.0
	for name: StringName in w:
		var p: BiomeProfile = _profiles[name]
		var k: float = w[name]
		fog += p.fog_color * k
		sky_t += p.sky_top * k
		sky_h += p.sky_horizon * k
		amb += p.ambient_color * k
		fd += p.fog_density * k
		ae += p.ambient_energy * k
	return {&"fog_color": fog, &"fog_density": fd, &"sky_top": sky_t,
			&"sky_horizon": sky_h, &"ambient_color": amb, &"ambient_energy": ae}

static func blended_density(w: Dictionary) -> float:
	_ensure()
	var d := 0.0
	for name: StringName in w:
		d += (_profiles[name] as BiomeProfile).foliage_density * w[name]
	return d

static func blended_tag_weights(w: Dictionary) -> Dictionary:
	_ensure()
	var out: Dictionary = {}
	for name: StringName in w:
		var p: BiomeProfile = _profiles[name]
		for tag: String in p.tag_weights:
			out[tag] = out.get(tag, 0.0) + p.tag_weights[tag] * w[name]
	return out

static func blended_ground_tint(w: Dictionary) -> Color:
	_ensure()
	var c := Color(0, 0, 0, 0)
	for name: StringName in w:
		c += (_profiles[name] as BiomeProfile).ground_tint * w[name]
	return c

static func blended_foliage_tint(w: Dictionary, tag: String) -> Color:
	_ensure()
	var c := Color(0, 0, 0, 0)
	for name: StringName in w:
		var p: BiomeProfile = _profiles[name]
		c += (p.foliage_tints.get(tag, Color(1, 1, 1)) as Color) * w[name]
	return c

static func _ensure() -> void:
	if not _profiles.is_empty():
		return
	for p: BiomeProfile in [_meadow(), _deep_forest(), _highland(), _blossom_grove(), _twilight_marsh()]:
		_profiles[p.biome_name] = p

static func _make(name: StringName) -> BiomeProfile:
	var p := BiomeProfile.new()
	p.biome_name = name
	return p

static func _meadow() -> BiomeProfile:
	var p := _make(&"meadow")
	p.fog_color = Color("dcebdd")
	p.fog_density = 0.0008
	p.sky_top = Color("8ec9e8")
	p.sky_horizon = Color("d7e8f2")
	p.ambient_color = Color(0.72, 0.70, 0.62)
	p.ambient_energy = 0.9
	p.ground_tint = Color(1.05, 1.0, 0.85)
	p.foliage_tints = {"grass": Color(1.05, 1.0, 0.8), "bush": Color(1.0, 1.0, 0.9),
			"tree": Color(1.0, 1.0, 0.95), "rock": Color(1, 1, 1)}
	p.foliage_density = 0.8
	p.tag_weights = {"grass": 0.45, "rock": 0.1, "bush": 0.2, "tree": 0.15}
	p.particles = {&"motes": 0.3}
	return p

static func _deep_forest() -> BiomeProfile:
	var p := _make(&"deep_forest")
	p.fog_color = Color("557567")
	p.fog_density = 0.004
	p.pocket_fog_density = 0.015
	p.sky_top = Color("6e93a8")
	p.sky_horizon = Color("87a5ad")
	p.ambient_color = Color(0.45, 0.52, 0.48)
	p.ambient_energy = 0.7
	p.ground_tint = Color(0.55, 0.75, 0.55)
	p.foliage_tints = {"grass": Color(0.6, 0.8, 0.6), "bush": Color(0.55, 0.75, 0.55),
			"tree": Color(0.6, 0.8, 0.62), "rock": Color(0.85, 0.9, 0.85)}
	p.foliage_density = 1.9
	p.tag_weights = {"grass": 0.15, "rock": 0.08, "bush": 0.22, "tree": 0.55}
	p.particles = {&"fireflies": 0.4}
	return p

static func _highland() -> BiomeProfile:
	var p := _make(&"highland")
	p.fog_color = Color("c2ccc9")
	p.fog_density = 0.0015
	p.sky_top = Color("a8bcc8")
	p.sky_horizon = Color("ccd6da")
	p.ambient_color = Color(0.60, 0.63, 0.60)
	p.ambient_energy = 0.85
	p.ground_tint = Color(0.85, 0.9, 0.8)
	p.foliage_tints = {"grass": Color(0.85, 0.9, 0.75), "bush": Color(0.8, 0.85, 0.72),
			"tree": Color(0.8, 0.88, 0.78), "rock": Color(1, 1, 1)}
	p.foliage_density = 1.2
	p.tag_weights = {"grass": 0.2, "rock": 0.45, "bush": 0.12, "tree": 0.08,
			"standing_stone": 0.03}
	p.particles = {&"motes": 0.2}
	return p

static func _blossom_grove() -> BiomeProfile:
	var p := _make(&"blossom_grove")
	p.fog_color = Color("f2dce8")
	p.fog_density = 0.0015
	p.sky_top = Color("c8d8f0")
	p.sky_horizon = Color("ecdce8")
	p.ambient_color = Color(0.75, 0.68, 0.70)
	p.ambient_energy = 0.9
	p.ground_tint = Color(1.0, 0.95, 0.9)
	p.foliage_tints = {"grass": Color(1.0, 0.95, 0.85), "bush": Color(1.05, 0.85, 0.95),
			"tree": Color(1.35, 0.85, 1.05), "rock": Color(1, 1, 1)}
	p.foliage_density = 1.1
	p.tag_weights = {"grass": 0.3, "rock": 0.05, "bush": 0.15, "tree": 0.45}
	p.particles = {&"petals": 0.6}
	return p

static func _twilight_marsh() -> BiomeProfile:
	var p := _make(&"twilight_marsh")
	p.fog_color = Color("24505c")
	p.fog_density = 0.012
	p.pocket_fog_density = 0.06
	p.sky_top = Color("2a3560")
	p.sky_horizon = Color("24505c")
	p.ambient_color = Color(0.30, 0.35, 0.45)
	p.ambient_energy = 0.55
	p.ground_tint = Color(0.45, 0.6, 0.55)
	p.foliage_tints = {"grass": Color(0.4, 0.6, 0.55), "bush": Color(0.35, 0.55, 0.5),
			"tree": Color(0.4, 0.55, 0.5), "rock": Color(0.7, 0.8, 0.8)}
	p.foliage_density = 0.9
	p.tag_weights = {"grass": 0.35, "rock": 0.08, "bush": 0.3, "tree": 0.1, "lantern": 0.02}
	p.particles = {&"orbs": 0.5, &"fireflies": 0.8}
	return p
