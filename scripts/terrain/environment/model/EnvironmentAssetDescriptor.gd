class_name EnvironmentAssetDescriptor
extends Resource

## Lightweight generated metadata. Gameplay meaning belongs to the consumer,
## not to this shared visual catalogue.
@export var id: StringName
@export_file("*.tres", "*.res") var visual_path: String
@export var tags: Array[StringName] = []
@export var measured_aabb: AABB
## Lightweight XZ samples of the authored geometry that actually reaches its
## ground datum. Structural planners use this instead of treating roofs/eaves'
## full visual AABB as a foundation. Generated only for assets tagged building.
@export var ground_contact_points: PackedVector2Array = PackedVector2Array()
@export var collision_piece_count: int = 0
@export var tint_group: StringName
@export var supports_instance_color: bool = false
@export var provenance_id: StringName
