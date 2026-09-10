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
	for p: BiomeProfile in [_meadow(), _deep_forest(), _highland(), _blossom_grove(), _twilight_marsh(), _amber_heath(), _jade_wetlands()]:
		_profiles[p.biome_name] = p

static func _make(name: StringName) -> BiomeProfile:
	var p := BiomeProfile.new()
	p.biome_name = name
	return p

# Stable IDs retain save/content compatibility; these are rebuilt art directions.
static func _art(id: StringName, title: String, ground: Color, tree: Color,
		fog: Color, density: float, foliage: float, water: Color, particles: Dictionary) -> BiomeProfile:
	var p := _make(id)
	p.display_name = title
	p.ground_tint = ground
	# Bush hue replacement consumes an absolute colour, not the source-atlas
	# multiplier used by ground_tint (which can exceed 1 and shift the hue).
	var bush_ground: Color = SUBSTRATES[id]
	p.foliage_tints = {"tree": tree, "bush": tree.lerp(bush_ground, 0.35),
		"grass": ground.lerp(Color.WHITE, 0.35), "rock": ground.lerp(Color.WHITE, 0.7)}
	p.fog_color = fog
	p.fog_density = density
	p.pocket_fog_density = density
	p.sky_top = Color("718fab")
	p.sky_horizon = Color("efdbc2")
	p.ambient_color = Color("c2d5e4")
	p.ambient_energy = 0.7
	p.foliage_density = foliage
	p.water_tint = water
	p.particles = particles
	return p

static func _meadow() -> BiomeProfile:
	return _art(&"meadow", "Sunwash Meadows", Color(0.82, 0.72, 1.04),
		Color(0.63, 0.78, 0.34), Color("d9debe"), 0.0, 0.8,
		Color("88cabb"), {&"motes": 0.45})

static func _deep_forest() -> BiomeProfile:
	return _art(&"deep_forest", "Lanternwood", Color(0.34, 0.48, 0.70),
		Color(0.16, 0.36, 0.38), Color("477c80"), 0.012, 1.9,
		Color("528c9c"), {&"fireflies": 1.2, &"orbs": 0.25})

static func _highland() -> BiomeProfile:
	return _art(&"highland", "Opal Highlands", Color(1.10, 0.77, 1.95),
		Color(0.48, 0.62, 0.68), Color("a8baca"), 0.0, 0.9,
		Color("91c6d6"), {&"motes": 0.25})

static func _blossom_grove() -> BiomeProfile:
	return _art(&"blossom_grove", "Cherryveil", Color(0.98, 0.68, 1.65),
		Color(1.0, 0.53, 0.72), Color("ddb3c9"), 0.004, 1.25,
		Color("94cbd2"), {&"petals": 1.6, &"motes": 0.3})

static func _twilight_marsh() -> BiomeProfile:
	return _art(&"twilight_marsh", "Moonfen", Color(0.40, 0.46, 1.28),
		Color(0.20, 0.31, 0.48), Color("365569"), 0.018, 0.95,
		Color("597eaa"), {&"orbs": 0.75, &"fireflies": 1.5})

static func _amber_heath() -> BiomeProfile:
	return _art(&"amber_heath", "Amber Heath", Color(1.30, 0.70, 0.90),
		Color(1.0, 0.54, 0.19), Color("cdb295"), 0.001, 0.8,
		Color("83b6ad"), {&"leaves": 0.9, &"motes": 0.45})

static func _jade_wetlands() -> BiomeProfile:
	return _art(&"jade_wetlands", "Jade Estuary", Color(0.61, 0.77, 1.05),
		Color(0.33, 0.70, 0.55), Color("8abfb8"), 0.006, 1.1,
		Color("65bbae"), {&"fireflies": 0.6, &"motes": 0.25})

static func local_atmosphere(pos: Vector3, world_seed: int) -> Color:
	# RGB is scattering colour, alpha is extinction per metre. No observer input.
	var w := Helper.biome_weights5(pos, world_seed)
	var blend := blend_atmosphere(w)
	var fog: Color = blend[&"fog_color"]
	fog.a = blend[&"fog_density"]
	return fog

static func water_tint_at(pos: Vector3, world_seed: int) -> Color:
	_ensure()
	var tint := Color(0, 0, 0, 0)
	var weights := Helper.biome_weights5(pos, world_seed)
	for id: StringName in weights:
		tint += (_profiles[id] as BiomeProfile).water_tint.srgb_to_linear() * weights[id]
	return tint

# Actual substrate colours (sRGB), independent of the source atlas hue. All
# ground and grass renderers sample this one field through BiomeGroundMap.
const SUBSTRATES := {
	&"meadow": Color("899e59"), &"deep_forest": Color("456a63"),
	&"highland": Color("a7aaa9"), &"blossom_grove": Color("99907f"),
	&"twilight_marsh": Color("4c647a"), &"amber_heath": Color("b69859"),
	&"jade_wetlands": Color("678e82"),
}
static func substrate_color(weights: Dictionary) -> Color:
	var color := Color(0, 0, 0, 0)
	for id: StringName in weights:
		color += (SUBSTRATES[id] as Color).srgb_to_linear() * weights[id]
	return color
