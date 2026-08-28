class_name FabricRecipe
extends RefCounted

## Immutable, resource-free description of one piece of urban fabric. Recipes
## own every fact needed by the worker: visual placements, conservative lattice
## occupancy, typed connection sockets, and the number of bearing parents.
enum SocketKind {
	WALK,
	ROOM,
	MARKET,
	BEARING,
}

const CELL_SIZE := 1.5

var recipe_id: StringName
var role_tags: Array[StringName] = []
var placements: Array[Dictionary] = []
## Multi-placement construction records whose internal seams must remain one
## authored run. Roof material phase and end caps therefore cannot drift through
## independent placement or later decoration.
var construction_runs: Array[Dictionary] = []
var solid_cells: Array[Vector3i] = []
var walk_cells: Array[Vector3i] = []
var headroom_cells: Array[Vector3i] = []
## The subset of reserved headroom that belongs to the exterior public realm.
## Private room clearance never enters this layer by implication.
var public_air_cells: Array[Vector3i] = []
## Deliberate holes through a structural public floor. They remain exterior
## air, are classified separately from missing geometry, and receive derived
## guards around every edge that is not a public transition.
var daylight_void_cells: Array[Vector3i] = []
## Non-public room volume. It may share reservation cells with private
## walk/headroom data, but never with the structural shell.
var inhabited_cells: Array[Vector3i] = []
var occluder_cells: Array[Vector3i] = []
## Exact local footprint that transfers a terrain-bearing recipe's load into
## natural ground. This is deliberately independent of shell occupancy: a
## hollow prefab still needs ground beneath its whole base, while eaves and
## exterior stairs must never grow an arbitrary terrain skirt. Cells are
## always on the recipe's local y=0 datum.
var terrain_bearing_cells: Array[Vector3i] = []
var sockets: Array[Dictionary] = []
## Exterior door thresholds. `cell` is the clear cell in the facade and
## `facing` points from the threshold toward the required public landing.
## Keeping this separate from ROOM sockets avoids pretending that a future
## interior connection is already part of the exterior circulation graph.
var entrances: Array[Dictionary] = []
var bearing_parent_count: int
var local_bounds := AABB()
## TASK I4 ROUND 6 -- ONE BOX PER PLACEMENT, in the same order as `placements`,
## measured at `seal()` off the same `descriptor.measured_aabb` the merged
## `local_bounds` above is built from.
##
## DERIVED AND NOT AUTHORED. No recipe writes it, nothing reads it before the
## seal, and it enters no signature: `construction_signature()` digests unit
## ids, recipe ids, origins, yaws, parents, bonds and suppressions, and
## `local_bounds` is still the merge it always was. It exists because the merge
## is the ONE fact the fabric layer had about a recipe's geometry, and the merge
## cannot tell a door standing a metre outside its room's envelope from the room
## itself -- which is what left a planter inside a wall, a gallery board over a
## deck a body stands on, and a floor board lying on a lawn (task I4 round 5's
## own first concern, all three of them one defect).
var placement_bounds: Array[AABB] = []
## Exact authored visual bounds expanded only by a module contract's declared
## construction clearance. Unlike lattice occupancy this envelope exists to
## stop unrelated meshes from interpenetrating between otherwise valid cells.
var local_clearance_bounds := AABB()
var _has_declared_clearance_bounds := false
var _socket_by_id: Dictionary = {}
var _sealed := false
var last_rejection := ""


func _init(p_recipe_id: StringName, p_role_tags: Array[StringName],
		p_bearing_parent_count: int) -> void:
	recipe_id = p_recipe_id
	role_tags.assign(p_role_tags)
	bearing_parent_count = p_bearing_parent_count


func add_placement(placement_id: StringName, asset_id: StringName,
		transform: Transform3D = Transform3D.IDENTITY) -> void:
	assert(not _sealed)
	placements.append({
		"id": placement_id,
		"asset_id": asset_id,
		"transform": transform,
	})


func add_construction_run(run_id: StringName, kind: StringName,
		placement_ids: Array[StringName], start_seam: float, end_seam: float,
		repeat_pitch: float, seam_profile: StringName,
		material_family: StringName) -> void:
	assert(not _sealed)
	construction_runs.append({
		"id": run_id,
		"kind": kind,
		"placement_ids": placement_ids.duplicate(),
		"start_seam": start_seam,
		"end_seam": end_seam,
		"repeat_pitch": repeat_pitch,
		"seam_profile": seam_profile,
		"material_family": material_family,
	})


