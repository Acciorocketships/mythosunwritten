class_name VillageMassingPlacement
extends RefCounted

## One accepted semantic building on one surveyed perch. It carries exact
## transformed solid geometry so packing and later occupancy use the same fact.
var stable_key: StringName
var asset_id: StringName
var perch: VillageTerrainPerch
var origin: Vector2
var yaw: float
var facade_index: int
var floor_y: float
var solid_centre: Vector2
var solid_half_extents: Vector2
var solid_angle: float
var solid_min_y: float
var solid_max_y: float
## Reviewed ground-contact footprint. This is an input to the later foundation
## or compact-core solve, not a fictional solid column to terrain. Massing may
## place an upper building over lower activity; the atomic support stage must
## then find real module geometry that avoids every reserved volume.
var support_centre: Vector2
var support_half_extents: Vector2
var support_angle: float
var entrance := Vector2.ZERO
var entrance_outward := Vector2.ZERO
var entrance_ground_contact := Vector2.ZERO
var entrance_ground_y: float = 0.0
var street_contact := Vector2.ZERO
var street_contact_y: float = 0.0
var entrance_stair_count: int = 0
var entrance_stair_base_y: float = 0.0
var entrance_residual_step: float = 0.0
var access_half_width: float = 0.0
var access_min_y: float = 0.0
var access_max_y: float = 0.0
## Ground access is optional only for retained upper-band buildings. Their
## doorway apron is served by the public platform graph instead of inventing a
## private staircase all the way to terrain.
var ground_accessible: bool = false


static func from_perch(slot: VillageMassingSlot, spec: VillageAssetSpec,
		p_perch: VillageTerrainPerch,
		p_facade_index: int = 0) -> VillageMassingPlacement:
	assert(p_facade_index == 0 or p_facade_index == 1)
	var placement := VillageMassingPlacement.new()
	placement.stable_key = slot.stable_key
	placement.asset_id = slot.asset_id
	placement.perch = p_perch
	placement.facade_index = p_facade_index
	placement.yaw = p_perch.yaw + float(p_facade_index) * PI
	placement.floor_y = p_perch.floor_y
	var basis := Basis(Vector3.UP, placement.yaw)
	var local_contact := spec.ground_contact_local_rect.get_center()
	var offset := basis * Vector3(local_contact.x, 0.0, local_contact.y)
	placement.origin = p_perch.anchor - Vector2(offset.x, offset.z)
	var transform := Transform3D(basis, Vector3(placement.origin.x,
		placement.floor_y, placement.origin.y))
	var solid := spec.world_solid(transform)
	placement.solid_centre = solid.centre
	placement.solid_half_extents = solid.half_extents
	placement.solid_angle = solid.angle
	var support := spec.world_ground_contact(transform)
	placement.support_centre = support.centre
	placement.support_half_extents = support.half_extents
	placement.support_angle = support.angle
	var vertical_origin := placement.floor_y - spec.entrance_floor_local_y
	placement.solid_min_y = vertical_origin + spec.measured_aabb.position.y
	placement.solid_max_y = vertical_origin + spec.measured_aabb.end.y
	return placement


func copy_for_slot(slot: VillageMassingSlot) -> VillageMassingPlacement:
	var copy := VillageMassingPlacement.new()
	copy.stable_key = slot.stable_key
	copy.asset_id = slot.asset_id
	copy.perch = perch
	copy.origin = origin
	copy.yaw = yaw
	copy.facade_index = facade_index
	copy.floor_y = floor_y
	copy.solid_centre = solid_centre
	copy.solid_half_extents = solid_half_extents
	copy.solid_angle = solid_angle
	copy.solid_min_y = solid_min_y
	copy.solid_max_y = solid_max_y
	copy.support_centre = support_centre
	copy.support_half_extents = support_half_extents
	copy.support_angle = support_angle
	copy.entrance = entrance
	copy.entrance_outward = entrance_outward
	copy.entrance_ground_contact = entrance_ground_contact
	copy.entrance_ground_y = entrance_ground_y
	copy.street_contact = street_contact
	copy.street_contact_y = street_contact_y
	copy.entrance_stair_count = entrance_stair_count
	copy.entrance_stair_base_y = entrance_stair_base_y
	copy.entrance_residual_step = entrance_residual_step
	copy.access_half_width = access_half_width
	copy.access_min_y = access_min_y
	copy.access_max_y = access_max_y
	copy.ground_accessible = ground_accessible
	return copy


func building_transform(spec: VillageAssetSpec) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), Vector3(origin.x,
		floor_y - spec.entrance_floor_local_y, origin.y))


