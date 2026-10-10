extends Resource
## Art controls shared by the renderer; changes blend while crossing biomes.
@export var biome: StringName
@export_range(0.0, 0.02, 0.0001) var volumetric_density := 0.001
@export_range(0.0, 1.0) var fog_anisotropy := 0.55
@export_range(0.0, 0.3) var bloom := 0.035
@export_range(0.5, 3.0) var glow_threshold := 1.1
@export_range(0.5, 1.5) var saturation := 1.12
@export_range(0.5, 1.5) var contrast := 1.04
@export_range(0.5, 1.5) var exposure := 1.0
@export_range(0.0, 1.0) var shadow_opacity := 0.88

## Keep local scattering inside the detailed shadow range in wooded biomes.
## Sky affect is separate so thicker ground mist does not bleach the sky.
@export_range(32.0, 192.0) var fog_length := 96.0
@export_range(0.0, 1.0) var fog_sky_affect := 0.15
@export_range(0.0, 1.0) var fog_ambient_inject := 0.15
@export_range(0.0, 4.0) var shadow_blur := 1.5
