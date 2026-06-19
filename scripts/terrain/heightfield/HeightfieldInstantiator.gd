class_name HeightfieldInstantiator
extends RefCounted

## Turns the heightfield plan into placement records and (Task 3) real tiles.
## A placement record is {variant_tag, family, world_x, world_z, origin_y, yaw}.

## `plan` is HeightfieldPlan OR HeightfieldRegion (both expose tile_plan + surface_height).
## Build the neighbour-height dictionaries (socket name -> surface height) for a cell.
static func _neighbour_heights(plan, cx: int, cz: int) -> Array:
	var cardinals: Dictionary = {}
	var diagonals: Dictionary = {}
	for off in HeightfieldFacing.OFFSET_TO_SOCKET.keys():
		var socket_name: String = HeightfieldFacing.OFFSET_TO_SOCKET[off]
		var h: float = plan.surface_height(cx + off.x, cz + off.y)
		if off.x == 0 or off.y == 0:
			cardinals[socket_name] = h
		else:
			diagonals[socket_name] = h
	return [cardinals, diagonals]


## One placement record per cell in the (2*place_radius+1)^2 block around (cx,cz).
static func placements(plan: HeightfieldPlan, cx: int, cz: int, place_radius: int) -> Array:
	var out: Array = []
	for dz in range(-place_radius, place_radius + 1):
		for dx in range(-place_radius, place_radius + 1):
			out.append(placement_for_cell(plan, cx + dx, cz + dz))
	return out


## `plan` is HeightfieldPlan OR HeightfieldRegion (both expose tile_plan + surface_height).
## The placement record for a single cell.
static func placement_for_cell(plan, cx: int, cz: int) -> Dictionary:
	var tp: Dictionary = plan.tile_plan(cx, cz)
	var h0: float = float(tp["height"])
	var nb: Array = _neighbour_heights(plan, cx, cz)
	var desc: Dictionary = HeightfieldVariant.cell_descriptor(
		h0, int(tp["storey"]), int(tp["level"]), nb[0], nb[1]
	)
	return {
		"variant_tag": desc["variant_tag"],
		"family": desc["family"],
		"world_x": float(cx) * HeightfieldPlan.TILE,
		"world_z": float(cz) * HeightfieldPlan.TILE,
		"origin_y": float(desc["origin_y"]),
		"yaw": HeightfieldFacing.yaw_for_rotation_steps(int(desc["rotation_steps"])),
	}


## HV variant_tag -> the module tag to look up in the library.
static func _lookup_tag(variant_tag: String) -> String:
	if variant_tag == "ground":
		return "ground-plain"
	return variant_tag


## Instantiate one placement record under `parent` and return the live instance,
## or null if no module matches the tag. Sets the transform directly (origin_y +
## a Y-axis yaw) — no socket attachment. Caller is responsible for indexing.
static func spawn_placement(
	record: Dictionary, library: TerrainModuleLibrary, parent: Node3D
) -> TerrainModuleInstance:
	var tag: String = _lookup_tag(String(record["variant_tag"]))
	var modules: TerrainModuleList = library.get_by_tags(TagList.new([tag]))
	if modules.is_empty():
		push_error("HeightfieldInstantiator: no module for tag '%s'" % tag)
		return null
	var template: TerrainModule = library.get_random(modules, true)
	var inst: TerrainModuleInstance = template.spawn()
	var basis: Basis = Basis(Vector3.UP, float(record["yaw"]))
	var origin: Vector3 = Vector3(float(record["world_x"]), float(record["origin_y"]), float(record["world_z"]))
	inst.set_transform(Transform3D(basis, origin))
	inst.create()
	if inst.root == null:
		return null
	parent.add_child(inst.root)
	return inst


# Instance state: cells already placed (so re-running a region is idempotent and
# churn-free). Keyed by Vector2i(cx, cz).
var _placed: Dictionary = {}
var _target_cache: Dictionary = {}


## Place every not-yet-placed cell in the (2*place_radius+1)^2 block around the
## center cell, under `parent`. Returns the instances spawned this call. A cell is
## placed at most once for the lifetime of this instance, so repeated calls as the
## player moves never re-place (or churn) settled tiles.
func place_region(
	plan: HeightfieldPlan, library: TerrainModuleLibrary, parent: Node3D,
	center_cx: int, center_cz: int, place_radius: int
) -> Array[TerrainModuleInstance]:
	# Collect not-yet-placed cells; if none, this frame is free.
	var new_cells: Array[Vector2i] = []
	for dz in range(-place_radius, place_radius + 1):
		for dx in range(-place_radius, place_radius + 1):
			var cell: Vector2i = Vector2i(center_cx + dx, center_cz + dz)
			if not _placed.has(cell):
				new_cells.append(cell)
	var spawned: Array[TerrainModuleInstance] = []
	if new_cells.is_empty():
		return spawned
	# Batch the plan computation for the whole region exactly once.
	var region: HeightfieldRegion = plan.compute_region(center_cx, center_cz, place_radius, _target_cache)
	for cell in new_cells:
		var rec: Dictionary = placement_for_cell(region, cell.x, cell.y)
		var inst: TerrainModuleInstance = spawn_placement(rec, library, parent)
		_placed[cell] = inst
		if inst != null:
			spawned.append(inst)
	return spawned


## Number of cells currently tracked as placed.
func placed_count() -> int:
	return _placed.size()


## Drop placed-cell records whose Chebyshev distance from (center_cx, center_cz)
## exceeds `keep_radius`. Returns the evicted (non-null) instances so the caller
## can remove their nodes/index entries — the placed set alone going stale would
## otherwise let a returning player double-place a cell.
func evict_placed_outside(center_cx: int, center_cz: int, keep_radius: int) -> Array[TerrainModuleInstance]:
	var survivors: Dictionary = {}
	var evicted: Array[TerrainModuleInstance] = []
	for cell in _placed.keys():
		if absi(cell.x - center_cx) <= keep_radius and absi(cell.y - center_cz) <= keep_radius:
			survivors[cell] = _placed[cell]
		else:
			var inst: TerrainModuleInstance = _placed[cell]
			if inst != null:
				evicted.append(inst)
	_placed = survivors
	var kept_cache: Dictionary = {}
	for cell in _target_cache.keys():
		if absi(cell.x - center_cx) <= keep_radius + 40 and absi(cell.y - center_cz) <= keep_radius + 40:
			kept_cache[cell] = _target_cache[cell]
	_target_cache = kept_cache
	return evicted


## Spawn one record; return 1 if it was dropped (no module / failed create), else 0.
## Surfaces gaps that spawn_placement otherwise reports only via push_error.
## NOTE: the empty-module case is checked here and returns early WITHOUT calling
## spawn_placement on purpose — spawn_placement push_error()s on a missing module,
## and this project's GUT config turns any push_error during a test into a failure.
## Do not "simplify" this to a bare spawn_placement delegation; it will break
## test_place_region_reports_dropped_cells_for_unknown_tag.
func spawn_count_dropped(record: Dictionary, library: TerrainModuleLibrary, parent: Node3D) -> int:
	var tag: String = _lookup_tag(String(record["variant_tag"]))
	var modules: TerrainModuleList = library.get_by_tags(TagList.new([tag]))
	if modules.is_empty():
		return 1  # Dropped: no module for this tag.
	var inst: TerrainModuleInstance = spawn_placement(record, library, parent)
	return 0 if inst != null else 1  # Dropped if spawn_placement failed.
