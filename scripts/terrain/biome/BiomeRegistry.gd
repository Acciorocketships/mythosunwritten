# scripts/terrain/biome/BiomeRegistry.gd
# Profile lookup + pure blending helpers (unit-testable, no scene tree).
class_name BiomeRegistry
extends RefCounted

## Ground appearance has two orthogonal owners: the shared KayKit palette
## texture supplies the global base swatch, while this pure field supplies
## biome and world-patch multipliers. Keep the patches broad enough for the
## terrain's 24 m tint lattice to interpolate them without visible facets.
const GROUND_PATCH_SCALE := 108.0
const GROUND_PATCH_WARMTH_SCALE := 156.0
const GROUND_PATCH_VALUE_RANGE := Vector2(0.96, 1.04)
const GROUND_PATCH_WARMTH := 0.025

static var _profiles: Dictionary = {}

static func biome_ids() -> Array[StringName]:
	return Helper.BIOME_NAMES.duplicate()

static func max_foliage_density() -> float:
	_ensure()
	var maximum := 0.0
	for biome_id: StringName in Helper.BIOME_NAMES:
		maximum = maxf(maximum, (_profiles[biome_id] as BiomeProfile).foliage_density)
	return maximum

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

static func blended_ground_tint(w: Dictionary) -> Color:
	_ensure()
	var c := Color(0, 0, 0, 0)
	for name: StringName in w:
		c += (_profiles[name] as BiomeProfile).ground_tint * w[name]
	return c

## Canonical continuous ground multiplier for terrain, cliff dressing, and
## dense grass. Changing the palette texture changes their base colour at
## once; this field adds only deterministic, low-amplitude local variation.
static func ground_tint_at(pos: Vector3, world_seed: int) -> Color:
	var tint := blended_ground_tint(Helper.biome_weights5(pos, world_seed))
	return tint * ground_patch_tint(pos, world_seed)

static func ground_patch_tint(pos: Vector3, world_seed: int) -> Color:
	var value_noise := Helper._value_noise01(pos, world_seed + 83,
		GROUND_PATCH_SCALE)
	var warmth_noise := Helper._value_noise01(pos, world_seed + 89,
		GROUND_PATCH_WARMTH_SCALE)
	var value := lerpf(GROUND_PATCH_VALUE_RANGE.x,
		GROUND_PATCH_VALUE_RANGE.y, value_noise)
	var warmth := lerpf(-GROUND_PATCH_WARMTH,
		GROUND_PATCH_WARMTH, warmth_noise)
	return Color(value * (1.0 + warmth), value,
		value * (1.0 - warmth * 0.7), 1.0)

static func blended_foliage_tint(w: Dictionary, tag: String) -> Color:
	_ensure()
	var c := Color(0, 0, 0, 0)
	for name: StringName in w:
		var p: BiomeProfile = _profiles[name]
		c += (p.foliage_tints.get(tag, Color(1, 1, 1)) as Color) * w[name]
	return c

## Descriptor-driven tint lookup. Keeping the mapping here means placement
## code never guesses how a pack-specific asset should react to a biome.
static func blended_environment_tint(w: Dictionary, tint_group: StringName) -> Color:
	if tint_group == &"identity":
		return Color.WHITE
	if tint_group == &"ground":
		return blended_ground_tint(w)
	return blended_foliage_tint(w, String(tint_group))

static func _ensure() -> void:
	if not _profiles.is_empty():
		return
	for p: BiomeProfile in [_meadow(), _deep_forest(), _highland(), _blossom_grove(), _twilight_marsh()]:
		_profiles[p.biome_name] = p

static func _make(name: StringName) -> BiomeProfile:
	var p := BiomeProfile.new()
	p.biome_name = name
	return p

# The five profiles trade on DISTINCT hue + clarity, not just light-vs-dark, so
# each reads as a different place: bright-clear warm meadow, dark hazy green
# forest, cool crisp grey highland, dreamy PINK blossom, dark teal marsh.
# foliage_tints omit tags they don't tint — blended_foliage_tint falls back to
# white (identity), so only deliberate tints are listed.