func add_socket(socket_id: StringName, kind: SocketKind, cell: Vector3i,
		facing: Vector3i) -> void:
	assert(not _sealed)
	sockets.append({
		"id": socket_id,
		"kind": kind,
		"cell": cell,
		"facing": facing,
	})


func add_entrance(entrance_id: StringName, cell: Vector3i,
		facing: Vector3i) -> void:
	assert(not _sealed)
	entrances.append({
		"id": entrance_id,
		"cell": cell,
		"facing": facing,
	})


func set_local_clearance_bounds(bounds: AABB) -> bool:
	if _sealed or _has_declared_clearance_bounds or not bounds.has_volume() \
			or not bounds.position.is_finite() or not bounds.size.is_finite():
		return false
	local_clearance_bounds = bounds
	_has_declared_clearance_bounds = true
	return true


func grow_local_clearance_bounds(bounds: AABB) -> bool:
	## A recipe may retain a conservative, previously reviewed construction
	## envelope after one of its visuals moves inward. The initial declaration is
	## still single-owner; this operation can only enlarge it, never overwrite or
	## shrink it.
	if _sealed or not _has_declared_clearance_bounds or not bounds.has_volume() \
			or not bounds.position.is_finite() or not bounds.size.is_finite():
		return false
	local_clearance_bounds = local_clearance_bounds.merge(bounds)
	return true


