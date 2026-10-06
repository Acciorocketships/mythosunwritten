class_name BuildingKit
extends RefCounted

## Resource-free description of one modular building asset pack.
##
## A kit states its native metric and maps pack-agnostic ROLES to baked catalog
## asset ids. `BuildingKitAssembler` realizes a `BuildingMass` purely through
## these roles, so any pack that can express them (or a union of several packs)
## can build the same planned architecture. A role a kit does not provide simply
## makes the designer skip that feature.
##
## Canonical piece convention (every role): the piece's pivot sits on the
## face/row line it closes, native +Z points OUTWARD from the building (or down
## the roof slope), +Y is up, and one module spans local x in [-w/2, w/2].
## Kits whose source assets use another convention publish per-role
## `anchors` (a native Transform3D applied before placement).

## Native metres per module cell (horizontal).
var module_width := 2.0
## Native metres per storey; one planner storey is two bands.
var storey_height := 3.0
## Native plinth course below the ground storey (0 = none).
var plinth_height := 0.0
## Native rise of one full roof slope row over one module of run.
var roof_row_rise := 3.0
## Native rise of the central ridge-top row used by odd-depth roofs.
var roof_top_rise := 1.5
## Ridge pivot lift above the even/odd nominal roof peak.
var roof_ridge_lift := Vector2(0.3, 0.19)
## Measured ridge cap top above its authored pivot, after kit anchors.
## Clearance includes this ornament; slope height alone is not the roof top.
var roof_ridge_head := 0.0
## A retracted complete eave course stops at its original upper row joint.
## Otherwise its shifted backing can emerge through the opposite ridge slope.
var tight_eave_joint_clip := false
## Native strips occupy whole bays; separate caps sit on the end walls.
## False retains kits whose regular strips are centred on bay boundaries.
var roof_edge_caps := false
## Native X bounds of separate authored roof end caps. When a verge is
## shortened, move the complete closure inward rather than slicing it off.
var roof_cap_x_bounds: Dictionary = {}
## Outward reach of complete native ridge Start/End caps, in metres.
var ridge_cap_reach := Vector2.ZERO
## Native outward projection of a jetty (upper storey beyond the one below).
var jetty_depth := 0.0
## Native outward distance from a wall piece's pivot line to its outer face.
var wall_face := 0.0
## Half thickness of the barge board across its roof-end plane.
var barge_half_depth := 0.0
## Extra native thickness the storey masonry (`wall.stone.plain/window/door`)
## carries in front of the timber wall plane: its openings sit that much
## deeper and the stone storey stands that much proud of timber above.
## Retaining courses (`wall.stone.retaining`, `wall.stone.course`) stay flush.
var masonry_depth := 0.0
## Measured bottom-centred native gate header and crown overlap under its cap.
var gate_arch_size := Vector3.ZERO
var gate_arch_cap_lap := 0.0
## Complete supported bay/spire envelope, relative to its window placement.
var oriel_bounds := AABB()
## The `awning` role's canonical size after its anchor: exactly
## `awning_width` modules wide, centred on x = 0, its back posts at z = 0 and
## `awning_depth` / `awning_height` native metres deep / tall before fitting.
## Half width of the `post.timber` role (native metres), used to close
## convex wall corners flush with both outer faces.
var corner_post_half := 0.0
var awning_width := 1.0
var awning_depth := 0.0
var awning_height := 0.0
var kit_id: StringName = &""
## Worker-readable baked roof triangles. The kit owns its geometry authority;
## roof union never loads source scenes or assumes an asset-pack path.
var roof_geometry_path := ""
## Native Pure Village roof family; chosen once per merged building.
var roof_palette: StringName = &"blue"
var frame_palette: StringName = &"native"
## Material-only variants share these canonical worker triangles.
var geometry_aliases: Dictionary = {}
## role (StringName) -> Array[StringName] of interchangeable asset ids.
var roles: Dictionary = {}
## role -> Transform3D correction applied in native piece space.
var anchors: Dictionary = {}
## asset id -> Transform3D correction for variants of one role whose pivots
## differ (applied after the role anchor).
var asset_anchors: Dictionary = {}


func has_role(role: StringName) -> bool:
	return roles.has(role) and not (roles[role] as Array).is_empty()


## Deterministic variant choice. `pick` is any stable hash.
func asset(role: StringName, pick: int = 0) -> StringName:
	var options: Array = roles.get(role, [])
	if options.is_empty():
		return &""
	return options[posmod(pick, options.size())]


func anchor(role: StringName) -> Transform3D:
	return anchors.get(role, Transform3D.IDENTITY)


func asset_anchor(asset_id: StringName) -> Transform3D:
	return asset_anchors.get(asset_id, Transform3D.IDENTITY)


## Outer-face distance of a storey wall of `material` (see masonry_depth).
func face_of(material: StringName, retaining := false) -> float:
	return wall_face + (masonry_depth if material == BuildingMass.MATERIAL_STONE \
		and not retaining else 0.0)


func band_height() -> float:
	return storey_height * 0.5


func all_asset_ids() -> Array[StringName]:
	var seen: Dictionary = {}
	for options: Array in roles.values():
		for id: StringName in options:
			seen[id] = true
	var out: Array[StringName] = []
	out.assign(KitVillageBuildings.sorted_ids(seen.keys()))
	return out


## Row count per side and whether a ridge-top row is needed for a roof of
## `depth` modules. Shared by the assembler and by clearance planning so a
## designer can reserve the exact roof envelope before choosing it.
func roof_profile(depth: int) -> Dictionary:
	var rows := depth / 2
	var top := depth % 2 == 1
	var height := float(rows) * roof_row_rise + (roof_top_rise if top else 0.0)
	return {"rows": rows, "top": top, "height": height}


func roof_clearance_height(depth: int) -> float:
	var profile := roof_profile(depth)
	var lift := roof_ridge_lift.y if bool(profile.top) else roof_ridge_lift.x
	return float(profile.height) + maxf(0.0, lift + roof_ridge_head)
