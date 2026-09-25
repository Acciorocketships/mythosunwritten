class_name VillageTimberCell
extends RefCounted

## One fixed, walk-bearing timber floor module. Kind is audit metadata only;
## geometry and materialization are shared by skirts, public platforms, and
## short aerial streets.
enum Kind {
	SKIRT,
	PLATFORM,
	WALKWAY,
}

var stable_id: StringName
var owner_id: StringName
var kind: Kind
var centre: Vector2
var floor_y: float
var yaw: float
var under_building: bool


func _init(p_stable_id: StringName, p_owner_id: StringName, p_kind: Kind,
		p_centre: Vector2, p_floor_y: float, p_yaw: float,
		p_under_building: bool = false) -> void:
	assert(not p_stable_id.is_empty() and not p_owner_id.is_empty())
	assert(p_centre.is_finite() and is_finite(p_floor_y) and is_finite(p_yaw))
	stable_id = p_stable_id
	owner_id = p_owner_id
	kind = p_kind
	centre = p_centre
	floor_y = p_floor_y
	yaw = p_yaw
	under_building = p_under_building


func shape() -> FeatureGroundShape:
	return FeatureGroundShape.oriented_rect(centre,
		Vector2.ONE * VillageProgram.MODULE * 0.5, yaw)
