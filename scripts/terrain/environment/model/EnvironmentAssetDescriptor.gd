class_name EnvironmentAssetDescriptor
extends Resource

## Lightweight generated metadata. Gameplay meaning belongs to the consumer,
## not to this shared visual catalogue.
@export var id: StringName
@export_file("*.tres", "*.res") var visual_path: String
@export var tags: Array[StringName] = []
@export var measured_aabb: AABB
@export var collision_piece_count: int = 0
@export var tint_group: StringName
@export var supports_instance_color: bool = false
@export var provenance_id: StringName
