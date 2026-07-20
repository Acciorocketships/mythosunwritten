# scripts/terrain/biome/BiomeProfile.gd
# Everything downstream reads about one biome: atmosphere, palette, scatter,
# particles. Constructed in code by BiomeRegistry (spec deviation: no .tres
# files until editor tuning is wanted — same schema).
class_name BiomeProfile
extends Resource

@export var biome_name: StringName
# atmosphere
@export var fog_color: Color
@export var fog_density: float
@export var pocket_fog_density: float = 0.0   # >0 ⇒ chunk FogVolumes when dominant
@export var sky_top: Color
@export var sky_horizon: Color
@export var ambient_color: Color
@export var ambient_energy: float = 1.0
# palette — MULTIPLIERS over the shared KayKit grass texel, not absolute colors
@export var ground_tint: Color
@export var foliage_tints: Dictionary = {}    # tag (String) → Color multiplier
# scatter
@export var foliage_density: float = 1.0
# particles: recipe → density (marsh carries two: orbs + fireflies)
@export var particles: Dictionary = {}        # StringName → float
