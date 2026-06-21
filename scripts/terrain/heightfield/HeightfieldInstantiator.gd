class_name HeightfieldInstantiator
extends RefCounted

## Turns the heightfield plan into placement records and (Task 3) real tiles.
## A placement record is {variant_tag, family, world_x, world_z, origin_y, yaw}.

## Flat 24x24 ground plate (same mesh as GroundTile) baked under cliff/level edge
## tiles so the ground extends beneath their inset, overhanging walls — the tiles
## are hollow shells whose walls sit ~1.5m in from the footprint edge, so without
## this you see a void under the lip and into the hollow interior.
const _BASE_FILL_SCENE: PackedScene = preload("res://terrain/gltf/hill_top_e_center_color_12.tscn")
const _STOREY_DROP: float = 4.0
const _LEVEL_DROP: float = 0.5

## Inner-corner cliff tile, stacked one storey below a convex corner whose diagonal
## drops two storeys. The cardinal clamp lets a corner column (storey S) sit one
## diagonal step above a pit (storey S-2), cardinals clamped to S-1 between. The
## S-1 interior corner of that pit belongs at the corner column, but the column's
## surface tile is the S convex corner — a single tile can't be a corner a storey
## below itself — so we stack the inner corner at S-1 to fill it.
# Sloped, C1-mating concave bottom half: pairs with the CliffCornerStacked convex
# top half on the column above (see placement_for_cell) so the 2-storey corner is
# continuous. (Levels are still sheer / out of scope for slopes.)
const _INNER_CORNER_SCENE: PackedScene = preload("res://terrain/scenes/slope/CliffInCornerStacked.tscn")
const _LEVEL_INNER_CORNER_SCENE: PackedScene = preload("res://terrain/scenes/LevelInCorner.tscn")
# diagonal socket -> [adjoining cardinal offsets, diagonal cell offset]
const _CORNER_DIAGS: Array = [
	["frontright", Vector2i(0, -1), Vector2i(1, 0), Vector2i(1, -1)],
	["backright", Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1)],
	["backleft", Vector2i(0, 1), Vector2i(-1, 0), Vector2i(-1, 1)],
	["frontleft", Vector2i(0, -1), Vector2i(-1, 0), Vector2i(-1, -1)],
]

## When true, every cliff/level tile gets a floating Label3D showing its variant
## tag + cell coords + storey/level — a diagnostic overlay for inspecting tiling
## bugs in-game. Toggled via TerrainGenerator.DEBUG_TILE_LABELS.
static var debug_labels: bool = false

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
	var understacks: Array = _understack_corners(plan, cx, cz, int(tp["storey"]), int(tp["level"]))
	# A convex corner sitting above a cliff understack (the concave bottom half is
	# spawned one storey below) uses the mating CONVEX TOP half so the 2-storey corner
	# is one continuous C1 slope instead of a ledge.
	var variant_tag: String = String(desc["variant_tag"])
	if variant_tag == "cliff-corner":
		for u in understacks:
			if not bool(u["is_level"]):
				variant_tag = "cliff-corner-stacked"
				break
	return {
		"variant_tag": variant_tag,
		"family": desc["family"],
		"world_x": float(cx) * HeightfieldPlan.TILE,
		"world_z": float(cz) * HeightfieldPlan.TILE,
		"origin_y": float(desc["origin_y"]),
		"yaw": HeightfieldFacing.yaw_for_rotation_steps(int(desc["rotation_steps"])),
		"understacks": understacks,
	}