static func _meadow() -> BiomeProfile:
	# Bright warm clear day — NO fog (owner: some biomes must be fog-free),
	# saturated warm green. fog_color stays: it still tints blends with foggy
	# neighbours at borders.
	var p := _make(&"meadow")
	p.fog_color = Color("d2ead9")
	p.fog_density = 0.0
	p.sky_top = Color("5cb3ea")            # bright saturated blue
	p.sky_horizon = Color("cdeaf6")
	p.ambient_color = Color(0.80, 0.76, 0.62)
	p.ambient_energy = 1.05
	# The atlas grass swatch is already strongly green. Keep meadow below 1.0
	# in value and lift its blue relative to green; the former >1 boost clipped
	# into a flat neon field under the clear biome's bright daylight.
	p.ground_tint = Color(0.72, 0.66, 1.0)
	p.foliage_tints = {"grass": Color(1.1, 1.05, 0.75), "tree": Color(1.02, 1.0, 0.9)}
	p.foliage_density = 0.8
	p.particles = {&"motes": 0.3}
	return p

static func _deep_forest() -> BiomeProfile:
	# Dark shaded woods — dense teal-green haze, saturated dark green.
	var p := _make(&"deep_forest")
	p.fog_color = Color("3d6b50")
	p.fog_density = 0.006
	p.pocket_fog_density = 0.02
	p.sky_top = Color("4f7a6a")            # muted green-grey, low
	p.sky_horizon = Color("7ba28d")
	p.ambient_color = Color(0.38, 0.50, 0.40)
	p.ambient_energy = 0.62
	p.ground_tint = Color(0.48, 0.72, 0.46)   # deep saturated green
	p.foliage_tints = {"grass": Color(0.55, 0.78, 0.52), "bush": Color(0.5, 0.72, 0.5),
			"tree": Color(0.55, 0.78, 0.58), "rock": Color(0.8, 0.88, 0.82)}
	p.foliage_density = 1.9
	p.particles = {&"fireflies": 0.4}
	return p

static func _highland() -> BiomeProfile:
	# Cold windswept rock — crisp and truly fog-free, cool blue-grey, desaturated.
	var p := _make(&"highland")
	p.fog_color = Color("b6c6d6")
	p.fog_density = 0.0
	p.sky_top = Color("6f9cc6")            # cool clear blue-grey
	p.sky_horizon = Color("c2d6e6")
	p.ambient_color = Color(0.62, 0.67, 0.74)   # cool
	p.ambient_energy = 1.0
	p.ground_tint = Color(0.80, 0.86, 0.86)     # desaturated cool grey-green
	p.foliage_tints = {"grass": Color(0.82, 0.88, 0.8), "bush": Color(0.78, 0.84, 0.78),
			"tree": Color(0.78, 0.86, 0.82)}
	p.foliage_density = 1.2
	p.particles = {&"motes": 0.2}
	return p

static func _blossom_grove() -> BiomeProfile:
	# Dreamy pink pocket — pink sky + fog (NOT blue), soft haze, pink canopies.
	var p := _make(&"blossom_grove")
	p.fog_color = Color("f4c9dd")
	p.fog_density = 0.0022
	p.sky_top = Color("e2add2")            # pink-lavender, not blue
	p.sky_horizon = Color("f9d8ea")
	p.ambient_color = Color(0.84, 0.66, 0.74)   # pink-warm
	p.ambient_energy = 0.95
	p.ground_tint = Color(1.08, 0.9, 0.94)      # pinkish
	p.foliage_tints = {"grass": Color(1.02, 0.92, 0.86), "bush": Color(1.1, 0.8, 0.95),
			"tree": Color(1.45, 0.78, 1.05)}     # strongly pink canopies
	p.foliage_density = 1.1
	p.particles = {&"petals": 0.6}
	return p

static func _twilight_marsh() -> BiomeProfile:
	# Dark eerie hollow — dense dark teal fog, indigo sky, glowing orbs.
	var p := _make(&"twilight_marsh")
	p.fog_color = Color("1f4a58")
	p.fog_density = 0.014
	p.pocket_fog_density = 0.06
	p.sky_top = Color("232d52")
	p.sky_horizon = Color("1f4a58")
	p.ambient_color = Color(0.28, 0.34, 0.45)
	p.ambient_energy = 0.5
	p.ground_tint = Color(0.42, 0.58, 0.55)
	p.foliage_tints = {"grass": Color(0.38, 0.58, 0.53), "bush": Color(0.33, 0.53, 0.48),
			"tree": Color(0.38, 0.53, 0.48), "rock": Color(0.65, 0.78, 0.78)}
	p.foliage_density = 0.9
	p.particles = {&"orbs": 0.5, &"fireflies": 0.8}
	return p
