class_name VillageAssetSpec
extends RefCounted

## Resource-free, reviewed structural facts. Source-pack paths and render
## resources stay in the bake; planning sees only stable IDs and measurements.
enum Role {
	HOUSE,
	CIVIC,
	SHELTER,
	MARKET,
}

## Semantic role never determines construction behavior. These orthogonal
## authored contracts let future kiosks, open workshops, raised shelters, and
## other families compose without adding role-specific planner branches.
enum AccessKind {
	ENTERABLE,
	SERVICE_FRONT,
}

enum FoundationKind {
	NONE,
	PERIMETER,
}

enum VerticalPolicy {
	GROUND_ONLY,
	STACKABLE,
}

## The doorway physics contract crosses this far past the authored entrance.
## Keeping the value beside the reviewed metric makes planning validation and
## the runtime collision probe describe the same point.
const ENTRANCE_INTERIOR_DEPTH := 1.25

var asset_id: StringName
var role: Role
var access_kind: AccessKind
var foundation_kind: FoundationKind
var vertical_policy: VerticalPolicy
var enclosed_interior: bool
var measured_aabb: AABB
## These are deliberately distinct. Whole visual bounds include roofs/eaves;
## lot clearance adds breathing room; the reviewed ground contact is the only
## footprint permitted to raise a floor or request foundation modules.
var solid_local_rect: Rect2
var lot_local_rect: Rect2
var ground_contact_local_rect: Rect2
var interior_local_rect: Rect2
var entrance_local: Vector2
var entrance_outward: Vector2
var entrance_floor_local_y: float
var permitted_tiers: Array[StringName] = []
var theme_asset_ids: Dictionary = {}
var attachments: Array[VillageAttachedAssetSpec] = []
var max_ground_relief: float
var lot_padding: float

