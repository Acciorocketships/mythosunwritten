extends RefCounted
## Physical flight margins chosen before public surfaces are sealed. Roof boxes
## are conservative construction reservations; the finished kit still owns its
## exact roof/public-air audit. Route addresses and headroom never shrink.
const B = preload(
	"res://scripts/terrain/features/villages/fabric/WarrenTransitionSurfaceBuilder.gd"
)
const JOINT_CLEARANCE := 0.02


static func roof_bounds(fabric: SettlementFabricPlan) -> Array[AABB]:
	var out: Array[AABB] = []
	for unit: FabricUnit in fabric.units:
		var recipe := fabric.recipe(unit.recipe_id)
		if recipe.has_tag(&"roof"):
			out.append(
				(
					FabricRecipe.lattice_transform(unit.lattice_origin, unit.yaw_quarters)
					* recipe.local_clearance_bounds
				)
			)
	return out


static func choose(
	transition: WarrenVolumeTransition, roofs: Array[AABB], surfaces: PublicRealmSurfacePlan
) -> Vector2:
	if transition == null or not transition.is_sealed() or not transition.is_vertical():
		return Vector2.ZERO
	var ends := B._span_endpoints(transition)
	var start: Vector3 = ends.start
	var end: Vector3 = ends.end
	var along := Vector3(transition.direction.x, 0, transition.direction.y)
	var across := Vector3(-along.z, 0, along.x)
	var run := (end - start).dot(along)
	var half := B.MACRO_SIZE * .5
	var low := minf(start.y, end.y)
	var high := (
		maxf(start.y, end.y) + TraversalEnvelope.MIN_HEADROOM / VillageWorldScale.VERTICAL_SCALE
	)
	var insets := Vector2.ZERO
	for box: AABB in roofs:
		if box.end.y <= low + 0.001 or box.position.y >= high:
			continue
		var near := INF
		var far := -INF
		var u0 := INF
		var u1 := -INF
		for i in 8:
			var offset := box.get_endpoint(i) - start
			near = minf(near, offset.dot(across))
			far = maxf(far, offset.dot(across))
			u0 = minf(u0, offset.dot(along))
			u1 = maxf(u1, offset.dot(along))
		if u1 <= 0.001 or u0 >= run - 0.001:
			continue
		if near > 0.0 and near < half and far >= half:
			insets.y = maxf(insets.y, half - near + JOINT_CLEARANCE)
		elif far < 0.0 and far > -half and near <= -half:
			insets.x = maxf(insets.x, half + far + JOINT_CLEARANCE)
	# Reject each side independently. No narrow flight can replace a lateral
	# route connection, including a court corner added by surface closure.
	for side in [-1, 1]:
		var slot := 0 if side == -1 else 1
		var trial := Vector2.ZERO
		trial[slot] = insets[slot]
		if (
			not B.valid_side_insets(trial)
			or _has_side_connection(transition, surfaces, Vector3i(across) * side)
		):
			insets[slot] = 0.0
	return insets


static func _has_side_connection(
	transition: WarrenVolumeTransition, surfaces: PublicRealmSurfacePlan, side: Vector3i
) -> bool:
	var own := {}
	for cell: Vector3i in transition.surface_cells():
		own[Vector2i(cell.x, cell.z)] = true
	for cell: Vector3i in transition.surface_cells():
		var neighbor := cell + side
		if own.has(Vector2i(neighbor.x, neighbor.z)):
			continue
		for y in range(
			mini(transition.from_cell.y, transition.to_cell.y),
			maxi(transition.from_cell.y, transition.to_cell.y) + 1
		):
			if surfaces.has_cell(Vector3i(neighbor.x, y, neighbor.z)):
				return true
	return false
