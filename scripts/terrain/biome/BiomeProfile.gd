# scripts/terrain/biome/BiomeProfile.gd
# Everything downstream reads about one biome: atmosphere, palette, scatter,
# particles. Constructed in code by BiomeRegistry (spec deviation: no .tres
# files until editor tuning is wanted — same schema).
class_name BiomeProfile
extends Resource

@export var biome_name: StringName
@export var display_name: String
@export var water_tint: Color = Color.WHITE
# atmosphere
@export var fog_color: Color
@export var fog_density: float
@export var pocket_fog_density: float = 0.0   # >0 ⇒ chunk FogVolumes when dominant
@export var sky_top: Color
@export var sky_horizon: Color
@export var ambient_color: Color
@export var ambient_energy: float = 1.0
@export var sun_color: Color = Color.WHITE
@export var sun_energy: float = 1.2
@export var glow_intensity: float = 0.8
# Local mist: metres above the terrain/water surface, independent of the viewer.
@export var mist_height: float = 4.5
@export var mist_upper_height: float = 22.0
@export var mist_upper_weight: float = 0.16
@export var mist_emission: float = 0.6
@export var haze_density: float = 0.0003
@export var sun_scattering: float = 1.1
@export_range(0.0, 1.0) var surface_dampness: float = 0.0
@export_range(0.0, 0.5) var foliage_transmission: float = 0.12
# palette — MULTIPLIERS over the shared KayKit grass texel, not absolute colors
@export var ground_tint: Color
@export var foliage_tints: Dictionary = {}    # tag (String) → Color multiplier
# scatter
@export var foliage_density: float = 1.0
# particles: recipe → density (marsh carries two: orbs + fireflies)
@export var particles: Dictionary = {}        # StringName → float