func configure_entrance(spec: VillageAssetSpec, terrain: VillageTerrainView,
		vocabulary: VillageElevatedProgram) -> bool:
	assert(spec != null and terrain != null and vocabulary != null)
	var transform := building_transform(spec)
	entrance = spec.world_entrance(transform)
	entrance_outward = spec.world_entrance_outward(transform)
	if not entrance_outward.is_normalized():
		return false
	var stair_run := vocabulary.stair_module_run
	var stair_rise := vocabulary.stair_aabb.size.y
	if stair_run <= 0.0 or stair_rise <= 0.0:
		return false
	# Door approaches are a cell-wide public route even when the authored stair
	# mesh is a little narrower. Keeping this width canonical lets a platform,
	# stair, or ground lane meet the same reviewed facade aperture without a
	# producer-specific sliver at the hand-off.
	access_half_width = maxf(VillageProgram.MODULE * 0.5,
		maxf(vocabulary.stair_aabb.size.x * 0.5,
			TraversalEnvelope.MIN_APERTURE_WIDTH * 0.5))
	# Enumerate the small fixed stair vocabulary instead of iterating a contact
	# distance/count guess. Every option samples the terrain at its own actual
	# run, so a change in ground height cannot oscillate the solve or leave the
	# final distance unsampled.
	var choice: Dictionary = {}
	for count in range(VillageMassingProgram.MAX_ENTRANCE_STAIR_SEGMENTS + 1):
		var contact_distance := VillageProgram.MODULE if count == 0 \
			else float(count) * stair_run
		var contact := entrance + entrance_outward * contact_distance
		var region := terrain.region_at(contact)
		var ground_y := TerrainSurfaceField.surface_y(region,
			contact.x, contact.y)
		var rise := floor_y - ground_y
		if count == 0:
			if not TraversalEnvelope.step_is_legal(rise):
				continue
		else:
			var residual := (rise - float(count) * stair_rise) * 0.5
			if not TraversalEnvelope.step_is_legal(residual):
				continue
		var residual_step := rise if count == 0 \
			else (rise - float(count) * stair_rise) * 0.5
		var error := absf(residual_step)
		if choice.is_empty() or error < float(choice.error) - 0.0001 \
				or (is_equal_approx(error, float(choice.error)) \
					and count < int(choice.count)):
			choice = {
				"contact": contact,
				"count": count,
				"ground_y": ground_y,
				"residual": residual_step,
				"error": error,
			}
	if choice.is_empty():
		if perch.architectural_band <= 0:
			return false
		ground_accessible = false
		entrance_ground_contact = entrance \
			+ entrance_outward * VillageDoorGeometry.clear_departure(self,
				access_half_width)
		entrance_ground_y = floor_y
		street_contact = entrance_ground_contact
		street_contact_y = floor_y
		entrance_stair_count = 0
		entrance_residual_step = 0.0
		entrance_stair_base_y = floor_y
		access_min_y = floor_y
		access_max_y = floor_y + TraversalEnvelope.MIN_HEADROOM
		return true
	ground_accessible = true
	entrance_ground_contact = choice.contact
	entrance_ground_y = float(choice.ground_y)
	entrance_stair_count = int(choice.count)
	entrance_residual_step = float(choice.residual)
	var total_stair_rise := float(entrance_stair_count) * stair_rise
	entrance_stair_base_y = entrance_ground_y + entrance_residual_step
	for sample_index in 5:
		var point := entrance.lerp(entrance_ground_contact,
			float(sample_index) / 4.0)
		if terrain.may_be_wet(point):
			return false
	# A full-width street cannot turn directly at a stair foot without its
	# swept edge clipping the facade. Reserve one fixed-module outward landing
	# and expose its far end as the public routing contact. The stair foot stays
	# separate so later materialization can place the exact authored flight. A
	# cliff or water immediately past the stair foot simply withholds the
	# optional street egress; that building can still join by its upper door.
	street_contact = entrance_ground_contact
	street_contact_y = entrance_ground_y
	var proposed_contact := entrance_ground_contact \
		+ entrance_outward * VillageProgram.MODULE
	var proposed_y := entrance_ground_y
	var landing_valid := true
	for sample_index in range(1, 4):
		var point := entrance_ground_contact.lerp(proposed_contact,
			float(sample_index) / 3.0)
		var ground_y := terrain.surface_y(point)
		if terrain.may_be_wet(point) or not TraversalEnvelope.step_is_legal(
				ground_y - proposed_y):
			landing_valid = false
			break
		proposed_y = ground_y
	if landing_valid:
		street_contact = proposed_contact
		street_contact_y = proposed_y
	access_min_y = minf(minf(entrance_ground_y, street_contact_y),
		entrance_stair_base_y)
	access_max_y = maxf(floor_y,
		entrance_stair_base_y + total_stair_rise) \
		+ TraversalEnvelope.MIN_HEADROOM
	return true


func solid_shape() -> FeatureGroundShape:
	return FeatureGroundShape.oriented_rect(solid_centre,
		solid_half_extents, solid_angle)


func support_shape() -> FeatureGroundShape:
	return FeatureGroundShape.oriented_rect(support_centre,
		support_half_extents, support_angle)


func overlaps(other: VillageMassingPlacement, margin: float) -> bool:
	if not solid_shape().intersects(other.solid_shape(), margin):
		return false
	return _vertical_overlap(solid_min_y, solid_max_y,
		other.solid_min_y, other.solid_max_y)


func access_shape() -> FeatureGroundShape:
	return FeatureGroundShape.capsule(entrance, entrance_ground_contact,
		access_half_width)


func route_access_shape() -> FeatureGroundShape:
	return FeatureGroundShape.capsule(entrance, street_contact,
		access_half_width)


func access_conflicts(other: VillageMassingPlacement, margin: float) -> bool:
	if access_shape().intersects(other.solid_shape(), margin) \
			and _vertical_overlap(access_min_y, access_max_y,
				other.solid_min_y, other.solid_max_y):
		return true
	if other.access_shape().intersects(solid_shape(), margin) \
			and _vertical_overlap(other.access_min_y, other.access_max_y,
				solid_min_y, solid_max_y):
		return true
	# Access reservations are public empty space, not solids. Let neighboring
	# doors share or cross a lane; the circulation solve will compile that
	# overlap into one connected fabric. Only access-versus-building overlap is
	# forbidden here.
	return false


func horizontal_reach_from(point: Vector2) -> float:
	var bounds := solid_shape().bounds()
	var reach := 0.0
	for corner: Vector2 in [bounds.position,
		Vector2(bounds.end.x, bounds.position.y), bounds.end,
		Vector2(bounds.position.x, bounds.end.y)]:
		reach = maxf(reach, point.distance_to(corner))
	return reach


static func _vertical_overlap(a_min: float, a_max: float,
		b_min: float, b_max: float) -> bool:
	return a_min < b_max - 0.001 and b_min < a_max - 0.001
