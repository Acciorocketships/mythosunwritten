class_name DressingChoice
extends Resource

@export var asset_id: StringName
@export var weight: float = 1.0
@export var biome_affinity: Dictionary = {}
## Authored stature tier for this visual species. DressingSet.scale_range is
## still the small natural variation around this canonical multiplier.
@export var scale_multiplier: float = 1.0
## Optional species footprint. Zero inherits the set radius; large-canopy
## landmark trees can reserve more room without spacing every shrub that far.
@export var spacing_radius: float = 0.0