static func compile(data: Dictionary, catalog: EnvironmentCatalog) -> VillageAssetSpec:
	var spec := VillageAssetSpec.new()
	spec.asset_id = StringName(data.get("id", ""))
	if spec.asset_id.is_empty() or catalog == null:
		push_error("Village asset specs require a stable catalog asset ID")
		return null
	var descriptor := catalog.descriptor(spec.asset_id)
	if descriptor == null or not descriptor.tags.has(&"village"):
		push_error("Village asset is missing or lacks the village tag: %s" \
			% String(spec.asset_id))
		return null
	spec.measured_aabb = descriptor.measured_aabb
	if not spec.measured_aabb.has_volume():
		push_error("Village asset has no measured volume: %s" % String(spec.asset_id))
		return null
	spec.role = int(data.get("role", Role.HOUSE)) as Role
	if not data.has("access_kind") or not data.has("foundation_kind") \
			or not data.has("vertical_policy") \
			or not data.has("enclosed_interior"):
		push_error("Village asset behavior must be authored independently from its role: %s" \
			% String(spec.asset_id))
		return null
	spec.access_kind = int(data.access_kind) as AccessKind
	spec.foundation_kind = int(data.foundation_kind) as FoundationKind
	spec.vertical_policy = int(data.vertical_policy) as VerticalPolicy
	spec.enclosed_interior = bool(data.enclosed_interior)
	if spec.access_kind < AccessKind.ENTERABLE \
			or spec.access_kind > AccessKind.SERVICE_FRONT \
			or spec.foundation_kind < FoundationKind.NONE \
			or spec.foundation_kind > FoundationKind.PERIMETER \
			or spec.vertical_policy < VerticalPolicy.GROUND_ONLY \
			or spec.vertical_policy > VerticalPolicy.STACKABLE \
			or (spec.enclosed_interior \
				and spec.access_kind != AccessKind.ENTERABLE) \
			or (spec.foundation_kind == FoundationKind.PERIMETER \
				and spec.access_kind != AccessKind.ENTERABLE):
		push_error("Village asset has an incompatible access/foundation contract: %s" \
			% String(spec.asset_id))
		return null
	var authored_variants: Dictionary = data.get("theme_variants", {})
	for theme: StringName in VillageProgram.THEMES:
		var variant_id := StringName(authored_variants.get(theme,
			spec.asset_id))
		var variant_descriptor := catalog.descriptor(variant_id)
		if variant_id.is_empty() or variant_descriptor == null \
				or not variant_descriptor.tags.has(&"village") \
				or not _same_bounds(spec.measured_aabb,
				variant_descriptor.measured_aabb):
			push_error("Village theme variant must exist and preserve planning bounds: %s/%s" \
				% [String(theme), String(variant_id)])
			return null
		spec.theme_asset_ids[theme] = variant_id
	spec.lot_padding = float(data.get("lot_padding", 0.6))
	spec.max_ground_relief = float(data.get("max_ground_relief", 2.75))
	if not is_finite(spec.lot_padding) or spec.lot_padding < 0.0 \
			or not is_finite(spec.max_ground_relief) \
			or spec.max_ground_relief < 0.0:
		push_error("Village asset relief and padding must be finite and non-negative")
		return null
	spec.solid_local_rect = Rect2(Vector2(spec.measured_aabb.position.x,
		spec.measured_aabb.position.z), Vector2(spec.measured_aabb.size.x,
		spec.measured_aabb.size.z))
	spec.lot_local_rect = spec.solid_local_rect.grow(spec.lot_padding)
	spec.ground_contact_local_rect = _rect2(
		data.get("ground_contact_rect", null))
	if not _valid_rect(spec.ground_contact_local_rect) \
			or not spec.solid_local_rect.grow(0.01).encloses(
				spec.ground_contact_local_rect):
		push_error("Village asset requires a reviewed ground-contact rect inside its visual bounds: %s" \
			% String(spec.asset_id))
		return null
	spec.interior_local_rect = _rect2(data.get("interior_rect", null))
	if not _valid_rect(spec.interior_local_rect) \
			or not spec.ground_contact_local_rect.grow(0.01).encloses(
				spec.interior_local_rect):
		push_error("Village asset requires a reviewed interior rect inside its ground contact: %s" \
			% String(spec.asset_id))
		return null
	spec.entrance_local = _vector2(data.get("entrance_local", null))
	spec.entrance_outward = _vector2(data.get("entrance_outward", null))
	spec.entrance_floor_local_y = float(data.get("entrance_floor_y",
		spec.measured_aabb.position.y))
	if not spec.entrance_local.is_finite() \
			or not spec.entrance_outward.is_finite() \
			or not is_equal_approx(spec.entrance_outward.length(), 1.0) \
			or not is_finite(spec.entrance_floor_local_y) \
			or spec.entrance_floor_local_y < spec.measured_aabb.position.y - 0.01 \
			or spec.entrance_floor_local_y > spec.measured_aabb.end.y:
		push_error("Village asset entrance metrics must be finite with a unit outward axis: %s" \
			% String(spec.asset_id))
		return null
	if spec.access_kind == AccessKind.ENTERABLE:
		# A declared doorway/opening must actually cross into the supported
		# structure. This rejects markers placed on a roof overhang or in front
		# of a facade that only look plausible from one camera.
		var inside_point := spec.entrance_local \
			- spec.entrance_outward * ENTRANCE_INTERIOR_DEPTH
		if not spec.interior_local_rect.grow(0.01).has_point(inside_point):
			push_error("Village entrance does not cross into its reviewed ground contact: %s" \
				% String(spec.asset_id))
			return null
	elif not spec.solid_local_rect.grow(0.01).has_point(spec.entrance_local):
		push_error("Village service front must lie on its reviewed structure: %s" \
			% String(spec.asset_id))
		return null
	var attachment_keys: Dictionary = {}
	for value: Variant in data.get("attachments", []):
		if not value is Dictionary:
			push_error("Village attachments must be dictionaries: %s" \
				% String(spec.asset_id))
			return null
		var attachment := VillageAttachedAssetSpec.compile(value, catalog,
			spec.measured_aabb)
		if attachment == null or attachment_keys.has(attachment.stable_key):
			if attachment != null:
				push_error("Village attachment keys must be unique within one asset")
			return null
		attachment_keys[attachment.stable_key] = true
		spec.attachments.append(attachment)
	spec.attachments.sort_custom(func(a: VillageAttachedAssetSpec,
			b: VillageAttachedAssetSpec) -> bool:
		return String(a.stable_key) < String(b.stable_key))
	for value: Variant in data.get("tiers", []):
		var tier := StringName(value)
		if not VillageProgram.TIERS.has(tier) or spec.permitted_tiers.has(tier):
			push_error("Village asset tier is unknown or duplicated: %s" % String(tier))
			return null
		spec.permitted_tiers.append(tier)
	if spec.permitted_tiers.is_empty():
		push_error("Village asset must be admitted by at least one tier: %s" \
			% String(spec.asset_id))
		return null
	spec.permitted_tiers.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	return spec

func allowed_in(tier: StringName) -> bool:
	return permitted_tiers.has(tier)

func has_enclosed_interior() -> bool:
	return enclosed_interior

func is_enterable() -> bool:
	return access_kind == AccessKind.ENTERABLE

