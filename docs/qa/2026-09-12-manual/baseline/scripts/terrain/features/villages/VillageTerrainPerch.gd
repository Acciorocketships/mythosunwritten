class_name VillageTerrainPerch
extends RefCounted

## One resource-free, immutable-by-convention building perch discovered from
## the final terrain field. A perch describes terrain opportunity only; later
## massing decides whether a building, retaining terrace, or public platform
## owns it.
enum SupportKind {
	NATURAL,
	RETAINED,
}

var candidate_key: StringName
var lattice_offset: Vector2i
var orientation_index: int
var anchor: Vector2
var yaw: float
var half_extents: Vector2
var floor_y: float
var minimum_y: float
var maximum_y: float
var relief: float
var support_ratio: float
var exposed_edge_mask: int
var support_kind: SupportKind
var distance_from_arrival: float
var structural_lift: float
## District-relative architectural band. Natural terrain perches retain -1;
## retained variants carry an exact half-level band chosen from the compiled
## vertical profile.
var architectural_band: int = -1

## Compact-neighbourhood facts are filled by VillageTerrainSurvey only after
## every individual candidate has been evaluated.
var neighbour_count: int = 0
var vertical_span: float = 0.0
var elevation_band_count: int = 0
var useful_relief_score: float = 0.0


func _init(p_candidate_key: StringName, p_lattice_offset: Vector2i,
		p_orientation_index: int, p_anchor: Vector2, p_yaw: float,
		p_half_extents: Vector2, p_floor_y: float, p_minimum_y: float,
		p_maximum_y: float, p_support_ratio: float,
		p_exposed_edge_mask: int, p_support_kind: SupportKind,
		p_distance_from_arrival: float, p_structural_lift: float = 0.0) -> void:
	candidate_key = p_candidate_key
	lattice_offset = p_lattice_offset
	orientation_index = p_orientation_index
	anchor = p_anchor
	yaw = p_yaw
	half_extents = p_half_extents
	floor_y = p_floor_y
	minimum_y = p_minimum_y
	maximum_y = p_maximum_y
	relief = p_maximum_y - p_minimum_y
	support_ratio = p_support_ratio
	exposed_edge_mask = p_exposed_edge_mask
	support_kind = p_support_kind
	distance_from_arrival = p_distance_from_arrival
	structural_lift = p_structural_lift


func is_valid() -> bool:
	return not candidate_key.is_empty() \
		and anchor.is_finite() and half_extents.is_finite() \
		and half_extents.x > 0.0 and half_extents.y > 0.0 \
		and is_finite(yaw) and is_finite(floor_y) \
		and is_finite(minimum_y) and is_finite(maximum_y) \
		and minimum_y <= maximum_y \
		and is_finite(relief) and relief >= 0.0 \
		and is_finite(support_ratio) \
		and support_ratio >= 0.0 and support_ratio <= 1.0 \
		and distance_from_arrival >= 0.0 \
		and is_finite(structural_lift) and structural_lift >= 0.0


func is_naturally_supported() -> bool:
	return support_kind == SupportKind.NATURAL