func seal(catalog: EnvironmentCatalog) -> bool:
	last_rejection = ""
	if _sealed or catalog == null or recipe_id.is_empty() \
			or role_tags.is_empty() or bearing_parent_count < 0 \
			or bearing_parent_count > 2 \
			or (placements.is_empty() and not has_tag(&"topology_only")):
		last_rejection = "missing id/catalog/tags, invalid bearing count, or empty visual recipe"
		return false
	if not _valid_names(role_tags) or not _unique_cells(solid_cells) \
			or not _unique_cells(walk_cells) or not _unique_cells(headroom_cells) \
			or not _unique_cells(public_air_cells) \
			or not _unique_cells(daylight_void_cells) \
			or not _unique_cells(inhabited_cells) \
			or not _unique_cells(occluder_cells) \
			or not _unique_cells(terrain_bearing_cells):
		last_rejection = "duplicate tag or occupancy cell"
		return false
	if has_tag(&"terrain_bearing") != not terrain_bearing_cells.is_empty():
		last_rejection = \
			"terrain-bearing tag and exact bearing footprint must exist together"
		return false
	for cell: Vector3i in terrain_bearing_cells:
		if cell.y != 0:
			last_rejection = "terrain bearing footprint leaves local datum at %s" % cell
			return false
	var solid: Dictionary = {}
	for cell: Vector3i in solid_cells:
		solid[_cell_key(cell)] = true
	var headroom: Dictionary = {}
	for cell: Vector3i in headroom_cells:
		if solid.has(_cell_key(cell)):
			last_rejection = "headroom overlaps solid at %s" % cell
			return false
		headroom[_cell_key(cell)] = true
	if has_tag(&"public_walk") != not public_air_cells.is_empty():
		last_rejection = "public-walk and public-air claims must exist together"
		return false
	for cell: Vector3i in public_air_cells:
		if not headroom.has(_cell_key(cell)):
			last_rejection = "public air is not reserved headroom at %s" % cell
			return false
	for cell: Vector3i in daylight_void_cells:
		var key := _cell_key(cell)
		if solid.has(key) or walk_cells.has(cell):
			last_rejection = "daylight void overlaps structure or floor at %s" % cell
			return false
	for cell: Vector3i in inhabited_cells:
		if solid.has(_cell_key(cell)):
			last_rejection = "inhabited volume overlaps structural solid at %s" % cell
			return false
	var placement_ids: Dictionary = {}
	var has_bounds := false
	placement_bounds.clear()
	for placement: Dictionary in placements:
		var placement_id := StringName(placement.get("id", ""))
		var asset_id := StringName(placement.get("asset_id", ""))
		var transform := placement.get("transform", Transform3D()) as Transform3D
		if placement_id.is_empty() or asset_id.is_empty() \
				or placement_ids.has(placement_id) or not transform.is_finite():
			last_rejection = "invalid or duplicate placement %s" % placement_id
			return false
		var descriptor := catalog.descriptor(asset_id)
		if descriptor == null or not descriptor.measured_aabb.has_volume():
			last_rejection = "placement %s references unavailable asset %s" % [
				placement_id, asset_id]
			return false
		placement_ids[placement_id] = true
		var bounds := transform * descriptor.measured_aabb
		placement_bounds.append(bounds)
		local_bounds = bounds if not has_bounds else local_bounds.merge(bounds)
		has_bounds = true
	var run_ids: Dictionary = {}
	for run: Dictionary in construction_runs:
		var run_id := StringName(run.get("id", ""))
		var kind := StringName(run.get("kind", ""))
		var run_placements: Array = run.get("placement_ids", []) as Array
		var start_seam := float(run.get("start_seam", NAN))
		var end_seam := float(run.get("end_seam", NAN))
		var repeat_pitch := float(run.get("repeat_pitch", 0.0))
		var seam_profile := StringName(run.get("seam_profile", ""))
		var material_family := StringName(run.get("material_family", ""))
		if run_id.is_empty() or kind.is_empty() or run_ids.has(run_id) \
				or run_placements.size() < 3 or not is_finite(start_seam) \
				or not is_finite(end_seam) or end_seam <= start_seam \
				or repeat_pitch <= 0.0 or seam_profile.is_empty() \
				or material_family.is_empty():
			last_rejection = "invalid construction run %s" % run_id
			return false
		var seen_run_placements: Dictionary = {}
		for placement_value: Variant in run_placements:
			var placement_id := StringName(placement_value)
			if placement_id.is_empty() or seen_run_placements.has(placement_id) \
					or not placement_ids.has(placement_id):
				last_rejection = "construction run %s references invalid placement %s" % [
					run_id, placement_id]
				return false
			seen_run_placements[placement_id] = true
		run_ids[run_id] = true
	if not has_bounds:
		var planning_cells: Array[Vector3i] = []
		planning_cells.append_array(solid_cells)
		planning_cells.append_array(walk_cells)
		planning_cells.append_array(headroom_cells)
		planning_cells.append_array(public_air_cells)
		planning_cells.append_array(daylight_void_cells)
		planning_cells.append_array(inhabited_cells)
		if planning_cells.is_empty():
			last_rejection = "topology-only recipe has no planning cells"
			return false
		local_bounds = _bounds_for_cells(planning_cells)
		has_bounds = local_bounds.has_volume()
	if not _has_declared_clearance_bounds:
		local_clearance_bounds = local_bounds
	elif not local_clearance_bounds.grow(0.001).encloses(local_bounds):
		last_rejection = "construction clearance does not enclose visual bounds"
		return false
	var socket_ids: Dictionary = {}
	for socket: Dictionary in sockets:
		var socket_id := StringName(socket.get("id", ""))
		var kind := int(socket.get("kind", -1))
		var cell := socket.get("cell", Vector3i()) as Vector3i
		var facing := socket.get("facing", Vector3i()) as Vector3i
		if socket_id.is_empty() or socket_ids.has(socket_id) \
				or kind < SocketKind.WALK or kind > SocketKind.BEARING \
				or absi(facing.x) + absi(facing.y) + absi(facing.z) != 1:
			last_rejection = "invalid or duplicate socket %s" % socket_id
			return false
		socket_ids[socket_id] = true
		_socket_by_id[socket_id] = {
			"id": socket_id,
			"kind": kind,
			"cell": cell,
			"facing": facing,
		}
	var entrance_ids: Dictionary = {}
	for entrance: Dictionary in entrances:
		var entrance_id := StringName(entrance.get("id", ""))
		var cell := entrance.get("cell", Vector3i()) as Vector3i
		var facing := entrance.get("facing", Vector3i()) as Vector3i
		if entrance_id.is_empty() or entrance_ids.has(entrance_id) \
				or absi(facing.x) + absi(facing.z) != 1 or facing.y != 0 \
				or solid.has(_cell_key(cell)) or not headroom.has(_cell_key(cell)):
			last_rejection = "invalid or duplicate exterior entrance %s" % entrance_id
			return false
		entrance_ids[entrance_id] = true
	if bearing_parent_count > 0:
		var bearing_socket_count := 0
		for socket: Dictionary in sockets:
			if int(socket.kind) == SocketKind.BEARING:
				bearing_socket_count += 1
		if bearing_socket_count < bearing_parent_count:
			last_rejection = "not enough bearing sockets"
			return false
	_sealed = has_bounds
	return _sealed