## Inner-corner tiles to stack one TIER below this cell — one per corner whose
## DIAGONAL drops two tiers (its two adjoining cardinals clamped to one between).
## That lower interior corner belongs at this (taller) column but its surface tile
## sits a tier higher, so we stack the inner corner (notch facing the pit). Works
## for both tiers: a storey corner (diagonal 2 storeys down) gets a cliff inner
## corner one storey (4m) down; a level corner (same storey, diagonal 2 levels
## down) gets a level inner corner one level (0.5m) down. Each entry is
## {yaw, drop, is_level}; a corner has one such diagonal, a peninsula can have two.
static func _understack_corners(plan, cx: int, cz: int, storey: int, level: int) -> Array:
	var out: Array = []
	for entry in _CORNER_DIAGS:
		var socket: String = entry[0]
		var c1: Vector2i = entry[1]
		var c2: Vector2i = entry[2]
		var d: Vector2i = entry[3]
		var s1: int = plan.storey_at(cx + c1.x, cz + c1.y)
		var s2: int = plan.storey_at(cx + c2.x, cz + c2.y)
		var sd: int = plan.storey_at(cx + d.x, cz + d.y)
		var yaw: float = HeightfieldFacing.yaw_for_rotation_steps(
			int(HeightfieldVariant.variant_for_missing([socket])["rotation_steps"]))
		if s1 == storey - 1 and s2 == storey - 1 and sd == storey - 2:
			out.append({"yaw": yaw, "drop": _STOREY_DROP, "is_level": false})
		elif s1 == storey and s2 == storey and sd == storey:
			# Same storey: check the level tier for the same two-tiers-down pattern.
			if (plan.level_at(cx + c1.x, cz + c1.y) == level - 1
					and plan.level_at(cx + c2.x, cz + c2.y) == level - 1
					and plan.level_at(cx + d.x, cz + d.y) == level - 2):
				out.append({"yaw": yaw, "drop": _LEVEL_DROP, "is_level": true})
	return out


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
	var understacks: Array = record.get("understacks", [])
	# Skip the flat base plate when an understack is present: the understack's
	# inner-corner top IS the tier-below floor (correctly notched toward the pit),
	# whereas the base plate is a full square that would float over the pit and
	# z-fight the understack top (the reported "superimposed center tile").
	if understacks.is_empty():
		_add_base_fill(inst, String(record["family"]), tag)
	_add_understack_corners(inst, understacks)
	if debug_labels:
		_add_debug_label(inst, record)
	return inst


## Stack inner-corner tiles one tier below this cell (children of its root, so
## they evict with it) to render the corners of two-tier diagonal drops. A cliff
## corner (storey drop) stacks a cliff inner corner one storey (4m) down; a level
## corner (level drop within a storey) stacks a level inner corner one level
## (0.5m) down. Each gets its own base plate so the ground reads under its lip.
static func _add_understack_corners(inst: TerrainModuleInstance, understacks: Array) -> void:
	var parent_yaw: float = inst.transform.basis.get_euler().y
	for u in understacks:
		var drop: float = float(u["drop"])
		var scene: PackedScene = _LEVEL_INNER_CORNER_SCENE if bool(u["is_level"]) else _INNER_CORNER_SCENE
		var tile: Node3D = scene.instantiate()
		# Local to this tile (origin at its top): one tier down, rotated from the
		# parent's yaw to the inner corner's absolute yaw.
		tile.transform = Transform3D(
			Basis(Vector3.UP, float(u["yaw"]) - parent_yaw),
			Vector3(0.0, -drop, 0.0))
		inst.root.add_child(tile)
		# Base plate one tier below the understack, so the ground extends under
		# its inset wall (the reported "tile below peeking through").
		var fill: Node3D = _BASE_FILL_SCENE.instantiate()
		fill.position = Vector3(0.0, -drop, 0.0)
		tile.add_child(fill)


## Floating label over a cliff/level tile: variant tag, cell coords, storey/level.
static func _add_debug_label(inst: TerrainModuleInstance, record: Dictionary) -> void:
	var family: String = String(record["family"])
	if family != "cliff" and family != "level":
		return
	var cxv: int = int(round(float(record["world_x"]) / HeightfieldPlan.TILE))
	var czv: int = int(round(float(record["world_z"]) / HeightfieldPlan.TILE))
	var oy: float = float(record["origin_y"])
	var storey: int = int(floor(oy / _STOREY_DROP))
	var lvl: int = int(round((oy - float(storey) * _STOREY_DROP) / _LEVEL_DROP))
	var lbl: Label3D = Label3D.new()
	lbl.text = "%s\n(%d,%d) s%d.%d" % [String(record["variant_tag"]).replace("cliff-", "C:").replace("level-", "L:"), cxv, czv, storey, lvl]
	lbl.font_size = 64
	lbl.pixel_size = 0.012
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.modulate = Color.YELLOW if String(record["variant_tag"]).ends_with("interior") else Color.WHITE
	lbl.outline_size = 16
	lbl.position = Vector3(0.0, 1.0, 0.0)
	inst.root.add_child(lbl)


## Bake a flat ground plate under a cliff/level EDGE tile (one with walls), one
## step below its top, so the ground reads continuously beneath the overhanging
## lip. Interior/center variants have no walls (no exposed drop) and need none.
static func _add_base_fill(inst: TerrainModuleInstance, family: String, tag: String) -> void:
	if family != "cliff" and family != "level":
		return
	if tag.ends_with("interior") or tag.ends_with("center"):
		return
	var drop: float = _STOREY_DROP if family == "cliff" else _LEVEL_DROP
	var fill: Node3D = _BASE_FILL_SCENE.instantiate()
	fill.position = Vector3(0.0, -drop, 0.0)
	inst.root.add_child(fill)


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
