class_name EnvironmentImposter
extends Resource

## Baked distant-tree card set: `frames` azimuth views side by side in each atlas.
@export var albedo: Texture2D            # RGB albedo under white instance tint, A coverage
## RGB: normal * 0.5 + 0.5 in frame f's basis (a = TAU * f / frames): x = frame right
## (cos a, 0, -sin a), y = world up, z = toward the capture eye (sin a, 0, cos a). A: tint response.
@export var normal: Texture2D
@export var frames: int = 8
@export var size: Vector2 = Vector2.ONE  # world metres covered by one frame (width, height)
@export var pivot_height: float = 0.0    # metres from the asset origin to the frame's bottom edge (frames are centred on the asset's vertical axis)
@export var crown_centre: Vector3 = Vector3.ZERO