func requires_foundation() -> bool:
	return foundation_kind == FoundationKind.PERIMETER

func is_stackable() -> bool:
	return vertical_policy == VerticalPolicy.STACKABLE

func asset_for_theme(theme: StringName) -> StringName:
	assert(theme_asset_ids.has(theme))
	return theme_asset_ids[theme]

func runtime_asset_ids() -> Array[StringName]:
	var unique: Dictionary = {}
	for asset_id: StringName in theme_asset_ids.values():
		unique[asset_id] = true
	for attachment: VillageAttachedAssetSpec in attachments:
		for runtime_id: StringName in attachment.runtime_asset_ids():
			unique[runtime_id] = true
	var out: Array[StringName] = []
	out.assign(unique.keys())
	out.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	return out

func primary_runtime_asset_ids() -> Array[StringName]:
	var unique: Dictionary = {}
	for runtime_id: StringName in theme_asset_ids.values():
		unique[runtime_id] = true
	var out: Array[StringName] = []
	out.assign(unique.keys())
	out.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	return out

func world_entrance(transform: Transform3D) -> Vector2:
	var point := transform * Vector3(entrance_local.x, 0.0, entrance_local.y)
	return Vector2(point.x, point.z)

func world_entrance_outward(transform: Transform3D) -> Vector2:
	var direction := transform.basis * Vector3(
		entrance_outward.x, 0.0, entrance_outward.y)
	return Vector2(direction.x, direction.z).normalized()

func world_entrance_floor_y(transform: Transform3D) -> float:
	return (transform * Vector3(entrance_local.x, entrance_floor_local_y,
		entrance_local.y)).y

func world_solid(transform: Transform3D) -> Dictionary:
	return _world_rect(transform, solid_local_rect)

func world_lot(transform: Transform3D) -> Dictionary:
	return _world_rect(transform, lot_local_rect)

func world_ground_contact(transform: Transform3D) -> Dictionary:
	return _world_rect(transform, ground_contact_local_rect)

func world_interior(transform: Transform3D) -> Dictionary:
	return _world_rect(transform, interior_local_rect)

func placement_for_door(door_world: Vector2,
		desired_outward: Vector2) -> Dictionary:
	assert(desired_outward.is_normalized())
	var yaw := entrance_outward.angle() - desired_outward.angle()
	var basis := Basis(Vector3.UP, yaw)
	var offset_3d := basis * Vector3(entrance_local.x, 0.0, entrance_local.y)
	return {
		"origin": door_world - Vector2(offset_3d.x, offset_3d.z),
		"yaw": yaw,
	}

func local_reach() -> float:
	var bounds_reach := Vector2(measured_aabb.size.x,
		measured_aabb.size.z).length() * 0.5
	var reach := maxf(bounds_reach, _rect_reach(lot_local_rect))
	for attachment: VillageAttachedAssetSpec in attachments:
		reach = maxf(reach, attachment.local_reach())
	return reach

static func _world_rect(transform: Transform3D, rect: Rect2) -> Dictionary:
	var local_centre := rect.get_center()
	var point := transform * Vector3(local_centre.x, 0.0, local_centre.y)
	var local_x := transform.basis * Vector3.RIGHT
	var basis_scale := transform.basis.get_scale()
	return {
		"centre": Vector2(point.x, point.z),
		"half_extents": Vector2(rect.size.x * basis_scale.x,
			rect.size.y * basis_scale.z) * 0.5,
		"angle": Vector2(local_x.x, local_x.z).angle(),
	}

static func _rect_reach(rect: Rect2) -> float:
	var reach := 0.0
	for point: Vector2 in [rect.position,
			Vector2(rect.end.x, rect.position.y), rect.end,
			Vector2(rect.position.x, rect.end.y)]:
		reach = maxf(reach, point.length())
	return reach

static func _vector2(value: Variant) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() == 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2(NAN, NAN)

static func _rect2(value: Variant) -> Rect2:
	if value is Rect2:
		return value
	if value is Array and value.size() == 4:
		return Rect2(float(value[0]), float(value[1]), float(value[2]),
			float(value[3]))
	return Rect2(Vector2(NAN, NAN), Vector2(NAN, NAN))

static func _valid_rect(value: Rect2) -> bool:
	return value.position.is_finite() and value.size.is_finite() \
		and value.size.x > 0.0 and value.size.y > 0.0

static func _same_bounds(a: AABB, b: AABB) -> bool:
	return a.position.is_equal_approx(b.position) \
		and a.size.is_equal_approx(b.size)
