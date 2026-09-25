class_name VillageCirculationNode
extends RefCounted

## One semantic contact in the derived circulation graph. Door and terrain
## contacts stay distinct so a stair cannot be silently flattened into a path.
enum Kind {
	ARRIVAL,
	DOOR,
	TERRAIN_CONTACT,
}

var stable_key: StringName
var kind: Kind
var owner_key: StringName
var point: Vector2
var surface_y: float
var outward: Vector2


func _init(p_stable_key: StringName, p_kind: Kind, p_point: Vector2,
		p_surface_y: float, p_owner_key: StringName = &"",
		p_outward: Vector2 = Vector2.ZERO) -> void:
	stable_key = p_stable_key
	kind = p_kind
	owner_key = p_owner_key
	point = p_point
	surface_y = p_surface_y
	outward = p_outward


func is_valid() -> bool:
	return not stable_key.is_empty() and point.is_finite() \
		and is_finite(surface_y) and outward.is_finite() \
		and (kind != Kind.DOOR or outward.is_normalized())

