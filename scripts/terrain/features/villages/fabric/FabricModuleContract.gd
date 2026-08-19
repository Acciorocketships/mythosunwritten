class_name FabricModuleContract
extends RefCounted

## Resource-free construction facts compiled from one reviewed runtime asset.
## Layout code consumes these contracts instead of knowing source pivots, mesh
## extents, roof pitches, or material families.
enum Kind {
	GENERIC,
	WALK_SURFACE,
	ROOF_REPEAT,
	ROOF_END,
	PREFAB,
	STAIR_SWITCHBACK,
}

var asset_id: StringName
var kind: Kind
var visual_bounds := AABB()
var walk_surface_y := 0.0
var repeat_axis := Vector3i.ZERO
var repeat_pitch := 0.0
## Gabled roofs use one authored slope on each side of the ridge. Keeping the
## transverse axis and offset in the contract prevents recipes from knowing an
## imported mesh pivot or mirroring an asset with forbidden negative scale.
var pair_axis := Vector3i.ZERO
var pair_offset := 0.0
var seam_profile: StringName
var material_family: StringName
var visual_clearance := 0.0
## Authored tread planes exclude handrails/posts from their vertical datums.
## A switchback may therefore seal above its high walking surface.
var stair_low_tread_y := 0.0
var stair_high_tread_y := 0.0
var _sealed := false
var last_rejection := ""


func _init(p_asset_id: StringName, p_kind: Kind, p_visual_bounds: AABB) -> void:
	asset_id = p_asset_id
	kind = p_kind
	visual_bounds = p_visual_bounds


func seal() -> bool:
	last_rejection = ""
	if _sealed or asset_id.is_empty() or not visual_bounds.has_volume() \
			or not visual_bounds.position.is_finite() \
			or not visual_bounds.size.is_finite() or visual_clearance < 0.0:
		last_rejection = "missing asset id or finite visual bounds"
		return false
	match kind:
		Kind.WALK_SURFACE:
			walk_surface_y = visual_bounds.end.y
		Kind.ROOF_REPEAT:
			if absi(repeat_axis.x) + absi(repeat_axis.y) \
					+ absi(repeat_axis.z) != 1 or repeat_axis.y != 0 \
					or absi(pair_axis.x) + absi(pair_axis.y) \
					+ absi(pair_axis.z) != 1 or pair_axis.y != 0 \
					or repeat_axis.x * pair_axis.x \
					+ repeat_axis.z * pair_axis.z != 0 or pair_offset <= 0.0 \
					or repeat_pitch <= 0.0 or seam_profile.is_empty() \
					or material_family.is_empty():
				last_rejection = "roof repeat lacks axis, pitch, seam, or material"
				return false
		Kind.ROOF_END:
			if seam_profile.is_empty():
				last_rejection = "roof end lacks a seam profile"
				return false
		Kind.STAIR_SWITCHBACK:
			if stair_high_tread_y <= stair_low_tread_y \
					or stair_low_tread_y < visual_bounds.position.y - 0.001 \
					or stair_high_tread_y > visual_bounds.end.y + 0.001:
				last_rejection = "switchback stair lacks measured tread planes"
				return false
	_sealed = true
	return true


func is_sealed() -> bool:
	return _sealed


func clearance_bounds() -> AABB:
	if visual_clearance <= 0.0:
		return visual_bounds
	var margin := Vector3(visual_clearance, 0.0, visual_clearance)
	return AABB(visual_bounds.position - margin,
		visual_bounds.size + margin * 2.0)