func is_sealed() -> bool:
	return _sealed


func has_tag(tag: StringName) -> bool:
	return role_tags.has(tag)


func socket(socket_id: StringName) -> Dictionary:
	return (_socket_by_id.get(socket_id, {}) as Dictionary).duplicate()


func asset_ids() -> Array[StringName]:
	var unique: Dictionary = {}
	for placement: Dictionary in placements:
		unique[StringName(placement.asset_id)] = true
	var out: Array[StringName] = []
	out.assign(unique.keys())
	out.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	return out


static func lattice_transform(origin: Vector3i, yaw_quarters: int) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, float(posmod(yaw_quarters, 4)) *
		PI * 0.5), Vector3(origin) * CELL_SIZE)


static func transform_cell(cell: Vector3i, origin: Vector3i,
		yaw_quarters: int) -> Vector3i:
	## TASK F2. The quarter turn about UP, in integers, spelled out here rather
	## than delegated: this is called for every lattice cell of every stamp,
	## recipe and cap the composition and the compiler touch — millions of times
	## per town — and at that rate a second GDScript call costs more than the
	## arithmetic. See `transform_direction` for why the four cases are exact.
	var quarter := yaw_quarters & 3
	if quarter == 0:
		return origin + cell
	if quarter == 1:
		return Vector3i(origin.x + cell.z, origin.y + cell.y,
			origin.z - cell.x)
	if quarter == 2:
		return Vector3i(origin.x - cell.x, origin.y + cell.y,
			origin.z - cell.z)
	return Vector3i(origin.x - cell.z, origin.y + cell.y, origin.z + cell.x)


static func transform_direction(direction: Vector3i,
		yaw_quarters: int) -> Vector3i:
	## TASK F2. The same quarter turn, without an origin.
	##
	## Both used to build `Basis(Vector3.UP, yaw * PI/2)` — trig, a 3x3 matrix,
	## a float vector product and three roundings — per call. `Basis(UP, t)`
	## maps (x, y, z) to (cos t * x + sin t * z, y, -sin t * x + cos t * z), and
	## at the four quarter turns the sines and cosines are 0 and +-1 to within a
	## float epsilon that `roundi` was already discarding, so these cases are
	## what it always computed. Checked exhaustively over yaw -8..11 and every
	## cell in [-9, 9]^3 against the Basis form: zero mismatches.
	##
	## `& 3` is `posmod(x, 4)` for every int in two's complement, and avoids a
	## built-in call in the same hot path.
	var quarter := yaw_quarters & 3
	if quarter == 0:
		return direction
	if quarter == 1:
		return Vector3i(direction.z, direction.y, -direction.x)
	if quarter == 2:
		return Vector3i(-direction.x, direction.y, -direction.z)
	return Vector3i(-direction.z, direction.y, direction.x)


static func box_cells(minimum: Vector3i, size: Vector3i) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for y in range(minimum.y, minimum.y + size.y):
		for z in range(minimum.z, minimum.z + size.z):
			for x in range(minimum.x, minimum.x + size.x):
				out.append(Vector3i(x, y, z))
	return out


static func _valid_names(values: Array[StringName]) -> bool:
	var unique: Dictionary = {}
	for value: StringName in values:
		if value.is_empty() or unique.has(value):
			return false
		unique[value] = true
	return true


static func _unique_cells(values: Array[Vector3i]) -> bool:
	var unique: Dictionary = {}
	for value: Vector3i in values:
		var key := _cell_key(value)
		if unique.has(key):
			return false
		unique[key] = true
	return true


static func _bounds_for_cells(cells: Array[Vector3i]) -> AABB:
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	var half := CELL_SIZE * 0.5
	for cell: Vector3i in cells:
		var centre := Vector3(cell) * CELL_SIZE
		minimum = minimum.min(centre - Vector3(half, 0.0, half))
		maximum = maximum.max(centre + Vector3(half, CELL_SIZE, half))
	return AABB(minimum, maximum - minimum)


static func _cell_key(cell: Vector3i) -> String:
	return "%d:%d:%d" % [cell.x, cell.y, cell.z]
