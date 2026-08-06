class_name SupportModule
extends RefCounted

## Compiled resource-free dimensions for one fixed collision-bearing support.
var asset_id: StringName
var height: float
var half_extents: Vector2
var local_bottom_y: float
## Optional reviewed planning stencil for compound supports. A trestle can
## reserve its actual frames instead of one solid box around all empty space.
var solid_stencil: Array[Dictionary] = []

func _init(p_asset_id: StringName, p_height: float,
		p_half_extents: Vector2, p_local_bottom_y: float = NAN,
		p_solid_stencil: Array[Dictionary] = []) -> void:
	assert(not p_asset_id.is_empty())
	assert(is_finite(p_height) and p_height > 0.0)
	assert(p_half_extents.x > 0.0 and p_half_extents.y > 0.0)
	asset_id = p_asset_id
	height = p_height
	half_extents = p_half_extents
	local_bottom_y = p_local_bottom_y if is_finite(p_local_bottom_y) \
		else -p_height * 0.5
	for entry: Dictionary in p_solid_stencil:
		var offset: Vector2 = entry.get("offset", Vector2(INF, INF))
		var extents: Vector2 = entry.get("half_extents", Vector2.ZERO)
		assert(offset.is_finite() and extents.x > 0.0 and extents.y > 0.0)
		solid_stencil.append({"offset": offset, "half_extents": extents})
	if solid_stencil.is_empty():
		solid_stencil.append({"offset": Vector2.ZERO,
			"half_extents": half_extents})
