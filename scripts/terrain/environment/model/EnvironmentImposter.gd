class_name EnvironmentImposter
extends Resource

## Baked distant-tree card set: `frames` azimuth views side by side in each atlas.
@export var albedo: Texture2D            # RGB albedo under white instance tint, A coverage
@export var normal: Texture2D            # RGB view-space normal * 0.5 + 0.5, A tint response
@export var frames: int = 8
@export var size: Vector2 = Vector2.ONE  # world metres covered by one frame (width, height)
@export var pivot_height: float = 0.0    # metres from the asset origin to the frame's bottom edge
@export var crown_centre: Vector3 = Vector3.ZERO
