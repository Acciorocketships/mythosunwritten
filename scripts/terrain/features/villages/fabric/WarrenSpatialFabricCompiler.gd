class_name WarrenSpatialFabricCompiler
extends RefCounted

## Measured-construction adapter for the authoritative 3D town.  This initial
## phase realizes every exact WarrenRoomStamp and its true bearing/party-wall
## relationships. Composed features are then realized from their already-sealed
## construction records before roofs are selected around the resulting measured
## envelopes. No method here may move, resize, or restamp the spatial topology.
static var last_failure := ""
static var last_audit: Dictionary = {}
## TASK F2. Per-stage wall clock for ONE compile, printed rather than stamped:
## the fabric compile is the second cost of a maze solve and `solve` is a
## fifteen-step pipeline, so "the compile is 1.9 s" needed a breakdown before
## anything could be done about it. Diagnostic only -- no sealed audit sees
## these numbers -- and off by default.
static var diagnostic_trace_timing := false
## Every campaign-flatten decision this compile, preserved across the atomic
## retry recursion so the sealed audit names the actual colliding unit.

## Facade and roof colour is owned by a jittered architectural district rather
## than hashed independently per room. Twelve fine cells are 18 m: large enough
## for neighbouring storeys and party-wall houses to read as one historical
## quarter, but small enough for even the compact town to contain several
## palettes. Jittered Voronoi ownership avoids visible square zoning seams.
const ARCHITECTURAL_DISTRICT_CELLS := 12
const ARCHITECTURAL_DISTRICT_JITTER := 4
## Maximum measured horizontal penetration for a thin setback cap to become
## typed facade flashing. Half a 1.5 m fine cell plus 0.15 m of authored-frame
## tolerance closes the reviewed projecting facades while remaining well below
## a whole room cell. Height has its own much tighter thin-cap limit below.
const SHALLOW_FLASHING_MAX_OVERLAP_M := 0.90
const SHALLOW_FLASHING_MAX_HEIGHT_M := 0.25
## A flat closure smaller than a complete 6 x 6 m building plate reads as the
## exposed lid of a module, even when a planter is placed on it.  Small rooms
## must resolve to a complete pitched crown; broad plates may retain the finite
## terrace/garden fallback while the future court grammar owns true walkable
## roof plazas.
const MIN_INTENTIONAL_FLAT_ROOF_FACE_COUNT := 16
## TASK C5e RULING 1 -- the authored modules a PARTIAL flat plate is tiled
## with, and the whole of the vocabulary that tiling may use. The ORDER is
## the authored slabs before the thin caps, largest first within each family:
## a remainder two cells wide takes the slab that a whole crown takes, and the
## thin cap is reached only by a shape no slab fits.
## A flat crown another storey stands on part of has no single `roof.flat.*`
## unit for the shape that is left over, and every one of the eight
## partial-plate seeds C5d measured died of exactly that.
##
## A partial private crown is weathered with the exact-footprint authored gable
## halves assembled below, never a walk deck, window canopy, or bare floor-plank
## slab. Flat tiles are admitted only when the exact source cell carries a
## PUBLIC_FLOOR face; that is a terrace/walkway construction fact, not a roof
## fallback. The empty base list is deliberate and keeps older callers/tests
## naming the finite vocabulary while making the private-roof rule impossible
## to bypass.
const FLAT_PLATE_TILE_RECIPES: Array[StringName] = []
## TASK H2 PART 4. The feature kinds that put a room, a gallery or a gateway
## out over air and owe the eye a visible brace under it -- the ones whose
## compilers emit `cantilever_support` shells. Named once so the bracket audit
## and any later reader cannot drift from the four `match` arms that build
## them.
const OVERHANG_SUPPORT_FEATURE_KINDS: Array[StringName] = [
	&"room_outcropping", &"room_overhang_support",
	&"frontier_gateway_support", &"arcade_overhang_support",
]
## TASK H2 PART 3. How a surviving flat crown is dressed, as eight seeded
## eighths: three take the RICH accent (a chimney on a narrow plate, a pergola
## awning and a second planting cluster on a broad one), two the plain planter,
## one a single flower clump, and TWO STAY BARE. The reference shows most
## terraces carrying something and none of them carrying everything, which is
## a distribution rather than a rule; this is that distribution, and it is a
## look dial -- `maze_dressed_crown_ratio` is the measurement that says whether
## the town needs another eighth either way.
const CROWN_DRESSING_TIERS: Array[StringName] = [
	&"rich", &"rich", &"rich", &"plain", &"plain", &"micro", &"", &"",
]
## The reviewed foundation asset is exactly 3 m tall on the 1.5 m sectional
## lattice. A retained house datum more than two bands above natural ground
## would therefore leave daylight beneath the stone. Reject that source
## construction instead of pretending one floating course reaches the terrain.
const FOUNDATION_MODULE_HEIGHT_BANDS := 2
## Grid owner of every fine cell maze mode keeps as STONE rather than building
## in: a flat-roofed plot's slab course and the leftover rock the town was cut
## out of (Task C5 rulings 2 and 3). `WarrenVolumetricSolver` assigns it; this
## file is where the fact is consumed -- as bearing for a house stacked on a
## flat roof, and as retained terrace the assembler renders in stone -- so the
## name lives here and the dependency runs one way.
const MAZE_RETAINED_STONE_ID := &"spatial.feature.maze_stone.00"
## TASK H1. One building lineage in this many wears a masonry GROUND STOREY;
## every other house is plank and plaster to its plinth course. See
## `_takes_stone_base`. Raising it removes stone from the streetscape and
## lowering it adds it back, and `exterior_wall_material_profile` is the
## measurement that says which the town needs.
## TASK I5 lowers this from four to three as a CANDIDATE rate. The final set is
## admitted by `_bounded_stone_base_lineages`, which keeps the authored stone
## share below the town-wide face budget instead of letting one compact seed's
## large lineages turn the whole settlement into a fortress.
const STONE_BASE_LINEAGE_MODULUS := 3
const STONE_BASE_FACE_RATIO_TARGET := 0.22
const STONE_BASE_SELECTION_MARKER := &"__bounded_stone_base_selection__"
## The two material families `exterior_wall_material_profile` sorts every
## exterior wall face into. `_room_recipe_facade_family` answers with the
## recipe's own vocabulary name -- `rock` for a terrain-bearing masonry base and
## `stone` for the (now unselected) masonry upper storeys -- and both of those
## are ashlar to a viewer, so the metric folds them together and calls
## everything else timber.
const STONE_WALL_FAMILIES: Array[StringName] = [&"rock", &"stone"]
## Grid uses that make a room's lateral face an EXTERIOR wall face. A face onto
## another room's private volume is a party wall the viewer never sees, and a
## face onto structural volume is buried in retained rock or a neighbour's
## construction; neither is a wall this metric may count.
const EXTERIOR_WALL_NEIGHBOUR_USES: Array[int] = [
	WarrenSpatialGrid.Use.OUTSIDE, WarrenSpatialGrid.Use.ALLOCATABLE,
	WarrenSpatialGrid.Use.PUBLIC_AIR, WarrenSpatialGrid.Use.DAYLIGHT_AIR,
]
## The offset above a room's own local street datum at which a wall is no
## longer any kind of base. Stone above it is the fortress the user rejected,
## so the audit counts it separately and the suites pin it.
const WALL_BASE_BAND_OFFSET := 1


static func _trace_stage(stage: String, started_ms: int) -> int:
	if diagnostic_trace_timing:
		print("FABRIC_TIMING ", stage, " ms=", Time.get_ticks_msec() - started_ms)
	return Time.get_ticks_msec()


static func _planned_plaza_support_cells(source: WarrenSpatialPlan) \
		-> Dictionary:
	## Translate only the source plot planner's typed plaza rectangle. Macro
	## columns expand to the same exact 2 x 2 fine lattice used by the volumetric
	## solver; subtracting one band names the structural cell whose top is the
	## public walk plane. Ordinary deck/court plots are deliberately excluded.
	var out: Dictionary = {}
	if source == null or source.source_volume == null:
		return out
	var maze := source.source_volume.mass_context.get(&"maze_source_plan") \
		as WarrenMazeSourcePlan
	if maze == null:
		return out
	for plot_value: Variant in maze.plots:
		var plot := plot_value as Dictionary
		if StringName(plot.get("id", &"")) \
				!= WarrenPlotReservations.PLAZA_PLOT_ID:
			continue
		var floor_band := int(plot["floor"])
		for column_value: Variant in plot["cells"] as Array:
			var column := column_value as Vector2i
			var origin := Vector3i(column.x * 2, floor_band - 1,
				column.y * 2)
			for offset: Vector3i in [Vector3i.ZERO, Vector3i.RIGHT,
					Vector3i.BACK, Vector3i(1, 0, 1)]:
				out[origin + offset] = true
		break
	return out


static func solve(source: WarrenSpatialPlan,
		program: SettlementFabricProgram) -> SettlementFabricPlan:
	## Compile the authoritative spatial town through the same sealed fabric,
	## surface, exterior-air, and solid/void transaction used by production.
	## Nothing in this adapter may infer a replacement footprint or route.
	last_failure = ""
	last_audit = {}
	if source == null or not source.is_sealed() or program == null:
		last_failure = "missing sealed spatial town or measured vocabulary"
		return null
	var solve_started_ms := Time.get_ticks_msec()
	var realm := WarrenSpatialPublicRealmAdapter.from_spatial(source)
	if realm == null:
		last_failure = "public realm adaptation failed: %s" % \
			WarrenSpatialPublicRealmAdapter.last_failure
		return null
	var stage_ms := _trace_stage("realm", solve_started_ms)
	var rooms := source.compiled_room_units_cache()
	var room_audit := source.compiled_room_audit_cache()
	if rooms.is_empty():
		rooms = compile_room_units(source, program)
		if rooms.is_empty():
			return null
		room_audit = last_audit.duplicate(true)
		source.cache_compiled_room_units(rooms, room_audit)
	stage_ms = _trace_stage("rooms", stage_ms)
	var features := compile_feature_units(source, program, rooms)
	if features.is_empty() and _constructed_feature_count(source) > 0:
		return null
	var feature_audit := last_audit.duplicate(true)
	stage_ms = _trace_stage("features", stage_ms)
	var roofs := compile_roof_units(source, program, rooms, features)
	if roofs.is_empty():
		return null
	var roof_audit := last_audit.duplicate(true)
	stage_ms = _trace_stage("roofs", stage_ms)
	var modular_box_audit := _modular_box_use_audit(source, program, rooms,
		roofs)
	if int(modular_box_audit.get("modular_box_unclassified_count", 0)) > 0 \
			or int(modular_box_audit.get("modular_box_roofless_house_count", 0)) \
				> 0 \
			or int(modular_box_audit.get("modular_box_partial_bearing_count", 0)) \
				> 0:
		last_failure = "spatial modular-box contract failed: %s" % \
			JSON.stringify(modular_box_audit.get(
				"modular_box_invalid_details", []))
		return null
	stage_ms = _trace_stage("modular_box", stage_ms)
	var result := SettlementFabricPlan.new(StringName("%s.fabric" % \
		source.stable_id))
	# TASK I2. The mass skin's facade families come out of the same district
	# field the room recipes above were chosen through, so the plan carries the
	# seed that field is a function of. Set BEFORE any skin is derived --
	# `_maze_stone_skin_audit` reads it off an unsealed plan.
	result.world_seed = source.world_seed
	if not result.set_asset_visual_bounds(program.asset_visual_bounds):
		last_failure = "could not attach measured fabric asset contracts"
		return null
	if not result.set_public_realm(realm):
		last_failure = "could not attach authoritative spatial public realm"
		return null
	for recipe: FabricRecipe in program.recipes():
		if not result.register_recipe(recipe):
			last_failure = "could not register recipe %s" % recipe.recipe_id
			return null
	for unit: FabricUnit in rooms:
		if not result.add_unit(unit):
			last_failure = "room %s rejected by common fabric: %s" % [
				unit.stable_id, result.last_rejection]
			return null
	for unit: FabricUnit in features:
		if not result.add_unit(unit):
			last_failure = "feature component %s rejected by common fabric: %s" % [
				unit.stable_id, result.last_rejection]
			return null
	for unit: FabricUnit in roofs:
		if not result.add_unit(unit):
			last_failure = "roof %s rejected by common fabric: %s" % [
				unit.stable_id, result.last_rejection]
			return null
	# The occupied-link grammar runs after the complete room/roof massing exists
	stage_ms = _trace_stage("add_units", stage_ms)
	var foundation_result := _retained_foundation_cells(source, result)
	if not bool(foundation_result.get("valid", false)) \
			or not result.set_retained_terrace(
				foundation_result.get("cells", {}) as Dictionary):
		last_failure = "spatial terrain foundations failed: %s" % String(
			foundation_result.get("rejection", "overlaps built mass"))
		return null
	var foundation_audit := _foundation_shell_audit(foundation_result, result)
	if int(foundation_audit.get("foundation_incomplete_shell_count", 0)) > 0 \
			or int(foundation_audit.get("foundation_missing_face_count", 0)) > 0 \
			or int(foundation_audit.get("foundation_floating_column_count", 0)) > 0:
		last_failure = "spatial terrain foundation shell is incomplete: %s" % \
			str(foundation_audit)
		return null
	stage_ms = _trace_stage("foundation", stage_ms)
	# The typed green precedes the surface transaction: guard construction needs
	# its exact mouths, so declaring it after the surface sealed made the topology
	# and the later render audit observe different squares.
	var planned_plaza := _planned_plaza_support_cells(source)
	if not result.set_planned_plaza(planned_plaza):
		last_failure = "planned village green topology is invalid"
		return null
	var surfaces := PublicRealmSurfaceSolver.solve(
		StringName("%s.surfaces" % result.stable_id), realm, result,
		source.source_volume)
	if surfaces == null or not result.set_surface_plan(surfaces):
		last_failure = "spatial public-surface closure failed"
		return null
	stage_ms = _trace_stage("surfaces", stage_ms)
	# TASK I4 ROUND 7. The two withdrawals that need the WHOLE town: a dressing
	# module buried in the retained skin, and a brace standing its collider in the
	# body column of a street. Both are decided here -- after the surface plan,
	# which is what says where the realm walks, and BEFORE the skin audit, so the
	# audit and the payload measure the town that is really built.
	var construction_crowns: Dictionary = {}
	for crown_value: Variant in roof_audit.get(
			"maze_construction_crown_unit_ids", []) as Array:
		construction_crowns[StringName(crown_value)] = true
	# Exterior circulation is topology, not a visual guess. Resolve its complete
	# street/terrace/skywalk component before optional dressing is withdrawn, so
	# a roof made reachable by a bridge receives the same swept-clearance contract
	# as a street and cannot keep a planter in the player's lane.
	var exterior_network := SettlementFabricAssembler.maze_exterior_network(
		result, construction_crowns)
	var suppression_audit := _suppress_intruding_modules(result,
		exterior_network.get("terrace_cells", {}) as Dictionary)
	stage_ms = _trace_stage("suppress_intruding", stage_ms)
	var volumes := FabricVolumeClassifier.solve(
		StringName("%s.volumes" % result.stable_id), realm, result)
	if volumes == null or not result.set_volume_plan(volumes):
		last_failure = "spatial exterior-air proof failed: %s %s" % [
			FabricVolumeClassifier.last_failure,
			JSON.stringify(FabricVolumeClassifier.last_diagnostic)]
		return null
	# TASK E4 ruling 1. `source_volume` is optional on a spatial plan (see
	# WarrenSpatialPlan._source_route_lineage_audit), so the maze source is
	# resolved defensively: without one the band profile below is all zeroes,
	# exactly as it is for every legacy town.
	var maze_source: WarrenMazeSourcePlan = null \
		if source.source_volume == null \
		else source.source_volume.mass_context.get(&"maze_source_plan") \
			as WarrenMazeSourcePlan
	stage_ms = _trace_stage("volumes", stage_ms)
	# TASK I3. The crown list rides in because the skywalk rule needs the town's
	# open flat crowns and the plan does not carry them until `seal`; the skin
	# audit is the one pass that already holds the shell those spans and the
	# outcroppings are measured against, so deriving them here costs one units
	# scan rather than a second shell.
	var stone_audit := _maze_stone_skin_audit(result, maze_source,
		source.grid, roof_audit.get("maze_construction_crown_unit_ids", []) as Array)
	if int(stone_audit.get("maze_stone_missing_face_count", 0)) > 0 \
			or int(stone_audit.get("maze_stone_doubled_cap_count", 0)) > 0 \
			or int(stone_audit.get("maze_turf_backed_facade_count", 0)) > 0:
		last_failure = ("retained maze stone is not fully skinned " \
			+ "(missing=%d %s doubled_caps=%d turf_facades=%d): %s") % [
				int(stone_audit.get("maze_stone_missing_face_count", 0)),
				str(stone_audit.get("maze_stone_missing_faces", [])),
				int(stone_audit.get("maze_stone_doubled_cap_count", 0)),
				int(stone_audit.get("maze_turf_backed_facade_count", 0)),
				str(stone_audit)]
		return null
	stage_ms = _trace_stage("stone_skin", stage_ms)
	var solid_void := FabricSolidVoidClassifier.solve(
		StringName("%s.solid-void" % result.stable_id), realm, result)
	if solid_void == null or not result.set_solid_void_plan(solid_void):
		last_failure = "spatial solid/void proof failed: %s" % \
			FabricSolidVoidClassifier.last_failure
		return null
	stage_ms = _trace_stage("solid_void", stage_ms)
	var lineage := source.audit.duplicate(true)
	lineage.merge(source.construction_plan.audit, true)
	lineage.merge(room_audit, true)
	lineage.merge(feature_audit, true)
	lineage.merge(roof_audit, true)
	lineage.merge(modular_box_audit, true)
	lineage["retained_foundation_cell_count"] = int(
		foundation_result.get("cell_count", 0))
	lineage["retained_foundation_column_count"] = int(
		foundation_result.get("column_count", 0))
	lineage["retained_foundation_max_depth_bands"] = int(
		foundation_result.get("max_depth_bands", 0))
	# TASK F3 MEMBER 6. Retained plinth cells -- foundation span or masonry
	# course -- the fabric had already built in, and which therefore never
	# entered the retained channel; see `_retained_foundation_cells`. Zero on
	# every flat corpus town, 6 on the D1 `step/3/standard` row.
	lineage["retained_foundation_built_in_cell_count"] = int(
		foundation_result.get("built_in_cell_count", 0))
	# Final retained terrain is resolved only after every measured roof and
	# structural cell exists. Publish both constructive withdrawals so visual
	# review can distinguish a roof-volume intersection from a detached source
	# scaffold without re-inferring either from render placements.
	for key: StringName in [&"maze_stone_withdrawn_for_roof_cells",
			&"maze_stone_withdrawn_for_roof_cell_keys",
			&"maze_unsupported_stone_cells_removed",
			&"maze_unsupported_stone_components_removed",
			&"maze_unsupported_stone_cell_keys"]:
		lineage[key] = foundation_result.get(key, 0 if String(key).ends_with(
			"cells") or String(key).ends_with("removed") else [])
	lineage.merge(foundation_audit, true)
	lineage.merge(suppression_audit, true)
	lineage.merge(stone_audit, true)
	# TASK H1. The wall metric rides beside the rock metric, never instead of
	# it: `stone_audit` above says how much MOUNTAIN shows, this says what the
	# TOWN WEARS, and the two are read together.
	lineage.merge(exterior_wall_material_profile(source, rooms, maze_source),
		true)
	lineage.merge(_maze_terrace_audit(result, roof_audit.get(
		"maze_construction_crown_unit_ids", []) as Array), true)
	lineage.merge(volumes.audit(), true)
	lineage.merge(solid_void.audit(), true)
	lineage["spatial_signature"] = source.deterministic_signature().sha256_text()
	lineage["construction_signature"] = result.construction_signature()
	lineage["generation_source"] = &"spatial_volumetric_warren"
	stage_ms = _trace_stage("lineage", stage_ms)
	var audit := SettlementFabricSolver.audit_plan(result, lineage)
	if int(audit.get("orphan_exterior_door_module_count", 0)) > 0 \
			or int(audit.get("entrance_surface_gap_count", 0)) > 0:
		last_failure = "spatial visible-door contract failed: %s / %s" % [
			str(audit.get("orphan_exterior_door_module_details", [])),
			str(audit.get("entrance_surface_gap_details", []))]
		return null
	# Preserve the generic unit-name grouping as a diagnostic, but do not let it
	# replace the source plan's explicit private-access proof. Recomposition makes
	# one WarrenBuildingVolume per connected 3D owner, and its parent links are the
	# only authoritative statement that an unaddressed segment reaches a doorway.
	for key: StringName in [&"building_stack_count",
			&"connected_building_stack_count", &"detached_building_stack_count"]:
		audit[StringName("legacy_unit_group_%s" % key)] = audit.get(key, -1)
		audit[key] = source.audit.get(key, -1)
	stage_ms = _trace_stage("audit_plan", stage_ms)
	if not result.seal(audit):
		last_failure = "spatial common-fabric seal failed: %s" % \
			result.last_rejection
		return null
	stage_ms = _trace_stage("seal", stage_ms)
	last_audit = audit
	return result

static func _modular_box_use_audit(source: WarrenSpatialPlan,
		program: SettlementFabricProgram, room_units: Array[FabricUnit],
		roof_units: Array[FabricUnit]) -> Dictionary:
	## A compact 3 m x 3 m room is useful vocabulary, but it may not become a
	## pasted-on voxel. Every such room must be one of the authored uses reviewed
	## for the town: a fully borne course in a real stack, a two-ended occupied
	## bridge, or the top room of a compact house with an actual roof. Larger
	## cantilevers have their own typed support transaction; a tower-sized room
	## never inherits that exception.
	var room_by_id: Dictionary = {}
	var room_by_unit_id: Dictionary = {}
	var unit_by_room_id: Dictionary = {}
	var room_id_by_cell: Dictionary = {}
	for building: WarrenBuildingVolume in source.buildings:
		for room: WarrenRoomStamp in building.room_records:
			room_by_id[room.stable_id] = room
			for cell: Vector3i in room.private_cells:
				room_id_by_cell[cell] = room.stable_id
	for unit: FabricUnit in room_units:
		var room_id := StringName(String(unit.stable_id).trim_prefix(
			"spatial.fabric."))
		if not room_by_id.has(room_id):
			continue
		unit_by_room_id[room_id] = unit
		room_by_unit_id[unit.stable_id] = room_by_id[room_id]
	var roofs_by_parent: Dictionary = {}
	for roof: FabricUnit in roof_units:
		var recipe := program.recipe(roof.recipe_id)
		if recipe == null or not recipe.has_tag(&"roof"):
			continue
		for parent_id: StringName in roof.parent_ids:
			if not room_by_unit_id.has(parent_id):
				continue
			var owned := roofs_by_parent.get(parent_id,
				[] as Array[FabricUnit]) as Array[FabricUnit]
			owned.append(roof)
			roofs_by_parent[parent_id] = owned
	var tower_count := 0
	var roofed_house_count := 0
	var support_course_count := 0
	var public_crown_support_count := 0
	var skywalk_count := 0
	var roofless_house_count := 0
	var partial_bearing_count := 0
	var unclassified_count := 0
	var details: Array[Dictionary] = []
	var invalid_details: Array[Dictionary] = []
	var room_ids: Array[StringName] = []
	room_ids.assign(room_by_id.keys())
	room_ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	for room_id: StringName in room_ids:
		var room := room_by_id[room_id] as WarrenRoomStamp
		if room.kind != &"tower":
			continue
		tower_count += 1
		var unit := unit_by_room_id.get(room_id) as FabricUnit
		var upper_room_ids: Dictionary = {}
		var footprint_columns: Dictionary = {}
		var borne_columns: Dictionary = {}
		var public_crown_columns: Dictionary = {}
		for cell: Vector3i in room.private_cells:
			if cell.y == room.lattice_origin.y:
				footprint_columns[Vector2i(cell.x, cell.z)] = true
			if cell.y != room.lattice_origin.y \
					+ WarrenSpatialGrid.STOREY_CELLS - 1:
				continue
			var crown_claim := source.grid.face_claim(cell, Vector3i.UP)
			if source.grid.use_at(cell + Vector3i.UP) \
					== WarrenSpatialGrid.Use.PUBLIC_AIR \
					and int(crown_claim.get("kind", -1)) \
						== WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR:
				public_crown_columns[Vector2i(cell.x, cell.z)] = true
			var upper_id := StringName(room_id_by_cell.get(cell + Vector3i.UP,
				&""))
			if not upper_id.is_empty() and upper_id != room_id:
				upper_room_ids[upper_id] = true
		if room.terrain_bearing \
				or _bears_on_retained_stone(source.grid, room):
			# Retained stone is a complete bearing plate (Task C5 ruling 2), so
			# a compact room standing on a flat roof's slab is as borne as one
			# standing on the ground.
			borne_columns = footprint_columns.duplicate()
		elif unit != null:
			for parent_id: StringName in unit.parent_ids:
				var parent := room_by_unit_id.get(parent_id) as WarrenRoomStamp
				if parent == null:
					continue
				for column_value: Variant in footprint_columns.keys():
					var column := column_value as Vector2i
					if parent.has_private_cell(Vector3i(column.x,
							room.lattice_origin.y - 1, column.y)):
						borne_columns[column] = true
		var bridge_supports := room.audit.get(
			"bridge_support_room_ids", []) as Array
		var bridge_endpoint_details: Array[Dictionary] = []
		for support_value: Variant in bridge_supports:
			var support_id := StringName(support_value)
			var support_room := room_by_id.get(support_id) as WarrenRoomStamp
			if support_room == null:
				continue
			bridge_endpoint_details.append({
				"room_id": support_room.stable_id,
				"source_parcel_id": support_room.source_parcel_id,
				"origin": support_room.lattice_origin,
				"kind": support_room.kind,
				"terrain_bearing": support_room.terrain_bearing,
				"support_parent_parcel_id":
					support_room.support_parent_parcel_id,
				"support_parent_storey_index":
					support_room.support_parent_storey_index,
			})
		var is_skywalk := bridge_supports.size() == 2
		var owned_roofs := roofs_by_parent.get(
			unit.stable_id if unit != null else &"",
			[] as Array[FabricUnit]) as Array[FabricUnit]
		var classification := &""
		if is_skywalk:
			classification = &"occupied_skywalk"
			skywalk_count += 1
		elif borne_columns.size() != footprint_columns.size():
			classification = &"partial_bearing"
			partial_bearing_count += 1
		elif not upper_room_ids.is_empty():
			classification = &"support_course"
			support_course_count += 1
		elif public_crown_columns.size() == footprint_columns.size():
			# A compact module carrying a complete public plaza is a structural
			# foundation course, not a roofless house.  The public surface owns its
			# weathering/collision above, and all four columns are required so an
			# arbitrary balcony corner or retained-grass lip cannot qualify.
			classification = &"public_crown_support"
			public_crown_support_count += 1
		elif not owned_roofs.is_empty():
			classification = &"roofed_compact_house"
			roofed_house_count += 1
		else:
			classification = &"roofless_house"
			roofless_house_count += 1
		if unit == null or classification.is_empty():
			classification = &"unclassified"
			unclassified_count += 1
		var roof_ids: Array[StringName] = []
		for roof: FabricUnit in owned_roofs:
			roof_ids.append(roof.stable_id)
		var detail := {"room_id": room_id,
			"classification": classification,
			"room_kind": room.kind,
			"room_origin": room.lattice_origin,
			"room_flat_roof": room.flat_roof,
			"room_recipe_id": unit.recipe_id if unit != null else &"",
			"terrain_bearing": room.terrain_bearing,
			"bearing_column_count": borne_columns.size(),
			"footprint_column_count": footprint_columns.size(),
			"upper_room_ids": upper_room_ids.keys(),
			"roof_unit_ids": roof_ids,
			"public_crown_column_count": public_crown_columns.size(),
			"bridge_support_count": bridge_supports.size(),
			"bridge_support_room_ids": bridge_supports.duplicate(),
			"bridge_support_directions": (room.audit.get(
				"bridge_support_directions", []) as Array).duplicate(),
			"bridge_support_building_ids": (room.audit.get(
				"bridge_support_building_ids", []) as Array).duplicate(),
			"bridge_endpoint_details": bridge_endpoint_details}
		if details.size() < 32:
			details.append(detail)
		if classification in [&"partial_bearing", &"roofless_house",
				&"unclassified"] and invalid_details.size() < 16:
			invalid_details.append(detail)
	return {
		"modular_box_room_count": tower_count,
		"modular_box_roofed_house_count": roofed_house_count,
		"modular_box_support_course_count": support_course_count,
		"modular_box_public_crown_support_count": public_crown_support_count,
		"modular_box_skywalk_count": skywalk_count,
		"modular_box_roofless_house_count": roofless_house_count,
		"modular_box_partial_bearing_count": partial_bearing_count,
		"modular_box_unclassified_count": unclassified_count,
		"modular_box_details": details,
		"modular_box_invalid_details": invalid_details,
	}


static func _retained_foundation_cells(source: WarrenSpatialPlan,
		plan: SettlementFabricPlan = null) -> Dictionary:
	## Spatial rooms are flat constructions on a terrain-relative source plan.
	## Where a footprint crosses lower natural ground, retain the exact source
	## mass between that ground and the room datum.  Public tunnels were already
	## removed from source mass, so they can never be filled by this operation.
	var cells: Dictionary = {}
	var columns: Dictionary = {}
	var room_records: Array[Dictionary] = []
	var max_depth := 0
	var terrain_bearing_room_count := 0
	var flush_room_count := 0
	if source == null or source.source_volume == null \
			or source.source_volume.envelope == null:
		return {"valid": false, "rejection": "missing source terrain envelope"}
	var volume := source.source_volume
	# TASK C5c RULING 4. In the plot model a house begins at its PLOT's floor
	# and never descends through the mass beneath it, because that mass is the
	# plot below or the derived rock the source retains (see
	# `WarrenParcelConstruction._support_base_band`). A house on a tier is
	# therefore routinely more than one authored plinth course above natural
	# ground, and the retained stone Task C5b skins is what carries it. Such a
	# room takes NO plinth at all -- one course under a room standing six bands
	# up would be a floating stone skirt -- and the whole span below it is
	# already the maze-stone channel's.
	var maze_source := volume.mass_context.get(&"maze_source_plan") \
		as WarrenMazeSourcePlan
	var maze_mode := maze_source != null
	var maze_stone_borne_room_count := 0
	var tunnel_roof_support_by_room: Dictionary = {}
	for feature: WarrenFeatureReservation in source.features:
		if feature.kind != &"arcade_overhang_support" \
				or not bool(feature.audit.get(
					"arcade_is_tunnel_roof_support", false)):
			continue
		var supported_room := StringName(feature.audit.get(
			"arcade_upper_room_id", &""))
		if not supported_room.is_empty():
			tunnel_roof_support_by_room[supported_room] = feature.stable_id
	# TASK F3 MEMBER 6. What the fabric has ALREADY BUILT IN, read once for the
	# whole function. The retained channel carries mass nobody built in -- that
	# is what `SettlementFabricPlan.set_retained_terrace` refuses, and until
	# this task its guard compared the wrong key type and refused nothing. The
	# maze-stone half below has always subtracted this set; the PLINTH half did
	# not, in either of its two write sites -- the foundation SPAN under a room
	# and the masonry COURSE at its datum -- and on `step/3/standard` it put
	# six such cells straight through two houses' `roof.flat.*` slabs.
	#
	# `built_in_cells` collects every cell either write site drops, which is
	# why it is a SET: the top band of a span is also that room's course cell,
	# so the two sites can offer the same cell twice and a running counter
	# would double it.
	#
	# COST, stated (fix round 1, MINOR 2). This projection used to be taken
	# lazily by the maze half alone, and skipped entirely on a plan with no
	# retained maze stone. It is unconditional now, so a plan with no maze
	# stone pays one `transformed_cells(&"solid")` it used to skip. Measured
	# nil on everything that exists -- every town this repository produces is a
	# maze town that took the projection anyway, and the four planner solves
	# moved 2158->2166, 2149->2159, 3557->3531, 4327->4314 ms across the whole
	# task -- but it is an addition on that path, not a saving.
	var built_solid: Dictionary = {} if plan == null \
		else plan.transformed_cells(&"solid")
	var built_in_cells: Dictionary = {}
	for building: WarrenBuildingVolume in source.buildings:
		for room: WarrenRoomStamp in building.room_records:
			if not room.terrain_bearing:
				continue
			terrain_bearing_room_count += 1
			var footprint: Dictionary = {}
			for cell: Vector3i in room.private_cells:
				if cell.y == room.lattice_origin.y:
					footprint[Vector2i(cell.x, cell.z)] = true
			var bearing_by_column: Dictionary = {}
			var room_needs_plinth := false
			# Buffered, not committed: a maze room the span below turns out to
			# carry contributes no plinth cell at all, and a half-written
			# course is exactly the partial shell `_foundation_shell_audit`
			# refuses.
			var room_plinth_cells: Dictionary = {}
			var stone_borne := false
			var exact_undercroft_void := false
			for fine_column_value: Variant in footprint.keys():
				var fine_column := fine_column_value as Vector2i
				var macro_column := Vector2i(
					floori(float(fine_column.x) / 2.0),
					floori(float(fine_column.y) / 2.0))
				if not volume.envelope.contains_column(macro_column):
					return {"valid": false, "rejection":
						"terrain-bearing room %s leaves source ground at %s" % [
							room.stable_id, fine_column]}
				var bearing := volume.envelope.bearing_at(macro_column)
				bearing_by_column[fine_column] = bearing
				var support := room.lattice_origin.y
				if bearing > support:
					return {"valid": false, "rejection":
						"terrain-bearing room %s begins below ground %d > %d" % [
							room.stable_id, bearing, support]}
				var depth := 0
				var span_is_whole := true
				for band in range(bearing, support):
					if source.grid.use_at(Vector3i(fine_column.x, band,
							fine_column.y)) == WarrenSpatialGrid.Use.PUBLIC_AIR:
						exact_undercroft_void = true
					if not volume.has_mass(Vector3i(macro_column.x, band,
							macro_column.y)):
						span_is_whole = false
						break
					room_plinth_cells[Vector3i(fine_column.x, band,
						fine_column.y)] = true
					depth += 1
				# `rock_shoulder` is the source's own top of derived rock on a
				# column, and on a column carrying plots it IS that column's
				# lowest plot floor -- so a room standing above it stands on
				# ANOTHER PLOT's building, and a masonry course laid on that
				# building's roof would be a stone band between two houses.
				if maze_mode and (exact_undercroft_void or not span_is_whole \
						or depth > FOUNDATION_MODULE_HEIGHT_BANDS \
						or maze_source.rock_shoulder(macro_column) < support):
					# A tier, a tunnel roof, or a bored street under the hill:
					# the plot planner's own support rule already proved this
					# floor stands on something, and the mass below is stone or
					# another building rather than this room's masonry course.
					stone_borne = true
					continue
				if not span_is_whole:
					return {"valid": false, "rejection":
						("terrain-bearing room %s has a foundation void " \
						+ "between stamped ground %d and support %d at %s") % [
							room.stable_id, bearing, support, fine_column]}
				if depth > FOUNDATION_MODULE_HEIGHT_BANDS:
					return {"valid": false, "rejection":
						("terrain-bearing room %s needs %d foundation bands; " \
						+ "the authored stone course reaches only %d") % [
							room.stable_id, depth,
							FOUNDATION_MODULE_HEIGHT_BANDS]}
				if depth > 0:
					room_needs_plinth = true
					max_depth = maxi(max_depth, depth)
			if stone_borne:
				# A tunnel/undercroft is deliberately air under part of a room's
				# floor, so requiring every fine column to be solid contradicts the
				# source topology that created it.  Require a complete measured
				# floorplate to bear on source mass across at least half its exact
				# fine columns instead.  The sealed source guarantees those mass
				# columns continue to terrain; the public-air cells remain untouched
				# beneath the plate.  Zero or minority bearing is still a floating
				# room and rejects the transaction.
				var exact_bearing_columns := 0
				for fine_column_value: Variant in footprint.keys():
					var fine_column := fine_column_value as Vector2i
					var macro_column := Vector2i(
						floori(float(fine_column.x) / 2.0),
						floori(float(fine_column.y) / 2.0))
					var below := Vector3i(fine_column.x,
						room.lattice_origin.y - 1, fine_column.y)
					exact_bearing_columns += int(source.grid.use_at(below) \
							!= WarrenSpatialGrid.Use.PUBLIC_AIR \
						and volume.has_mass(Vector3i(macro_column.x,
							room.lattice_origin.y - 1, macro_column.y)))
				if exact_bearing_columns * 2 < footprint.size() \
						and not tunnel_roof_support_by_room.has(room.stable_id):
					return {"valid": false, "rejection":
						("terrain-bearing room %s has only %d/%d exact " \
						+ "source-bearing columns and no grounded tunnel " \
						+ "portal") % [room.stable_id,
							exact_bearing_columns, footprint.size()]}
				maze_stone_borne_room_count += 1
				continue
			# TASK F3 MEMBER 6, WRITE SITE 1 OF 2 -- the foundation SPAN under
			# this room, minus whatever the FABRIC has already built in. See
			# `built_solid` above: the retained channel carries mass nobody
			# built in, and neither plinth write site subtracted the fabric the
			# way the maze-stone half always has. On `step/3/standard` this is
			# the site that offered all six cells, because a span's top band is
			# the same cell the course below would have written.
			for plinth_value: Variant in room_plinth_cells.keys():
				var plinth_cell := plinth_value as Vector3i
				if built_solid.has(plinth_cell):
					built_in_cells[plinth_cell] = true
					continue
				cells[plinth_cell] = true
			if not room_needs_plinth:
				flush_room_count += 1
				continue
			# A plinth is one building-wide masonry course, not a sample of the
			# terrain columns that happened to be low. Fill the complete course
			# immediately below the room datum so `plinth_faces()` derives one
			# closed perimeter. Columns already at grade bury this course in the
			# terrain; columns over a drop expose it. Every column must still be
			# real source mass or its own untouched ground, and non-public, so
			# this can never bridge a tunnel or manufacture a floating stone
			# skirt.
			#
			# TASK D1. "Bury this course in the terrain" is what the paragraph
			# above always claimed and what only real ground can produce: a
			# room straddling a one-band step needs the course on its low
			# columns, and on its AT-GRADE columns that same band is inside the
			# hillside. The envelope models no cell below a column's own
			# terrain, so `has_mass` answered false and the course could not
			# close -- the ramp fixture's 3/standard died exactly there. A band
			# below `bearing_at` is untouched ground by construction (nothing
			# is borable under it: `slot_is_borable` refuses `cell.y <
			# base_at`), so it is the one other thing a masonry course may
			# legitimately sit in. On flat input every bearing is zero and a
			# room needing a plinth stands at datum >= 1, so the clause is
			# unreachable and the flat corpus is unmoved.
			#
			# Keyed on the maze source all the same, the way C6's
			# `_required_room_clearance` is: the relaxation is equally true of
			# a mass-first town on a real hillside, but the legacy path is
			# byte-identical this phase and a shared file is where that would
			# quietly stop being so.
			var course_cells: Array[Vector3i] = []
			for fine_column_value: Variant in footprint.keys():
				var fine_column := fine_column_value as Vector2i
				var macro_column := Vector2i(
					floori(float(fine_column.x) / 2.0),
					floori(float(fine_column.y) / 2.0))
				var course_cell := Vector3i(fine_column.x,
					room.lattice_origin.y - 1, fine_column.y)
				# `bearing_by_column` holds every fine column of this footprint
				# (the loop above writes one entry per column before this one
				# runs), so it is read directly rather than defaulted.
				var buried := maze_mode \
					and course_cell.y < int(bearing_by_column[fine_column])
				if (not buried and not volume.has_mass(Vector3i(
							macro_column.x, course_cell.y, macro_column.y))) \
						or source.grid.use_at(course_cell) \
							== WarrenSpatialGrid.Use.PUBLIC_AIR:
					return {"valid": false, "rejection":
						("terrain-bearing room %s cannot close its plinth " \
						+ "course at %s (origin=%s macro=%s bearing=%d " \
						+ "mass=%s use=%d shoulder=%d)") % [room.stable_id,
							course_cell, room.lattice_origin, macro_column,
							int(bearing_by_column[fine_column]), str(volume.has_mass(
								Vector3i(macro_column.x, course_cell.y,
									macro_column.y))), source.grid.use_at(course_cell),
							maze_source.rock_shoulder(macro_column)]}
				# TASK F3 MEMBER 6, WRITE SITE 2 OF 2 -- the masonry COURSE at
				# this room's datum. A cell the FABRIC already built in is
				# skipped, exactly as the span above and the maze-stone half
				# below skip one. The column really does carry mass here -- the
				# check above proved it -- but a house's own `roof.flat.*` slab
				# is standing in that mass, and laying a masonry course through
				# it is the stone band between two houses that task C5c's
				# `stone_borne` rule exists to prevent. `stone_borne` reads the
				# SOURCE's rock shoulder and so cannot see it: on a terraced
				# fixture the shoulder is high enough that the room looks
				# terrain-borne while a neighbour's crown occupies the same
				# band. MEASURED over 29 towns: 0 such cells on all 24 corpus
				# towns, on the production settlement and on three of the four
				# D1 sloped rows; 6 on `step/3/standard`, through
				# `roof.flat.row` and `roof.flat.slim`. Dropping them from the
				# course as well as from the channel is what keeps the shell
				# audit exact -- a neighbour that is built solid closes the seam
				# the dropped cell used to close.
				if built_solid.has(course_cell):
					built_in_cells[course_cell] = true
					continue
				cells[course_cell] = true
				columns[fine_column] = true
				course_cells.append(course_cell)
			course_cells.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
				if a.y != b.y:
					return a.y < b.y
				if a.z != b.z:
					return a.z < b.z
				return a.x < b.x)
			room_records.append({
				"room_id": room.stable_id,
				"support_band": room.lattice_origin.y,
				"course_cells": course_cells,
				"bearing_by_column": bearing_by_column,
			})
	# TASK C5 RULING 3 -- maze mode's retained STONE, which is the same
	# material through the same channel and is deliberately NOT a building
	# plinth. `WarrenVolumetricSolver` already decided which cells these are
	# (the flat-roof slab courses and every leftover cell the source calls
	# solid at or above its own terrain datum) and owns them in the grid, so
	# this reads the decision instead of making a second one.
	#
	# They enter `cells` -- the set `set_retained_terrace` receives -- but NOT
	# `room_records`, so the building-shell checks below still audit exactly
	# the building plinths they always audited. A cell the fabric already
	# built in is skipped by the `built_solid` subtraction rather than left for
	# the plan to refuse, and the one-band `roof.flat.*` unit standing on a
	# flat parcel's slab is exactly such a cell.
	#
	# TASK F3 MEMBER 6. This paragraph used to justify the subtraction by
	# saying `set_retained_terrace` "rejects an overlap with solid outright".
	# It did not: its guard compared Vector3i keys against a String-keyed map
	# and could never fire, so this subtraction was the ONLY rule keeping
	# retained stone out of built mass -- and it covered the maze-stone half
	# alone, which is how six plinth-course cells reached two houses' roof
	# slabs on `step/3/standard`. The plinth half subtracts the same set now
	# (see the course loop above) and the fixed guard is the backstop.
	#
	# TASK C5b RULING 1: they enter it TAGGED. The assembler skins a retained
	# mountain and a building's plinth course by two different rules, and the
	# only thing that tells the two apart at render time is this value. No
	# reader of the channel has ever looked at a retained cell's value, and a
	# legacy plan still writes `true`, so the tag is additive.
	var maze_stone: Dictionary = {}
	var roof_visual_cells: Dictionary = {} if plan == null \
		else _actual_roof_visual_cells(plan)
	var maze_stone_withdrawn_for_roof: Dictionary = {}
	var unsupported_maze_stone: Dictionary = {}
	var unsupported_maze_stone_components := 0
	if source.grid != null:
		var maze_owned: Array[Vector3i] = []
		for cell: Vector3i in source.grid.cells_with_use(
				WarrenSpatialGrid.Use.STRUCTURAL_VOLUME):
			if source.grid.owner_name_at(cell) == MAZE_RETAINED_STONE_ID \
					and not cells.has(cell):
				maze_owned.append(cell)
		# TASK F3 MEMBER 6. The solid projection used to be taken here, lazily,
		# because only this half needed it. The plinth-course half needs it
		# too, so it is read once at the top of the function and both halves
		# subtract the same set -- one reading of the fabric per compile
		# instead of one, and the same answer for both.
		var maze_candidates: Dictionary = {}
		for cell: Vector3i in maze_owned:
			if built_solid.has(cell):
				continue
			# Retained source mass is allowed to BEAR a finished roof, but it may
			# never remain visible THROUGH that roof.  Source construction keeps
			# conservative slab/shoulder cells until every room and roof has been
			# accepted, because those cells are useful bearing facts while the
			# town is assembled.  This final transaction is where that temporary
			# scaffold becomes visible retained terrain.  Subtract the exact
			# measured placement volume of every accepted roof here -- neither the
			# source planner nor the renderer has to guess which stone cube a roof
			# was meant to replace.
			if roof_visual_cells.has(cell):
				maze_stone_withdrawn_for_roof[cell] = true
				continue
			maze_candidates[cell] = true
		# A source massif is a temporary construction envelope, not permission to
		# render arbitrary leftover cubes.  Keep only retained stone whose exact
		# face-connected load path reaches the sampled terrain datum, either
		# directly or through final fabric solids/plinths.  This makes a retained
		# tunnel shoulder valid while removing roof-height source scaffolding that
		# became isolated when rooms and their measured roofs were committed.
		#
		# Retained source stone is never the authority that proves a final room's
		# bearing; the sealed room/foundation DAG already owns that proof. Therefore
		# every unreachable source component is culled, even when its old envelope
		# touches a terrain-bearing footprint. Treating that incidental touch as a
		# new support obligation made obsolete roof-height source cubes veto an
		# otherwise grounded finished building—the exact stone-around-roof defect
		# this final transaction exists to prevent.
		var support := _supported_retained_maze_cells(source, plan, cells,
			maze_candidates, built_solid)
		var supported_candidates := support.get("supported", {}) as Dictionary
		unsupported_maze_stone = support.get("unsupported", {}) as Dictionary
		unsupported_maze_stone_components = int(support.get(
			"unsupported_component_count", 0))
		for cell: Vector3i in maze_candidates:
			if not supported_candidates.has(cell):
				continue
			cells[cell] = SettlementFabricAssembler.MAZE_STONE_TAG
			maze_stone[cell] = true
	return {"valid": true, "cells": cells, "cell_count": cells.size(),
		"column_count": columns.size(), "max_depth_bands": max_depth,
		"terrain_bearing_room_count": terrain_bearing_room_count,
		# TASK F3 MEMBER 6. Retained PLINTH cells dropped because the fabric had
		# already built in them -- foundation span and masonry course alike
		# (fix round 1, MINOR 1: the counter was called `built_course_...` and
		# both write sites feed it, so the name said half of what it counts).
		# It is the stone that would have been drawn through a neighbouring
		# house's crown. Published rather than silent: 0 on every flat corpus
		# town and on three of the four D1 sloped rows, 6 on
		# `step/3/standard`, and a number that starts climbing means the plot
		# model is stacking rooms on roofs the source still calls terrain.
		"built_in_cell_count": built_in_cells.size(),
		# The WHOLE retained maze channel, every tag together. Named
		# `..._stone_cells` since Task C5c fix 1 so that
		# `maze_retained_rock_cells` means DERIVED ROCK everywhere it appears,
		# in this audit and in the solver's alike.
		"maze_retained_stone_cells": maze_stone.size(),
		"maze_stone_withdrawn_for_roof_cells": \
			maze_stone_withdrawn_for_roof.size(),
		"maze_stone_withdrawn_for_roof_cell_keys": \
			_sorted_v3_keys(maze_stone_withdrawn_for_roof),
		"maze_unsupported_stone_cells_removed": unsupported_maze_stone.size(),
		"maze_unsupported_stone_components_removed": \
			unsupported_maze_stone_components,
		"maze_unsupported_stone_cell_keys": \
			_sorted_v3_keys(unsupported_maze_stone),
		"maze_stone_borne_room_count": maze_stone_borne_room_count,
		# TASK C5c RULING 1: the retained channel carries ONE material and
		# THREE facts. `WarrenVolumetricSolver` split them where the split is
		# decided -- derived rock outside every plot, a plot's own roof band,
		# and plot mass the composition never built in -- and this reads that
		# decision rather than re-deriving it from a source plan the compiler
		# would then have to know about. The three reconcile against
		# `maze_retained_stone_cells` up to the cells the fabric had already
		# built in (which never enter this channel). Absent, and therefore
		# zero, on every legacy plan.
		"maze_retained_rock_cells": int(source.audit.get(
			"maze_retained_rock_cells", 0)),
		"maze_retained_rock_stone_roof_cells": int(source.audit.get(
			"maze_retained_rock_stone_roof_cells", 0)),
		"maze_unroomed_plot_cells": int(source.audit.get(
			"maze_unroomed_plot_cells", 0)),
		"maze_unroomed_plot_share": float(source.audit.get(
			"maze_unroomed_plot_share", 0.0)),
		"maze_stone_cells": maze_stone,
		"flush_room_count": flush_room_count, "room_records": room_records}


static func _supported_retained_maze_cells(source: WarrenSpatialPlan,
		plan: SettlementFabricPlan, plinth_cells: Dictionary,
		candidates: Dictionary, built_solid: Dictionary) -> Dictionary:
	## Resolve support on the same 1.5 m construction lattice used by rooms,
	## roofs, and retained stone.  The source envelope supplies only the root
	## datum; it does not itself become a visible solid.  Flooding the completed
	## construction union from those roots means support is transitive and
	## correct by construction, rather than inferred from a component's size,
	## height, seed, or proximity to a particular roof.
	var connected: Dictionary = {}
	var unsupported: Dictionary = {}
	if source == null or source.source_volume == null \
			or source.source_volume.envelope == null or candidates.is_empty():
		return {"supported": connected, "unsupported": unsupported,
			"unsupported_component_count": 0,
			"unsupported_structural_contact_count": 0,
			"unsupported_structural_contact_cells": []}
	var union: Dictionary = {}
	for cell: Vector3i in candidates:
		union[cell] = true
	for cell: Vector3i in built_solid:
		union[cell] = true
	for cell: Vector3i in plinth_cells:
		union[cell] = true
	# Some authored terrain contacts are deliberately openings in a shell (a
	# doorway threshold is the common case).  They remain exact bearing nodes
	# even when they are not also semantic wall solids.
	var terrain_bearing: Dictionary = {} if plan == null \
		else plan.transformed_cells(&"terrain_bearing")
	if plan != null:
		for cell: Vector3i in terrain_bearing:
			union[cell] = true
	var queue: Array[Vector3i] = []
	var envelope := source.source_volume.envelope
	for cell: Vector3i in union:
		var macro := Vector2i(floori(float(cell.x) / 2.0),
			floori(float(cell.z) / 2.0))
		if envelope.contains_column(macro) \
				and cell.y <= envelope.bearing_at(macro):
			connected[cell] = true
			queue.append(cell)
	var directions: Array[Vector3i] = [Vector3i.LEFT, Vector3i.RIGHT,
		Vector3i.FORWARD, Vector3i.BACK, Vector3i.UP, Vector3i.DOWN]
	var cursor := 0
	while cursor < queue.size():
		var cell := queue[cursor]
		cursor += 1
		for direction: Vector3i in directions:
			var neighbor := cell + direction
			if union.has(neighbor) and not connected.has(neighbor):
				connected[neighbor] = true
				queue.append(neighbor)
	var supported: Dictionary = {}
	for cell: Vector3i in candidates:
		if connected.has(cell):
			supported[cell] = true
		else:
			unsupported[cell] = true
	# Face connectivity is enough for a tunnel crown, because its opening is a
	# typed PUBLIC_AIR void and the neighboring stone carries it. It is not enough
	# for a source cell above an unclaimed OUTSIDE cell: that pattern is exactly a
	# leftover rock shelf after the lower source mass was released for a roof or
	# room. Retained terrain has no cantilever vocabulary, so keep only the
	# bottom-up prefix of each such column. This is a monotone structural closure,
	# not a size/seed exception: once a lower stone cell is absent, no higher stone
	# cell can restore that column's load path.
	var supported_order: Array[Vector3i] = []
	supported_order.assign(supported.keys())
	supported_order.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		if a.y != b.y:
			return a.y < b.y
		if a.z != b.z:
			return a.z < b.z
		return a.x < b.x)
	for cell: Vector3i in supported_order:
		var macro := Vector2i(floori(float(cell.x) / 2.0),
			floori(float(cell.z) / 2.0))
		if not envelope.contains_column(macro) \
				or cell.y <= envelope.bearing_at(macro):
			continue
		var below := cell + Vector3i.DOWN
		if source.grid.use_at(below) != WarrenSpatialGrid.Use.OUTSIDE \
				or supported.has(below) or built_solid.has(below) \
				or plinth_cells.has(below) or terrain_bearing.has(below):
			continue
		supported.erase(cell)
		unsupported[cell] = true
	var component_count := 0
	var structural_contacts: Dictionary = {}
	var unvisited := unsupported.duplicate()
	while not unvisited.is_empty():
		component_count += 1
		var component_queue: Array[Vector3i] = [unvisited.keys()[0] as Vector3i]
		unvisited.erase(component_queue[0])
		var component_cursor := 0
		while component_cursor < component_queue.size():
			var cell := component_queue[component_cursor]
			component_cursor += 1
			# Side contact with a wall is merely a closed visual seam. Only a
			# typed terrain-bearing footprint on or immediately above this
			# unsupported stone claims it as a load path and must reject rather
			# than be cosmetically culled.
			if terrain_bearing.has(cell) \
					or terrain_bearing.has(cell + Vector3i.UP):
				structural_contacts[cell] = true
			for direction: Vector3i in directions:
				var neighbor := cell + direction
				if unvisited.has(neighbor):
					unvisited.erase(neighbor)
					component_queue.append(neighbor)
	return {"supported": supported, "unsupported": unsupported,
		"unsupported_component_count": component_count,
		"unsupported_structural_contact_count": structural_contacts.size(),
		"unsupported_structural_contact_cells": \
			_sorted_v3_keys(structural_contacts)}


static func _actual_roof_visual_cells(plan: SettlementFabricPlan) -> Dictionary:
	## Rasterize only final accepted roof placements, not a prospective closure
	## or a roof recipe's broad merged clearance box.  Fine-grid cells are the
	## retained terrain's actual construction currency, so one shared exact
	## AABB/cell-volume overlap decides whether a source-mass cell may enter the
	## visible retained channel.  The roof stays authoritative even when its
	## sloped shell occupies only part of the conservative semantic solid band.
	var out: Dictionary = {}
	if plan == null:
		return out
	var cell_size := FabricRecipe.CELL_SIZE
	var half := cell_size * 0.5
	for unit: FabricUnit in plan.units:
		var recipe := plan.recipe(unit.recipe_id)
		if recipe == null or not recipe.has_tag(&"roof"):
			continue
		var unit_transform := unit.transform()
		for index in recipe.placements.size():
			var placement := recipe.placements[index] as Dictionary
			if unit.suppressed_placement_ids.has(StringName(placement.id)) \
					or index >= recipe.placement_bounds.size():
				continue
			var bounds: AABB = unit_transform * recipe.placement_bounds[index]
			if not bounds.has_volume():
				continue
			var minimum := bounds.position
			var maximum := bounds.end
			var min_x := floori((minimum.x - half) / cell_size) - 1
			var max_x := ceili((maximum.x + half) / cell_size) + 1
			var min_y := floori(minimum.y / cell_size) - 1
			var max_y := ceili(maximum.y / cell_size) + 1
			var min_z := floori((minimum.z - half) / cell_size) - 1
			var max_z := ceili((maximum.z + half) / cell_size) + 1
			for y in range(min_y, max_y + 1):
				for z in range(min_z, max_z + 1):
					for x in range(min_x, max_x + 1):
						var cell := Vector3i(x, y, z)
						var cell_bounds := AABB(Vector3(cell) * cell_size \
							+ Vector3(-half, 0.0, -half),
							Vector3.ONE * cell_size)
						if SettlementFabricPlan._aabb_overlaps_volume(
								bounds, cell_bounds):
							out[cell] = true
	return out


static func _sorted_v3_keys(source: Dictionary) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	out.assign(source.keys())
	out.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		if a.y != b.y:
			return a.y < b.y
		if a.z != b.z:
			return a.z < b.z
		return a.x < b.x)
	return out


static func _maze_terrace_audit(plan: SettlementFabricPlan,
		crown_unit_ids: Array = []) -> Dictionary:
	## TASK C5e RULING 3. What the flat crowns really are, and what they wear.
	## The rule and the payload are both `SettlementFabricAssembler`'s, so this
	## audit reads them rather than restating them: how many cells of open
	## crown the town built, how many of their boundaries are a fall, and how
	## many railing instances the renderer is handed for those boundaries.
	##
	## They are three separate statements on purpose. A 3 m module spans two
	## boundaries, so the rail count is deliberately NOT the edge count and no
	## test should assert they are equal; what a test can hold is that every
	## edge is covered exactly once, which needs both numbers published.
	##
	## Every count is zero on a legacy plan, which tags no maze stone.
	##
	## The crown ids are handed in rather than read back off the plan: this
	## runs BEFORE `result.seal(audit)`, so the plan does not carry them yet.
	## Every later caller (the assembler on a sealed plan, and the composition
	## test) reads the same list out of the sealed audit.
	if plan == null:
		return {"maze_construction_crown_cell_count": 0,
			"maze_terrace_deck_cell_count": 0,
			"maze_terrace_edge_count": 0, "maze_terrace_railing_count": 0}
	var crowns: Dictionary = {}
	for crown_value: Variant in crown_unit_ids:
		crowns[StringName(crown_value)] = true
	return {
		"maze_construction_crown_cell_count": SettlementFabricAssembler \
			.maze_construction_crown_cells(plan, crowns).size(),
		"maze_terrace_deck_cell_count": SettlementFabricAssembler \
			.maze_terrace_deck_cells(plan, crowns).size(),
		"maze_terrace_edge_count": SettlementFabricAssembler \
			.maze_terrace_edges(plan, crowns).size(),
		"maze_terrace_railing_count": SettlementFabricAssembler \
			.maze_terrace_railings(plan, crowns).instance_count,
	}


static func _maze_stone_skin_audit(plan: SettlementFabricPlan,
		maze_source: WarrenMazeSourcePlan = null,
		grid: WarrenSpatialGrid = null,
		crown_unit_ids: Array = []) -> Dictionary:
	## TASK C5b RULING 2 -- the skin is an IDENTITY, not a hope. The face rule
	## and the payload are both the assembler's, so this audit states that the
	## panels it emitted really COVER the shell it derived: every exposed face
	## closed by something, no cap covered twice, and the panel count handed to
	## the renderer equal to the panel count the rule produced.
	##
	## It runs AFTER `set_surface_plan` and not beside the plinth shell audit,
	## because a sky-facing face is only suppressed by the planked floor above
	## it, and the surface plan is the only place that fact lives. Every count
	## is zero on a legacy plan, which tags no cell.
	##
	## FIX 1, MINOR 5. `maze_stone_missing_face_count` used to be
	## `expected - rendered`, which is one instance per panel by construction
	## and so could never be anything but zero. It is now a COVERAGE
	## shortfall, stated here in this file's own terms -- a 3 m module covers
	## two bands, a flat one covers two cells, a building's plinth panel
	## covers the band beneath it -- so the gate in `solve` bites if the
	## assembler's coursing or pairing ever leaves the mountain open.
	if plan == null:
		var empty := {"maze_stone_cell_count": 0,
			"maze_stone_exposed_face_count": 0,
			"maze_stone_expected_face_count": 0,
			"maze_stone_rendered_face_count": 0,
			"maze_stone_missing_face_count": 0,
			"maze_stone_doubled_cap_count": 0,
			"maze_stone_top_face_count": 0,
			"maze_stone_bottom_face_count": 0,
			"maze_stone_top_slab_count": 0,
			"maze_stone_bottom_slab_count": 0,
			"maze_stone_faces_suppressed_by_paving": 0,
			"maze_stone_faces_deferred_to_plinth": 0,
			"maze_skin_masonry_panel_count": 0,
			"maze_skin_soffit_panel_count": 0,
			"maze_skin_natural_panel_count": 0,
			"maze_skin_green_cap_count": 0,
			"maze_terrain_ground_cell_count": 0,
			"maze_terrain_ground_surface_count": 0,
			"maze_skin_facade_panel_count": 0,
			"maze_skin_facade_blue_panel_count": 0,
			"maze_skin_facade_orange_panel_count": 0,
			"maze_skin_facade_amber_panel_count": 0,
			"maze_skin_facade_window_panel_count": 0,
			"maze_skin_above_ground_stone_face_count": 0,
			"maze_skin_max_consecutive_facade_storeys": 0,
			"maze_skin_tall_course_mismatch_count": 0,
			"maze_turf_backed_facade_count": 0,
			"maze_garden_cell_count": 0,
			"maze_village_green_cell_count": 0,
			"maze_plaza_entry_count": 0,
			"maze_plaza_centre_feature_count": 0,
			"maze_plaza_centre_feature_asset": &"",
			"maze_garden_planting_count": 0,
			"maze_garden_planting_refused_count": 0,
			"maze_garden_decor_type_count": 0,
			"maze_garden_decor_adjacent_repeat_count": 0,
			"maze_stall_canopy_count": 0,
			"maze_stall_goods_count": 0,
			"maze_garden_dressing_instance_count": 0,
			"maze_skywalk_span_count": 0,
			"maze_skywalk_deck_cell_count": 0,
			"maze_skywalk_instance_count": 0,
			"maze_facade_bay_count": 0,
			"maze_facade_bump_out_count": 0,
			"maze_facade_outcrop_bracket_count": 0,
			"maze_facade_outcrop_instance_count": 0,
			"maze_paved_bench_cap_count": 0,
			"maze_tall_bank_masonry_panel_count": 0,
			"maze_skin_cut_panel_count": 0,
			"maze_skin_cut_fallback_masonry_count": 0,
			"maze_skin_cut_tail_candidate_count": 0,
			"maze_skin_cut_tail_unclearable_count": 0,
			"maze_skin_coursed_trim_count": 0,
			"maze_stone_cap_jut_cell_count": 0,
			"maze_skin_cap_trim_count": 0,
			"maze_free_bench_stone_cap_count": 0,
			"maze_undercroft_stone_cap_count": 0,
			"maze_green_cap_jut_cell_count": 0,
			"maze_green_cap_jut_over_air_count": 0,
			"maze_shared_street_cap_count": 0,
			"maze_low_bank_face_count": 0,
			"maze_tall_bank_face_count": 0,
			"maze_tallest_bank_bands": 0,
			"maze_tall_bank_runs": [],
			"maze_bank_height_histogram": {}}
		empty.merge(maze_stone_band_profile({}, null), true)
		return empty
	var ground_skin := SettlementFabricAssembler.maze_ground_skin_transaction(plan)
	var retained := ground_skin.retained as Dictionary
	var stone := SettlementFabricAssembler.maze_stone_cells(retained)
	var solids := ground_skin.solids as Dictionary
	var plinths := ground_skin.plinths as Dictionary
	var paved := ground_skin.paved as Dictionary
	# TASK H2 PART 1. Every cell the public realm's own walk surfaces occupy,
	# over ALL FIVE surface kinds rather than the three `PAVED_FLOOR_KINDS`
	# that DRAW themselves. The two questions are different: `paved` above asks
	# "does something else already close this boundary", and this asks "does
	# anybody WALK here", which is what tells a street's own pavement from a
	# parapet lid on a house nobody stands on. TASK H2b moved the set into the
	# assembler, which now needs the same answer to decide a cap's treatment,
	# and reads it here rather than deriving a second one.
	var walked := ground_skin.walked as Dictionary
	# ONE derivation of the shell for the whole audit AND for the payload it
	# measures. `exposed`, `faces` and `treatments` are pure functions of the
	# cell sets above; this pass used to derive `exposed` four times over
	# (its own, one inside `maze_stone_faces`, and both again inside the
	# `maze_stone_walls` call below), `faces` twice and `treatments` twice, for
	# identical dictionaries every time.
	# TASK I4 ROUND 6. The derived per-placement module boxes, built once for the
	# whole audit and handed to the same rules the payload hands them to -- see
	# `SettlementFabricAssembler.maze_module_footprints`.
	var footprints := ground_skin.footprints as Dictionary
	var shell := ground_skin.shell as Dictionary
	var exposed := shell.exposed as Dictionary
	var faces := shell.faces as Dictionary
	var sides := SettlementFabricAssembler.FACE_DIRECTIONS.size()
	# TASK C5b FIX 1, IMPORTANT 4. What the planked-floor exception really
	# costs the shell, now that it is three surface kinds and not five.
	var suppressed_by_paving := 0
	for cell_value: Variant in stone.keys():
		var above := (cell_value as Vector3i) + Vector3i.UP
		suppressed_by_paving += int(paved.has(above) and not retained.has(above) \
			and not solids.has(above))
	# Which cells each horizontal slab covers: its own, and the neighbour the
	# assembler paired it with.
	var cap_coverage: Dictionary = {}
	var top_slabs := 0
	var bottom_slabs := 0
	var deferred_to_plinth := 0
	for key_value: Variant in faces.keys():
		var key := key_value as Vector4i
		if key.w < sides:
			continue
		var direction := SettlementFabricAssembler.STONE_FACE_DIRECTIONS[key.w]
		top_slabs += int(direction == Vector3i.UP)
		bottom_slabs += int(direction == Vector3i.DOWN)
		cap_coverage[key] = int(cap_coverage.get(key, 0)) + 1
		var partner := faces[key] as Vector3i
		if partner == Vector3i.ZERO:
			continue
		var mate := Vector4i(key.x + partner.x, key.y + partner.y,
			key.z + partner.z, key.w)
		cap_coverage[mate] = int(cap_coverage.get(mate, 0)) + 1
	var top_face_count := 0
	var bottom_face_count := 0
	var missing_face_count := 0
	var missing_faces: Array[Vector4i] = []
	var doubled_cap_count := 0
	for key_value: Variant in exposed.keys():
		var key := key_value as Vector4i
		if key.w >= sides:
			var direction := SettlementFabricAssembler \
				.STONE_FACE_DIRECTIONS[key.w]
			top_face_count += int(direction == Vector3i.UP)
			bottom_face_count += int(direction == Vector3i.DOWN)
			var slabs := int(cap_coverage.get(key, 0))
			if slabs == 0:
				missing_face_count += 1
				missing_faces.append(key)
			doubled_cap_count += int(slabs > 1)
			continue
		# A side course hangs from the top of its cell and is 3 m tall, so the
		# panel that closes this band is keyed at this band or the one above.
		if faces.has(key) \
				or faces.has(Vector4i(key.x, key.y + 1, key.z, key.w)):
			continue
		# ... unless a building's own plinth panel already stands in this
		# plane one band up, in which case the stone deliberately starts below
		# it rather than intersecting it (fix 1, IMPORTANT 2).
		if _plinth_closes_band(plinths, key):
			deferred_to_plinth += 1
			continue
		missing_face_count += 1
		missing_faces.append(key)
	var rendered := SettlementFabricAssembler.maze_stone_walls(retained,
		solids, paved, plinths, walked, shell, plan.world_seed)
	# TASK H2b. What the shell WEARS, counted over the same panel set the
	# coverage identity above is measured on, and split by the bank each side
	# panel stands in so the two pins have a denominator: masonry above the
	# retaining budget is the defect, and a stone slab on a bench nobody walks
	# is the other one.
	var treatments := shell.treatments as Dictionary
	var masonry_panels := 0
	var soffit_panels := 0
	var natural_panels := 0
	var green_panels := 0
	# TASK I2. THE WALL-MATERIAL METRIC, EXTENDED OVER CLAD MASS. Task H1's
	# `exterior_wall_material_profile` scores what the town's ROOMS wear; the
	# exposed massif now wears the same authored vocabulary, so the same question
	# is asked of it here -- how many mass faces are building storeys, in which
	# timber family, and how many of them carry a window rather than a boarded
	# panel. The family split is the check that a district's mass and its houses
	# agree: a town whose facade families are lopsided against
	# `_architectural_district_theme`'s own 4/2/2 phase split would mean the skin
	# is colouring itself.
	var facade_panels := 0
	var facade_windows := 0
	var facade_by_family: Dictionary = {&"blue": 0, &"orange": 0, &"amber": 0}
	# TASK I2. THE PIN THE DIRECTION ASKS FOR: "remove all stone from everywhere
	# but the ground floor of select buildings". Above-ground stone on the MASS
	# is a side panel wearing coursed rock in a bank taller than the retaining
	# budget -- one storey of stone holding a terrace is the allowed low base,
	# anything above it is the wall the user rejected. It is the same population
	# `tall_bank_masonry` counts and is published under its own name because the
	# two now mean different things to a reader: one is H2b's "that face is
	# hillside", this is I2's "that face is a building".
	var above_ground_stone := 0
	# FIX 1, MINOR 2. A grass quad that reaches past the cells its own panel
	# closes, and -- the pin -- one that reaches over open AIR. A stone ledge
	# corbels; a lawn sheet over nothing does not.
	var green_jut_cells := 0
	var green_jut_over_air := 0
	# TASK I4. The plank terraces annotation 2 demotes the small free tops to,
	# and the leans annotation 1 refuses -- both counted where the treatment is
	# read rather than re-derived somewhere else.
	var green_lean_refusals := 0
	var tall_bank_masonry := 0
	# TASK I7. The visible vertical-run proof for the alternating stone/facade
	# vocabulary. Counting actual panel treatments makes this a guard against a
	# future material-policy regression, not merely a restatement of the rule.
	var max_consecutive_facade_storeys := 0
	var tall_course_mismatches := 0
	var turf_backed_facades := 0
	# TASK H2c FIX 1. How much rock the street cuts, and how much of it the cut
	# could not be expressed on and had to be coursed instead. The second is
	# zero by construction today; it is published so a day it is not cannot be
	# a surprise.
	var cut_panels := 0
	var cut_fallback_masonry := 0
	# TASK H2c FIX 1. The tail half of the cut: panels a street crosses under,
	# and the ones where no rise both clads the band and clears the body -- a
	# crossing that passes a corner of mass at head height, which is a ROUTING
	# fact no cladding can answer.
	#
	# FIX 2, MINOR 4 -- CANDIDATES, NOT SHORTENINGS. This counts the panels the
	# tail clamp is OFFERED: a walked cell in the panel's own mass column within
	# `NATURAL_ROCK_CUT_BAND_REACH`. The emitter shortens only when the ceiling
	# is under the roll it already made (`rise_ceiling < rise` in
	# `_maze_natural_face_transform`), so a panel that rolled short enough on
	# its own is counted here and never moved. The name says candidate now
	# rather than clamped; the number is the same number it always was, and the
	# renaming is the whole of the fix.
	var tail_candidates := 0
	var tail_unclearable := 0
	# The coursed twin of the tail clamp: masonry panels trimmed to their own
	# band because the course they would have buried into is an open street.
	var coursed_trim := 0
	# TASK I1 FIX 1. The HORIZONTAL twin of both: unpaired cap slabs cut back to
	# the run they close because the 0.75 m they reach past it is a street. The
	# jut cells are published beside it exactly as the green quad's are, so
	# "how far do the caps reach" and "how many of them reach over somebody" stay
	# two separate, checkable statements.
	var cap_jut_cells := 0
	var cap_trim := 0
	var free_bench_stone_caps := 0
	var undercroft_caps := 0
	var shared_street_caps := 0
	var low_bank_faces := 0
	var tall_bank_faces := 0
	var tallest_bank := 0
	var bank_counts: Dictionary = {}
	var tall_bank_runs: Array[Dictionary] = []
	for key_value: Variant in treatments.keys():
		var key := key_value as Vector4i
		var treatment := int(treatments[key])
		var is_down_soffit := key.w >= sides \
			and SettlementFabricAssembler.STONE_FACE_DIRECTIONS[key.w] \
				== Vector3i.DOWN
		# MASONRY remains the semantic fallback treatment, but a floor-facing
		# boundary realizes that treatment as an authored timber soffit. Keep the
		# material census faithful to what the renderer actually builds instead of
		# reporting those planks as rock.
		soffit_panels += int(is_down_soffit)
		masonry_panels += int(treatment \
			== SettlementFabricAssembler.SkinTreatment.MASONRY \
			and not is_down_soffit)
		natural_panels += int(treatment \
			== SettlementFabricAssembler.SkinTreatment.NATURAL)
		green_panels += int(treatment \
			== SettlementFabricAssembler.SkinTreatment.GREEN)
		if treatment == SettlementFabricAssembler.SkinTreatment.FACADE:
			facade_panels += 1
			var family := SettlementFabricAssembler.maze_facade_family(key,
				plan.world_seed)
			facade_by_family[family] = int(facade_by_family.get(family, 0)) + 1
			facade_windows += int(String(SettlementFabricAssembler
				.maze_facade_module(key, plan.world_seed)).contains(".window."))
		if treatment == SettlementFabricAssembler.SkinTreatment.GREEN:
			# TASK I4: the quad's own coverage, which is the PAIR and never the
			# lean -- the audit and the payload derive it through one function.
			var cap_partner := SettlementFabricAssembler.maze_green_cap_partner(
				key, faces[key] as Vector3i, exposed)
			green_lean_refusals += int(cap_partner \
				!= (faces[key] as Vector3i))
			for jut: Vector3i in SettlementFabricAssembler.maze_green_cap_jut_cells(
					Vector3i(key.x, key.y, key.z), cap_partner):
				green_jut_cells += 1
				green_jut_over_air += int(not retained.has(jut) \
					and not solids.has(jut))
		if key.w >= sides:
			if treatment == SettlementFabricAssembler.SkinTreatment.MASONRY:
				cap_jut_cells += SettlementFabricAssembler \
					.maze_stone_cap_jut_cells(key, faces[key] as Vector3i).size()
				# Every unpaired upward cap is now the exact 1.5 m singleton
				# variant. Count that construction fact directly; the former audit
				# asked whether the obsolete 3 m slab would have jutted over a
				# walkway and therefore reported zero even while the renderer used
				# the trimmed mesh. Downward masonry treatments render as soffits,
				# so they are deliberately outside this horizontal cap census.
				cap_trim += int(SettlementFabricAssembler \
					.STONE_FACE_DIRECTIONS[key.w] == Vector3i.UP \
					and (faces[key] as Vector3i) == Vector3i.ZERO)
			if treatment != SettlementFabricAssembler.SkinTreatment.MASONRY \
					or SettlementFabricAssembler.STONE_FACE_DIRECTIONS[key.w] \
						!= Vector3i.UP \
					or walked.has(Vector3i(key.x, key.y + 1, key.z)):
				continue
			# A masonry cap whose OWN cell nobody walks. It survives only by
			# sharing its 3 m slab with a cell the realm does walk -- a bench
			# that happens to lie beside a street -- and greening it would put
			# lawn under that pavement. Published and watched; the strict pin
			# below is the one that must be zero.
			shared_street_caps += 1
			var partner := faces[key] as Vector3i
			# TASK I4 ROUND 7 -- AND AN UNDERCROFT IS NOT A FREE BENCH. The strict
			# pin below asks "is there a top here a body could stand on and enjoy
			# that the town paved in stone instead of greening". A cap a building's
			# own floor board covers, or one with a module inside body height over
			# it, is not such a top: nobody can stand on it at all, greening it lays
			# turf nobody can see, and decking it advertises a platform nobody can
			# reach (the r6 review's I4). `_maze_cap_is_free` is what sends those
			# here, and this is that same question asked back.
			if SettlementFabricAssembler.maze_cap_is_undercroft(key, partner,
					exposed, footprints):
				undercroft_caps += 1
				continue
			if partner == Vector3i.ZERO:
				free_bench_stone_caps += 1
				continue
			var mate := Vector4i(key.x + partner.x, key.y + partner.y,
				key.z + partner.z, key.w)
			free_bench_stone_caps += int(not exposed.has(mate) \
				or not walked.has(Vector3i(mate.x, mate.y + 1, mate.z)))
			continue
		var over_budget := SettlementFabricAssembler.maze_bank_height(exposed,
			key) > SettlementFabricAssembler.STONE_BUDGET_BANDS
		var backs_green_ground := SettlementFabricAssembler \
			.maze_face_backs_green_ground(key, treatments, faces, exposed)
		turf_backed_facades += int(backs_green_ground \
			and treatment == SettlementFabricAssembler.SkinTreatment.FACADE)
		if over_budget:
			var course_from_top := SettlementFabricAssembler \
				.maze_bank_course_from_top(exposed, key)
			var expected := SettlementFabricAssembler.SkinTreatment.MASONRY \
				if backs_green_ground \
				else SettlementFabricAssembler.SkinTreatment.FACADE \
					if course_from_top % 2 == 0 \
					else SettlementFabricAssembler.SkinTreatment.MASONRY
			tall_course_mismatches += int(treatment != expected)
			if treatment == SettlementFabricAssembler.SkinTreatment.FACADE:
				var consecutive := 1
				var below := Vector4i(key.x,
					key.y - SettlementFabricAssembler.STONE_COURSE_BANDS,
					key.z, key.w)
				while int(treatments.get(below, -1)) \
						== SettlementFabricAssembler.SkinTreatment.FACADE:
					consecutive += 1
					below.y -= SettlementFabricAssembler.STONE_COURSE_BANDS
				max_consecutive_facade_storeys = maxi(
					max_consecutive_facade_storeys, consecutive)
		var crossed := SettlementFabricAssembler.maze_natural_face_is_cut(key,
			walked)
		cut_panels += int(crossed \
			and treatment == SettlementFabricAssembler.SkinTreatment.NATURAL)
		cut_fallback_masonry += int(crossed and over_budget \
			and treatment == SettlementFabricAssembler.SkinTreatment.MASONRY)
		coursed_trim += int(treatment \
			== SettlementFabricAssembler.SkinTreatment.MASONRY \
			and SettlementFabricAssembler.maze_stone_face_overhangs_walk(key,
				walked))
		if treatment == SettlementFabricAssembler.SkinTreatment.NATURAL \
				and SettlementFabricAssembler.maze_natural_face_overhung_band(
					key, walked) < key.y:
			tail_candidates += 1
			tail_unclearable += int(not SettlementFabricAssembler \
				.maze_natural_face_tail_is_clearable(key, walked))
		tall_bank_masonry += int(treatment \
			== SettlementFabricAssembler.SkinTreatment.MASONRY and over_budget)
		above_ground_stone += int(treatment \
			== SettlementFabricAssembler.SkinTreatment.MASONRY and over_budget)
	for key_value: Variant in exposed.keys():
		var key := key_value as Vector4i
		if key.w >= sides:
			continue
		var height := SettlementFabricAssembler.maze_bank_height(exposed, key)
		tallest_bank = maxi(tallest_bank, height)
		bank_counts[height] = int(bank_counts.get(height, 0)) + 1
		if height > SettlementFabricAssembler.STONE_BUDGET_BANDS:
			tall_bank_faces += 1
		else:
			low_bank_faces += 1
		# One deterministic record per tall contiguous side run. This is useful
		# production telemetry, not a second classifier: it reads the exact shell
		# and height function above and merely names which source mass the run came
		# from so a future regression can be fixed in that producer.
		if height <= SettlementFabricAssembler.STONE_BUDGET_BANDS \
				or exposed.has(Vector4i(key.x, key.y - 1, key.z, key.w)):
			continue
		var source_kind := &"retained_rock"
		var macro := Vector2i(_macro_of(key.x), _macro_of(key.z))
		var datum := key.y
		if maze_source != null and maze_source.massif != null \
				and maze_source.massif.has_column(macro):
			var source_bands := _plot_bands_at(maze_source, macro)
			if source_bands.has(key.y):
				source_kind = &"plot_roof" if bool(source_bands[key.y]) \
					else &"unroomed_plot"
			elif maze_source.raised_shoulder_columns().has(macro):
				source_kind = &"raised_shoulder"
			datum = maze_source.local_public_datum(macro, key.y)
		tall_bank_runs.append({"bottom": Vector3i(key.x, key.y, key.z),
			"top_band": key.y + height - 1, "direction": key.w,
			"height": height, "macro_column": macro,
			"source_kind": source_kind, "public_datum": datum})
	tall_bank_runs.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		if int(left.height) != int(right.height):
			return int(left.height) > int(right.height)
		var a := left.bottom as Vector3i
		var b := right.bottom as Vector3i
		if a != b:
			if a.y != b.y:
				return a.y < b.y
			if a.x != b.x:
				return a.x < b.x
			return a.z < b.z
		return int(left.direction) < int(right.direction))
	# TASK I2. THE GARDEN SPLIT. `garden` is every cell a green cap floors -- the
	# yards, one entry per piece of ground rather than per slab -- `plaza` is the
	# largest connected run among them, promoted to the village green, and
	# `planting` is what really stands on them, counted off the payload the
	# renderer is handed rather than off the rule that placed it. The PAVED half
	# of the split is beside it: sky-facing caps the realm walks, which keep
	# their stone because they are a street's own floor.
	var garden := (ground_skin.garden as Dictionary).duplicate()
	for planned_cell_value: Variant in plan.planned_plaza_cells.keys():
		garden[planned_cell_value as Vector3i] = true
	var decor_skin := SettlementFabricAssembler.maze_skin_panel_boxes(
		retained, solids, paved, plinths, shell.treatments as Dictionary, shell)
	var planting := SettlementFabricAssembler.maze_garden_dressing(retained,
		solids, paved, plinths, walked, shell, footprints,
		plan.planned_plaza_cells, decor_skin,
		ground_skin.capped_ground as Dictionary)
	# TASK I3. The square's own three facts, derived exactly as the dressing
	# derives them: the run a street can actually reach, the mouths it reaches it
	# by, and what stands in the clearing.
	var plaza := SettlementFabricAssembler.maze_plaza_cells_for(plan, garden,
		walked)
	var plaza_entries := SettlementFabricAssembler.maze_plaza_entries(plaza,
		walked)
	var plaza_feature := SettlementFabricAssembler.maze_plaza_centre_feature(
		plaza, plaza_entries, footprints, decor_skin, walked)
	# TASK I3. `maze_garden_planting_count` stays what it has always meant --
	# what GROWS on the yards -- so it is counted off the `maze-garden/` ids
	# rather than off the dressing payload's whole instance count, which now
	# also carries the square's paved thresholds and its centre feature.
	var planting_instances := 0
	# TASK I4 ROUND 5, ITEMS 1, 2 and 5. What the dressing payload really carries,
	# by channel: what grows, what a canopy is stocked with, how many DISTINCT
	# pieces the town's decor uses, and how many neighbours ended up wearing the
	# same one anyway.
	var goods_instances := 0
	var decor_types: Dictionary = {}
	var decor_by_cell: Dictionary = {}
	var decor_group: Dictionary = {}
	for asset_value: Variant in planting.batches.keys():
		var batch := planting.batches[asset_value] as Dictionary
		for id_value: Variant in batch.get("ids", []) as Array:
			var id := String(id_value)
			goods_instances += int(id.begins_with("maze-stall-goods/"))
			if not id.begins_with("maze-garden/"):
				continue
			planting_instances += 1
			decor_types[StringName(asset_value)] = true
			var parts := id.trim_prefix("maze-garden/").split("/")
			var anchor := Vector3i(int(parts[0]), int(parts[1]), int(parts[2]))
			decor_by_cell[anchor] = StringName(asset_value)
			decor_group[anchor] = anchor
			# TASK I4 ROUND 6. A piece that spans a PAIR wears both cells, and
			# its id says which -- so a bench standing beside an identical bench
			# still reads as a repeat while the bench's own two cells do not.
			if parts.size() >= 5:
				var mate := anchor + Vector3i(int(parts[3]), 0, int(parts[4]))
				decor_by_cell[mate] = StringName(asset_value)
				decor_group[mate] = anchor
	var decor_adjacent_repeats := 0
	for cell_value: Variant in decor_by_cell.keys():
		var decor_cell := cell_value as Vector3i
		for step: Vector3i in [Vector3i(1, 0, 0), Vector3i(0, 0, 1)]:
			if not decor_by_cell.has(decor_cell + step) \
					or Vector3i(decor_group[decor_cell]) \
						== Vector3i(decor_group[decor_cell + step]):
				continue
			decor_adjacent_repeats += int(StringName(decor_by_cell[decor_cell]) \
				== StringName(decor_by_cell[decor_cell + step]))
	var planting_refused := 0
	var planting_reserved: Dictionary = {}
	for cell_value: Variant in (plaza_feature.get("cells", {}) \
			as Dictionary).keys():
		planting_reserved[cell_value as Vector3i] = true
	for site: Dictionary in SettlementFabricAssembler \
			.maze_garden_planting_sites(garden, plaza, plaza_entries,
				planting_reserved, treatments, footprints, decor_skin, walked):
		planting_refused += int(bool(site.refused))
	var paved_bench_caps := 0
	for key_value: Variant in treatments.keys():
		var key := key_value as Vector4i
		paved_bench_caps += int(key.w >= sides \
			and SettlementFabricAssembler.STONE_FACE_DIRECTIONS[key.w] \
				== Vector3i.UP \
			and int(treatments[key]) \
				== SettlementFabricAssembler.SkinTreatment.MASONRY)
	# TASK I3. THE LIFE, counted where the shell it hangs on is derived.
	# `spans` is the town's open timber bridges; the cells they claim are what
	# the outcropping rule must keep clear, and both the payload and this audit
	# derive them the same way from the same shell, so the two cannot drift.
	var crowns: Dictionary = {}
	for crown_value: Variant in crown_unit_ids:
		crowns[StringName(crown_value)] = true
	var spans := SettlementFabricAssembler.maze_skywalk_spans(plan, crowns)
	var skywalk_deck_cells := 0
	for span: Dictionary in spans:
		skywalk_deck_cells += int(span.gap)
	var outcrop_kinds := SettlementFabricAssembler.maze_facade_outcrop_kinds(
		retained, solids, paved, plinths, walked, shell,
		SettlementFabricAssembler.maze_skywalk_cells(spans))
	var facade_bays := 0
	var facade_bumps := 0
	for kind_value: Variant in outcrop_kinds.values():
		facade_bays += int(int(kind_value) \
			== SettlementFabricAssembler.FacadeOutcrop.BAY)
		facade_bumps += int(int(kind_value) \
			== SettlementFabricAssembler.FacadeOutcrop.BUMP)
	# TASK I4, ANNOTATION 1. Derived once and read twice: the edges the lawns
	# have, and the rim pieces the payload really lays over them.
	# TASK I4 ROUND 5, ITEM 4. The boundary set now carries the LEVEL junctions
	# as well as the drops, so `walked` and `paved` come with it.
	var capped_ground := ground_skin.capped_ground as Dictionary
	var terrain_controls := SettlementFabricAssembler \
		.maze_terrain_control_surface_cells(plan)
	var terrain_region := SettlementFabricAssembler.maze_terrain_surface_region(
		retained, capped_ground, terrain_controls)
	var rim_faces := SettlementFabricAssembler.maze_garden_rim_face_count(shell,
		walked, paved, footprints, capped_ground, true, terrain_region)
	var rim_instances := SettlementFabricAssembler.maze_green_rim_walls(retained,
		solids, paved, plinths, walked, shell, footprints, capped_ground,
		true, terrain_region).instance_count
	# TASK I4, ANNOTATIONS 3 and 6. The two new dressing channels, counted off
	# the same rules the payload places them with.
	# TASK I4 ROUND 5, ITEM 3. The headroom gate reads the capped stances too.
	var capped := SettlementFabricAssembler.maze_capped_stance_cells(shell,
		footprints)
	for capped_cell_value: Variant in capped_ground.keys():
		capped[capped_cell_value as Vector3i] = true
	# The former short corbel asset read as stairs floating beneath every
	# overhang. Structural skins and their boundary posts own bearing now, so the
	# whole legacy bearer channel is intentionally withdrawn.
	var floor_bearers_borne := 0
	var floor_bearers_refused := 0
	for site: Dictionary in SettlementFabricAssembler \
			.maze_public_floor_bearer_sites(retained, solids, paved, walked,
				capped):
		floor_bearers_refused += 1
	# TASK I4 ROUND 8, PART 1. The cladding the frontage stands off, from the same
	# shell this audit already holds -- so the sites this counts are the sites the
	# payload lays, stand-off and all.
	var frontage_skin := decor_skin
	var frontages := SettlementFabricAssembler.maze_perimeter_frontage_sites(
		retained, solids, paved, walked, plan.world_seed, frontage_skin,
		footprints)
	var frontages_wide := 0
	# TASK I4 ROUND 5, ITEM 2. Every canopy this fabric stands, wherever it stands
	# it: the square's own centre feature and the town's outward front. The goods
	# under them are counted off the payloads themselves, so "every canopy is
	# stocked" is a ratio a reader can check rather than a promise.
	var stall_canopies := int(SettlementFabricAssembler.STALL_CANOPIES.has(
		StringName(plaza_feature.get("asset", &""))))
	for site: Dictionary in frontages:
		frontages_wide += int((site.cells as Array).size() \
			>= SettlementFabricAssembler.PERIMETER_WINDOW_CELLS)
		stall_canopies += int(SettlementFabricAssembler.STALL_CANOPIES.has(
			StringName(site.asset)))
	var frontage_payload := SettlementFabricAssembler.maze_perimeter_frontage(
		retained, solids, paved, walked, plan.world_seed, frontage_skin,
		footprints)
	for asset_value: Variant in frontage_payload.batches.keys():
		var frontage_batch := frontage_payload.batches[asset_value] as Dictionary
		for id_value: Variant in frontage_batch.get("ids", []) as Array:
			goods_instances += int(String(id_value).begins_with(
				"maze-stall-goods/"))
	var out := {
		"maze_skywalk_span_count": spans.size(),
		"maze_skywalk_deck_cell_count": skywalk_deck_cells,
		"maze_skywalk_instance_count": SettlementFabricAssembler \
			.maze_skywalks_from(spans, plan).instance_count,
		"maze_enclosed_skywalk_span_count": spans.filter(
			func(span: Dictionary) -> bool:
				return bool(span.get("enclosed", false))).size(),
		"maze_facade_bay_count": facade_bays,
		"maze_facade_bump_out_count": facade_bumps,
		# Two bearers per projection and no branch that can skip them, so this is
		# `2 x (bays + bump-outs)` by construction -- published anyway, because
		# "every overhang shows its bracket" is a promise a reader should be able
		# to CHECK rather than take on the word of a comment.
		"maze_facade_outcrop_bracket_count": 2 * outcrop_kinds.size(),
		"maze_facade_outcrop_instance_count": SettlementFabricAssembler \
			.maze_facade_outcroppings(retained, solids, paved, plinths, walked,
				shell, plan.world_seed,
				SettlementFabricAssembler.maze_skywalk_cells(spans)) \
			.instance_count,
		"maze_skin_masonry_panel_count": masonry_panels,
		"maze_skin_soffit_panel_count": soffit_panels,
		"maze_skin_natural_panel_count": natural_panels,
		"maze_skin_green_cap_count": green_panels,
		# Turf is no longer counted through one asset instance per logical cap
		# panel. It is one exact TerrainChunkMesher union over the cells the
		# treatment covers, using the streamed terrain material and tint field.
		"maze_terrain_ground_cell_count": garden.size(),
		"maze_terrain_ground_surface_count": int(not garden.is_empty()),
		"maze_skin_facade_panel_count": facade_panels,
		"maze_skin_facade_blue_panel_count": int(facade_by_family.get(&"blue",
			0)),
		"maze_skin_facade_orange_panel_count": int(facade_by_family.get(
			&"orange", 0)),
		"maze_skin_facade_amber_panel_count": int(facade_by_family.get(&"amber",
			0)),
		"maze_skin_facade_window_panel_count": facade_windows,
		"maze_skin_above_ground_stone_face_count": above_ground_stone,
		"maze_skin_max_consecutive_facade_storeys":
			max_consecutive_facade_storeys,
		"maze_skin_tall_course_mismatch_count": tall_course_mismatches,
		"maze_turf_backed_facade_count": turf_backed_facades,
		"maze_garden_cell_count": garden.size(),
		"maze_village_green_cell_count": plaza.size(),
		"maze_plaza_entry_count": plaza_entries.size(),
		"maze_plaza_centre_feature_count": int(not plaza_feature.is_empty()),
		"maze_plaza_centre_feature_asset": StringName(
			plaza_feature.get("asset", &"")),
		"maze_garden_planting_count": planting_instances,
		# TASK I4 ROUND 5. ITEM 1: the sites whose odds roll said "plant here" and
		# whose real free ground held nothing the pool carries -- a cell walled on
		# two sides is 0.394 m of a 1.5 m cell, and a bare cell there is the point.
		# ITEM 5: how wide the town's decor vocabulary really came out, and how
		# many lateral neighbours still ended up wearing the same piece.
		"maze_garden_planting_refused_count": planting_refused,
		"maze_garden_decor_type_count": decor_types.size(),
		"maze_garden_decor_adjacent_repeat_count": decor_adjacent_repeats,
		# ITEM 2: every canopy this fabric stands and the goods under it. Five
		# pieces a canopy -- the stocked counter, three goods and the hanging
		# string -- so the two numbers are each other's proof.
		"maze_stall_canopy_count": stall_canopies,
		"maze_stall_goods_count": goods_instances,
		"maze_garden_dressing_instance_count": planting.instance_count,
		"maze_paved_bench_cap_count": paved_bench_caps,
		"maze_green_cap_jut_cell_count": green_jut_cells,
		"maze_green_cap_jut_over_air_count": green_jut_over_air,
		# TASK I4, ANNOTATION 1. The turf edge, as two numbers that have to
		# agree: how many edges the town's lawns HAVE, and how many rim pieces
		# were laid. The DEFICIT is the pin -- one bare cut anywhere makes it
		# positive -- and the lean refusals are what made it reachable.
		"maze_garden_rim_face_count": rim_faces,
		"maze_garden_rim_instance_count": rim_instances,
		"maze_garden_rim_deficit": rim_faces - rim_instances,
		"maze_green_cap_lean_refusal_count": green_lean_refusals,
		# A rejected garden run remains a structural roof. No skin treatment may
		# manufacture a walkable-looking platform outside the public-realm plan.
		"maze_unclaimed_platform_cap_count": 0,
		"maze_garden_run_minimum_cells": SettlementFabricAssembler \
			.GARDEN_RUN_MINIMUM_CELLS,
		"maze_garden_run_count": SettlementFabricAssembler \
			.maze_garden_run_count(garden),
		# TASK I4, ANNOTATION 3. The public floor plates that had nothing under
		# them, and the ones the headroom gate or a missing wall refused.
		"maze_public_floor_bearer_count": floor_bearers_borne,
		"maze_public_floor_bearer_refused_count": floor_bearers_refused,
		# TASK I4, ANNOTATION 6. The town's dressed foot.
		"maze_perimeter_frontage_count": frontages.size(),
		"maze_perimeter_frontage_wide_count": frontages_wide,
		"maze_tall_bank_masonry_panel_count": tall_bank_masonry,
		"maze_skin_cut_panel_count": cut_panels,
		"maze_skin_cut_fallback_masonry_count": cut_fallback_masonry,
		"maze_skin_cut_tail_candidate_count": tail_candidates,
		"maze_skin_cut_tail_unclearable_count": tail_unclearable,
		"maze_skin_coursed_trim_count": coursed_trim,
		"maze_stone_cap_jut_cell_count": cap_jut_cells,
		"maze_skin_cap_trim_count": cap_trim,
		"maze_free_bench_stone_cap_count": free_bench_stone_caps,
		"maze_undercroft_stone_cap_count": undercroft_caps,
		"maze_shared_street_cap_count": shared_street_caps,
		"maze_low_bank_face_count": low_bank_faces,
		"maze_tall_bank_face_count": tall_bank_faces,
		"maze_tallest_bank_bands": tallest_bank,
		"maze_tall_bank_runs": tall_bank_runs,
		"maze_bank_height_histogram": WarrenMazeSourcePlan.ascending_histogram(
			bank_counts),
		"maze_stone_cell_count": stone.size(),
		"maze_stone_exposed_face_count": exposed.size(),
		"maze_stone_expected_face_count": faces.size(),
		# `rendered` contains the authored vertical/cap modules. GREEN panels are
		# covered by the procedural terrain-ground union, so include their logical
		# panel count in this shell-coverage identity without pretending they are
		# still individual EnvironmentVisual instances.
		"maze_stone_rendered_face_count": rendered.instance_count + green_panels,
		"maze_stone_missing_face_count": missing_face_count,
		"maze_stone_missing_faces": missing_faces,
		"maze_stone_doubled_cap_count": doubled_cap_count,
		"maze_stone_top_face_count": top_face_count,
		"maze_stone_bottom_face_count": bottom_face_count,
		"maze_stone_top_slab_count": top_slabs,
		"maze_stone_bottom_slab_count": bottom_slabs,
		"maze_stone_faces_suppressed_by_paving": suppressed_by_paving,
		"maze_stone_faces_deferred_to_plinth": deferred_to_plinth,
	}
	out.merge(maze_stone_band_profile(exposed, maze_source, grid, walked),
		true)
	return out


## TASK E4 ruling 1 -- the user's first binding direction measured on the
## RENDERED shell rather than on the source's own derivation of it.
##
## `WarrenMazeSourcePlan.exterior_stone_band_profile` measures the source's
## DERIVED rock: solid the plot layer gave to nobody. That is only half of
## what a viewer calls stone. `WarrenVolumetricSolver._retain_maze_rock`
## retains three more things as the same masonry -- a plot's roof band, the
## span of a released bridge, and above all UNROOMED PLOT MASS, the building
## the composition never managed to room (its own ceiling lives in the
## composition suite) -- and every one of those stands at PLOT heights, which
## is exactly where high stone would show. So the profile is measured a
## second time here, over `exposed_maze_stone_faces`, which is the shell the
## assembler really skins.
##
## Same datum rule, same threshold, same histogram shape as the source's, so
## the two numbers are directly comparable; a fine cell's band IS its macro
## band (`_fine_square` halves x and z only), and its column is that fine
## column floor-divided by two.
##
## `maze_stone_plot_mass_*` splits out the faces standing on mass some plot
## claims -- the difference between the two measurements, stated as a number
## instead of left to be inferred. FIX 1, IMPORTANT 1 SPLITS IT AGAIN, because
## "plot mass" is not a synonym for "a building the composition never roomed":
## a plot's `[floor, top)` also contains its ROOF BAND SPAN, which is roof by
## the height contract and where no room may ever stand
## (`WarrenMazeBlockPartitioner.plot_roof_band_span`). Stone there is the
## parapet course doing its job, not a shortfall, and calling it a quarry block
## was wrong. So `maze_stone_roof_band_high_face_count` and
## `maze_stone_unroomed_high_face_count` name the two halves and sum to
## `maze_stone_plot_mass_high_face_count`.
##
## `maze_stone_raised_shoulder_high_face_count` is task E4 ruling 2's
## measurement on this side: how much of the high stone stands on a no-plot
## column whose sealed shoulder grew above its own massif envelope. It is
## disjoint from both plot-mass halves by definition, since a raised-shoulder
## column carries no plot. `maze_stone_grounded_face_count` (fix 1, minor 4)
## is the source profile's own `grounded_faces` on this side: faces with no
## public floor inside the datum radius at all, read against bare terrain.
##
## Every key is zero on a legacy plan, which retains no maze stone and has no
## maze source to read a datum from.
static func maze_stone_band_profile(exposed: Dictionary,
		maze_source: WarrenMazeSourcePlan,
		grid: WarrenSpatialGrid = null,
		walked: Dictionary = {}) -> Dictionary:
	var faces := 0
	var high_faces := 0
	var plot_mass_faces := 0
	var plot_mass_high_faces := 0
	var roof_band_high_faces := 0
	var unroomed_high_faces := 0
	var raised_shoulder_high_faces := 0
	var grounded_faces := 0
	var crown_cap_faces := 0
	var paved_crown_cap_faces := 0
	var borne_crown_cap_faces := 0
	var bearing_crown_cap_faces := 0
	var crown_cap_details: Array[String] = []
	var min_offset := 0
	var max_offset := 0
	var band_counts: Dictionary = {}
	var storey_counts: Dictionary = {}
	if maze_source != null and maze_source.massif != null:
		var candidates_by_column: Dictionary = {}
		var plot_bands_by_column: Dictionary = {}
		# TASK H2 PART 1. The bands a flat-roofed STACK PARENT reserves as its
		# stacked child's bearing plate, per column
		# (`WarrenVolumetricSolver._maze_flat_slab_cells`, restated from the
		# same plot facts rather than read back off the grid). A cap there is
		# the one crown lid H2 could not retire: the whole plate has to be
		# structure before the composition runs, and narrowing it to the
		# child's own footprint costs a corpus town its seal.
		var bearing_bands_by_column := _maze_parent_crown_bands(maze_source)
		var raised: Dictionary = {}
		for column: Vector2i in maze_source.raised_shoulder_columns():
			raised[column] = true
		# No sorted key walk: every accumulation below is a sum, a min, a max
		# or a histogram bucket, and the two histograms leave through
		# `ascending_histogram`, so the answer is order-free by construction.
		for key_value: Variant in exposed.keys():
			var key := key_value as Vector4i
			var column := Vector2i(_macro_of(key.x), _macro_of(key.z))
			if not maze_source.massif.has_column(column):
				continue
			if not candidates_by_column.has(column):
				candidates_by_column[column] = \
					maze_source.public_datum_candidates(column)
				plot_bands_by_column[column] = _plot_bands_at(maze_source,
					column)
			var offset := key.y - WarrenMazeSourcePlan.nearest_datum_band(
				candidates_by_column[column] as Dictionary, key.y,
				maze_source.massif.base_at(column))
			var storey := 0 if offset <= 0 \
				else (offset + WarrenBuildingParcel.STOREY_BANDS - 1) \
					/ WarrenBuildingParcel.STOREY_BANDS
			var high := int(offset > WarrenMazeSourcePlan.LOW_STONE_BANDS)
			var bands := plot_bands_by_column[column] as Dictionary
			var on_plot := int(bands.has(key.y))
			var on_roof := on_plot * int(bool(bands.get(key.y, false)))
			# TASK H2 PART 1 -- THE CROWN CAP, IN ITS THREE KINDS. One
			# SKY-FACING face of retained stone standing inside a house plot's
			# own roof band span: the pale rock slab
			# `SettlementFabricAssembler.maze_stone_walls` lays flat on top of
			# a crown. Deliberately NOT filtered by the high-stone threshold
			# the four counts above use -- a crown cap is a fact at every
			# height, because it is a roof. Side faces of the same span are the
			# honest parapet edge of a terrace and are not counted at all.
			#
			# What stands on the cap is what tells the four apart, and only
			# the last is the defect this task is pinned on:
			#
			# - PAVED: the public realm WALKS the cell above. Then the stone
			#   IS the street -- Task C5b measured that suppressing the cap
			#   under a terrain street or a stair left the mountain open to the
			#   sky, so the cap draws that walk surface, and "the street stands
			#   on stone" is this phase's own pinned design
			#   (`ROUTE_ON_STONE_FLOOR`).
			# - BORNE: a building's own `PRIVATE_VOLUME` stands there. The
			#   stone is that building's bearing. It shows only where the
			#   composition left the volume UNSTAMPED -- a room it reserved and
			#   never built -- which is a composition residue (the same one
			#   `maze_unroomed_plot_share` measures) and not a roof decision.
			# - BEARING: the cell is inside a flat-roofed STACK PARENT's own
			#   crown span, which `WarrenVolumetricSolver
			#   ._retain_maze_slab_courses` reserves as structure BEFORE the
			#   composition runs so a stacked child can prove its bearing
			#   against the grid. Task H2 tried twice to narrow that plate to
			#   the child's footprint and put it back both times: a child's
			#   COMPOSED room is not its plot, and either narrowing costs
			#   12/large its town. This is the one crown lid the phase did not
			#   retire, and it is counted rather than absorbed.
			# - RUBBLE: none of the above. Nothing stands on this crown,
			#   nothing walks it and nobody reserved it, so the masonry lid is
			#   exactly the fortress read the user rejected. Pinned at zero.
			if key.w >= SettlementFabricAssembler.FACE_DIRECTIONS.size() \
					and SettlementFabricAssembler.STONE_FACE_DIRECTIONS[
						key.w] == Vector3i.UP \
					and bool(bands.get(key.y, false)):
				var above := Vector3i(key.x, key.y + 1, key.z)
				var use_above := grid.use_at(above) \
					if grid != null and grid.contains(above) else -1
				if walked.has(above):
					paved_crown_cap_faces += 1
				elif use_above == WarrenSpatialGrid.Use.PRIVATE_VOLUME:
					borne_crown_cap_faces += 1
				elif (bearing_bands_by_column.get(column,
						{}) as Dictionary).has(key.y):
					bearing_crown_cap_faces += 1
				else:
					crown_cap_faces += 1
					if crown_cap_details.size() < 8:
						crown_cap_details.append("%d:%d:%d" % [key.x, key.y,
							key.z])
			min_offset = offset if faces == 0 else mini(min_offset, offset)
			max_offset = offset if faces == 0 else maxi(max_offset, offset)
			faces += 1
			high_faces += high
			plot_mass_faces += on_plot
			plot_mass_high_faces += high * on_plot
			roof_band_high_faces += high * on_roof
			unroomed_high_faces += high * (on_plot - on_roof)
			raised_shoulder_high_faces += high * int(raised.has(column))
			grounded_faces += int((candidates_by_column[column] \
				as Dictionary).is_empty())
			band_counts[offset] = int(band_counts.get(offset, 0)) + 1
			storey_counts[storey] = int(storey_counts.get(storey, 0)) + 1
	return {
		"maze_stone_profiled_face_count": faces,
		"maze_stone_high_face_count": high_faces,
		"maze_stone_high_face_ratio": float(high_faces) \
			/ float(maxi(1, faces)),
		"maze_stone_plot_mass_face_count": plot_mass_faces,
		"maze_stone_plot_mass_high_face_count": plot_mass_high_faces,
		"maze_stone_roof_band_high_face_count": roof_band_high_faces,
		"maze_stone_unroomed_high_face_count": unroomed_high_faces,
		"maze_stone_raised_shoulder_high_face_count": \
			raised_shoulder_high_faces,
		"maze_rubble_crown_cap_count": crown_cap_faces,
		"maze_paved_crown_cap_count": paved_crown_cap_faces,
		"maze_borne_crown_cap_count": borne_crown_cap_faces,
		"maze_bearing_crown_cap_count": bearing_crown_cap_faces,
		"maze_rubble_crown_cap_cells": crown_cap_details,
		"maze_stone_grounded_face_count": grounded_faces,
		"maze_stone_band_histogram": WarrenMazeSourcePlan.ascending_histogram(
			band_counts),
		"maze_stone_storey_histogram": \
			WarrenMazeSourcePlan.ascending_histogram(storey_counts),
		"maze_stone_min_band_offset": min_offset,
		"maze_stone_max_band_offset": max_offset,
	}


static func _macro_of(fine: int) -> int:
	## The macro coordinate a fine x or z belongs to. FLOOR division, not the
	## truncating kind: `_fine_square` maps macro -3 onto fine -6 and -5, and
	## `-5 / 2` is -2 in GDScript, which would file half the town's western
	## columns one column too far east.
	return (fine - posmod(fine, 2)) / 2


static func _maze_parent_crown_bands(
		maze_source: WarrenMazeSourcePlan) -> Dictionary:
	## `{column: {band: true}}` for every flat-roofed STACK PARENT's crown span
	## -- the plate `WarrenVolumetricSolver._retain_maze_slab_courses` reserves
	## as structure before the composition runs, and the one place a masonry
	## crown lid legitimately survives Task H2.
	##
	## Derived from the same plot facts the solver uses, not read back off the
	## grid, so the two cannot drift; empty for a legacy plan, which has no
	## maze source and therefore no stack parents.
	var out: Dictionary = {}
	if maze_source == null:
		return out
	var parents: Dictionary = {}
	for parent_value: Variant in (WarrenMazeBlockPartitioner.stack_parents(
			maze_source)["parents"] as Dictionary).values():
		parents[StringName(parent_value)] = true
	if parents.is_empty():
		return out
	for plot: Dictionary in maze_source.plots:
		if StringName(plot["kind"]) != WarrenMazeSourcePlan.PLOT_HOUSE \
				or not parents.has(StringName(plot["id"])) \
				or not WarrenMazeBlockPartitioner.plot_is_flat_roofed(
					maze_source, plot):
			continue
		var top_band := int(plot["top"])
		var roof_base := WarrenBuildingParcel.flat_roof_base_band(
			int(plot["floor"]), top_band)
		for cell_value: Variant in plot["cells"] as Array:
			var column := cell_value as Vector2i
			if not out.has(column):
				out[column] = {}
			for band in range(roof_base, top_band):
				(out[column] as Dictionary)[band] = true
	return out


static func _plot_bands_at(maze_source: WarrenMazeSourcePlan,
		column: Vector2i) -> Dictionary:
	## `{band: is_roof_band}` for every band some plot claims on this column.
	## Retained stone standing in one of them is a plot's own mass rather than
	## the mountain -- and the VALUE says which kind (fix 1, IMPORTANT 1): a
	## band inside `WarrenMazeBlockPartitioner.plot_roof_band_span` is roof by
	## the height contract, where no room may ever stand, so stone there is the
	## parapet course rather than a building the composition never roomed.
	## Plots are pairwise disjoint on a column, so no band is written twice.
	var out: Dictionary = {}
	for plot: Dictionary in maze_source.plots:
		if not (plot["cells"] as Array).has(column):
			continue
		var roof := WarrenMazeBlockPartitioner.plot_roof_band_span(maze_source,
			plot)
		for band in range(int(plot["floor"]), int(plot["top"])):
			out[band] = band >= roof.x and band < roof.y
	return out


## TASK H1. THE WALL METRIC. `maze_stone_band_profile` above measures what the
## MASSIF is -- how much retained mountain shows and how high it stands. This
## measures what the TOWN WEARS: every exterior wall face of every room unit,
## sorted into the two material families a viewer can tell apart and bucketed by
## the same band-offset-over-local-street-datum the rock metric uses, through the
## same `WarrenMazeSourcePlan.nearest_datum_band` (reused, never re-derived, so
## "how much stone" and "how high the stone stands" cannot disagree about where
## the ground is).
##
## A wall FACE, not a wall MODULE: one lateral face of one room cell whose
## neighbour is exterior air (`EXTERIOR_WALL_NEIGHBOUR_USES`). Party walls and
## rock-buried faces are excluded because nobody sees them, which is the whole
## point of a metric named after the eye. The count is therefore directly
## comparable with the rock metric's face count rather than with a module tally
## whose denominator depends on how a recipe happens to be cut up.
##
## SCOPE, stated so nothing hides. ROOM units only, because rooms are the mass a
## viewer reads as the town. Two things are deliberately outside it and neither
## is silently absorbed: the retained massif skin, which is not a wall anybody
## chose and is measured by the `maze_stone_*` keys merged beside these ones and
## printed on the same sweep row; and FEATURE units -- arcade overhang
## foundations, the rising ring's `room.pier.base.rock` -- which are structural
## supports, read as masonry legitimately, and are named here rather than
## counted. `exterior_wall_unprofiled_unit_count` is the guard on the scope
## itself: a room unit whose stamp this walk never reached. It is 0 by
## construction and a non-zero is a defect, not a category.
##
## Also the base-coherence audit, because it needs the same enumeration.
## `fragmented_base_run_count` is the user's named defect: along ONE building's
## exterior face at one band, a stone run interrupted by a non-stone segment and
## resumed. A neighbouring building in a different material is a SEAM, not a
## fragment, so runs are cut at the lineage boundary. Openings cannot break a run
## by construction -- a doorway cell wears its own family's authored door leaf --
## so no opening exemption is needed and none is granted.
static func exterior_wall_material_profile(source: WarrenSpatialPlan,
		room_units: Array[FabricUnit],
		maze_source: WarrenMazeSourcePlan) -> Dictionary:
	var family_by_room_id: Dictionary = {}
	var base_by_room_id: Dictionary = {}
	for unit: FabricUnit in room_units:
		var room_id := StringName(String(unit.stable_id).trim_prefix(
			"spatial.fabric."))
		family_by_room_id[room_id] = &"stone" \
			if STONE_WALL_FAMILIES.has(_room_recipe_facade_family(
				unit.recipe_id)) else &"timber"
		base_by_room_id[room_id] = String(unit.recipe_id).contains(".base.")
	var profiled_rooms: Dictionary = {}
	var candidates_by_column: Dictionary = {}
	var faces := 0
	var stone_faces := 0
	var off_datum_faces := 0
	var high_stone_faces := 0
	var stone_band_counts: Dictionary = {}
	var timber_band_counts: Dictionary = {}
	var min_offset := 0
	var max_offset := 0
	# {run key: {position along the run: is_stone}}. The key names the plane a
	# run lies in AND the lineage that owns it, so a run never crosses a
	# building seam.
	var base_runs: Dictionary = {}
	var grid := source.grid
	for building: WarrenBuildingVolume in source.buildings:
		for room: WarrenRoomStamp in building.room_records:
			if not family_by_room_id.has(room.stable_id):
				continue
			profiled_rooms[room.stable_id] = true
			var stone := StringName(
				family_by_room_id[room.stable_id]) == &"stone"
			var is_base := bool(base_by_room_id[room.stable_id])
			for cell: Vector3i in room.private_cells:
				var column := Vector2i(_macro_of(cell.x), _macro_of(cell.z))
				var on_massif := maze_source != null \
					and maze_source.massif != null \
					and maze_source.massif.has_column(column)
				var offset := 0
				if on_massif:
					if not candidates_by_column.has(column):
						candidates_by_column[column] = \
							maze_source.public_datum_candidates(column)
					offset = cell.y - WarrenMazeSourcePlan.nearest_datum_band(
						candidates_by_column[column] as Dictionary, cell.y,
						maze_source.massif.base_at(column))
				for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
						Vector3i.FORWARD, Vector3i.BACK]:
					if not EXTERIOR_WALL_NEIGHBOUR_USES.has(int(
							grid.use_at(cell + direction))):
						continue
					if not on_massif:
						faces += 1
						stone_faces += int(stone)
						off_datum_faces += 1
						continue
					min_offset = offset if faces == off_datum_faces \
						else mini(min_offset, offset)
					max_offset = offset if faces == off_datum_faces \
						else maxi(max_offset, offset)
					faces += 1
					stone_faces += int(stone)
					high_stone_faces += int(stone \
						and offset > WALL_BASE_BAND_OFFSET)
					var counts := stone_band_counts if stone \
						else timber_band_counts
					counts[offset] = int(counts.get(offset, 0)) + 1
					if not is_base:
						continue
					# A face on +-X lies in a plane of constant X and its run
					# extends along Z; a face on +-Z is the other way round. The
					# key is the plane (lineage, facing, band, fixed axis) and
					# the entry is the position ALONG the run.
					var run_key := "%s|%d|%d|%d|%d" % [
						String(room.source_parcel_id), direction.x, direction.z,
						cell.y, cell.x if direction.x != 0 else cell.z]
					var run := base_runs.get(run_key, {}) as Dictionary
					run[cell.z if direction.x != 0 else cell.x] = stone
					base_runs[run_key] = run
	var fragmented := 0
	var fragment_details: Array[Dictionary] = []
	var run_keys: Array = base_runs.keys()
	run_keys.sort()
	for run_key_value: Variant in run_keys:
		var run := base_runs[run_key_value] as Dictionary
		var positions: Array = run.keys()
		positions.sort()
		# Split into MAXIMAL CONTIGUOUS stretches first: two stone segments with
		# a gap of unbuilt columns between them are two faces of one building,
		# not one interrupted face.
		var stretches: Array[Array] = []
		var stretch: Array[bool] = []
		var previous := 0
		for index in positions.size():
			var position := int(positions[index])
			if index > 0 and position != previous + 1:
				stretches.append(stretch)
				stretch = []
			stretch.append(bool(run[position]))
			previous = position
		stretches.append(stretch)
		for candidate: Array in stretches:
			var materials: Array[bool] = []
			materials.assign(candidate)
			if not _run_is_fragmented(materials):
				continue
			fragmented += 1
			if fragment_details.size() < 8:
				fragment_details.append({"run": String(run_key_value),
					"materials": _run_text(materials)})
	var profiled := faces - off_datum_faces
	return {
		"exterior_wall_face_count": faces,
		"exterior_wall_stone_face_count": stone_faces,
		"exterior_wall_timber_face_count": faces - stone_faces,
		"exterior_wall_stone_face_ratio": float(stone_faces) \
			/ float(maxi(1, faces)),
		"exterior_wall_profiled_face_count": profiled,
		"exterior_wall_off_datum_face_count": off_datum_faces,
		"exterior_wall_high_stone_face_count": high_stone_faces,
		"exterior_wall_high_stone_face_ratio": float(high_stone_faces) \
			/ float(maxi(1, profiled)),
		"exterior_wall_stone_band_histogram": \
			WarrenMazeSourcePlan.ascending_histogram(stone_band_counts),
		"exterior_wall_timber_band_histogram": \
			WarrenMazeSourcePlan.ascending_histogram(timber_band_counts),
		"exterior_wall_min_band_offset": min_offset,
		"exterior_wall_max_band_offset": max_offset,
		"exterior_wall_unprofiled_unit_count": room_units.size() \
			- profiled_rooms.size(),
		"base_face_run_count": base_runs.size(),
		"fragmented_base_run_count": fragmented,
		"fragmented_base_run_details": fragment_details,
	}


static func _run_is_fragmented(run: Array[bool]) -> bool:
	## Stone, then something else, then stone again, along one contiguous face
	## of one building. The user's words: "the base is quite fragmented".
	var seen_stone := false
	var seen_gap := false
	for stone: bool in run:
		if stone:
			if seen_gap:
				return true
			seen_stone = true
		elif seen_stone:
			seen_gap = true
	return false


static func _run_text(run: Array[bool]) -> String:
	var out := ""
	for stone: bool in run:
		out += "S" if stone else "t"
	return out


static func _plinth_closes_band(plinths: Dictionary, face: Vector4i) -> bool:
	## Does a building's plinth panel already close the band this stone face
	## stands in? The panel hangs from the top of its own cell and is 3 m tall,
	## so a plinth face one band ABOVE this one, in the same plane, covers it.
	## The plane has two keyings -- the cell above, or the cell across the
	## boundary one band up facing back -- and this audit checks both, because
	## the assembler must defer to either.
	if plinths.is_empty():
		return false
	var above := Vector4i(face.x, face.y + 1, face.z, face.w)
	if plinths.has(above):
		return true
	var direction := SettlementFabricAssembler.FACE_DIRECTIONS[face.w]
	return plinths.has(Vector4i(above.x + direction.x, above.y,
		above.z + direction.z, face.w + 1 - 2 * (face.w % 2)))


static func _foundation_shell_audit(foundation_result: Dictionary,
		plan: SettlementFabricPlan) -> Dictionary:
	## Audit the exact faces the assembler will render, not a looser proxy. Every
	## exposed boundary of every building-wide course must own one stone module;
	## every module must descend to (or slightly bury into) that room's stamped
	## natural ground. The four-direction mask catches the old three-sided shell
	## even when its raw face count happened to look plausible.
	if plan == null or not bool(foundation_result.get("valid", false)):
		return {
			"foundation_building_count": 0,
			"foundation_closed_shell_count": 0,
			"foundation_incomplete_shell_count": 1,
			"foundation_expected_face_count": 0,
			"foundation_rendered_face_count": 0,
			"foundation_missing_face_count": 0,
			"foundation_floating_column_count": 0,
			"foundation_shell_details": [],
		}
	var retained := foundation_result.get("cells", {}) as Dictionary
	var maze_stone := foundation_result.get(
		"maze_stone_cells", {}) as Dictionary
	var maze_suppressed_face_count := 0
	var solids := plan.transformed_cells(&"solid")
	var bearing_footprint := plan.transformed_cells(&"terrain_bearing")
	var rendered := SettlementFabricAssembler.plinth_faces(retained, solids,
		bearing_footprint)
	var expected_face_count := 0
	var missing_face_count := 0
	var floating_column_count := 0
	var closed_shell_count := 0
	var incomplete_shell_count := 0
	var details: Array[Dictionary] = []
	for record_value: Variant in foundation_result.get(
			"room_records", []) as Array:
		var record := record_value as Dictionary
		var course_cells := record.get("course_cells", []) as Array[Vector3i]
		var own_course: Dictionary = {}
		for cell: Vector3i in course_cells:
			own_course[cell] = true
		var bearing_by_column := record.get(
			"bearing_by_column", {}) as Dictionary
		var direction_mask := 0
		var exposed_direction_mask := 0
		var room_expected_faces := 0
		var room_missing_faces := 0
		var room_floating_columns := 0
		for cell: Vector3i in course_cells:
			var bearing := int(bearing_by_column.get(
				Vector2i(cell.x, cell.z), cell.y))
			var module_bottom_band := cell.y + 1 \
				- FOUNDATION_MODULE_HEIGHT_BANDS
			if module_bottom_band > bearing:
				room_floating_columns += 1
			for direction_index in SettlementFabricAssembler.FACE_DIRECTIONS.size():
				var direction := SettlementFabricAssembler \
					.FACE_DIRECTIONS[direction_index]
				var neighbor := cell + direction
				if own_course.has(neighbor):
					continue
				direction_mask |= 1 << direction_index
				# An exactly adjoining retained course or occupied building cell
				# closes this seam. It is not an exposed side and must not receive
				# two intersecting stone panels.
				if retained.has(neighbor) or solids.has(neighbor) \
						or bearing_footprint.has(neighbor + Vector3i.UP):
					# TASK C5, review IMPORTANT 2 (measurement only). Retained
					# maze STONE closes this seam in the plan and renders
					# nothing at all today, so the panel this course would have
					# worn disappears without anything taking its place. That is
					# a render debt C5b inherits, and this is its size.
					maze_suppressed_face_count += int(maze_stone.has(neighbor) \
						and not solids.has(neighbor) \
						and not bearing_footprint.has(neighbor + Vector3i.UP))
					continue
				exposed_direction_mask |= 1 << direction_index
				room_expected_faces += 1
				if not rendered.has(Vector4i(cell.x, cell.y, cell.z,
						direction_index)):
					room_missing_faces += 1
		expected_face_count += room_expected_faces
		missing_face_count += room_missing_faces
		floating_column_count += room_floating_columns
		var shell_is_closed := direction_mask == 15 \
			and room_missing_faces == 0 and room_floating_columns == 0
		closed_shell_count += int(shell_is_closed)
		incomplete_shell_count += int(not shell_is_closed)
		details.append({
			"room_id": StringName(record.get("room_id", &"")),
			"course_cell_count": course_cells.size(),
			"perimeter_direction_mask": direction_mask,
			"exposed_direction_mask": exposed_direction_mask,
			"expected_face_count": room_expected_faces,
			"missing_face_count": room_missing_faces,
			"floating_column_count": room_floating_columns,
		})
	return {
		"terrain_bearing_room_count": int(foundation_result.get(
			"terrain_bearing_room_count", 0)),
		"flush_foundation_room_count": int(foundation_result.get(
			"flush_room_count", 0)),
		# Retained stone that is NOT a building plinth (Task C5 ruling 3):
		# counted, and outside every check above, because it owns no room
		# record and therefore no shell to close.
		"maze_retained_stone_cells": int(foundation_result.get(
			"maze_retained_stone_cells", 0)),
		# The same stone told apart (Task C5c ruling 1): derived rock the plot
		# model wants, a plot's own roof course, and unroomed plot mass it does
		# not want at all.
		"maze_retained_rock_cells": int(foundation_result.get(
			"maze_retained_rock_cells", 0)),
		"maze_retained_rock_stone_roof_cells": int(foundation_result.get(
			"maze_retained_rock_stone_roof_cells", 0)),
		# Rooms on a tier, a tunnel roof or a deep rock base: terrain-bearing,
		# but carried by retained stone or by the house below rather than by an
		# authored plinth course of their own (Task C5c ruling 4).
		"maze_stone_borne_room_count": int(foundation_result.get(
			"maze_stone_borne_room_count", 0)),
		"maze_unroomed_plot_cells": int(foundation_result.get(
			"maze_unroomed_plot_cells", 0)),
		"maze_unroomed_plot_share": float(foundation_result.get(
			"maze_unroomed_plot_share", 0.0)),
		"maze_plinth_faces_suppressed_by_stone": maze_suppressed_face_count,
		"foundation_building_count": details.size(),
		"foundation_closed_shell_count": closed_shell_count,
		"foundation_incomplete_shell_count": incomplete_shell_count,
		"foundation_expected_face_count": expected_face_count,
		"foundation_rendered_face_count": rendered.size(),
		"foundation_missing_face_count": missing_face_count,
		"foundation_floating_column_count": floating_column_count,
		"foundation_shell_details": details,
	}


static func compile_room_units(source: WarrenSpatialPlan,
		program: SettlementFabricProgram) -> Array[FabricUnit]:
	last_failure = ""
	last_audit = {}
	if source == null or not source.is_sealed() or program == null:
		last_failure = "missing sealed spatial plan or measured vocabulary"
		return [] as Array[FabricUnit]
	var room_started_ms := Time.get_ticks_msec()
	var rooms: Array[WarrenRoomStamp] = []
	var building_by_room: Dictionary = {}
	var room_by_id: Dictionary = {}
	for building: WarrenBuildingVolume in source.buildings:
		for room: WarrenRoomStamp in building.room_records:
			rooms.append(room)
			building_by_room[room.stable_id] = building.stable_id
			room_by_id[room.stable_id] = room
	var low_base_lineages := _low_base_lineages(source, rooms)
	var stone_base_lineages := _bounded_stone_base_lineages(source, rooms,
		low_base_lineages)
	rooms.sort_custom(func(a: WarrenRoomStamp, b: WarrenRoomStamp) -> bool:
		# A street-bridge room may meet a half-storey-staggered flank whose
		# base sits one band above its own; ordering bridges one band late
		# guarantees every flank unit it names exists before it binds --
		# two for the `room.bridge.*` arch, one for the bracketed jetty.
		var a_y := a.lattice_origin.y + int(not (a.audit.get(
			"bridge_support_room_ids", []) as Array).is_empty())
		var b_y := b.lattice_origin.y + int(not (b.audit.get(
			"bridge_support_room_ids", []) as Array).is_empty())
		if a_y != b_y:
			return a_y < b_y
		if a.source_storey_index != b.source_storey_index:
			return a.source_storey_index < b.source_storey_index
		return String(a.stable_id) < String(b.stable_id))
	var room_by_source_level: Dictionary = {}
	var room_by_private_cell: Dictionary = {}
	var room_id_by_private_cell: Dictionary = {}
	for room: WarrenRoomStamp in rooms:
		var key := _source_level_key(room.source_parcel_id,
			room.source_storey_index)
		if room_by_source_level.has(key):
			last_failure = "two rooms own source level %s" % key
			return [] as Array[FabricUnit]
		room_by_source_level[key] = room
		for cell: Vector3i in room.private_cells:
			room_by_private_cell[cell] = room
			room_id_by_private_cell[cell] = room.stable_id
	# Compile the bearing graph in its own deterministic topological order.
	# Height plus stable-id was only an approximation: a half-storey bridge end
	# can sit one band above the occupied span and sort after the room that names
	# it. The plan already carries every exact support relationship, so construction
	# consumes that DAG directly instead of guessing parenthood from altitude.
	rooms = _rooms_in_support_order(rooms, room_by_source_level,
		room_by_private_cell)
	if rooms.is_empty() and not room_by_id.is_empty():
		return [] as Array[FabricUnit]
	# Roof faces are already authoritative plan facts at this point. Reserve the
	# exact finite weather-closure domain for each face (complete tiled gable,
	# handed partial gable, or an already-public structural deck) before choosing
	# optional phase-B facade projections.
	# Without this ordering a bay/laundry/sign detail can be legal against every
	# room, then make an unrelated roof impossible several compiler phases later.
	var room_stage_ms := _trace_stage("room.index", room_started_ms)
	var required_roof_clearance := _required_roof_clearance(source, program,
		rooms, room_id_by_private_cell)
	room_stage_ms = _trace_stage("room.roof_clearance", room_stage_ms)
	var feature_portal_masks := _feature_portal_masks(source, room_by_id)
	if not last_failure.is_empty():
		return [] as Array[FabricUnit]
	var feature_portal_opening_count := 0
	for mask_value: Variant in feature_portal_masks.values():
		feature_portal_opening_count += _feature_portal_bit_count(int(mask_value))
	# TASK C6 RULING 1. The ROOMS are authoritative plan facts here too, and the
	# ordering argument above is theirs as well: reserve the smallest measured
	# shell every room is REQUIRED to take before choosing anyone's optional
	# phase-B projection. Maze towns are where this bites -- the plot model
	# stacks unrelated houses one band apart across a corner, so an ivy, sign or
	# laundry piece hung 0.3-0.8 m off the front of a house at band 2 reaches
	# into the footprint of a house at band 4 that has not been compiled yet.
	# When that house's turn came, the only recovery `compile_room_units` owns
	# -- demote THIS room from phase B to phase A -- was already spent on the
	# wrong room: a ground room's `*.base.*` shell is mandatory and has no
	# phase-B mate at all, so `fallback_id == recipe_id` and the town died.
	# Measured: it is the whole `failed measured phase selection` family.
	room_stage_ms = _trace_stage("room.portals", room_stage_ms)
	var required_room_clearance := _required_room_clearance(source, program,
		rooms, room_id_by_private_cell, feature_portal_masks)
	var units: Array[FabricUnit] = []
	var unit_by_room: Dictionary = {}
	var prior_unit_by_cell: Dictionary = {}
	var desired_phase_b_count := 0
	var selected_phase_b_count := 0
	var facade_phase_fallback_count := 0
	var hero_feature_facade_fallback_count := 0
	var roof_clearance_facade_fallback_count := 0
	var required_room_facade_fallback_count := 0
	var required_room_yields: Array[Dictionary] = []
	var physical_support_redirect_count := 0
	var retained_stone_bearing_count := 0
	var suppressed_party_wall_module_count := 0
	var facade_family_counts: Dictionary = {}
	var facade_style_counts: Dictionary = {}
	var building_variant_counts: Dictionary = {}
	var lineage_style_by_id: Dictionary = {}
	room_stage_ms = _trace_stage("room.room_clearance", room_stage_ms)
	var room_probe := SettlementFabricPlan.new(&"spatial.room-phase-selection")
	for recipe_value: FabricRecipe in program.recipes():
		if not room_probe.register_recipe(recipe_value):
			last_failure = "room phase selection could not register %s" \
				% recipe_value.recipe_id
			return [] as Array[FabricUnit]
	for room: WarrenRoomStamp in rooms:
		var feature_portal_mask := int(feature_portal_masks.get(room.stable_id, 0))
		var on_retained_stone := _room_bears_on_retained_stone(source, program,
			room, feature_portal_mask)
		retained_stone_bearing_count += int(on_retained_stone)
		# TASK H1. `chosen_material` -- this is the pass that decides what the
		# town is built of, and the only one that does. Every reservation the
		# pipeline made for this room, here and upstream, was measured against
		# the wider masonry shell.
		var recipe_id := _room_recipe_id(room, source.world_seed, true,
			feature_portal_mask, on_retained_stone, true, low_base_lineages,
			stone_base_lineages)
		var desired_phase_b := _is_phase_b_recipe(recipe_id)
		desired_phase_b_count += int(desired_phase_b)
		var recipe := program.recipe(recipe_id)
		if recipe == null or not _recipe_stays_inside_stamp(recipe, room):
			last_failure = "measured recipe %s changes room stamp %s" % [
				recipe_id, room.stable_id]
			return [] as Array[FabricUnit]
		if not _entrance_matches(recipe, room):
			var entrance := (recipe.entrances[0] as Dictionary) \
				if recipe != null and recipe.entrances.size() == 1 else {}
			var actual_cell := FabricRecipe.transform_cell(
				entrance.get("cell", Vector3i.ZERO) as Vector3i,
				room.lattice_origin, room.yaw_quarters) if not entrance.is_empty() \
				else Vector3i(2147483647, 2147483647, 2147483647)
			var actual_facing := FabricRecipe.transform_direction(
				entrance.get("facing", Vector3i.ZERO) as Vector3i,
				room.yaw_quarters) if not entrance.is_empty() else Vector3i.ZERO
			last_failure = ("measured doorway in %s changes threshold for %s " \
				+ "kind=%s phase=%d yaw=%d expected=%s/%s actual=%s/%s") % [
				recipe_id, room.stable_id, room.kind, room.address_door_phase,
				room.yaw_quarters, room.threshold_cell, room.frontage_direction,
				actual_cell, actual_facing]
			return [] as Array[FabricUnit]
		var parents: Array[StringName] = []
		var bonds: Array[Dictionary] = []
		var bridge_support_room_ids: Array[StringName] = []
		bridge_support_room_ids.assign(room.audit.get(
			"bridge_support_room_ids", []) as Array)
		if not bridge_support_room_ids.is_empty():
			# A street-bridge room bears on the flanking rooms it spans
			# between: TWO for the `room.bridge.*` arch, and exactly ONE for
			# Task E3b's `room.jetty.*`, whose second bearing is the separately
			# reserved bracket course rather than a wall. Every bond named here
			# goes through the exact strict socket adjacency, whichever form it
			# is; a bridge that cannot meet a flank it names is a compile
			# failure, never a silently floating room.
			var bridge_lineages: Dictionary = {}
			for flank_room_id: StringName in bridge_support_room_ids:
				var flank_room := room_by_id.get(flank_room_id) \
					as WarrenRoomStamp
				var flank_unit := unit_by_room.get(flank_room_id) as FabricUnit
				if flank_room == null or flank_unit == null:
					last_failure = "bridge room %s has no built flank %s" % [
						room.stable_id, flank_room_id]
					return [] as Array[FabricUnit]
				var span_bond := _bridge_span_bond(room, recipe, flank_room,
					flank_unit, program)
				if span_bond.is_empty():
					last_failure = "bridge room %s cannot meet flank %s" % [
						room.stable_id, flank_room_id]
					return [] as Array[FabricUnit]
				parents.append(flank_unit.stable_id)
				bonds.append(span_bond)
				bridge_lineages[flank_room.source_parcel_id] = true
			if bridge_support_room_ids.size() == 2 \
					and bridge_lineages.size() != 2:
				last_failure = "skywalk room %s does not join two independent buildings" \
					% room.stable_id
				return [] as Array[FabricUnit]
		elif on_retained_stone:
			# No bearing bond, for the reason stated at the recipe choice
			# above. The room's ANCESTRY is untouched: the support DAG and the
			# private-access proof still name the house underneath it.
			pass
		elif not room.terrain_bearing:
			var parent_key := _source_level_key(
				room.support_parent_parcel_id,
				room.support_parent_storey_index)
			var lineage_parent := room_by_source_level.get(parent_key) \
				as WarrenRoomStamp
			var parent_room := _physical_support_parent(room,
				room_by_private_cell, lineage_parent)
			if parent_room == null or not unit_by_room.has(parent_room.stable_id):
				last_failure = "room %s has no built support parent %s" % [
					room.stable_id, parent_key]
				return [] as Array[FabricUnit]
			physical_support_redirect_count += int(lineage_parent != null \
				and parent_room.stable_id != lineage_parent.stable_id)
			var parent_unit := unit_by_room[parent_room.stable_id] as FabricUnit
			var bearing := _bearing_bond(room, parent_room, parent_unit.stable_id)
			if bearing.is_empty():
				last_failure = "offset room %s has no exact bearing overlap" % \
					room.stable_id
				return [] as Array[FabricUnit]
			parents.append(parent_unit.stable_id)
			bonds.append(bearing)
		var seams := _prior_visual_seam_units(source.grid, room,
			prior_unit_by_cell, building_by_room, room_probe, recipe)
		var suppressed := _suppressed_party_wall_placements(source.grid,
			room, recipe)
		var unit := FabricUnit.new(StringName("spatial.fabric.%s" % room.stable_id),
			recipe_id, room.lattice_origin, room.yaw_quarters, parents, bonds,
			&"", seams, suppressed)
		if not unit.is_valid():
			last_failure = "room %s produced an invalid fabric unit" % room.stable_id
			return [] as Array[FabricUnit]
		# The flush fallback is the same wall in the same material, one phase
		# plainer, so it takes `chosen_material` too: a demotion may not also be
		# a change of material.
		var fallback_id := _room_recipe_id(room, source.world_seed, false,
			feature_portal_mask, on_retained_stone, true, low_base_lineages,
			stone_base_lineages)
		var fallback_recipe := program.recipe(fallback_id)
		var feature_conflict := _room_feature_envelope_conflict(source,
			program, room, recipe)
		var roof_conflict := _room_required_roof_conflict(room, recipe,
			required_roof_clearance, program)
		var projection_conflict := _room_optional_projection_conflict(room,
			recipe, fallback_recipe, required_room_clearance)
		var desired_rejection := "visual envelope intersects unrelated feature %s" \
			% feature_conflict if not feature_conflict.is_empty() \
			else "visual envelope intersects required roof %s" % roof_conflict \
			if not roof_conflict.is_empty() \
			else "optional facade projection intersects required room %s" \
			% projection_conflict if not projection_conflict.is_empty() else ""
		var desired_added := feature_conflict.is_empty() \
			and roof_conflict.is_empty() and projection_conflict.is_empty() \
			and room_probe.add_unit(unit)
		if not desired_added:
			if desired_rejection.is_empty():
				desired_rejection = room_probe.last_rejection
			if fallback_id == recipe_id:
				last_audit["room_phase_failure"] = \
					_room_phase_failure_audit(room, recipe, seams,
						room_probe, unit_by_room, room_by_id, source.grid)
				last_failure = "room %s failed measured phase selection: %s" % [
					room.stable_id, desired_rejection]
				return [] as Array[FabricUnit]
			if fallback_recipe == null \
					or not _recipe_stays_inside_stamp(fallback_recipe, room) \
					or not _entrance_matches(fallback_recipe, room):
				last_failure = "room %s has no measured facade fallback" \
					% room.stable_id
				return [] as Array[FabricUnit]
			suppressed = _suppressed_party_wall_placements(source.grid,
				room, fallback_recipe)
			unit = FabricUnit.new(unit.stable_id, fallback_id,
				room.lattice_origin, room.yaw_quarters, parents, bonds, &"", seams,
				suppressed)
			var fallback_conflict := _room_feature_envelope_conflict(source,
				program, room, fallback_recipe)
			var fallback_roof_conflict := _room_required_roof_conflict(room,
				fallback_recipe, required_roof_clearance, program)
			if not unit.is_valid() or not fallback_conflict.is_empty() \
					or not fallback_roof_conflict.is_empty() \
					or not room_probe.add_unit(unit):
				last_audit["room_phase_failure"] = \
					_room_phase_failure_audit(room, fallback_recipe, seams,
						room_probe, unit_by_room, room_by_id, source.grid)
				var fallback_rejection := \
					"visual envelope intersects unrelated feature %s" \
						% fallback_conflict if not fallback_conflict.is_empty() \
					else "visual envelope intersects required roof %s" \
						% fallback_roof_conflict \
						if not fallback_roof_conflict.is_empty() \
					else room_probe.last_rejection
				last_failure = "room %s fallback failed measured phase selection: %s" \
					% [room.stable_id, fallback_rejection]
				return [] as Array[FabricUnit]
			facade_phase_fallback_count += 1
			hero_feature_facade_fallback_count += int(
				not feature_conflict.is_empty())
			roof_clearance_facade_fallback_count += int(
				not roof_conflict.is_empty())
			required_room_facade_fallback_count += int(
				not projection_conflict.is_empty())
			if not projection_conflict.is_empty():
				# Named, not just counted: this is the fact a test can check
				# against the sealed plan and the measured vocabulary without
				# asking the compiler what it decided.
				required_room_yields.append({"room_id": room.stable_id,
					"desired_recipe_id": recipe_id,
					"chosen_recipe_id": fallback_id,
					"required": projection_conflict})
		selected_phase_b_count += int(_is_phase_b_recipe(unit.recipe_id))
		suppressed_party_wall_module_count += \
			unit.suppressed_placement_ids.size()
		var facade_family := _room_recipe_facade_family(unit.recipe_id)
		facade_family_counts[facade_family] = int(
			facade_family_counts.get(facade_family, 0)) + 1
		var facade_phase := _room_recipe_facade_phase(unit.recipe_id)
		var style_key := StringName("%s.%d" % [String(room.kind),
			facade_phase / 2])
		facade_style_counts[style_key] = int(
			facade_style_counts.get(style_key, 0)) + 1
		var variant_key := StringName("%s.%s.%d" % [String(room.kind),
			String(facade_family), facade_phase / 2])
		building_variant_counts[variant_key] = int(
			building_variant_counts.get(variant_key, 0)) + 1
		lineage_style_by_id[room.source_parcel_id] = facade_phase / 2
		units.append(unit)
		unit_by_room[room.stable_id] = unit
		for cell: Vector3i in room.private_cells:
			prior_unit_by_cell[cell] = unit.stable_id
	last_audit = {
		"desired_facade_phase_b_count": desired_phase_b_count,
		"selected_facade_phase_b_count": selected_phase_b_count,
		"facade_phase_fallback_count": facade_phase_fallback_count,
		"facade_phase_a_count": units.size() - selected_phase_b_count,
		"hero_feature_facade_fallback_count": \
			hero_feature_facade_fallback_count,
		"roof_clearance_facade_fallback_count": \
			roof_clearance_facade_fallback_count,
		"required_room_facade_fallback_count": \
			required_room_facade_fallback_count,
		"required_room_facade_yields": required_room_yields,
		"required_roof_clearance_envelope_count": \
			required_roof_clearance.size(),
		"required_roof_closure_group_count": required_roof_clearance.size(),
		"required_room_clearance_envelope_count": \
			required_room_clearance.size(),
		"physical_support_redirect_count": physical_support_redirect_count,
		"retained_stone_bearing_room_count": retained_stone_bearing_count,
		"bounded_stone_base_lineage_count": maxi(0,
			stone_base_lineages.size() - int(stone_base_lineages.has(
				STONE_BASE_SELECTION_MARKER))),
		"suppressed_party_wall_module_count": \
			suppressed_party_wall_module_count,
		"feature_portal_room_count": feature_portal_masks.size(),
		"feature_portal_opening_count": feature_portal_opening_count,
		"facade_family_counts": facade_family_counts,
		"facade_style_counts": facade_style_counts,
		"facade_style_count": facade_style_counts.size(),
		"building_variant_counts": building_variant_counts,
		"building_variant_count": building_variant_counts.size(),
		"styled_building_lineage_count": lineage_style_by_id.size(),
	}
	return units


static func _room_phase_failure_audit(room: WarrenRoomStamp,
		recipe: FabricRecipe, declared_seams: Array[StringName],
		probe: SettlementFabricPlan, unit_by_room: Dictionary,
		room_by_id: Dictionary, grid: WarrenSpatialGrid) -> Dictionary:
	var bounds := FabricRecipe.lattice_transform(room.lattice_origin,
		room.yaw_quarters) * recipe.local_clearance_bounds
	var overlaps: Array[Dictionary] = []
	for prior_room_value: Variant in unit_by_room.keys():
		var prior_room_id := StringName(prior_room_value)
		var prior_unit := unit_by_room[prior_room_id] as FabricUnit
		var prior_recipe := probe.recipe(prior_unit.recipe_id)
		if prior_recipe == null:
			continue
		var prior_bounds := prior_unit.transform() \
			* prior_recipe.local_clearance_bounds
		if not SettlementFabricPlan._aabb_overlaps_volume(bounds, prior_bounds):
			continue
		var prior_room := room_by_id.get(prior_room_id) as WarrenRoomStamp
		var contact_faces: Array[Dictionary] = []
		if prior_room != null:
			for cell: Vector3i in room.private_cells:
				for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
						Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD,
						Vector3i.BACK]:
					if not prior_room.has_private_cell(cell + direction):
						continue
					var claim := grid.face_claim(cell, direction)
					contact_faces.append({"cell": cell, "direction": direction,
						"kind": int(claim.get("kind", -1)),
						"owner": StringName(claim.get("owner_id", &""))})
		overlaps.append({"unit_id": prior_unit.stable_id,
			"room_id": prior_room_id, "recipe_id": prior_unit.recipe_id,
			"bounds": prior_bounds,
			"declared_seam": declared_seams.has(prior_unit.stable_id),
			"edge_nick": SettlementFabricPlan._is_edge_nick(bounds,
				prior_bounds), "contact_faces": contact_faces})
	return {"room_id": room.stable_id, "source_parcel_id": room.source_parcel_id,
		"kind": room.kind, "origin": room.lattice_origin,
		"recipe_id": recipe.recipe_id, "bounds": bounds,
		"declared_seams": declared_seams.duplicate(), "overlaps": overlaps}


static func _party_wall_allowed_room_ids(source: WarrenSpatialPlan,
		room: WarrenRoomStamp, room_id_by_private_cell: Dictionary) \
		-> Dictionary:
	## The rooms a reservation belonging to `room` may be met by: itself, and
	## every room on the far side of a PARTY_WALL face. A party wall IS the
	## shell contract for "these two shells touch", so a reservation it makes
	## can never be a reason to refuse the neighbour it shares that wall with.
	##
	## One statement of it, because both pre-passes need it and a reservation
	## that admitted a different set of neighbours from the other would be a
	## silent disagreement about what contact means.
	return _party_wall_allowed_room_ids_for_grid(source.grid, room,
		room_id_by_private_cell)


static func _party_wall_allowed_room_ids_for_grid(grid: WarrenSpatialGrid,
		room: WarrenRoomStamp, room_id_by_private_cell: Dictionary) \
		-> Dictionary:
	var allowed_room_ids: Dictionary = {room.stable_id: true}
	# Some roof roles terminate at one particular typed party plane. An occupied
	# bridge endpoint, for example, uses a seam-clipped gable toward the bridge
	# house; a different house touching its rear or side is ordinary obstruction,
	# not permission to consume that reserved crown. The topology producer names
	# the finite room ids that may use such a seam. Absence of the contract keeps
	# the ordinary all-party-walls behavior below.
	var explicit_party_ids: Dictionary = {}
	var has_explicit_party_contract := room.audit.has(
		"roof_party_allowed_room_ids")
	if has_explicit_party_contract:
		for room_id_value: Variant in room.audit.get(
				"roof_party_allowed_room_ids", []) as Array:
			explicit_party_ids[StringName(room_id_value)] = true
	for cell: Vector3i in room.private_cells:
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD, Vector3i.BACK]:
			var neighbor_id := StringName(room_id_by_private_cell.get(
				cell + direction, &""))
			if neighbor_id.is_empty() or neighbor_id == room.stable_id:
				continue
			# A prospective bridge body is intentionally absent from the live grid
			# while this reversible roof preflight runs, so its PARTY_WALL face cannot
			# have been committed yet. The endpoint nevertheless names that one future
			# room explicitly, and the reconstructed room map proves exact adjacency.
			# Treat those two source facts as the pending party seam; requiring the
			# later face claim here made the all-or-nothing transaction circular.
			if has_explicit_party_contract and explicit_party_ids.has(neighbor_id):
				allowed_room_ids[neighbor_id] = true
				continue
			var claim := grid.face_claim(cell, direction)
			if int(claim.get("kind", -1)) \
					== WarrenSpatialGrid.FaceKind.PARTY_WALL \
					and (not has_explicit_party_contract \
						or explicit_party_ids.has(neighbor_id)):
				allowed_room_ids[neighbor_id] = true
	return allowed_room_ids


static func _required_room_clearance(source: WarrenSpatialPlan,
		program: SettlementFabricProgram, rooms: Array[WarrenRoomStamp],
		room_id_by_private_cell: Dictionary,
		feature_portal_masks: Dictionary) -> Array[Dictionary]:
	## TASK C6 RULING 1. The mandatory shell of every room: the recipe
	## `_room_recipe_id` returns with `allow_phase_b` false, which is the
	## SMALLEST authored construction that room can ever be built from. A
	## ground or retained-stone room has only that one shell; an upper room may
	## additionally hang an ivy, sign, laundry or windowbox piece off its front,
	## and that piece is optional by construction -- see
	## `SettlementFabricProgram._add_front_facade_detail`, whose own doc says it
	## exists so a detail "can fall back to the flush phase-A shell at a tight
	## party wall instead of clipping a lane".
	##
	## MAZE TOWNS ONLY, because the ordering defect is theirs: the plot model
	## packs unrelated houses one band apart across a shared corner, and the
	## selection loop walks rooms bottom band first, so the projecting room is
	## almost always compiled BEFORE the mandatory room it reaches into. On a
	## route-first or mass-first plan this returns an empty list and the gate
	## below is inert, so every legacy payload is byte-identical.
	var out: Array[Dictionary] = []
	if source.source_volume == null \
			or not source.source_volume.mass_context.has(&"maze_source_plan"):
		return out
	for room: WarrenRoomStamp in rooms:
		var mask := int(feature_portal_masks.get(room.stable_id, 0))
		var required_id := _room_recipe_id(room, source.world_seed, false, mask,
			_room_bears_on_retained_stone(source, program, room, mask))
		var required_recipe := program.recipe(required_id)
		if required_recipe == null or required_recipe.placements.is_empty():
			continue
		var allowed_room_ids := _party_wall_allowed_room_ids(source, room,
			room_id_by_private_cell)
		out.append({"owner_room_id": room.stable_id,
			"recipe_id": required_id,
			"bounds": FabricRecipe.lattice_transform(room.lattice_origin,
				room.yaw_quarters) * required_recipe.local_clearance_bounds,
			"allowed_room_ids": allowed_room_ids})
	return out


static func _room_optional_projection_conflict(room: WarrenRoomStamp,
		recipe: FabricRecipe, fallback_recipe: FabricRecipe,
		required_room_clearance: Array[Dictionary]) -> StringName:
	## Refuse a phase-B facade whose OPTIONAL projection is the sole reason its
	## envelope meets a room that has no choice about its own shell.
	##
	## The last clause is the whole safety of this gate, and it is why it can
	## never demote a facade for a contact the fabric already forgives: if the
	## FLUSH phase-A shell meets that same room too, the projection is not the
	## cause and nothing is refused. Every relation the plan admits by
	## construction -- a bearing parent under a stacked room, a party wall, a
	## bridge flank -- meets flush as well as projecting, so it is skipped here
	## and stays the business of `SettlementFabricPlan.add_unit`.
	if required_room_clearance.is_empty() or room == null or recipe == null \
			or fallback_recipe == null \
			or recipe.recipe_id == fallback_recipe.recipe_id \
			or recipe.placements.is_empty():
		return &""
	var transform := FabricRecipe.lattice_transform(room.lattice_origin,
		room.yaw_quarters)
	var projecting_bounds := transform * recipe.local_clearance_bounds
	var flush_bounds := transform * fallback_recipe.local_clearance_bounds
	for required: Dictionary in required_room_clearance:
		if StringName(required.owner_room_id) == room.stable_id \
				or (required.allowed_room_ids as Dictionary).has(
					room.stable_id):
			continue
		var required_bounds := required.bounds as AABB
		if not _aabb_overlaps_volume(projecting_bounds, required_bounds) \
				or _aabb_overlaps_volume(flush_bounds, required_bounds):
			continue
		return StringName("%s/%s" % [required.owner_room_id,
			required.recipe_id])
	return &""


static func _required_roof_clearance(source: WarrenSpatialPlan,
		program: SettlementFabricProgram, rooms: Array[WarrenRoomStamp],
		room_id_by_private_cell: Dictionary) -> Array[Dictionary]:
	## Compile a lower bound on the measured roof construction that the sealed
	## face plan must eventually receive. This must be an ACTUAL weather closure,
	## never the thin flat-cap placeholder that used to let projecting facades win
	## the volume and make the later gable impossible. A complete terminal plate
	## reserves its all-low tiled profile; a private partial row reserves both
	## handed exact gable halves; only an already-sealed PUBLIC_FLOOR reserves
	## plank backing. These are finite measured alternatives, not speculative
	## halos, and room facades are selected only after they are in the transaction.
	## Each dictionary below is one REQUIRED closure with one or more finite
	## alternatives. A facade blocks the closure only when it blocks EVERY
	## alternative; this is the same existential contract used by the feature
	## solver and prevents a left-handed partial gable from reserving the space of
	## its mutually exclusive right-handed mate.
	var roof_faces_by_room := _roof_faces_by_room(source,
		room_id_by_private_cell)
	return _required_roof_clearance_for_grid(source.grid, program, rooms,
		room_id_by_private_cell, roof_faces_by_room, source.world_seed)


static func required_roof_closure_options(grid: WarrenSpatialGrid,
		buildings: Array[WarrenBuildingVolume],
		program: SettlementFabricProgram, world_seed: int) -> Array[Dictionary]:
	## Public projection of the compiler's exact roof-domain construction for
	## feature solvers that run before `WarrenSpatialPlan` exists. Roof faces are
	## read from the same sealed face claims; no second footprint heuristic or
	## asset table is maintained by balconies/outcroppings.
	if grid == null or program == null:
		return [] as Array[Dictionary]
	var rooms: Array[WarrenRoomStamp] = []
	for building: WarrenBuildingVolume in buildings:
		for room: WarrenRoomStamp in building.room_records:
			rooms.append(room)
	return required_roof_closure_options_for_rooms(grid, rooms, program,
		world_seed)


static func required_roof_closure_options_for_rooms(grid: WarrenSpatialGrid,
		rooms: Array[WarrenRoomStamp], program: SettlementFabricProgram,
		world_seed: int) -> Array[Dictionary]:
	## Exact room-stamp projection of the roof-domain transaction. Feature beams
	## and residual packing both run before their proposed rooms have entered the
	## live grid, so deriving exposure from `grid.use_at()` makes those reversible
	## proposals invisible. Instead, reconstruct the future occupied volume from
	## the same room stamps the compiler will consume and expose precisely those
	## top-band cells with no room above. Existing PUBLIC_AIR/face claims remain in
	## `grid` and are still consulted by `_required_roof_clearance_for_grid` when
	## choosing a public deck versus a private weather closure.
	if grid == null or program == null:
		return [] as Array[Dictionary]
	var room_id_by_private_cell: Dictionary = {}
	for room: WarrenRoomStamp in rooms:
		if room == null:
			continue
		for cell: Vector3i in room.private_cells:
			room_id_by_private_cell[cell] = room.stable_id
	var roof_faces_by_room: Dictionary = {}
	for room: WarrenRoomStamp in rooms:
		if room == null:
			continue
		var top_y := room.lattice_origin.y \
			+ WarrenSpatialGrid.STOREY_CELLS - 1
		for cell: Vector3i in room.private_cells:
			if cell.y != top_y \
					or room_id_by_private_cell.has(cell + Vector3i.UP):
				continue
			if not roof_faces_by_room.has(room.stable_id):
				roof_faces_by_room[room.stable_id] = [] as Array[Vector3i]
			(roof_faces_by_room[room.stable_id] \
				as Array[Vector3i]).append(cell)
	return _required_roof_clearance_for_grid(grid, program, rooms,
		room_id_by_private_cell, roof_faces_by_room, world_seed)


static func _required_roof_clearance_for_grid(grid: WarrenSpatialGrid,
		program: SettlementFabricProgram, rooms: Array[WarrenRoomStamp],
		room_id_by_private_cell: Dictionary, roof_faces_by_room: Dictionary,
		world_seed: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for room: WarrenRoomStamp in rooms:
		if not roof_faces_by_room.has(room.stable_id):
			continue
		var face_cells := roof_faces_by_room[room.stable_id] \
			as Array[Vector3i]
		var allowed_room_ids := _party_wall_allowed_room_ids_for_grid(grid, room,
			room_id_by_private_cell)
		var explicit_party_ids: Dictionary = {}
		var has_explicit_party_contract := room.audit.has(
			"roof_party_allowed_room_ids")
		if has_explicit_party_contract:
			for room_id_value: Variant in room.audit.get(
					"roof_party_allowed_room_ids", []) as Array:
				explicit_party_ids[StringName(room_id_value)] = true
		# A lower roof meeting the wall of a taller neighboring room is also a
		# typed construction seam. Derive those exact cap-perimeter contacts from
		# the sealed occupancy now; the measured seam policy below still decides
		# whether a particular roof/room envelope contact is shallow enough.
		for contact_id: StringName in _setback_wall_room_ids(face_cells,
				room_id_by_private_cell):
			if not has_explicit_party_contract \
					or explicit_party_ids.has(contact_id):
				allowed_room_ids[contact_id] = true
		if _is_full_roof_plate(room, face_cells) \
				and not _touches_public_air(grid, face_cells):
			# This is the same finite construction domain consumed by final roof
			# assembly, including its even-cell phase correction and exact public-air
			# test.  The former single "minimum roof" used the room origin directly;
			# after a quarter turn that reserved a crown 1.5 m away from the one later
			# built, and it never noticed when the real eaves entered a walkway.
			var candidate_rows: Array[Dictionary] = []
			if room.audit.has("bridge_party_roof_yaw_quarters"):
				# A bridge endpoint owns one seam-clipped gable at the source-planned
				# party plane. Its closure reservation must be that same role recipe
				# and absolute ridge orientation; reserving a generic low terminal
				# roof here lets later rooms consume cells the final bridge gable owns.
				candidate_rows = _full_roof_candidates(room, world_seed)
			else:
				candidate_rows = _full_roof_candidates(room, world_seed)
				for terminal_id: StringName in _terminal_tight_gable_recipe_ids(
						room, world_seed):
					candidate_rows.append({"recipe_id": terminal_id,
						"yaw_offset": 0})
			var options: Array[Dictionary] = []
			var seen_options: Dictionary = {}
			for candidate: Dictionary in candidate_rows:
				var roof_id := StringName(candidate.get("recipe_id", &""))
				var yaw_offset := int(candidate.get("yaw_offset", 0))
				var roof_yaw := posmod(room.yaw_quarters + yaw_offset, 4)
				var option_key := "%s/r%d" % [roof_id, roof_yaw]
				if roof_id.is_empty() or seen_options.has(option_key):
					continue
				seen_options[option_key] = true
				var roof_recipe := program.recipe(roof_id)
				if roof_recipe == null:
					continue
				var roof_origin := _phase_aligned_full_roof_origin(room,
					roof_recipe, roof_yaw)
				var roof_probe := FabricUnit.new(StringName(
					"required-roof.%s.%s" % [room.stable_id, option_key]),
					roof_id, roof_origin, roof_yaw)
				if not _unit_public_air_conflicts(grid, roof_probe,
						roof_recipe).is_empty():
					continue
				var roof_transform := FabricRecipe.lattice_transform(roof_origin,
					roof_yaw)
				options.append({"recipe_id": roof_id, "origin": roof_origin,
					"yaw_quarters": roof_yaw, "bounds": roof_transform \
						* roof_recipe.local_clearance_bounds})
			# Preserve an empty domain as an explicit impossibility. Reversible
			# source-plan selection can then remove the optional parcel (or reject a
			# required one) instead of discovering the invalid crown after commit.
			out.append({"owner_room_id": room.stable_id, "options": options,
				"allowed_room_ids": allowed_room_ids})
			continue
		for piece_value: Variant in _cap_pieces(face_cells):
			var piece := piece_value as Dictionary
			var reserve_rows: Array[Array] = []
			if StringName(piece.kind) == &"stamp":
				reserve_rows = _terminal_cap_rows(
					piece.cells as Array[Vector3i])
			else:
				reserve_rows.append(piece.cells as Array[Vector3i])
			for row: Array[Vector3i] in reserve_rows:
				var cap := _cap_placement(grid, row, room, world_seed)
				if cap.is_empty():
					continue
				var cap_transform := FabricRecipe.lattice_transform(
					cap.origin as Vector3i, int(cap.yaw_quarters))
				var public_row := true
				for face: Vector3i in row:
					var air_cell := face + Vector3i.UP
					var floor_claim := grid.face_claim(air_cell,
						Vector3i.DOWN)
					if grid.use_at(air_cell) \
							!= WarrenSpatialGrid.Use.PUBLIC_AIR \
							or int(floor_claim.get("kind", -1)) \
								!= WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR:
						public_row = false
						break
				var reserve_ids: Array[StringName] = []
				if public_row:
					reserve_ids.append(StringName(cap.recipe_id))
				else:
					var theme := _architectural_roof_theme(
						room.lattice_origin, world_seed)
					var family := "orange" if theme == &"orange" else "blue"
					for side in ["negative", "positive"]:
						reserve_ids.append(StringName(
							"roof.partial.gable.%s.%d.%s" % [family,
								row.size(), side]))
				var options: Array[Dictionary] = []
				for reserve_id: StringName in reserve_ids:
					var reserve_recipe := program.recipe(reserve_id)
					if reserve_recipe == null:
						continue
					# Publish only closures that the final assembler could actually
					# commit.  The former partial-roof branch exposed both handed
					# assets even when their measured collider entered a public body
					# lane, so a room could survive proposal selection and discover
					# that it had no legal roof only after the layout was irreversible.
					var reserve_probe := FabricUnit.new(StringName(
						"required-roof.%s.%s.r%d" % [room.stable_id,
							reserve_id, int(cap.yaw_quarters)]), reserve_id,
						cap.origin as Vector3i, int(cap.yaw_quarters))
					if not _unit_public_air_conflicts(grid, reserve_probe,
							reserve_recipe).is_empty():
						continue
					options.append({"recipe_id": reserve_id,
						"origin": cap.origin as Vector3i,
						"yaw_quarters": int(cap.yaw_quarters),
						"bounds": cap_transform \
							* reserve_recipe.local_clearance_bounds})
				# Empty is an explicit construction result, not absence of an
				# obligation. The room-envelope solver consumes this empty domain
				# while it can still yield/replace the source parcel. Omitting it
				# allowed the exact roof failure to survive until final assembly.
				out.append({"owner_room_id": room.stable_id,
					"options": options,
					"allowed_room_ids": allowed_room_ids})
	return out


static func _room_required_roof_conflict(room: WarrenRoomStamp,
		recipe: FabricRecipe, required_roof_clearance: Array[Dictionary],
		program: SettlementFabricProgram) \
		-> StringName:
	if room == null or recipe == null or recipe.placements.is_empty():
		return &""
	var room_bounds := FabricRecipe.lattice_transform(room.lattice_origin,
		room.yaw_quarters) * recipe.local_clearance_bounds
	for closure: Dictionary in required_roof_clearance:
		var owner_room_id := StringName(closure.owner_room_id)
		if owner_room_id == room.stable_id:
			continue
		var party_wall_contact := (closure.allowed_room_ids as Dictionary).has(
			room.stable_id)
		var all_options_blocked := true
		var option_ids := PackedStringArray()
		for option: Dictionary in closure.options as Array[Dictionary]:
			var roof_recipe := program.recipe(StringName(option.recipe_id))
			option_ids.append(String(option.recipe_id))
			if roof_recipe == null:
				continue
			var roof_bounds := option.bounds as AABB
			if not _aabb_overlaps_volume(room_bounds, roof_bounds) \
					or party_wall_contact \
					and _required_roof_party_seam_is_measured(room, recipe,
						room_bounds, owner_room_id, option, roof_recipe):
				all_options_blocked = false
				break
		if all_options_blocked:
			return StringName("%s/%s" % [owner_room_id,
				"|".join(option_ids)])
	return &""


static func _required_roof_party_seam_is_measured(room: WarrenRoomStamp,
		room_recipe: FabricRecipe, room_bounds: AABB,
		owner_room_id: StringName, roof_option: Dictionary,
		roof_recipe: FabricRecipe) -> bool:
	## Party-wall topology permits CONTACT; it does not permit arbitrary visual
	## interpenetration. Reuse the plan's one measured roof-junction policy here
	## so the early ordering proof and final transaction cannot disagree about
	## the difference. The synthetic units carry only the exact relationship and
	## transforms already present in the two sealed plan facts.
	var room_unit_id := StringName("roof-clearance.room.%s" % room.stable_id)
	var roof_unit_id := StringName("roof-clearance.roof.%s" % owner_room_id)
	var room_unit := FabricUnit.new(room_unit_id, room_recipe.recipe_id,
		room.lattice_origin, room.yaw_quarters)
	var roof_seams: Array[StringName] = [room_unit_id]
	var roof_unit := FabricUnit.new(roof_unit_id, roof_recipe.recipe_id,
		roof_option.origin as Vector3i, int(roof_option.yaw_quarters),
		[] as Array[StringName], [] as Array[Dictionary], &"", roof_seams)
	var seam_policy := SettlementFabricPlan.new(&"required-roof-seam-policy")
	return seam_policy._connected_roof_seam_is_measured(roof_unit, roof_recipe,
		roof_option.bounds as AABB, room_unit, room_recipe, room_bounds)


static func _roof_candidate_required_closure_conflict(candidate: FabricUnit,
		candidate_recipe: FabricRecipe, current_room_id: StringName,
		required_closures: Array[Dictionary],
		unbuilt_roof_room_ids: Dictionary,
		program: SettlementFabricProgram) -> StringName:
	## Sequential commitment is safe only if every still-unbuilt roof retains at
	## least one exact weather closure. This turns the roof campaign into the same
	## monotone reservation problem as room facades: rich/tall candidates are
	## welcome when they leave all later domains non-empty; the finite low-gable
	## profile wins when they do not. No room ordering or seed is encoded here.
	if candidate == null or candidate_recipe == null or program == null:
		return &""
	var candidate_bounds := candidate.transform() \
		* candidate_recipe.local_clearance_bounds
	for closure: Dictionary in required_closures:
		var owner_room_id := StringName(closure.owner_room_id)
		if not unbuilt_roof_room_ids.has(owner_room_id):
			continue
		var party_wall_contact := (closure.allowed_room_ids as Dictionary).has(
			current_room_id)
		var all_options_blocked := true
		var option_ids := PackedStringArray()
		for option: Dictionary in closure.options as Array[Dictionary]:
			var option_recipe := program.recipe(StringName(option.recipe_id))
			option_ids.append(String(option.recipe_id))
			if option_recipe == null:
				continue
			var option_unit_id := StringName(
				"future-roof-closure.%s" % owner_room_id)
			var option_seams: Array[StringName] = [candidate.stable_id]
			var option_unit := FabricUnit.new(option_unit_id,
				option_recipe.recipe_id, option.origin as Vector3i,
				int(option.yaw_quarters), [] as Array[StringName],
				[] as Array[Dictionary], &"", option_seams)
			# Semantic construction claims are stricter than visual joinery. Two
			# roofs may share a measured eave seam, but they can never both own the
			# same solid/headroom/walk cell.
			if _future_unit_semantic_conflict(candidate, candidate_recipe,
					option_unit, option_recipe):
				continue
			var option_bounds := option.bounds as AABB
			if not _aabb_overlaps_volume(candidate_bounds, option_bounds):
				all_options_blocked = false
				break
			if party_wall_contact:
				var seam_policy := SettlementFabricPlan.new(
					&"future-roof-seam-policy")
				if seam_policy._connected_roof_seam_is_measured(candidate,
						candidate_recipe, candidate_bounds, option_unit,
						option_recipe, option_bounds):
					all_options_blocked = false
					break
		if all_options_blocked:
			return StringName("%s/%s" % [owner_room_id,
				"|".join(option_ids)])
	return &""


static func _future_unit_semantic_conflict(left: FabricUnit,
		left_recipe: FabricRecipe, right: FabricUnit,
		right_recipe: FabricRecipe) -> bool:
	## Mirror `SettlementFabricPlan._claim_cells` for a pair that has not yet
	## entered the same transaction. Keeping the conflicting layer pairs in one
	## table makes this pre-proof stay visibly identical to the authoritative
	## solid/headroom/walk ownership rule.
	var left_layers: Dictionary = {
		&"solid": _transformed_recipe_cell_set(left_recipe.solid_cells, left),
		&"headroom": _transformed_recipe_cell_set(
			left_recipe.headroom_cells, left),
		&"walk": _transformed_recipe_cell_set(left_recipe.walk_cells, left),
	}
	var right_layers: Dictionary = {
		&"solid": _transformed_recipe_cell_set(right_recipe.solid_cells, right),
		&"headroom": _transformed_recipe_cell_set(
			right_recipe.headroom_cells, right),
		&"walk": _transformed_recipe_cell_set(right_recipe.walk_cells, right),
	}
	for pair: Array[StringName] in [
		[&"solid", &"solid"] as Array[StringName],
		[&"solid", &"headroom"] as Array[StringName],
		[&"solid", &"walk"] as Array[StringName],
		[&"headroom", &"solid"] as Array[StringName],
		[&"headroom", &"headroom"] as Array[StringName],
		[&"walk", &"solid"] as Array[StringName],
		[&"walk", &"walk"] as Array[StringName],
	]:
		var left_cells := left_layers[pair[0]] as Dictionary
		var right_cells := right_layers[pair[1]] as Dictionary
		for cell_value: Variant in left_cells.keys():
			if right_cells.has(cell_value):
				return true
	return false


static func _transformed_recipe_cell_set(local_cells: Array[Vector3i],
		unit: FabricUnit) -> Dictionary:
	var out: Dictionary = {}
	for local_cell: Vector3i in local_cells:
		out[FabricRecipe.transform_cell(local_cell, unit.lattice_origin,
			unit.yaw_quarters)] = true
	return out


static func _aabb_overlaps_volume(left: AABB, right: AABB,
		epsilon: float = 0.10) -> bool:
	# Keep this identical to SettlementFabricPlan's measured-envelope policy.
	# This is an early ordering gate, not a looser second definition of contact.
	var overlap_x := minf(left.end.x, right.end.x) \
		- maxf(left.position.x, right.position.x)
	var overlap_y := minf(left.end.y, right.end.y) \
		- maxf(left.position.y, right.position.y)
	var overlap_z := minf(left.end.z, right.end.z) \
		- maxf(left.position.z, right.position.z)
	return overlap_x > epsilon and overlap_y > epsilon and overlap_z > epsilon


static func _feature_portal_masks(source: WarrenSpatialPlan,
		room_by_id: Dictionary) -> Dictionary:
	## Reduce sealed feature endpoints into local room-face masks before any room
	## recipe is selected. The feature geometry is already authoritative here;
	## the compiler is only choosing the finite shell variant that tells the same
	## story visually and in its solid/headroom layers.
	var out: Dictionary = {}
	for feature: WarrenFeatureReservation in source.features:
		if feature.construction_records.is_empty():
			continue
		if diagnostic_trace_timing and feature.kind in [&"tower_annex",
				&"balcony", &"courtyard_bridge_house", &"enclosed_skywalk"]:
			print("FABRIC_TIMING feature_portal_candidate kind=", feature.kind,
				" id=", feature.stable_id, " endpoints=", feature.endpoints,
				" audit=", feature.audit)
		if feature.kind == &"tower_annex":
			var room_id := StringName(feature.audit.get("annex_room_id", &""))
			if room_id.is_empty() or feature.endpoints.size() != 1:
				last_failure = "%s %s lacks one portal endpoint" % [
					feature.kind, feature.stable_id]
				return {}
			var facing := feature.audit.get("annex_endpoint_facing",
				Vector3i.ZERO) as Vector3i
			if not _record_feature_portal(out, room_by_id, room_id,
					(feature.endpoints[0] as Dictionary).cell as Vector3i,
					_feature_endpoint_facing(feature, 0, facing)):
				return {}
		elif feature.kind == &"facade_bay":
			# A bay window is a shallow projection from a complete facade, not a
			# private doorway. Opening the parent's whole 1.5 x 3 m portal behind a
			# half-width/partial-height bay exposed an arch-sized black cavity around
			# it and made the construction read as an unfinished frame. The occupied
			# parent room remains visually closed; the bay's declared semantic seam
			# is sufficient for its measured overlap and bearing contract.
			continue
		elif feature.kind == &"balcony":
			var room_id := StringName(feature.audit.get("balcony_room_id", &""))
			if room_id.is_empty() or feature.endpoints.size() != 1:
				last_failure = "balcony %s lacks one portal endpoint" % \
					feature.stable_id
				return {}
			var facing := feature.audit.get("balcony_endpoint_facing",
				Vector3i.ZERO) as Vector3i
			if not _record_feature_portal(out, room_by_id, room_id,
					(feature.endpoints[0] as Dictionary).cell as Vector3i,
					_feature_endpoint_facing(feature, 0, facing)):
				return {}
		elif feature.kind == &"courtyard_bridge_house":
			var room_id := StringName(feature.audit.get(
				"courtyard_bridge_house_room_id", &""))
			if room_id.is_empty() or feature.endpoints.size() != 1:
				last_failure = "courtyard bridge %s lacks one portal endpoint" \
					% feature.stable_id
				return {}
			var facing := feature.audit.get(
				"courtyard_bridge_house_endpoint_facing",
				Vector3i.ZERO) as Vector3i
			if not _record_feature_portal(out, room_by_id, room_id,
					(feature.endpoints[0] as Dictionary).cell as Vector3i,
					_feature_endpoint_facing(feature, 0, facing)):
				return {}
		elif feature.kind == &"enclosed_skywalk":
			var bindings: Array[Dictionary] = []
			bindings.assign(feature.audit.get("skywalk_endpoint_bindings", []) \
				as Array)
			if bindings.is_empty():
				bindings = [
					{"endpoint_kind": &"room", "room_id": StringName(
						feature.audit.get("skywalk_left_room_id", &""))},
					{"endpoint_kind": &"room", "room_id": StringName(
						feature.audit.get("skywalk_right_room_id", &""))},
				] as Array[Dictionary]
			if bindings.size() != feature.endpoints.size():
				last_failure = "skywalk %s portal bindings differ from endpoints" % \
					feature.stable_id
				return {}
			for endpoint_index in bindings.size():
				var binding := bindings[endpoint_index]
				var endpoint_kind := StringName(binding.get("endpoint_kind", &"room"))
				if endpoint_kind == &"landmark":
					continue
				if endpoint_kind != &"room":
					last_failure = "skywalk %s has unsupported endpoint kind %s" % [
						feature.stable_id, endpoint_kind]
					return {}
				var room_id := StringName(binding.get("room_id", &""))
				var facing := binding.get("facing", Vector3i.ZERO) as Vector3i
				if not _record_feature_portal(out, room_by_id, room_id,
						(feature.endpoints[endpoint_index] as Dictionary).cell \
							as Vector3i,
						_feature_endpoint_facing(feature, endpoint_index, facing)):
					return {}
	return out


static func _feature_endpoint_facing(feature: WarrenFeatureReservation,
		endpoint_index: int, recorded_facing: Vector3i) -> Vector3i:
	if _is_cardinal_xz(recorded_facing):
		return recorded_facing
	# Compatibility with source plans sealed before endpoint facing became an
	# explicit audit fact: the occupied feature begins exactly one cell outside
	# its room endpoint, so the unique adjacent reserved cell recovers direction.
	var endpoint := (feature.endpoints[endpoint_index] as Dictionary).cell \
		as Vector3i
	var recovered: Array[Vector3i] = []
	for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
			Vector3i.FORWARD, Vector3i.BACK]:
		if feature.reserved_cells.has(endpoint + direction):
			recovered.append(direction)
	return recovered[0] if recovered.size() == 1 else Vector3i.ZERO


static func _record_feature_portal(out: Dictionary, room_by_id: Dictionary,
		room_id: StringName, endpoint_cell: Vector3i,
		world_facing: Vector3i) -> bool:
	var room := room_by_id.get(room_id) as WarrenRoomStamp
	if room == null:
		last_failure = "feature portal names missing room %s" % room_id
		return false
	if not _is_cardinal_xz(world_facing):
		last_failure = "feature portal %s has no cardinal outward direction" % \
			room_id
		return false
	var local_facing := FabricRecipe.transform_direction(world_facing,
		-room.yaw_quarters)
	var portal_bit := _portal_bit_for_facing(local_facing)
	var local_cell := _inverse_cell(endpoint_cell, room.lattice_origin,
		room.yaw_quarters)
	var expected_cell := _portal_cell_for_room(room.kind, portal_bit)
	if portal_bit == 0 or local_cell != expected_cell:
		last_failure = "feature portal %s endpoint %s is not its centre facade %s" \
			% [room_id, local_cell, local_facing]
		return false
	out[room_id] = int(out.get(room_id, 0)) | portal_bit
	return true


static func _portal_bit_for_facing(local_facing: Vector3i) -> int:
	match local_facing:
		Vector3i.FORWARD:
			return SettlementFabricProgram.FEATURE_PORTAL_NORTH
		Vector3i.RIGHT:
			return SettlementFabricProgram.FEATURE_PORTAL_EAST
		Vector3i.BACK:
			return SettlementFabricProgram.FEATURE_PORTAL_SOUTH
		Vector3i.LEFT:
			return SettlementFabricProgram.FEATURE_PORTAL_WEST
		_:
			return 0


static func _portal_cell_for_room(kind: StringName, portal_bit: int) \
		-> Vector3i:
	var minimum := Vector2i.ZERO
	var maximum := Vector2i.ZERO
	match kind:
		&"tower":
			minimum = Vector2i(-1, -1)
			maximum = Vector2i(0, 0)
		&"slim":
			minimum = Vector2i(-1, -2)
			maximum = Vector2i(0, 1)
		&"row":
			minimum = Vector2i(-2, -1)
			maximum = Vector2i(1, 0)
		&"building":
			minimum = Vector2i(-2, -2)
			maximum = Vector2i(1, 1)
		&"long":
			minimum = Vector2i(-2, -3)
			maximum = Vector2i(1, 2)
		_:
			return Vector3i(2147483647, 2147483647, 2147483647)
	match portal_bit:
		SettlementFabricProgram.FEATURE_PORTAL_NORTH:
			return Vector3i(0, 0, minimum.y)
		SettlementFabricProgram.FEATURE_PORTAL_EAST:
			return Vector3i(maximum.x, 0, 0)
		SettlementFabricProgram.FEATURE_PORTAL_SOUTH:
			return Vector3i(0, 0, maximum.y)
		SettlementFabricProgram.FEATURE_PORTAL_WEST:
			return Vector3i(minimum.x, 0, 0)
		_:
			return Vector3i(2147483647, 2147483647, 2147483647)


static func _feature_portal_bit_count(mask: int) -> int:
	var count := 0
	for bit in [SettlementFabricProgram.FEATURE_PORTAL_NORTH,
			SettlementFabricProgram.FEATURE_PORTAL_EAST,
			SettlementFabricProgram.FEATURE_PORTAL_SOUTH,
			SettlementFabricProgram.FEATURE_PORTAL_WEST]:
		count += int((mask & bit) != 0)
	return count


static func _is_cardinal_xz(direction: Vector3i) -> bool:
	return direction.y == 0 and absi(direction.x) + absi(direction.z) == 1


static func _is_phase_b_recipe(recipe_id: StringName) -> bool:
	return _room_recipe_facade_phase(recipe_id) % 2 == 1


static func _room_recipe_facade_phase(recipe_id: StringName) -> int:
	var id := String(recipe_id).get_slice(".portal.", 0).trim_suffix(".door_b")
	var suffix := id.get_slice(".", id.get_slice_count(".") - 1)
	if suffix.length() != 1:
		return 0
	var phase := suffix.unicode_at(0) - "a".unicode_at(0)
	return phase if phase >= 0 \
		and phase < SettlementFabricProgram.FACADE_PHASE_COUNT else 0


static func compile_feature_units(source: WarrenSpatialPlan,
		program: SettlementFabricProgram,
		room_units: Array[FabricUnit]) -> Array[FabricUnit]:
	## Construction records are sealed topology facts. This adapter may only bind
	## their measured sockets to the already-compiled endpoint rooms; it proves
	## that the resulting recipe layers reproduce the exact reserved cell union.
	last_failure = ""
	last_audit = {}
	if source == null or not source.is_sealed() or program == null \
			or room_units.is_empty():
		last_failure = "missing spatial plan, vocabulary, or compiled rooms"
		return [] as Array[FabricUnit]
	var room_unit_by_stamp: Dictionary = {}
	var source_parcel_by_room: Dictionary = {}
	var seam_ids_by_source_parcel: Dictionary = {}
	for room_unit: FabricUnit in room_units:
		var room_id := StringName(String(room_unit.stable_id).trim_prefix(
			"spatial.fabric."))
		room_unit_by_stamp[room_id] = room_unit
	for building: WarrenBuildingVolume in source.buildings:
		for room: WarrenRoomStamp in building.room_records:
			source_parcel_by_room[room.stable_id] = room.source_parcel_id
			if not seam_ids_by_source_parcel.has(room.source_parcel_id):
				seam_ids_by_source_parcel[room.source_parcel_id] = [] \
					as Array[StringName]
			var room_unit := room_unit_by_stamp.get(room.stable_id) as FabricUnit
			if room_unit != null:
				(seam_ids_by_source_parcel[room.source_parcel_id] \
					as Array[StringName]).append(room_unit.stable_id)
	for seam_ids_value: Variant in seam_ids_by_source_parcel.values():
		(seam_ids_value as Array[StringName]).sort_custom(func(a: StringName,
				b: StringName) -> bool:
			return String(a) < String(b))
	var probe := SettlementFabricPlan.new(&"spatial.feature-selection")
	for recipe: FabricRecipe in program.recipes():
		if not probe.register_recipe(recipe):
			last_failure = "feature selection could not register recipe %s" % \
				recipe.recipe_id
			return [] as Array[FabricUnit]
	for room_unit: FabricUnit in room_units:
		if not probe.add_unit(room_unit):
			last_failure = "feature selection rejected source room %s: %s" % [
				room_unit.stable_id, probe.last_rejection]
			return [] as Array[FabricUnit]
	var ordered_features: Array[WarrenFeatureReservation] = []
	for feature: WarrenFeatureReservation in source.features:
		if not feature.construction_records.is_empty():
			ordered_features.append(feature)
	ordered_features.sort_custom(func(a: WarrenFeatureReservation,
			b: WarrenFeatureReservation) -> bool:
		return String(a.stable_id) < String(b.stable_id))
	var out: Array[FabricUnit] = []
	var compiled_support_units: Array[FabricUnit] = []
	var realized_cells: Dictionary = {}
	var compiled_feature_unit_by_owner: Dictionary = {}
	var skywalk_count := 0
	var courtyard_bridge_count := 0
	var market_count := 0
	var balcony_count := 0
	var room_outcropping_support_count := 0
	var room_overhang_support_count := 0
	var frontier_gateway_support_count := 0
	var arcade_overhang_support_count := 0
	var tower_annex_count := 0
	var facade_bay_count := 0
	var landmark_count := 0
	var interstitial_join_count := 0
	# TASK H2 PART 4 -- "we can't have floating buildings", counted on the
	# RENDERED side. `*_support_feature_count` above says how many overhang
	# features compiled at all; these say how many timber/stone BRACKET UNITS
	# the renderer is actually handed for them, and -- the one that can be
	# pinned -- how many overhangs compiled without a single brace.
	# `cantilever_support` is the recipe tag `_compile_room_outcropping_supports`
	# and `_compile_frontier_gateway_supports` already require of every shell
	# they emit, so this counts the same objects those functions validate
	# rather than a second notion of "a support".
	var overhang_bracket_unit_count := 0
	var bracketed_overhang_feature_count := 0
	var bracketless_overhang_feature_count := 0
	var overhang_bracket_recipe_counts: Dictionary = {}
	for feature: WarrenFeatureReservation in ordered_features:
		var feature_units: Array[FabricUnit] = []
		match feature.kind:
			&"courtyard_bridge_house":
				feature_units = _compile_courtyard_bridge_house_feature(feature,
					program, room_unit_by_stamp, source_parcel_by_room,
					seam_ids_by_source_parcel)
				courtyard_bridge_count += int(not feature_units.is_empty())
			&"enclosed_skywalk":
				feature_units = _compile_skywalk_feature(feature, program,
					room_unit_by_stamp, source_parcel_by_room,
					seam_ids_by_source_parcel,
					compiled_feature_unit_by_owner)
				skywalk_count += int(not feature_units.is_empty())
			&"covered_market":
				feature_units = _compile_market_feature(feature, program,
					room_unit_by_stamp, source_parcel_by_room,
					seam_ids_by_source_parcel)
				market_count += int(not feature_units.is_empty())
			&"balcony":
				feature_units = _compile_balcony_feature(feature, program,
					room_unit_by_stamp, source_parcel_by_room,
					seam_ids_by_source_parcel)
				balcony_count += int(not feature_units.is_empty())
			&"room_outcropping":
				feature_units = _compile_room_outcropping_supports(feature,
					program, room_unit_by_stamp)
				room_outcropping_support_count += int(
					not feature_units.is_empty())
			&"room_overhang_support":
				feature_units = _compile_room_outcropping_supports(feature,
					program, room_unit_by_stamp)
				room_overhang_support_count += int(
					not feature_units.is_empty())
			&"frontier_gateway_support":
				feature_units = _compile_frontier_gateway_supports(feature,
					program, room_unit_by_stamp)
				frontier_gateway_support_count += int(
					not feature_units.is_empty())
			&"arcade_overhang_support":
				feature_units = _compile_arcade_overhang_supports(feature,
					program, room_unit_by_stamp)
				arcade_overhang_support_count += int(
					not feature_units.is_empty())
			&"tower_annex":
				feature_units = _compile_tower_annex_feature(feature, program,
					room_unit_by_stamp, source_parcel_by_room,
					seam_ids_by_source_parcel)
				tower_annex_count += int(not feature_units.is_empty())
			&"facade_bay":
				feature_units = _compile_tower_annex_feature(feature, program,
					room_unit_by_stamp, source_parcel_by_room,
					seam_ids_by_source_parcel)
				facade_bay_count += int(not feature_units.is_empty())
			&"interstitial_join":
				feature_units = _compile_interstitial_join_feature(feature,
					program, source, room_unit_by_stamp, out)
				interstitial_join_count += int(not feature_units.is_empty())
			&"prefab_landmark":
				feature_units = _compile_landmark_feature(feature, program)
				landmark_count += int(not feature_units.is_empty())
			_:
				last_failure = "constructed spatial feature %s has no compiler" % \
					feature.kind
				return [] as Array[FabricUnit]
		if feature_units.is_empty():
			return [] as Array[FabricUnit]
		if not _feature_units_match_reservation(feature, feature_units, program):
			last_failure = "feature %s construction changes its reserved volume" % \
				feature.stable_id
			return [] as Array[FabricUnit]
		var feature_brackets := 0
		for unit: FabricUnit in feature_units:
			var unit_recipe := program.recipe(unit.recipe_id)
			var unit_is_support := unit_recipe != null \
				and unit_recipe.has_tag(&"cantilever_support")
			if unit_recipe != null:
				var unit_clearance := unit.transform() \
					* unit_recipe.local_clearance_bounds
				# Support courses are selected as one compatible structural frame.
				# Make every measured intersection explicit before the plan gate sees
				# it; this is a typed timber joint, not a general overlap exemption.
				# Interstitial strips extend the same rule to any feature whose
				# measured envelope crosses one: the strip fills proven-vacant
				# trapped cells, so the crossing is a joint, not displacement.
				for prior: FabricUnit in compiled_support_units:
					var prior_recipe := program.recipe(prior.recipe_id)
					if prior_recipe == null:
						continue
					var prior_is_strip := String(prior.recipe_id).begins_with(
							"interstitial.") \
						or String(prior.recipe_id).begins_with(
							"roof.setback.lean.")
					if not unit_is_support and not prior_is_strip:
						continue
					var prior_clearance := prior.transform() \
						* prior_recipe.local_clearance_bounds
					if SettlementFabricPlan._aabb_overlaps_volume(
							unit_clearance, prior_clearance) \
							and not unit.visual_seam_ids.has(prior.stable_id):
						unit.visual_seam_ids.append(prior.stable_id)
			if not probe.add_unit(unit):
				last_failure = "feature component %s rejected: %s" % [
					unit.stable_id, probe.last_rejection]
				return [] as Array[FabricUnit]
			out.append(unit)
			if unit_recipe != null and unit_recipe.has_tag(&"cantilever_support"):
				compiled_support_units.append(unit)
				overhang_bracket_unit_count += 1
				overhang_bracket_recipe_counts[unit.recipe_id] = int(
					overhang_bracket_recipe_counts.get(unit.recipe_id, 0)) + 1
				feature_brackets += 1
			# Interstitial strips are structural courses wedged against the same
			# walls the bracket frames anchor to; a later support course that
			# measures into one declares the same typed timber joint it would
			# declare against an earlier brace.
			if feature.kind == &"interstitial_join":
				compiled_support_units.append(unit)
		if feature.kind in OVERHANG_SUPPORT_FEATURE_KINDS:
			bracketed_overhang_feature_count += int(feature_brackets > 0)
			bracketless_overhang_feature_count += int(feature_brackets == 0)
		if feature.kind == &"prefab_landmark" and feature_units.size() == 1:
			compiled_feature_unit_by_owner[feature.stable_id] = feature_units[0]
		for cell: Vector3i in feature.reserved_cells:
			if realized_cells.has(cell):
				last_failure = "constructed features overlap at %s" % cell
				return [] as Array[FabricUnit]
			realized_cells[cell] = feature.stable_id
	last_audit = {
		"source_constructed_feature_count": ordered_features.size(),
		"realized_constructed_feature_count": skywalk_count + market_count \
			+ balcony_count + tower_annex_count + facade_bay_count + landmark_count \
			+ courtyard_bridge_count + room_outcropping_support_count \
			+ room_overhang_support_count \
			+ frontier_gateway_support_count + arcade_overhang_support_count \
			+ interstitial_join_count,
		"skywalk_feature_count": skywalk_count,
		"interstitial_join_feature_count": interstitial_join_count,
		"courtyard_bridge_house_feature_count": courtyard_bridge_count,
		"covered_market_feature_count": market_count,
		"balcony_feature_count": balcony_count,
		"room_outcropping_support_feature_count":
			room_outcropping_support_count,
		"room_overhang_support_feature_count": room_overhang_support_count,
		"frontier_gateway_support_feature_count":
			frontier_gateway_support_count,
		"arcade_overhang_support_feature_count":
			arcade_overhang_support_count,
		"tower_annex_feature_count": tower_annex_count,
		"facade_bay_feature_count": facade_bay_count,
		"prefab_landmark_feature_count": landmark_count,
		"overhang_bracket_unit_count": overhang_bracket_unit_count,
		"bracketed_overhang_feature_count": bracketed_overhang_feature_count,
		"bracketless_overhang_feature_count":
			bracketless_overhang_feature_count,
		"overhang_bracket_recipe_counts": overhang_bracket_recipe_counts,
		"feature_construction_unit_count": out.size(),
		"feature_reserved_cell_count": realized_cells.size(),
	}
	return out


static func _compile_room_outcropping_supports(
		feature: WarrenFeatureReservation,
		program: SettlementFabricProgram,
		room_unit_by_stamp: Dictionary) -> Array[FabricUnit]:
	## The occupied upper room was compiled in the ordinary room pass. These
	## records realize only the exact bracket courses derived from its sealed
	## bearing edge; they neither restamp nor resize the room volume.
	var out: Array[FabricUnit] = []
	var overhang := feature.kind == &"room_overhang_support"
	var upper_id := StringName(feature.audit.get(
		"overhang_upper_room_id" if overhang else "outcrop_upper_room_id", &""))
	var lower_id := StringName(feature.audit.get(
		"overhang_lower_room_id" if overhang else "outcrop_lower_room_id", &""))
	var upper_unit := room_unit_by_stamp.get(upper_id) as FabricUnit
	var lower_unit := room_unit_by_stamp.get(lower_id) as FabricUnit
	if upper_unit == null or lower_unit == null \
			or feature.construction_records.is_empty() \
			or not bool(feature.audit.get("overhang_is_supported" if overhang \
				else "outcrop_is_integrated_cantilever", false)):
		last_failure = "room projection %s lacks its two room plates or supports" \
			% feature.stable_id
		return out
	var neighbor_units: Array[StringName] = []
	for neighbor_value: Variant in feature.audit.get(
			"overhang_support_neighbor_room_ids" if overhang \
			else "outcrop_support_neighbor_room_ids", []):
		var neighbor_id := StringName(neighbor_value)
		var neighbor_unit := room_unit_by_stamp.get(neighbor_id) as FabricUnit
		if neighbor_unit == null:
			last_failure = "room projection %s names missing support seam %s" % [
				feature.stable_id, neighbor_id]
			return [] as Array[FabricUnit]
		neighbor_units.append(neighbor_unit.stable_id)
	var shells: Array[FabricUnit] = []
	for index in feature.construction_records.size():
		var record := feature.construction_records[index]
		shells.append(_feature_component_shell(feature, index, record))
	var built_support_seams: Array[StringName] = []
	for shell: FabricUnit in shells:
		var recipe := program.recipe(shell.recipe_id)
		if recipe == null or not recipe.has_tag(&"cantilever_support") \
				or not recipe.has_tag(&"visual_attachment") \
				or not recipe.solid_cells.is_empty() \
				or not recipe.walk_cells.is_empty() \
				or not recipe.headroom_cells.is_empty() \
				or recipe.bearing_parent_count != 0:
			last_failure = "room projection %s has a non-attachment support recipe" \
				% feature.stable_id
			return [] as Array[FabricUnit]
		# SettlementFabricPlan validates a visual seam against construction that
		# already exists. A multi-brace support course is therefore an ordered
		# dependency: every brace may meet its two room plates and earlier braces,
		# while the later brace declares the reciprocal geometric exception when
		# it is added. Forward-referencing every sibling made the first brace fail
		# despite the complete feature reservation being valid.
		var seams: Array[StringName] = [upper_unit.stable_id,
			lower_unit.stable_id]
		seams.append_array(neighbor_units)
		seams.append_array(built_support_seams)
		out.append(FabricUnit.new(shell.stable_id, shell.recipe_id,
			shell.lattice_origin, shell.yaw_quarters,
			[] as Array[StringName], [] as Array[Dictionary], &"", seams))
		built_support_seams.append(shell.stable_id)
	return out


static func _compile_frontier_gateway_supports(
		feature: WarrenFeatureReservation,
		program: SettlementFabricProgram,
		room_unit_by_stamp: Dictionary) -> Array[FabricUnit]:
	## The gateway room already owns the occupied volume. This adapter realizes
	## only its sealed underside bracket course and names every measured room it
	## touches as an explicit joinery seam.
	var out: Array[FabricUnit] = []
	var room_id := StringName(feature.audit.get("gateway_room_id", &""))
	var room_unit := room_unit_by_stamp.get(room_id) as FabricUnit
	if room_unit == null or feature.construction_records.size() != 1 \
			or not (bool(feature.audit.get("gateway_is_terrain_anchored", false)) \
				or bool(feature.audit.get("gateway_is_flank_borne", false))):
		last_failure = "gateway/jetty %s lacks its anchored room or bracket" \
			% feature.stable_id
		return out
	var seams: Array[StringName] = [room_unit.stable_id]
	for neighbor_value: Variant in feature.audit.get(
			"gateway_support_neighbor_room_ids", []):
		var neighbor_id := StringName(neighbor_value)
		var neighbor_unit := room_unit_by_stamp.get(neighbor_id) as FabricUnit
		if neighbor_unit == null:
			last_failure = "frontier gateway %s names missing support seam %s" % [
				feature.stable_id, neighbor_id]
			return [] as Array[FabricUnit]
		seams.append(neighbor_unit.stable_id)
	var record := feature.construction_records[0] as Dictionary
	var shell := _feature_component_shell(feature, 0, record)
	var recipe := program.recipe(shell.recipe_id)
	if recipe == null or not recipe.has_tag(&"cantilever_support") \
			or not recipe.has_tag(&"visual_attachment") \
			or not recipe.solid_cells.is_empty() \
			or not recipe.walk_cells.is_empty() \
			or not recipe.headroom_cells.is_empty() \
			or recipe.bearing_parent_count != 0:
		last_failure = "frontier gateway %s has a non-attachment support recipe" \
			% feature.stable_id
		return [] as Array[FabricUnit]
	out.append(FabricUnit.new(shell.stable_id, shell.recipe_id,
		shell.lattice_origin, shell.yaw_quarters,
		[] as Array[StringName], [] as Array[Dictionary], &"", seams))
	return out


static func _compile_arcade_overhang_supports(
		feature: WarrenFeatureReservation,
		program: SettlementFabricProgram,
		room_unit_by_stamp: Dictionary) -> Array[FabricUnit]:
	## The upper and lower rooms remain the occupied construction.  This adapter
	## realizes the exact four-corner support frame around their public-air span
	## and declares every measured room contact as authored joinery.
	var out: Array[FabricUnit] = []
	var upper_id := StringName(feature.audit.get("arcade_upper_room_id", &""))
	var lower_id := StringName(feature.audit.get("arcade_lower_room_id", &""))
	var upper_unit := room_unit_by_stamp.get(upper_id) as FabricUnit
	var lower_unit := room_unit_by_stamp.get(lower_id) as FabricUnit
	var tunnel_roof_support := bool(feature.audit.get(
		"arcade_is_tunnel_roof_support", false))
	if upper_unit == null \
			or not tunnel_roof_support and lower_unit == null \
			or feature.construction_records.size() != 1 \
			or int(feature.audit.get("arcade_support_course_count", 0)) != 1:
		last_failure = "arcade overhang %s lacks its rooms or foundation shell" \
			% feature.stable_id
		return out
	var seams: Array[StringName] = [upper_unit.stable_id]
	if lower_unit != null:
		seams.append(lower_unit.stable_id)
	for neighbor_value: Variant in feature.audit.get(
			"arcade_support_neighbor_room_ids", []):
		var neighbor_id := StringName(neighbor_value)
		var neighbor_unit := room_unit_by_stamp.get(neighbor_id) as FabricUnit
		if neighbor_unit == null:
			last_failure = "arcade overhang %s names missing support seam %s" % [
				feature.stable_id, neighbor_id]
			return [] as Array[FabricUnit]
		if not seams.has(neighbor_unit.stable_id):
			seams.append(neighbor_unit.stable_id)
	var record := feature.construction_records[0] as Dictionary
	var shell := _feature_component_shell(feature, 0, record)
	var recipe := program.recipe(shell.recipe_id)
	if recipe == null or not recipe.has_tag(&"cantilever_support") \
			or not recipe.has_tag(&"visual_attachment") \
			or not recipe.has_tag(&"arcade_portal_support") \
			or not recipe.has_tag(&"four_corner_support_frame") \
			or recipe.placements.size() != 4 \
			or not recipe.solid_cells.is_empty() \
			or not recipe.walk_cells.is_empty() \
			or not recipe.headroom_cells.is_empty() \
			or recipe.bearing_parent_count != 0:
		last_failure = "arcade overhang %s has an incomplete foundation recipe" \
			% feature.stable_id
		return [] as Array[FabricUnit]
	out.append(FabricUnit.new(shell.stable_id, shell.recipe_id,
		shell.lattice_origin, shell.yaw_quarters,
		[] as Array[StringName], [] as Array[Dictionary], &"", seams))
	return out


static func _compile_interstitial_join_feature(
		feature: WarrenFeatureReservation,
		program: SettlementFabricProgram, source: WarrenSpatialPlan,
		room_unit_by_stamp: Dictionary,
		prior_feature_units: Array[FabricUnit]) -> Array[FabricUnit]:
	## Realize a typed interstitial join. The reservation already owns the slot
	## volume and its two-owner relationship; this adapter binds the measured
	## strip to its exact bearing parent and names every touching room as a
	## visual seam, so the join compiles through the same envelope gate as any
	## other unit instead of hiding a gap behind coincidental meshes.
	var out: Array[FabricUnit] = []
	if feature.construction_records.size() != 1:
		last_failure = "interstitial join %s needs exactly one record" \
			% feature.stable_id
		return out
	var record := feature.construction_records[0]
	var shell := _feature_component_shell(feature, 0, record)
	var recipe := program.recipe(shell.recipe_id)
	if recipe == null:
		last_failure = "interstitial join %s names unknown recipe %s" % [
			feature.stable_id, shell.recipe_id]
		return out
	var strip_cells: Dictionary = {}
	for cell: Vector3i in feature.reserved_cells:
		strip_cells[cell] = true
	# Every room touching the strip is an explicit visual seam.
	var seams: Array[StringName] = []
	var seam_set: Dictionary = {}
	for building: WarrenBuildingVolume in source.buildings:
		for room: WarrenRoomStamp in building.room_records:
			if not room_unit_by_stamp.has(room.stable_id):
				continue
			var touches := false
			for cell_value: Variant in strip_cells:
				var cell := cell_value as Vector3i
				for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
						Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD,
						Vector3i.BACK,
						Vector3i.UP + Vector3i.LEFT,
						Vector3i.UP + Vector3i.RIGHT,
						Vector3i.UP + Vector3i.FORWARD,
						Vector3i.UP + Vector3i.BACK,
						Vector3i.DOWN + Vector3i.LEFT,
						Vector3i.DOWN + Vector3i.RIGHT,
						Vector3i.DOWN + Vector3i.FORWARD,
						Vector3i.DOWN + Vector3i.BACK]:
					if room.has_private_cell(cell + direction):
						touches = true
						break
				if touches:
					break
			if not touches:
				continue
			var unit := room_unit_by_stamp.get(room.stable_id) as FabricUnit
			if unit != null and not seam_set.has(unit.stable_id):
				seam_set[unit.stable_id] = true
				seams.append(unit.stable_id)
	# A room whose measured eave or bay envelope grazes the strip from a
	# distance shares the reveal too: the strip never exceeds its proven
	# trapped cells, so every such intersection is a typed joint, mirrored
	# from the room gate's interstitial exemption.
	var strip_bounds := FabricRecipe.lattice_transform(shell.lattice_origin,
		shell.yaw_quarters) * recipe.local_clearance_bounds
	for building: WarrenBuildingVolume in source.buildings:
		for room: WarrenRoomStamp in building.room_records:
			var unit := room_unit_by_stamp.get(room.stable_id) as FabricUnit
			if unit == null or seam_set.has(unit.stable_id):
				continue
			var room_recipe := program.recipe(unit.recipe_id)
			if room_recipe == null:
				continue
			var room_bounds := FabricRecipe.lattice_transform(
				room.lattice_origin, room.yaw_quarters) \
				* room_recipe.local_clearance_bounds
			if SettlementFabricPlan._aabb_overlaps_volume(strip_bounds,
					room_bounds):
				seam_set[unit.stable_id] = true
				seams.append(unit.stable_id)
	# Sibling strips: a stacked slit band, or a nearby shoulder whose sloped
	# envelope grazes this one, names the earlier strip as a typed joint —
	# the same structural-course rule the bracket frames use.
	for prior: FabricUnit in prior_feature_units:
		if not String(prior.recipe_id).begins_with("interstitial.") \
				and not String(prior.recipe_id).begins_with(
					"roof.setback.lean."):
			continue
		var prior_recipe := program.recipe(prior.recipe_id)
		if prior_recipe == null or seam_set.has(prior.stable_id):
			continue
		var prior_bounds := FabricRecipe.lattice_transform(
			prior.lattice_origin, prior.yaw_quarters) \
			* prior_recipe.local_clearance_bounds
		if SettlementFabricPlan._aabb_overlaps_volume(strip_bounds,
				prior_bounds):
			seam_set[prior.stable_id] = true
			seams.append(prior.stable_id)
	seams = _unique_sorted_names(seams)
	var parents: Array[StringName] = []
	var bonds: Array[Dictionary] = []
	if recipe.bearing_parent_count > 0:
		var below := (record.origin as Vector3i) + Vector3i.DOWN
		var parent_room: WarrenRoomStamp = null
		for building: WarrenBuildingVolume in source.buildings:
			for room: WarrenRoomStamp in building.room_records:
				if room.has_private_cell(below):
					parent_room = room
					break
			if parent_room != null:
				break
		var parent_unit := room_unit_by_stamp.get(
			parent_room.stable_id) as FabricUnit if parent_room != null \
			else null
		if parent_unit == null:
			last_failure = "interstitial join %s has no built bearing parent" \
				% feature.stable_id
			return out
		var parent_local := _inverse_cell(below, parent_room.lattice_origin,
			parent_room.yaw_quarters)
		parents.append(parent_unit.stable_id)
		bonds.append(FabricUnit.bond(&"bearing.bottom", parent_unit.stable_id,
			SettlementFabricProgram._bearing_cell_socket_id(&"top",
				parent_local.x, parent_local.z)))
	out.append(FabricUnit.new(shell.stable_id, shell.recipe_id,
		shell.lattice_origin, shell.yaw_quarters, parents, bonds, &"", seams))
	return out


static func _compile_tower_annex_feature(feature: WarrenFeatureReservation,
		program: SettlementFabricProgram,
		room_unit_by_stamp: Dictionary, source_parcel_by_room: Dictionary,
		seam_ids_by_source_parcel: Dictionary) -> Array[FabricUnit]:
	var room_id := StringName(feature.audit.get("annex_room_id", &""))
	if room_id.is_empty() or feature.endpoints.size() != 1 \
			or feature.construction_records.size() != 1:
		last_failure = "%s %s lacks one exact room/recipe" \
			% [feature.kind, feature.stable_id]
		return [] as Array[FabricUnit]
	var room_unit := room_unit_by_stamp.get(room_id) as FabricUnit
	if room_unit == null:
		last_failure = "%s %s parent room %s was not compiled" % [
			feature.kind, feature.stable_id, room_id]
		return [] as Array[FabricUnit]
	var component := _feature_component_shell(feature, 0,
		feature.construction_records[0])
	var recipe := program.recipe(component.recipe_id)
	if recipe == null or not recipe.has_tag(&"outcropping") \
			or recipe.bearing_parent_count != 1:
		last_failure = "%s %s lacks a one-bearing occupied recipe" \
			% [feature.kind, feature.stable_id]
		return [] as Array[FabricUnit]
	var endpoint_cell := (feature.endpoints[0] as Dictionary).cell as Vector3i
	var matches := _matching_room_connections(component, room_unit, program,
		endpoint_cell, true)
	if matches.size() != 1:
		last_failure = "%s %s has %d exact room/socket matches" % [
			feature.kind, feature.stable_id, matches.size()]
		return [] as Array[FabricUnit]
	var source_parcel_id := StringName(source_parcel_by_room.get(room_id, &""))
	var seams: Array[StringName] = []
	seams.assign(seam_ids_by_source_parcel.get(source_parcel_id, []) \
		as Array[StringName])
	return [_feature_component_with_connections(component,
		[matches[0]] as Array[Dictionary], [room_unit] as Array[FabricUnit],
		true, seams)] as Array[FabricUnit]


static func _compile_landmark_feature(feature: WarrenFeatureReservation,
		program: SettlementFabricProgram) -> Array[FabricUnit]:
	if feature.endpoints.size() != 1 \
			or feature.construction_records.size() != 1:
		last_failure = "prefab landmark %s lacks one exact doorway/recipe" \
			% feature.stable_id
		return [] as Array[FabricUnit]
	var component := _feature_component_shell(feature, 0,
		feature.construction_records[0])
	var recipe := program.recipe(component.recipe_id)
	if recipe == null or not recipe.has_tag(&"prefab_anchor") \
			or not recipe.has_tag(&"terrain_bearing") \
			or recipe.bearing_parent_count != 0:
		last_failure = "prefab landmark %s lacks a terrain-bearing anchor recipe" \
			% feature.stable_id
		return [] as Array[FabricUnit]
	var expected_entrance := feature.audit.get("landmark_entrance_cell",
		Vector3i(2147483647, 2147483647, 2147483647)) as Vector3i
	var expected_landing := feature.audit.get("landmark_public_landing_cell",
		Vector3i(2147483647, 2147483647, 2147483647)) as Vector3i
	var matching_entrances := 0
	for entrance: Dictionary in recipe.entrances:
		var world_cell := FabricRecipe.transform_cell(entrance.cell as Vector3i,
			component.lattice_origin, component.yaw_quarters)
		var world_facing := FabricRecipe.transform_direction(
			entrance.facing as Vector3i, component.yaw_quarters)
		matching_entrances += int(world_cell == expected_entrance \
			and world_cell + world_facing == expected_landing)
	if matching_entrances != 1:
		last_failure = "prefab landmark %s construction moves its public doorway" \
			% feature.stable_id
		return [] as Array[FabricUnit]
	return [component] as Array[FabricUnit]


static func _compile_balcony_feature(feature: WarrenFeatureReservation,
		program: SettlementFabricProgram,
		room_unit_by_stamp: Dictionary, source_parcel_by_room: Dictionary,
		seam_ids_by_source_parcel: Dictionary) -> Array[FabricUnit]:
	var room_id := StringName(feature.audit.get("balcony_room_id", &""))
	if room_id.is_empty() or feature.endpoints.size() != 1 \
			or feature.construction_records.size() != 1:
		last_failure = "balcony %s lacks one exact room/recipe" % feature.stable_id
		return [] as Array[FabricUnit]
	var room_unit := room_unit_by_stamp.get(room_id) as FabricUnit
	if room_unit == null:
		last_failure = "balcony %s parent room %s was not compiled" % [
			feature.stable_id, room_id]
		return [] as Array[FabricUnit]
	var component := _feature_component_shell(feature, 0,
		feature.construction_records[0])
	var recipe := program.recipe(component.recipe_id)
	if recipe == null or not recipe.has_tag(&"balcony") \
			or recipe.bearing_parent_count != 1:
		last_failure = "balcony %s lacks a one-bearing occupied recipe" % \
			feature.stable_id
		return [] as Array[FabricUnit]
	var endpoint_cell := (feature.endpoints[0] as Dictionary).cell as Vector3i
	var matches := _matching_room_connections(component, room_unit, program,
		endpoint_cell, true)
	if matches.size() != 1:
		last_failure = "balcony %s has %d exact doorway/socket matches" % [
			feature.stable_id, matches.size()]
		return [] as Array[FabricUnit]
	var source_parcel_id := StringName(source_parcel_by_room.get(room_id, &""))
	var seams: Array[StringName] = []
	seams.assign(seam_ids_by_source_parcel.get(source_parcel_id, []) \
		as Array[StringName])
	return [_feature_component_with_connections(component,
		[matches[0]] as Array[Dictionary], [room_unit] as Array[FabricUnit],
		true, seams)] as Array[FabricUnit]


static func _compile_market_feature(feature: WarrenFeatureReservation,
		program: SettlementFabricProgram,
		room_unit_by_stamp: Dictionary, source_parcel_by_room: Dictionary,
		seam_ids_by_source_parcel: Dictionary) -> Array[FabricUnit]:
	var room_id := StringName(feature.audit.get("market_backing_room_id", &""))
	if room_id.is_empty() or feature.endpoints.size() != 1 \
			or feature.construction_records.size() != 1:
		last_failure = "covered market %s lacks one exact backing room/recipe" % \
			feature.stable_id
		return [] as Array[FabricUnit]
	var room_unit := room_unit_by_stamp.get(room_id) as FabricUnit
	if room_unit == null:
		last_failure = "covered market %s backing room %s was not compiled" % [
			feature.stable_id, room_id]
		return [] as Array[FabricUnit]
	var component := _feature_component_shell(feature, 0,
		feature.construction_records[0])
	var recipe := program.recipe(component.recipe_id)
	if recipe == null or not recipe.has_tag(&"covered_market") \
			or recipe.bearing_parent_count != 0:
		last_failure = "covered market %s lacks a terrain-bearing bazaar recipe" % \
			feature.stable_id
		return [] as Array[FabricUnit]
	var endpoint_cell := (feature.endpoints[0] as Dictionary).cell as Vector3i
	var matches := _matching_market_connections(component, room_unit, program,
		endpoint_cell)
	if matches.size() != 1:
		last_failure = "covered market %s has %d exact backing socket matches" % [
			feature.stable_id, matches.size()]
		return [] as Array[FabricUnit]
	var source_parcel_id := StringName(source_parcel_by_room.get(room_id, &""))
	var seams: Array[StringName] = []
	seams.assign(seam_ids_by_source_parcel.get(source_parcel_id, []) \
		as Array[StringName])
	var connection := matches[0] as Dictionary
	var bonds: Array[Dictionary] = [FabricUnit.bond(
		StringName(connection.own_market), room_unit.stable_id,
		StringName(connection.target_market))]
	return [FabricUnit.new(component.stable_id, component.recipe_id,
		component.lattice_origin, component.yaw_quarters,
		[] as Array[StringName], bonds, &"", seams)] as Array[FabricUnit]


static func _compile_courtyard_bridge_house_feature(
		feature: WarrenFeatureReservation, program: SettlementFabricProgram,
		room_unit_by_stamp: Dictionary, source_parcel_by_room: Dictionary,
		seam_ids_by_source_parcel: Dictionary) -> Array[FabricUnit]:
	## The topology record is ordered parent-to-child: a pitched corner knuckle
	## bonds to the addressed room, then a single inhabited cantilever bay bonds
	## to the remaining corner socket. The far end is deliberately closed; making
	## it seek a second room would recreate the impossible U-link that blocked the
	## upper public gateway beside the court.
	var room_id := StringName(feature.audit.get(
		"courtyard_bridge_house_room_id", &""))
	if room_id.is_empty() or feature.endpoints.size() != 1 \
			or feature.construction_records.size() != 2:
		last_failure = "courtyard bridge %s lacks one room or two components" \
			% feature.stable_id
		return [] as Array[FabricUnit]
	var room_unit := room_unit_by_stamp.get(room_id) as FabricUnit
	if room_unit == null:
		last_failure = "courtyard bridge %s parent room %s was not compiled" % [
			feature.stable_id, room_id]
		return [] as Array[FabricUnit]
	var source_parcel_id := StringName(source_parcel_by_room.get(room_id, &""))
	var lineage_seams: Array[StringName] = []
	lineage_seams.assign(seam_ids_by_source_parcel.get(source_parcel_id, []) \
		as Array[StringName])
	var corner_shell := _feature_component_shell(feature, 0,
		feature.construction_records[0])
	var corner_recipe := program.recipe(corner_shell.recipe_id)
	if corner_recipe == null or not String(corner_shell.recipe_id).begins_with(
			"skywalk.corner.") or corner_recipe.bearing_parent_count != 1:
		last_failure = "courtyard bridge %s lacks its measured corner knuckle" \
			% feature.stable_id
		return [] as Array[FabricUnit]
	var endpoint_cell := (feature.endpoints[0] as Dictionary).cell as Vector3i
	var room_matches := _matching_room_connections(corner_shell, room_unit,
		program, endpoint_cell, true)
	if room_matches.size() != 1:
		last_failure = "courtyard bridge %s has %d exact room/socket matches" % [
			feature.stable_id, room_matches.size()]
		return [] as Array[FabricUnit]
	var corner := _feature_component_with_connections(corner_shell,
		[room_matches[0]] as Array[Dictionary],
		[room_unit] as Array[FabricUnit], true, lineage_seams)
	var bay_shell := _feature_component_shell(feature, 1,
		feature.construction_records[1])
	var bay_recipe := program.recipe(bay_shell.recipe_id)
	if bay_recipe == null or not String(bay_shell.recipe_id).begins_with(
			"skywalk.cantilever.") or bay_recipe.bearing_parent_count != 1:
		last_failure = "courtyard bridge %s lacks its one-bearing occupied bay" \
			% feature.stable_id
		return [] as Array[FabricUnit]
	var bay_matches := _matching_room_connections(bay_shell, corner, program)
	if bay_matches.size() != 1:
		last_failure = "courtyard bridge %s bay has %d corner/socket matches" % [
			feature.stable_id, bay_matches.size()]
		return [] as Array[FabricUnit]
	var bay := _feature_component_with_connections(bay_shell,
		[bay_matches[0]] as Array[Dictionary], [corner] as Array[FabricUnit],
		true, lineage_seams)
	return [corner, bay] as Array[FabricUnit]


static func _compile_skywalk_feature(feature: WarrenFeatureReservation,
		program: SettlementFabricProgram,
		room_unit_by_stamp: Dictionary, source_parcel_by_room: Dictionary,
		seam_ids_by_source_parcel: Dictionary,
		compiled_feature_unit_by_owner: Dictionary = {}) -> Array[FabricUnit]:
	var bindings: Array[Dictionary] = []
	bindings.assign(feature.audit.get("skywalk_endpoint_bindings", []) as Array)
	if bindings.is_empty():
		bindings = [
			{"endpoint_kind": &"room", "owner_id": &"", "room_id":
				StringName(feature.audit.get("skywalk_left_room_id", &""))},
			{"endpoint_kind": &"room", "owner_id": &"", "room_id":
				StringName(feature.audit.get("skywalk_right_room_id", &""))},
		] as Array[Dictionary]
	if bindings.size() != 2 or feature.endpoints.size() != 2:
		last_failure = "skywalk %s lacks two exact endpoint rooms" % \
			feature.stable_id
		return [] as Array[FabricUnit]
	var endpoint_specs: Array[Dictionary] = []
	for endpoint_index in 2:
		var binding := bindings[endpoint_index]
		var endpoint_kind := StringName(binding.get("endpoint_kind", &"room"))
		var room_id := StringName(binding.get("room_id", &""))
		var room_unit: FabricUnit
		var seam_ids: Array[StringName] = []
		if endpoint_kind == &"landmark":
			var owner_id := StringName(binding.get("owner_id", &""))
			room_unit = compiled_feature_unit_by_owner.get(owner_id) as FabricUnit
			if room_unit != null:
				seam_ids.append(room_unit.stable_id)
		else:
			room_unit = room_unit_by_stamp.get(room_id) as FabricUnit
			var source_parcel_id := StringName(source_parcel_by_room.get(room_id,
				&""))
			seam_ids.assign(seam_ids_by_source_parcel.get(source_parcel_id, []) \
				as Array[StringName])
		if room_unit == null:
			last_failure = "skywalk %s endpoint %s was not compiled" % [
				feature.stable_id, room_id]
			return [] as Array[FabricUnit]
		endpoint_specs.append({"unit": room_unit, "cell":
			(feature.endpoints[endpoint_index] as Dictionary).cell as Vector3i,
			"seam_ids": seam_ids})
	var records := feature.construction_records
	if records.size() == 1:
		var component := _feature_component_shell(feature, 0, records[0])
		var recipe := program.recipe(component.recipe_id)
		if recipe == null or recipe.bearing_parent_count != 2:
			last_failure = "straight skywalk %s lacks a two-bearing recipe" % \
				feature.stable_id
			return [] as Array[FabricUnit]
		var connections: Array[Dictionary] = []
		for endpoint: Dictionary in endpoint_specs:
			var matches := _matching_room_connections(component,
				endpoint.unit as FabricUnit, program, endpoint.cell as Vector3i, true)
			if matches.size() != 1:
				last_failure = "straight skywalk %s has %d socket matches to %s" % [
					feature.stable_id, matches.size(),
					(endpoint.unit as FabricUnit).stable_id]
				return [] as Array[FabricUnit]
			connections.append(matches[0])
		if connections[0].own_room == connections[1].own_room:
			last_failure = "straight skywalk %s reuses one endpoint socket" % \
				feature.stable_id
			return [] as Array[FabricUnit]
		return [_feature_component_with_connections(component, connections,
			[endpoint_specs[0].unit, endpoint_specs[1].unit] as Array[FabricUnit],
			true, _unique_sorted_names((endpoint_specs[0].seam_ids \
				as Array[StringName]) + (endpoint_specs[1].seam_ids \
				as Array[StringName])))] as Array[FabricUnit]
	if records.size() != 3:
		last_failure = "skywalk %s has unsupported %d-component construction" % [
			feature.stable_id, records.size()]
		return [] as Array[FabricUnit]
	var endpoint_lineage_seams := _unique_sorted_names(
		(endpoint_specs[0].seam_ids as Array[StringName]) \
		+ (endpoint_specs[1].seam_ids as Array[StringName]))
	var first_shell := _feature_component_shell(feature, 0, records[0])
	var endpoint_options: Array[Dictionary] = []
	for endpoint_index in endpoint_specs.size():
		var endpoint := endpoint_specs[endpoint_index]
		var matches := _matching_room_connections(first_shell,
			endpoint.unit as FabricUnit, program, endpoint.cell as Vector3i, true)
		for match: Dictionary in matches:
			endpoint_options.append({"endpoint_index": endpoint_index,
				"connection": match})
	if endpoint_options.size() != 1:
		last_failure = "corner skywalk %s first arm has %d endpoint matches" % [
			feature.stable_id, endpoint_options.size()]
		return [] as Array[FabricUnit]
	var first_endpoint_index := int(endpoint_options[0].endpoint_index)
	var first_endpoint := endpoint_specs[first_endpoint_index]
	var first := _feature_component_with_connections(first_shell,
		[endpoint_options[0].connection] as Array[Dictionary],
		[first_endpoint.unit] as Array[FabricUnit], true,
		endpoint_lineage_seams)
	var corner_shell := _feature_component_shell(feature, 1, records[1])
	var corner_matches := _matching_room_connections(corner_shell, first,
		program)
	if corner_matches.size() != 1:
		last_failure = "corner skywalk %s knuckle has %d arm matches" % [
			feature.stable_id, corner_matches.size()]
		return [] as Array[FabricUnit]
	var corner := _feature_component_with_connections(corner_shell,
		[corner_matches[0]] as Array[Dictionary], [first] as Array[FabricUnit],
		true, endpoint_lineage_seams)
	var final_shell := _feature_component_shell(feature, 2, records[2])
	var corner_to_final := _matching_room_connections(final_shell, corner,
		program)
	var final_endpoint := endpoint_specs[1 - first_endpoint_index]
	var endpoint_to_final := _matching_room_connections(final_shell,
		final_endpoint.unit as FabricUnit, program,
		final_endpoint.cell as Vector3i, true)
	if corner_to_final.size() != 1 or endpoint_to_final.size() != 1 \
			or corner_to_final[0].own_room == endpoint_to_final[0].own_room:
		last_failure = "corner skywalk %s final arm does not close both seams" % \
			feature.stable_id
		return [] as Array[FabricUnit]
	var final_connections: Array[Dictionary] = [corner_to_final[0],
		endpoint_to_final[0]]
	var final_unit := _feature_component_with_connections(final_shell,
		final_connections, [corner] as Array[FabricUnit], false,
		endpoint_lineage_seams)
	return [first, corner, final_unit] as Array[FabricUnit]


static func _feature_component_shell(feature: WarrenFeatureReservation,
		index: int, record: Dictionary) -> FabricUnit:
	return FabricUnit.new(StringName("spatial.fabric.%s.component.%02d" % [
		feature.stable_id, index]), StringName(record.recipe_id),
		record.origin as Vector3i, int(record.yaw_quarters))


static func _feature_component_with_connections(shell: FabricUnit,
		connections: Array[Dictionary], bearing_parents: Array[FabricUnit],
		all_connections_bear: bool,
		visual_seams: Array[StringName] = []) -> FabricUnit:
	var parents: Array[StringName] = []
	for parent: FabricUnit in bearing_parents:
		parents.append(parent.stable_id)
	var bonds: Array[Dictionary] = []
	for connection_index in connections.size():
		var connection := connections[connection_index]
		bonds.append(FabricUnit.bond(StringName(connection.own_room),
			StringName(connection.target_unit),
			StringName(connection.target_room)))
		if all_connections_bear or connection_index < bearing_parents.size():
			bonds.append(FabricUnit.bond(StringName(connection.own_bearing),
				StringName(connection.target_unit),
				StringName(connection.target_bearing)))
	return FabricUnit.new(shell.stable_id, shell.recipe_id,
		shell.lattice_origin, shell.yaw_quarters, parents, bonds, &"",
		visual_seams)


static func _matching_room_connections(own: FabricUnit, target: FabricUnit,
		program: SettlementFabricProgram,
		expected_target_cell: Vector3i = Vector3i.ZERO,
		require_expected_cell: bool = false) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var own_recipe := program.recipe(own.recipe_id)
	var target_recipe := program.recipe(target.recipe_id)
	if own_recipe == null or target_recipe == null:
		return out
	for own_socket: Dictionary in own_recipe.sockets:
		var own_room := StringName(own_socket.id)
		if int(own_socket.kind) != FabricRecipe.SocketKind.ROOM \
				or String(own_room).contains(".corner."):
			continue
		for target_socket: Dictionary in target_recipe.sockets:
			var target_room := StringName(target_socket.id)
			if int(target_socket.kind) != FabricRecipe.SocketKind.ROOM \
					or String(target_room).contains(".corner.") \
					or not SettlementFabricPlan._sockets_meet(own, own_socket,
						target, target_socket):
				continue
			if require_expected_cell and _socket_world_cell(target,
					target_socket) != expected_target_cell:
				continue
			var own_bearing := StringName(String(own_room).replace("room.",
				"bearing."))
			var target_bearing := StringName(String(target_room).replace("room.",
				"bearing."))
			var own_bearing_socket := own_recipe.socket(own_bearing)
			var target_bearing_socket := target_recipe.socket(target_bearing)
			if own_bearing_socket.is_empty() or target_bearing_socket.is_empty() \
					or not SettlementFabricPlan._sockets_meet(own,
						own_bearing_socket, target, target_bearing_socket):
				continue
			out.append({"own_room": own_room, "target_unit": target.stable_id,
				"target_room": target_room, "own_bearing": own_bearing,
				"target_bearing": target_bearing})
	return out


static func _matching_market_connections(own: FabricUnit, target: FabricUnit,
		program: SettlementFabricProgram,
		expected_target_cell: Vector3i) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var own_recipe := program.recipe(own.recipe_id)
	var target_recipe := program.recipe(target.recipe_id)
	if own_recipe == null or target_recipe == null:
		return out
	for own_socket: Dictionary in own_recipe.sockets:
		if int(own_socket.kind) != FabricRecipe.SocketKind.MARKET:
			continue
		for target_socket: Dictionary in target_recipe.sockets:
			if int(target_socket.kind) != FabricRecipe.SocketKind.MARKET \
					or _socket_world_cell(target, target_socket) \
						!= expected_target_cell \
					or not SettlementFabricPlan._sockets_meet(own, own_socket,
						target, target_socket):
				continue
			out.append({"own_market": StringName(own_socket.id),
				"target_market": StringName(target_socket.id)})
	return out


static func _socket_world_cell(unit_value: FabricUnit,
		socket: Dictionary) -> Vector3i:
	return FabricRecipe.transform_cell(socket.cell as Vector3i,
		unit_value.lattice_origin, unit_value.yaw_quarters)


static func _feature_units_match_reservation(
		feature: WarrenFeatureReservation, units: Array[FabricUnit],
		program: SettlementFabricProgram) -> bool:
	if feature.kind in [&"room_outcropping", &"room_overhang_support",
			&"frontier_gateway_support", &"arcade_overhang_support"]:
		# The feature's reserved cells are the already-realized upper room. Its
		# construction records are deliberately zero-cell bracket attachments;
		# requiring them to reproduce the room would duplicate occupied mass.
		for unit: FabricUnit in units:
			var attachment := program.recipe(unit.recipe_id)
			if attachment == null \
					or not attachment.has_tag(&"cantilever_support") \
					or not attachment.solid_cells.is_empty() \
					or not attachment.walk_cells.is_empty() \
					or not attachment.headroom_cells.is_empty():
				return false
		return not units.is_empty()
	var realized: Dictionary = {}
	for unit: FabricUnit in units:
		var recipe := program.recipe(unit.recipe_id)
		if recipe == null:
			return false
		for cells: Array[Vector3i] in [recipe.solid_cells,
				recipe.headroom_cells, recipe.walk_cells]:
			for local_cell: Vector3i in cells:
				realized[FabricRecipe.transform_cell(local_cell,
					unit.lattice_origin, unit.yaw_quarters)] = true
	var reserved: Dictionary = {}
	for cell: Vector3i in feature.reserved_cells:
		reserved[cell] = true
	return _same_cell_set(realized, reserved)


static func _constructed_feature_count(source: WarrenSpatialPlan) -> int:
	var count := 0
	for feature: WarrenFeatureReservation in source.features:
		count += int(not feature.construction_records.is_empty())
	return count


static func compile_roof_units(source: WarrenSpatialPlan,
		program: SettlementFabricProgram,
		room_units: Array[FabricUnit],
		fixed_feature_units: Array[FabricUnit] = []) -> Array[FabricUnit]:
	last_failure = ""
	last_audit = {}
	if source == null or not source.is_sealed() or program == null \
			or room_units.is_empty():
		last_failure = "missing spatial plan, vocabulary, or compiled rooms"
		return [] as Array[FabricUnit]
	var roof_started_ms := Time.get_ticks_msec()
	var room_by_id: Dictionary = {}
	var room_id_by_cell: Dictionary = {}
	for building: WarrenBuildingVolume in source.buildings:
		for room: WarrenRoomStamp in building.room_records:
			room_by_id[room.stable_id] = room
			for cell: Vector3i in room.private_cells:
				room_id_by_cell[cell] = room.stable_id
	var unit_by_room: Dictionary = {}
	var unit_by_private_cell: Dictionary = {}
	for unit: FabricUnit in room_units:
		var room_id := StringName(String(unit.stable_id).trim_prefix(
			"spatial.fabric."))
		if not room_by_id.has(room_id):
			last_failure = "room unit %s has no spatial stamp" % unit.stable_id
			return [] as Array[FabricUnit]
		unit_by_room[room_id] = unit
		var room := room_by_id[room_id] as WarrenRoomStamp
		for cell: Vector3i in room.private_cells:
			unit_by_private_cell[cell] = unit.stable_id
	var probe := SettlementFabricPlan.new(&"spatial.roof-selection")
	for recipe: FabricRecipe in program.recipes():
		if not probe.register_recipe(recipe):
			last_failure = "roof selection could not register recipe %s" % \
				recipe.recipe_id
			return [] as Array[FabricUnit]
	for room_unit: FabricUnit in room_units:
		if not probe.add_unit(room_unit):
			last_failure = "roof selection rejected source room %s: %s" % [
				room_unit.stable_id, probe.last_rejection]
			return [] as Array[FabricUnit]
	for feature_unit: FabricUnit in fixed_feature_units:
		if not probe.add_unit(feature_unit):
			last_failure = "roof selection rejected fixed feature %s: %s" % [
				feature_unit.stable_id, probe.last_rejection]
			return [] as Array[FabricUnit]
	# Is this the PLOT MODEL's town? One reading, taken from the volume the
	# spatial plan was composed from, for the one legacy rule Task C5d ruling
	# 1 has to switch off (the dormer bar, at the foot of this function).
	# Empty on every route-first and mass-first plan.
	var maze_plot_model := source.source_volume != null \
		and source.source_volume.mass_context.has(&"maze_source_plan")
	var roof_stage_ms := _trace_stage("roof.probe_seed", roof_started_ms)
	var roof_faces_by_room := _roof_faces_by_room(source, room_id_by_cell)
	var roof_rooms: Array[WarrenRoomStamp] = []
	for roof_room_value: Variant in room_by_id.values():
		roof_rooms.append(roof_room_value as WarrenRoomStamp)
	var required_future_roof_closures := _required_roof_clearance(source,
		program, roof_rooms, room_id_by_cell)
	var unbuilt_roof_room_ids: Dictionary = {}
	for roof_room_id_value: Variant in roof_faces_by_room.keys():
		var roof_room_id := StringName(roof_room_id_value)
		var roof_parent := unit_by_room.get(roof_room_id) as FabricUnit
		var roof_parent_recipe := program.recipe(roof_parent.recipe_id) \
			if roof_parent != null else null
		if roof_parent_recipe == null \
				or not roof_parent_recipe.has_tag(&"integrated_pitched_roof"):
			unbuilt_roof_room_ids[roof_room_id] = true
	var roof_room_id_by_face: Dictionary = {}
	for roof_room_id_value: Variant in roof_faces_by_room.keys():
		var roof_room_id := StringName(roof_room_id_value)
		for roof_face: Vector3i in roof_faces_by_room[roof_room_id] \
				as Array[Vector3i]:
			roof_room_id_by_face[roof_face] = roof_room_id
	roof_stage_ms = _trace_stage("roof.faces", roof_stage_ms)
	var roof_neighborhood := _spatial_roof_neighborhood(source,
		room_by_id, roof_faces_by_room)
	if roof_neighborhood.is_empty() and not last_failure.is_empty():
		return [] as Array[FabricUnit]
	var roof_proposal_by_room := roof_neighborhood.get(
		"proposal_by_room", {}) as Dictionary
	# A source `flat_roof` stamp states STRUCTURAL CAPACITY: its top may carry an
	# upper room or public surface.  It does not decide the appearance of a free
	# terminal crown.  That distinction is resolved here from the final sealed
	# volume.  A complete exposed plate with no public-air claim above it is a
	# house crown and therefore requests a measured gable; a partial plate or a
	# plate carrying public circulation remains construction.  The result is
	# correct by construction rather than by a seeded visual preference: adding
	# or removing an upper storey changes the same occupancy fact that changes the
	# roof, and an isolated plank lid can no longer survive merely because an
	# earlier plot proposal happened to call the room flat.
	var plot_flat_room_ids: Dictionary = {}
	var plot_pitched_room_ids: Dictionary = {}
	for room_id_value: Variant in roof_faces_by_room.keys():
		var plot_room_id := StringName(room_id_value)
		var plot_room := room_by_id[plot_room_id] as WarrenRoomStamp
		if not plot_room.flat_roof:
			continue
		plot_flat_room_ids[plot_room_id] = true
		var plot_faces := roof_faces_by_room[plot_room_id] as Array[Vector3i]
		if _is_full_roof_plate(plot_room, plot_faces) \
				and not _touches_public_air(source.grid, plot_faces):
			plot_pitched_room_ids[plot_room_id] = true
			# Keep the complete roof-neighborhood proposal. It carries typed
			# ridge/valley/eave-wall seams that let a gable meet adjacent mass
			# cleanly; erasing it here made every terminal roof collide as an
			# unrelated isolated shell and then fall back to a plank lid.
			continue
		if not roof_proposal_by_room.has(plot_room_id):
			continue
		var plot_proposal := (roof_proposal_by_room[
			plot_room_id] as Dictionary).duplicate(true)
		plot_proposal["flat_roof"] = true
		plot_proposal["roof_junction_rules"] = [] as Array[Dictionary]
		roof_proposal_by_room[plot_room_id] = plot_proposal
	if not plot_flat_room_ids.is_empty():
		for neighbor_id_value: Variant in roof_proposal_by_room.keys():
			var neighbor_id := StringName(neighbor_id_value)
			var neighbor_proposal := roof_proposal_by_room[
				neighbor_id] as Dictionary
			var kept: Array[Dictionary] = []
			for rule_value: Variant in neighbor_proposal.get(
					"roof_junction_rules", []) as Array:
				var rule := rule_value as Dictionary
				var rule_neighbor := StringName(rule.get("neighbor_id", &""))
				if plot_flat_room_ids.has(rule_neighbor) \
						and not plot_pitched_room_ids.has(rule_neighbor):
					continue
				kept.append(rule)
			if kept.size() == (neighbor_proposal.get("roof_junction_rules",
					[]) as Array).size():
				continue
			var trimmed := neighbor_proposal.duplicate(true)
			trimmed["roof_junction_rules"] = kept
			roof_proposal_by_room[neighbor_id] = trimmed
	var room_ids: Array[StringName] = []
	room_ids.assign(roof_faces_by_room.keys())
	room_ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		var left := room_by_id[a] as WarrenRoomStamp
		var right := room_by_id[b] as WarrenRoomStamp
		return left.lattice_origin.y < right.lattice_origin.y \
			if left.lattice_origin.y != right.lattice_origin.y \
			else String(a) < String(b))
	var out: Array[FabricUnit] = []
	var source_face_count := 0
	var realized_face_count := 0
	var pitched_count := 0
	var flat_count := 0
	var flat_terrace_count := 0
	var flat_garden_count := 0
	var rich_flat_garden_count := 0
	var rich_flat_garden_fallback_count := 0
	var micro_flat_garden_count := 0
	var flat_garden_rejections: Array[Dictionary] = []
	var flat_roof_recipe_counts: Dictionary = {}
	var lived_in_flat_terrace_count := 0
	var awning_flat_terrace_count := 0
	var furnished_flat_terrace_count := 0
	var lamped_flat_terrace_count := 0
	var cap_count := 0
	var plain_cap_count := 0
	var lean_to_cap_count := 0
	var shed_cap_count := 0
	var macro_gable_cap_count := 0
	var macro_gable_fallback_count := 0
	var terminal_macro_cap_fallback_count := 0
	var terrace_cap_count := 0
	var garden_cap_count := 0
	var terrace_cap_fallback_count := 0
	var garden_cap_fallback_count := 0
	var one_storey_chimney_roof_count := 0
	var rejected_pitched_count := 0
	var rejected_flat_count := 0
	var dormered_pitched_roof_count := 0
	var paired_dormer_roof_count := 0
	var rejected_pitched_details: Array[Dictionary] = []
	var pitched_roof_family_counts := {&"orange": 0, &"blue": 0,
		&"boarded": 0}
	var pitched_roof_recipe_counts: Dictionary = {}
	var exposed_roof_room_kind_counts: Dictionary = {}
	var exposed_roof_feature_counts: Dictionary = {}
	var alternate_pitched_roof_count := 0
	var quarter_turned_square_roof_count := 0
	var pending_roof_trims: Array[Dictionary] = []
	var atomic_neighborhood_roof_count := 0
	var integrated_bridge_roof_count := 0
	var partial_plate_pitched_count := 0
	var plot_flat_room_count := 0
	var plot_flat_count := 0
	var plot_flat_pitched_count := 0
	var plot_flat_partial_plate_count := 0
	var plot_flat_rejected_count := 0
	var maze_pitched_count := 0
	var maze_pitched_refused_count := 0
	var maze_pitched_partial_plate_count := 0
	var maze_crown_fell_through_count := 0
	var maze_pitched_rooms: Array[StringName] = []
	var maze_pitched_refused_details: Array[Dictionary] = []
	var maze_flat_crown_rooms: Array[StringName] = []
	# TASK H2 PART 3 -- what the surviving terraces WEAR.
	var maze_dressed_crown_count := 0
	var maze_bare_crown_count := 0
	var maze_crown_chimney_count := 0
	var maze_crown_awning_count := 0
	var maze_crown_planter_count := 0
	var maze_crown_dressing_recipe_counts: Dictionary = {}
	var maze_tiled_plate_count := 0
	var maze_plate_tile_count := 0
	var maze_plate_refused_count := 0
	var maze_plate_tile_recipe_counts: Dictionary = {}
	# TASK E3b RULING 1 -- THE TWO VOCABULARY GATES, AND THEIR AUDIT.
	#
	# `maze_street_borne_plate_count` (gate 1): flat crowns admitted to the
	# tiling because part of the plate carries a STREET
	# (`_touches_public_air`). Before this task one such cell vetoed the whole
	# crown -- slab AND tiles -- and sent it to the finite setback vocabulary,
	# where a leftover one-cell strip has no authored shed and the town died.
	#
	# `maze_lid_repair_cap_count` / `_cell_count` (gate 2): one-cell setback
	# strips kept as plank caps because the maze lid CONTINUES across them,
	# with `maze_cross_lineage_repairs` the subset whose continuing crown
	# belongs to another lineage. Both are keyed on `plot_flat`, which only the
	# maze translator's own `flat_roof` stamp ever sets.
	#
	# Cross-lineage ownership does not select a roof. `_tile_flat_plate` reads
	# each finished face: private pairs receive real gable halves and explicit
	# public-floor cells receive deck backing. The sliver continuation below is
	# the separate case where the maze lid itself proves the face is buried.
	var maze_street_borne_plate_count := 0
	var maze_street_borne_full_plate_count := 0
	var maze_cross_lineage_repairs := 0
	var maze_lid_repair_cap_count := 0
	var maze_lid_repair_cell_count := 0
	# TASK C5e RULING 3, review fix 1 (IMPORTANT 2). The units that really ARE
	# a plot-flat crown -- this branch's own slabs and the tiles that complete
	# a partial one -- named as they are emitted. The assembler cannot re-derive
	# this: it holds the fabric plan, not the plot model's room stamps, and a
	# recipe tag alone would also select a pitched house's weather shoulder.
	var maze_construction_crown_units: Array[StringName] = []
	roof_stage_ms = _trace_stage("roof.neighborhood", roof_stage_ms)
	for room_id: StringName in room_ids:
		# From this point the current room owns the next choice. Every candidate is
		# checked only against still-unbuilt closures; already-built roofs are
		# checked by the authoritative transaction probe.
		unbuilt_roof_room_ids.erase(room_id)
		var room := room_by_id[room_id] as WarrenRoomStamp
		exposed_roof_room_kind_counts[room.kind] = int(
			exposed_roof_room_kind_counts.get(room.kind, 0)) + 1
		exposed_roof_feature_counts[room.roof_feature] = int(
			exposed_roof_feature_counts.get(room.roof_feature, 0)) + 1
		var parent_unit := unit_by_room[room_id] as FabricUnit
		var face_cells := roof_faces_by_room[room_id] as Array[Vector3i]
		source_face_count += face_cells.size()
		var parent_recipe := program.recipe(parent_unit.recipe_id)
		if parent_recipe != null \
				and parent_recipe.has_tag(&"integrated_pitched_roof"):
			# The bridge/jetty recipe already committed its measured gable with
			# the occupied shell and exact support bonds.  Counting its exposed
			# faces here preserves the roof identity without emitting a second
			# competing roof unit over the same room.
			realized_face_count += face_cells.size()
			pitched_count += 1
			integrated_bridge_roof_count += 1
			continue
		var full := _is_full_roof_plate(room, face_cells)
		var room_seams := _roof_room_seams(source.grid, room,
			unit_by_private_cell, parent_unit.stable_id)
		room_seams.append_array(_setback_wall_room_ids(face_cells,
			unit_by_private_cell))
		# A bridge endpoint is planned before its occupied span so the reversible
		# source transaction can prove both bearings and both closures together.
		# The source stamp therefore carries the exact future room ids at which its
		# seam-clipped gable terminates. By roof-compilation time every room unit
		# exists: translate those source facts to final unit ids here instead of
		# rediscovering the joint from overlapping visual envelopes. This admits
		# only the proved endpoint-to-span seam; unrelated intersections still fail.
		for party_room_id_value: Variant in room.audit.get(
				"roof_party_allowed_room_ids", []) as Array:
			var party_room := unit_by_room.get(StringName(
				party_room_id_value)) as FabricUnit
			if party_room != null and not room_seams.has(party_room.stable_id):
				room_seams.append(party_room.stable_id)
		room_seams = _unique_sorted_names(room_seams)
		var selected := false
		var attempt_failures := PackedStringArray()
		var neighborhood_proposal := roof_proposal_by_room.get(room_id,
			{}) as Dictionary
		var requires_atomic_neighborhood := not neighborhood_proposal.is_empty() \
			and not bool(neighborhood_proposal.get("flat_roof", false)) \
			and not (neighborhood_proposal.get(
				"roof_junction_rules", []) as Array).is_empty()
		var plate_pitched := not full \
			and bool(neighborhood_proposal.get("partial_plate", false)) \
			and not bool(neighborhood_proposal.get("flat_roof", false))
		# A classified junction IS the typed relationship that explains roof
		# contact: a stepped eave dying into the half-storey neighbor's facade
		# is the treatment the module table sealed, so that neighbor's room is
		# a declared seam of the pitched shell, not an unrelated envelope.
		var junction_room_seams := room_seams.duplicate()
		var typed_junction_room_seams: Array[StringName] = []
		for rule_value: Variant in neighborhood_proposal.get(
				"roof_junction_rules", []) as Array:
			var junction_neighbor := unit_by_room.get(StringName(
				(rule_value as Dictionary).neighbor_id)) as FabricUnit
			if junction_neighbor != null and not junction_room_seams.has(
					junction_neighbor.stable_id):
				junction_room_seams.append(junction_neighbor.stable_id)
			if junction_neighbor != null and not typed_junction_room_seams.has(
					junction_neighbor.stable_id):
				typed_junction_room_seams.append(junction_neighbor.stable_id)
		var plot_flat := plot_flat_room_ids.has(room_id)
		# A terminal house crown derived from the finished volume. It remains a
		# flat-capable stamp in every structural respect, but its complete exposed
		# plate carries neither upper mass nor public realm, so an authored gable is
		# its first and normal closure.
		var pitched_preferred := plot_flat \
			and plot_pitched_room_ids.has(room_id)
		plot_flat_room_count += int(plot_flat)
		if (full or plate_pitched) and (not plot_flat or pitched_preferred) \
				and not _touches_public_air(source.grid, face_cells):
			var pitched_candidates := _full_roof_candidates(room,
				source.world_seed, neighborhood_proposal) if full \
				else _plate_roof_candidates(neighborhood_proposal)
			# A terminal house must close with roof material, never the floor-plank
			# cap. The compact/tall gable remains the normal silhouette; this exact
			# low-gable vocabulary is the final finite alternative when its authored
			# eave cannot coexist with a dense roof-wall/support junction.
			if full and pitched_preferred:
				for tight_gable_id: StringName in \
						_terminal_tight_gable_recipe_ids(room, source.world_seed):
					pitched_candidates.append({"recipe_id": tight_gable_id,
						"yaw_offset": 0})
			var pitched_rejections: Array[Dictionary] = []
			for candidate_index in pitched_candidates.size():
				var candidate := pitched_candidates[candidate_index]
				var pitched_id := StringName(candidate.recipe_id)
				var yaw_offset := int(candidate.yaw_offset)
				var pitched := _full_roof_unit(room_id, room, parent_unit,
					pitched_id, _roof_seams_for_candidate(junction_room_seams,
						parent_unit.stable_id, out, fixed_feature_units, false),
					program, yaw_offset) if full \
					else _plate_roof_unit(room_id, room, parent_unit,
						pitched_id, neighborhood_proposal,
						_roof_seams_for_candidate(junction_room_seams,
							parent_unit.stable_id, out, fixed_feature_units, false))
				_append_explicit_roof_party_room_seams(pitched, room,
					unit_by_room)
				# The roof-topology plan classified these exact wall/eave contacts
				# before candidate selection. Carry only those named neighbors onto
				# the candidate; SettlementFabricPlan still measures the final lap and
				# rejects a deep gable, while a tight terminal step can close the joint.
				for junction_seam: StringName in typed_junction_room_seams:
					if not pitched.visual_seam_ids.has(junction_seam):
						pitched.visual_seam_ids.append(junction_seam)
				pitched.visual_seam_ids = _unique_sorted_names(
					pitched.visual_seam_ids)
				var pitched_recipe := program.recipe(pitched_id)
				if pitched_recipe == null:
					last_failure = "missing full roof recipe %s" % pitched_id
					return [] as Array[FabricUnit]
				var roof_air_conflicts := _unit_public_air_conflicts(source.grid,
					pitched, pitched_recipe)
				if not roof_air_conflicts.is_empty():
					var air_rejection := "exact roof volume enters public air %s" \
						% str(roof_air_conflicts)
					pitched_rejections.append({"recipe_id": pitched_id,
						"yaw_offset": yaw_offset, "rejection": air_rejection})
					attempt_failures.append("pitched %s/r%d: %s" % [pitched_id,
						yaw_offset, air_rejection])
					continue
				var future_roof_conflict := \
					_roof_candidate_required_closure_conflict(pitched,
						pitched_recipe, room_id, required_future_roof_closures,
						unbuilt_roof_room_ids, program)
				if not future_roof_conflict.is_empty():
					var future_rejection := \
						"blocks required future roof closure %s" \
							% future_roof_conflict
					pitched_rejections.append({"recipe_id": pitched_id,
						"yaw_offset": yaw_offset, "rejection": future_rejection})
					attempt_failures.append("pitched %s/r%d: %s" % [pitched_id,
						yaw_offset, future_rejection])
					continue
				if probe.add_unit(pitched):
					out.append(pitched)
					if bool(candidate.get("uses_roof_neighborhood", false)):
						atomic_neighborhood_roof_count += 1
						for trim_value: Variant in candidate.get(
								"trim_components", []):
							pending_roof_trims.append({
								"room_id": room_id,
								"roof_unit_id": pitched.stable_id,
								"component": (trim_value as Dictionary).duplicate(true),
							})
					realized_face_count += face_cells.size()
					pitched_count += 1
					maze_pitched_count += int(plot_flat)
					plot_flat_pitched_count += int(plot_flat)
					if plot_flat:
						maze_pitched_rooms.append(room_id)
					partial_plate_pitched_count += int(plate_pitched)
					alternate_pitched_roof_count += int(candidate_index > 0)
					quarter_turned_square_roof_count += int(full \
						and yaw_offset != 0)
					var roof_family := _roof_recipe_family(pitched_id)
					pitched_roof_family_counts[roof_family] = int(
						pitched_roof_family_counts.get(roof_family, 0)) + 1
					pitched_roof_recipe_counts[pitched_id] = int(
						pitched_roof_recipe_counts.get(pitched_id, 0)) + 1
					one_storey_chimney_roof_count += int(
						room.source_storey_index == 0 and String(pitched_id) \
							.contains(".short."))
					dormered_pitched_roof_count += int(pitched_recipe.has_tag(
						&"dormer"))
					paired_dormer_roof_count += int(pitched_recipe.has_tag(
						&"paired_dormer"))
					selected = true
					break
				pitched_rejections.append({"recipe_id": pitched_id,
					"yaw_offset": yaw_offset, "rejection": probe.last_rejection})
				attempt_failures.append("pitched %s/r%d: %s" % [pitched_id,
					yaw_offset, probe.last_rejection])
			if not selected:
				rejected_pitched_count += 1
				if rejected_pitched_details.size() < 32:
					rejected_pitched_details.append({"room_id": room_id,
						"attempts": pitched_rejections})
		if selected:
			continue
		# A joined roof is one atomic neighborhood choice. Falling back one member
		# at a time produced the capture defect where a pitched eave stopped against
		# an unrelated flat plate or a differently aligned gable. Reject this whole
		# construction and let the bounded selector choose another composition.
		# A previous implementation recursively converted the whole campaign to
		# flat caps here.  That was a visual repair after the construction had
		# already been chosen, and could silently erase a tower or skywalk roof.
		# Failure is now atomic: an invalid joined roof never becomes different
		# architecture downstream.
		# A complete joined crown is atomic: none of its members may silently become
		# different architecture. A PARTIAL plate is a different source fact. Its
		# full-footprint neighborhood gable is only the preferred single-shell
		# treatment; when that measured shell cannot fit around upper mass, the exact
		# exposed-face partition below remains a complete, lossless roof transaction.
		# Let that finite solver try native sheds/gables rather than rejecting the
		# town for a roof volume that covers cells the source never exposed.
		if requires_atomic_neighborhood and not plate_pitched:
			var campaign := _roof_neighborhood_component(
				roof_proposal_by_room, room_id)
			last_failure = "atomic roof neighborhood for %s rejected (campaign %s): %s" % [
				room_id, campaign, "; ".join(attempt_failures)]
			return [] as Array[FabricUnit]
		if pitched_preferred and full \
				and not _touches_public_air(source.grid, face_cells):
			# TASK C5d RULING 2, REWRITTEN BY TASK H2 FIX ROUND 1 (minor 6) --
			# the pitched preference, MEASURED HERE AND NOWHERE ELSE.
			#
			# The old text said this crown had been found GEOMETRICALLY free --
			# its plot top strictly above every 4-neighbour plot and street
			# band, so an authored eave has nothing to reach over. That test no
			# longer exists. Task H2 withdrew it (`WarrenMazeBlockPartitioner
			# .plot_prefers_pitched_roof` asks one question now: is this crown
			# FREE, meaning nothing stands on it and it carries no public
			# realm), on the argument that an ESTIMATE in front of a
			# MEASUREMENT can only refuse crowns the measurement would have
			# allowed. So a preferred crown here may sit shoulder to shoulder
			# with taller neighbours, and whether its shell really fits is
			# decided below by `_unit_touches_public_air` against the real grid
			# and by `probe.add_unit` against the real neighbours -- never
			# assumed by this branch.
			#
			# The candidates are the ordinary finite full-roof set taken with
			# an EMPTY neighbourhood proposal, and a refusal here can never
			# reach the atomic-neighbourhood retry. Both hold for one reason,
			# and it is a mechanism rather than a geometry claim: every
			# plot-flat crown had its own proposal FORCED to `flat_roof` with
			# its `roof_junction_rules` emptied, and every neighbour's rule
			# naming it dropped, at the top of this function. So this stamp's
			# proposal would return no candidates at all, no neighbour has
			# planned a join into it, and `requires_atomic_neighborhood` is
			# false here by construction -- the retry above returned long
			# before this branch could be reached. A refusal is an audit count
			# (`maze_pitched_refused_count`) and the slab below is the
			# fallback -- never a rejection of the town.
			var preferred_candidates := _full_roof_candidates(room,
				source.world_seed)
			# The first neighborhood-aware pass and this isolated terminal retry
			# must expose the same complete closure domain. Omitting the exact low
			# profiles here made a crown report "no authored gable" after the rich
			# pair failed, even though the program had already compiled its valid
			# tiled terminal closure.
			for tight_gable_id: StringName in \
					_terminal_tight_gable_recipe_ids(room, source.world_seed):
				preferred_candidates.append({"recipe_id": tight_gable_id,
					"yaw_offset": 0})
			var preferred_rejections: Array[Dictionary] = []
			for preferred_index in preferred_candidates.size():
				var preferred_candidate := preferred_candidates[
					preferred_index]
				var preferred_id := StringName(preferred_candidate.recipe_id)
				var preferred_yaw := int(preferred_candidate.yaw_offset)
				var preferred_recipe := program.recipe(preferred_id)
				if preferred_recipe == null:
					last_failure = "missing full roof recipe %s" % preferred_id
					return [] as Array[FabricUnit]
				var preferred_unit := _full_roof_unit(room_id, room,
					parent_unit, preferred_id, _roof_seams_for_candidate(
						room_seams, parent_unit.stable_id, out,
						fixed_feature_units, false), program, preferred_yaw)
				_append_explicit_roof_party_room_seams(preferred_unit, room,
					unit_by_room)
				var public_conflicts := _unit_public_air_conflicts(source.grid,
					preferred_unit, preferred_recipe)
				if not public_conflicts.is_empty():
					var air_rejection := "exact roof volume enters protected public body lane"
					preferred_rejections.append({"recipe_id": preferred_id,
						"yaw_offset": preferred_yaw, "rejection": air_rejection,
						"public_air_cells": public_conflicts})
					attempt_failures.append(("preferred pitched %s/r%d: %s") % [
						preferred_id, preferred_yaw, "%s at %s" % [air_rejection,
							public_conflicts]])
					continue
				var future_roof_conflict := \
					_roof_candidate_required_closure_conflict(preferred_unit,
						preferred_recipe, room_id, required_future_roof_closures,
						unbuilt_roof_room_ids, program)
				if not future_roof_conflict.is_empty():
					var future_rejection := \
						"blocks required future roof closure %s" \
							% future_roof_conflict
					preferred_rejections.append({"recipe_id": preferred_id,
						"yaw_offset": preferred_yaw,
						"rejection": future_rejection})
					attempt_failures.append("preferred pitched %s/r%d: %s" % [
						preferred_id, preferred_yaw, future_rejection])
					continue
				if not probe.add_unit(preferred_unit):
					preferred_rejections.append({"recipe_id": preferred_id,
						"yaw_offset": preferred_yaw,
						"rejection": probe.last_rejection})
					attempt_failures.append("preferred pitched %s/r%d: %s" % [
						preferred_id, preferred_yaw, probe.last_rejection])
					continue
				out.append(preferred_unit)
				realized_face_count += face_cells.size()
				pitched_count += 1
				maze_pitched_count += 1
				plot_flat_pitched_count += 1
				maze_pitched_rooms.append(room_id)
				alternate_pitched_roof_count += int(preferred_index > 0)
				quarter_turned_square_roof_count += int(preferred_yaw != 0)
				var preferred_family := _roof_recipe_family(preferred_id)
				pitched_roof_family_counts[preferred_family] = int(
					pitched_roof_family_counts.get(preferred_family, 0)) + 1
				pitched_roof_recipe_counts[preferred_id] = int(
					pitched_roof_recipe_counts.get(preferred_id, 0)) + 1
				one_storey_chimney_roof_count += int(
					room.source_storey_index == 0 \
						and String(preferred_id).contains(".short."))
				dormered_pitched_roof_count += int(preferred_recipe.has_tag(
					&"dormer"))
				paired_dormer_roof_count += int(preferred_recipe.has_tag(
					&"paired_dormer"))
				selected = true
				break
			if not selected:
				maze_pitched_refused_count += 1
				if maze_pitched_refused_details.size() < 32:
					maze_pitched_refused_details.append({"room_id": room_id,
						"attempts": preferred_rejections})
				# A complete terminal plate is a HOUSE crown, not latent public
				# structure. Turning a failed gable into a flat slab was the late
				# appearance repair that produced the remaining timber-framed boxes in
				# fixed-seed review. Refuse the construction atomically so the bounded
				# procedural selector can choose massing whose authored roof envelopes
				# actually fit. True terraces never enter this branch: public-air and
				# partial/load-bearing plates were excluded when the terminal set was
				# derived.
				last_failure = ("terminal house crown %s has no fitting authored " \
					+ "gable: %s") % [room_id, JSON.stringify(
						preferred_rejections)]
				return [] as Array[FabricUnit]
		elif pitched_preferred:
			# TASK H2. The crown ASKED for a pitched shell and the branch above
			# never ran: its plate is partial (another storey stands on part of
			# it) or part of it carries a street. Counted apart from
			# `maze_pitched_refused_count`, which is the crown whose authored
			# shell WAS measured and rejected -- the two are different facts
			# and only the second is about the vocabulary. `preference =
			# pitched + refused + partial plate` closes over the preference, so
			# no preferred crown goes unaccounted.
			maze_pitched_partial_plate_count += 1
		if selected:
			continue
		# A preferred gable is one finite construction alternative, not a repair
		# authority.  If its real collider cannot coexist with an upper street,
		# court, or neighbouring authored envelope, retain the source plan's exact
		# plate.  The plate is subsequently classified as construction, terrace, or
		# public circulation from the sealed graph; no arbitrary plank platform is
		# inferred from the visual fallback.
		# TASK E3b RULING 1, GATE 1 -- WHEN ONE SLAB CANNOT STAND, TILE.
		#
		# Two facts can stop a plot-flat crown taking one whole-footprint
		# `roof.flat.*` slab: another storey stands on part of it (a PARTIAL
		# plate, C5e's case), or part of it carries a STREET (`street_borne`:
		# the slab's own solid volume would enter that street's headroom).
		# Before this task only the first went to the tiling; the street vetoed
		# the WHOLE crown -- slab and tiles alike -- and dropped it into the
		# finite setback vocabulary, where a leftover one-cell strip has no
		# authored shed and the town died (measured: `7/standard` under the
		# +1-storey widening, `roof remainder for
		# ...house.000.part01.room00 contains a 1-cell exposed sliver`, with a
		# street standing on one cell of that same crown).
		#
		# The rule is now one sentence: A MAZE FLAT CROWN NEVER LEAVES THE FLAT
		# VOCABULARY. It slabs when a slab can stand and tiles when one cannot,
		# and the tiling proves each module on its own -- so the cells under a
		# street take the thin plank cap that claims no mass rather than a slab
		# that would enter the street.
		var street_borne := plot_flat \
			and _touches_public_air(source.grid, face_cells)
		maze_street_borne_plate_count += int(street_borne)
		maze_street_borne_full_plate_count += int(street_borne and full)
		if plot_flat and full and not street_borne:
			# The plot's own slab, at the same lattice datum every full roof
			# unit uses and exactly one band tall (the authored `roof.flat.*`
			# extent).
			var slab_id := _flat_roof_recipe_id(room)
			var slab_recipe := program.recipe(slab_id)
			if slab_recipe == null:
				last_failure = "missing exact flat roof recipe %s" % slab_id
				return [] as Array[FabricUnit]
			var slab := _full_roof_unit(room_id, room, parent_unit, slab_id,
				_roof_seams_for_candidate(room_seams, parent_unit.stable_id,
					out, fixed_feature_units), program)
			if _unit_touches_public_air(source.grid, slab, slab_recipe):
				attempt_failures.append(
					"plot flat %s: exact roof volume enters public air" \
						% slab_id)
			elif probe.add_unit(slab):
				out.append(slab)
				maze_construction_crown_units.append(slab.stable_id)
				maze_flat_crown_rooms.append(room_id)
				realized_face_count += face_cells.size()
				flat_count += 1
				plot_flat_count += 1
				flat_roof_recipe_counts[slab_id] = int(
					flat_roof_recipe_counts.get(slab_id, 0)) + 1
				# TASK H2 PART 3 -- THE SURVIVING TERRACE GETS DRESSED.
				#
				# After part 2 a plot-flat crown is no longer "the ordinary
				# roof of this town": it is the crown something stands on or
				# walks. Those are the terraces the reference dresses --
				# chimneys, planters, a pergola frame -- and the battery
				# measured ZERO furnished terraces before this task.
				#
				# The accent is the authored `roof.flat.*.garden[.rich|.micro]`
				# family, bonded onto the slab exactly as the legacy flat
				# branch below bonds it, and NOT the `*.terrace.*` recipe
				# family: a terrace recipe carries its own railing run on one
				# side, and C5e's `maze_terrace_railings` already rails every
				# open edge of this crown, so the terrace family would double
				# the fence on one side and leave the others as the recipe
				# found them. The garden accent adds no solid and no occluder
				# cell, so the deck, its edges and its railings are the same
				# facts they were.
				#
				# MEASURED, NOT MAXIMAL (the plan's own words). The seeded tier
				# in `_maze_crown_dressing_candidates` leaves a quarter of the
				# crowns bare and gives the richest accent to three eighths;
				# every tier is then proved against the real neighbourhood and
				# falls back to a simpler one, so a crown under a jettied
				# storey ends up with a flower rather than a chimney through
				# the floor above it.
				var dressed := false
				for dressing_id: StringName in \
						_maze_crown_dressing_candidates(room,
							source.world_seed, slab_id):
					var dressing_recipe := program.recipe(dressing_id)
					if dressing_recipe == null:
						continue
					var dressing := _flat_roof_garden_unit(room_id, slab,
						dressing_id)
					if _unit_touches_public_air(source.grid, dressing,
							dressing_recipe):
						attempt_failures.append(
							"crown dressing %s: enters public air" \
								% dressing_id)
						continue
					if not probe.add_unit(dressing):
						attempt_failures.append("crown dressing %s: %s" % [
							dressing_id, probe.last_rejection])
						continue
					out.append(dressing)
					dressed = true
					maze_dressed_crown_count += 1
					maze_crown_dressing_recipe_counts[dressing_id] = int(
						maze_crown_dressing_recipe_counts.get(dressing_id,
							0)) + 1
					maze_crown_chimney_count += int(dressing_recipe.has_tag(
						&"chimney"))
					maze_crown_awning_count += int(dressing_recipe.has_tag(
						&"roof_garden_awning"))
					maze_crown_planter_count += int(not dressing_recipe.has_tag(
						&"micro_roof_garden"))
					break
				maze_bare_crown_count += int(not dressed)
				continue
			else:
				attempt_failures.append("plot flat %s: %s" % [slab_id,
					probe.last_rejection])
			rejected_flat_count += 1
			plot_flat_rejected_count += 1
		if plot_flat and (not full or street_borne):
			# TASK C5e RULING 1 -- A PARTIAL PLATE TILES.
			#
			# Another storey of this same building stands on part of this
			# crown, so the exposed remainder is not a complete footprint and
			# no single `roof.flat.*` module covers it. Before this task the
			# remainder went to the finite setback vocabulary and was required
			# to become a pitched shed or gable: eight of the thirteen
			# non-sealing corpus seeds, the 9/standard pin and the blocker on
			# the no-descent relaxation were all that one refusal.
			#
			# The remainder is covered by `_tile_flat_plate`: exact compact-gable
			# halves on private faces, deck backing only on typed public floors.
			# Each piece is a real roof unit, and the complete partition is one
			# transaction, so an untileable shape changes nothing.
			var tiling := _tile_flat_plate(source, program, probe, room_id,
				room, parent_unit, face_cells, room_seams, out,
				fixed_feature_units, unit_by_room, unit_by_private_cell)
			var plate_tiles := tiling.get("units",
				[] as Array[FabricUnit]) as Array[FabricUnit]
			if not plate_tiles.is_empty():
				var committed := true
				for plate_tile: FabricUnit in plate_tiles:
					if probe.add_unit(plate_tile):
						out.append(plate_tile)
						maze_construction_crown_units.append(plate_tile.stable_id)
						continue
					last_failure = "proved flat plate tiling changed before commit for %s: %s" % [
						room_id, probe.last_rejection]
					committed = false
					break
				if not committed:
					return [] as Array[FabricUnit]
				realized_face_count += face_cells.size()
				maze_flat_crown_rooms.append(room_id)
				maze_tiled_plate_count += 1
				maze_plate_tile_count += plate_tiles.size()
				for plate_tile: FabricUnit in plate_tiles:
					maze_plate_tile_recipe_counts[plate_tile.recipe_id] = int(
						maze_plate_tile_recipe_counts.get(
							plate_tile.recipe_id, 0)) + 1
				continue
			maze_plate_refused_count += 1
			attempt_failures.append("flat plate tiling: %s" % String(
				tiling.get("failure", "rejected")))
		if full and not plot_flat \
				and not _touches_public_air(source.grid, face_cells) \
				and face_cells.size() >= MIN_INTENTIONAL_FLAT_ROOF_FACE_COUNT:
			# A single-storey building's exposed lid read as a bare box in the
			# annotated review. The authored railed terrace (lived-in first)
			# is the deliberate closure for it; the plain flat plus garden
			# remains the multi-storey default and the fallback.
			if room.source_storey_index == 0:
				for terrace_id: StringName in _flat_roof_terrace_candidates(
						room, source.world_seed):
					var terrace_recipe := program.recipe(terrace_id)
					if terrace_recipe == null:
						continue
					var terrace := _full_roof_unit(room_id, room, parent_unit,
						terrace_id, _roof_seams_for_candidate(
							junction_room_seams, parent_unit.stable_id, out,
							fixed_feature_units), program)
					if _unit_touches_public_air(source.grid, terrace,
							terrace_recipe):
						attempt_failures.append(
							"terrace %s: enters public air" % terrace_id)
						continue
					if not probe.add_unit(terrace):
						attempt_failures.append("terrace %s: %s" % [
							terrace_id, probe.last_rejection])
						continue
					out.append(terrace)
					realized_face_count += face_cells.size()
					flat_count += 1
					flat_terrace_count += 1
					lived_in_flat_terrace_count += int(
						terrace_recipe.has_tag(&"lived_in_roof_terrace"))
					flat_roof_recipe_counts[terrace_id] = int(
						flat_roof_recipe_counts.get(terrace_id, 0)) + 1
					selected = true
					break
			if selected:
				continue
			var flat_id := _flat_roof_recipe_id(room)
			var flat := _full_roof_unit(room_id, room, parent_unit, flat_id,
				_roof_seams_for_candidate(room_seams, parent_unit.stable_id, out,
					fixed_feature_units), program)
			var flat_recipe := program.recipe(flat_id)
			if flat_recipe == null:
				last_failure = "missing exact flat roof recipe %s" % flat_id
				return [] as Array[FabricUnit]
			if _unit_touches_public_air(source.grid, flat, flat_recipe):
				rejected_flat_count += 1
				attempt_failures.append(
					"flat: exact roof volume enters public air")
			else:
				if probe.add_unit(flat):
					var base_garden_id := StringName("%s.garden" % flat_id)
					var garden_ids: Array[StringName] = [StringName(
						"%s.rich" % base_garden_id), base_garden_id,
						StringName("%s.micro" % base_garden_id),
						StringName("%s.micro.0" % base_garden_id),
						StringName("%s.micro.1" % base_garden_id),
						StringName("%s.micro.2" % base_garden_id),
						StringName("%s.micro.3" % base_garden_id)]
					var garden: FabricUnit
					var garden_selected := false
					for garden_index in garden_ids.size():
						var garden_id := garden_ids[garden_index]
						if program.recipe(garden_id) == null:
							continue
						garden = _flat_roof_garden_unit(room_id, flat,
							garden_id)
						if probe.add_unit(garden):
							garden_selected = true
							rich_flat_garden_count += int(garden_index == 0)
							rich_flat_garden_fallback_count += int(
								garden_index > 0)
							var garden_recipe := program.recipe(garden_id)
							micro_flat_garden_count += int(garden_recipe != null \
								and garden_recipe.has_tag(&"micro_roof_garden"))
							break
						flat_garden_rejections.append({"room_id": room_id,
							"recipe_id": garden_id,
							"rejection": probe.last_rejection})
					if not garden_selected:
						last_failure = ("flat roof %s has no collision-free measured " \
							+ "accent: %s") % [room_id,
							JSON.stringify(flat_garden_rejections.slice(
								maxi(0, flat_garden_rejections.size() - 3)))]
						return [] as Array[FabricUnit]
					out.append(flat)
					out.append(garden)
					realized_face_count += face_cells.size()
					flat_count += 1
					flat_garden_count += 1
					flat_roof_recipe_counts[flat_id] = int(
						flat_roof_recipe_counts.get(flat_id, 0)) + 1
					continue
				rejected_flat_count += 1
				attempt_failures.append("flat: %s" % probe.last_rejection)
		# Reaching the finite setback vocabulary on a flat-roofed stamp means
		# one of two different things, and they are counted apart because only
		# one of them is a defect.
		#
		# PARTIAL PLATE (measured, and the authored vocabulary's own limit):
		# another room stands on part of this crown, so the exposed remainder
		# is not a complete footprint and there is no `roof.flat.*` module for
		# it -- every flat recipe is a whole-footprint stamp. The remainder
		# keeps the finite setback vocabulary. Counted, never called pitched.
		#
		# FULL PLATE that still lands here: the slab was authored for this
		# exact plate and was refused, so the room really did receive a
		# pitched shell against ruling 1. `plot_flat_roof_pitched_count`
		# counts only that case, and the composition test requires it to be
		# zero.
		plot_flat_partial_plate_count += int(plot_flat and not full)
		# TASK C5d, review minor 8. A COMPLETE plate that reaches the finite
		# setback vocabulary took neither the preferred pitched shell nor its
		# own slab, so `maze_pitched_refused_count` alone would imply it fell
		# back to a slab it never got. Counted here instead of being excluded
		# anywhere: this is the crown that fell through both.
		maze_crown_fell_through_count += int(plot_flat and full)
		var pieces := _cap_pieces(face_cells)
		if pieces.is_empty():
			last_failure = "no finite setback cap partition fits roof region for %s (%s; %s)" \
				% [room_id, "; ".join(attempt_failures),
					_cap_failure_diagnostic(source.grid, face_cells)]
			return [] as Array[FabricUnit]
		for row_index in pieces.size():
			var piece := pieces[row_index] as Dictionary
			var macro_piece := StringName(piece.kind) == &"stamp"
			var row := piece.cells as Array[Vector3i]
			var cap := _setback_gable_placement(piece, room,
				source.world_seed) \
				if macro_piece \
				else _cap_placement(source.grid, row, room, source.world_seed)
			if cap.is_empty():
				last_failure = "no native setback cap fits row %d for %s" % [
					row_index, room_id]
				return [] as Array[FabricUnit]
			# Set by the one-cell lid repair below, and read where the
			# forbidden-plain-cap gate counts this row's unit.
			var lid_repaired := false
			# An exposed shoulder may never survive as a horizontal modular lid,
			# regardless of its length or whether a planter could dress it. Its only
			# admissible treatment is a measured half-gable whose complete long edge
			# terminates in one continuing upper wall or roof. This produces a real
			# attached lean-to/T-roof relationship; without that exact seam the source
			# composition is rejected.
			if not macro_piece:
				var roof_join := _setback_lean_to_placement(source, row, room,
					cap, unit_by_private_cell)
				if roof_join.is_empty():
					roof_join = _setback_roof_join_placement(source, row, room,
						cap, roof_room_id_by_face)
				var shed := _setback_shed_placement(row, room,
					source.world_seed, cap, roof_join)
				# TASK E3b RULING 1, GATE 2 -- THE CROSS-LINEAGE SLIVER REPAIR.
				#
				# `_setback_shed_placement` is authored for 2, 4 and 6 cells,
				# so a ONE-cell strip has no shed at all and this is where the
				# town died. The shoulder rule above is right about an exposed
				# shoulder -- but this strip is not one when the flat lid
				# CONTINUES across its long edges: on a maze crown the whole
				# roof surface is already a horizontal plank lid (C5e ruling
				# 1), so a plank strip carrying it on is that crown's
				# vernacular rather than a modular lid pasted on a shoulder.
				# `_maze_lid_repair_neighbors` is the proof, and it is the
				# LINEAGE-AGNOSTIC half of this task: the continuing crown may
				# belong to another lineage, provided every room involved --
				# this one and each continuing neighbour -- is a maze flat
				# stamp that is not merely PREFERRING pitched (fix round 1,
				# IMPORTANT 1). The repaired cap is deliberately NOT counted in
				# `plain_cap_count`, for the same reason the tiling branch is
				# not: the forbidden-plain-cap gate is about exposed shoulders,
				# and this strip is proved not to be one.
				#
				# COVERAGE GAP, STATED (fix round 1, IMPORTANT 3). No corpus
				# town reaches this branch: a plot-flat crown only arrives at
				# the setback vocabulary when its tiling was refused by the
				# whole-set probe, and `maze_partial_plate_refused_count` is 0
				# on all 24 towns, so the three keys below are published as
				# zeroes everywhere. The rule is covered DIRECTLY instead, by
				# `test_a_one_cell_maze_sliver_is_repaired_only_where_the_lid
				# _continues`, which drives this helper over six fixtures
				# including the two that must stay refused; the corpus test
				# asserts only that the keys are PUBLISHED. If a future change
				# makes a crown refuse its tiling, this branch runs for the
				# first time with only that fixture behind it.
				var lid_repair: Dictionary = {}
				if shed.is_empty() and plot_flat:
					lid_repair = _maze_lid_repair_neighbors(row,
						room_id, roof_room_id_by_face, plot_flat_room_ids,
						plot_pitched_room_ids)
				if shed.is_empty() and not lid_repair.is_empty():
					lid_repaired = true
					maze_lid_repair_cap_count += 1
					maze_lid_repair_cell_count += row.size()
					maze_cross_lineage_repairs += int(bool(
						lid_repair.get("cross_lineage", false)))
				elif shed.is_empty():
					var top_context: Array[Dictionary] = []
					for private_cell: Vector3i in room.private_cells:
						if private_cell.y != room.lattice_origin.y + 1:
							continue
						var above := private_cell + Vector3i.UP
						top_context.append({"cell": private_cell,
							"above_use": source.grid.use_at(above),
							"above_owner": source.grid.owner_name_at(above),
							"reservation_bits": source.grid.reservation_bits_at(above),
							"reservation_owners": source.grid \
								.reservation_owner_names_at(above,
									source.grid.reservation_bits_at(above)),
							"is_roof_face": face_cells.has(private_cell)})
					last_failure = ("roof remainder for %s contains a %d-cell " \
						+ "exposed sliver without a native shallow shed roof " \
						+ "(source faces=%s; remainder=%s; top=%s)") % [room_id,
						row.size(), face_cells, row, JSON.stringify(top_context)]
					return [] as Array[FabricUnit]
				if not shed.is_empty():
					cap = shed
			# A setback roof is not a license to intersect every room that happens
			# to share a party wall with its parent.  That broad exception admitted
			# little gables deep into the valley between two continuing upper rooms.
			# Multiple pieces over this one parent and physically attached feature
			# units remain explicit seams; a lean-to adds its one measured wall seam
			# below. An ordinary macro gable that clips a neighbor must therefore
			# rotate, use its authored plain-pitched shell, resolve to one deliberate
			# large flat roof, or become a complete lean-to campaign.
			var seams := _roof_seams_for_candidate([] as Array[StringName],
				parent_unit.stable_id, out, fixed_feature_units)
			var end_wall_room_ids: Array[StringName] = []
			var edge_roof_room_ids: Array[StringName] = []
			if macro_piece:
				end_wall_room_ids = _setback_gable_end_room_ids(row, cap,
					unit_by_private_cell)
				for gable_room_id: StringName in end_wall_room_ids:
					if not seams.has(gable_room_id):
						seams.append(gable_room_id)
				edge_roof_room_ids = _setback_complete_edge_roof_room_ids(
					row, cap, room.stable_id, roof_room_id_by_face)
				for edge_roof_room_id: StringName in edge_roof_room_ids:
					for prior_roof: FabricUnit in out:
						if String(prior_roof.stable_id).begins_with(
								"spatial.roof.%s" % edge_roof_room_id) \
								and not seams.has(prior_roof.stable_id):
							seams.append(prior_roof.stable_id)
			else:
				end_wall_room_ids = _setback_wall_room_ids(row,
					unit_by_private_cell)
			seams = _unique_sorted_names(seams)
			var upper_room_unit_id := StringName(cap.get(
				"upper_room_unit_id", &""))
			if not upper_room_unit_id.is_empty() \
					and not seams.has(upper_room_unit_id):
				seams.append(upper_room_unit_id)
			for upper_id_value: Variant in cap.get(
					"upper_room_unit_ids", []) as Array:
				var upper_id := StringName(upper_id_value)
				if not upper_id.is_empty() and not seams.has(upper_id):
					seams.append(upper_id)
			var roof_seam_room_id := StringName(cap.get(
				"roof_seam_room_id", &""))
			if not roof_seam_room_id.is_empty():
				for prior_roof: FabricUnit in out:
					if String(prior_roof.stable_id).begins_with(
							"spatial.roof.%s" % roof_seam_room_id) \
							and not seams.has(prior_roof.stable_id):
						seams.append(prior_roof.stable_id)
				seams = _unique_sorted_names(seams)
			var cap_unit := _cap_unit(room_id, row_index, room, parent_unit,
				cap, seams)
			_append_shallow_prior_roof_seams(cap_unit, room_seams, out,
				program)
			_append_shallow_room_seams(cap_unit, end_wall_room_ids,
				unit_by_room, unit_by_private_cell, program)
			var cap_recipe := program.recipe(StringName(cap.recipe_id))
			var cap_enters_public_air := cap_recipe != null \
				and _unit_touches_public_air(source.grid, cap_unit, cap_recipe)
			if cap_enters_public_air or not probe.add_unit(cap_unit):
				var terrace_rejection := probe.last_rejection
				if cap_enters_public_air:
					terrace_rejection = "exact setback roof volume enters public air"
				if macro_piece:
					var fallback_ids: Array[StringName] = []
					var plain_id := _plain_pitched_recipe_id(
						StringName(cap.recipe_id))
					if plain_id != StringName(cap.recipe_id):
						fallback_ids.append(plain_id)
					if row.size() >= MIN_INTENTIONAL_FLAT_ROOF_FACE_COUNT:
						fallback_ids.append(_flat_roof_recipe_id_for_kind(
							StringName(piece.room_kind)))
					var fallback_failures := PackedStringArray([
						terrace_rejection])
					var fallback_selected := false
					# A square/tower crown has the same occupied footprint after a
					# quarter turn, while its measured eave/ridge bounds do not. The
					# full-room path already uses this alternative; compound shoulders
					# need it too so diagonal eave corners can clear rather than overlap.
					if StringName(piece.room_kind) in [&"tower", &"building"]:
						var rotated_ids: Array[StringName] = [StringName(cap.recipe_id)]
						if plain_id != StringName(cap.recipe_id):
							rotated_ids.append(plain_id)
						for rotated_id: StringName in rotated_ids:
							var rotated_cap := cap.duplicate(true)
							rotated_cap["recipe_id"] = rotated_id
							rotated_cap["yaw_quarters"] = posmod(
								int(cap.yaw_quarters) + 1, 4)
							var rotated_seams: Array[StringName] = []
							rotated_seams.assign(seams)
							for original_gable_id: StringName in end_wall_room_ids:
								rotated_seams.erase(original_gable_id)
							var rotated_gable_room_ids := \
								_setback_gable_end_room_ids(row, rotated_cap,
									unit_by_private_cell)
							for rotated_gable_id: StringName in rotated_gable_room_ids:
								if not rotated_seams.has(rotated_gable_id):
									rotated_seams.append(rotated_gable_id)
							rotated_seams = _unique_sorted_names(rotated_seams)
							var rotated_unit := _cap_unit(room_id, row_index,
								room, parent_unit, rotated_cap, rotated_seams)
							_append_shallow_prior_roof_seams(rotated_unit,
								room_seams, out, program)
							_append_shallow_room_seams(rotated_unit,
								end_wall_room_ids, unit_by_room,
								unit_by_private_cell, program)
							var rotated_recipe := program.recipe(rotated_id)
							if rotated_recipe != null \
									and not _unit_touches_public_air(source.grid,
										rotated_unit, rotated_recipe) \
									and probe.add_unit(rotated_unit):
								cap = rotated_cap
								cap_unit = rotated_unit
								fallback_selected = true
								break
							fallback_failures.append("%s/r1: %s" % [
								rotated_id, probe.last_rejection])
					for fallback_id: StringName in fallback_ids \
							if not fallback_selected else [] as Array[StringName]:
						cap["recipe_id"] = fallback_id
						cap_unit = _cap_unit(room_id, row_index, room,
							parent_unit, cap, seams)
						_append_shallow_prior_roof_seams(cap_unit, room_seams,
							out, program)
						_append_shallow_room_seams(cap_unit, end_wall_room_ids,
							unit_by_room, unit_by_private_cell, program)
						var fallback_recipe := program.recipe(fallback_id)
						if fallback_recipe != null \
								and not _unit_touches_public_air(source.grid,
									cap_unit, fallback_recipe) \
								and probe.add_unit(cap_unit):
							fallback_selected = true
							break
						fallback_failures.append("%s: %s" % [fallback_id,
							probe.last_rejection])
					if not fallback_selected:
						# A compound shoulder is admitted because its exact cells can be
						# partitioned into authored shapes.  If the recognizable gable's
						# measured eave cannot clear a neighboring macro room, preserve the
						# same lossless partition with native terminal strips. Every strip
						# must become a typed lean-to at a complete upper facade or roof seam.
						# This is atomic: no first strip commits unless every strip fits.
						var terminal := _terminal_macro_cap_fallback(source,
							program, probe, row, row_index, room_id, room,
							parent_unit, seams, room_seams, unit_by_room,
							unit_by_private_cell, out, roof_room_id_by_face)
						var terminal_units := terminal.get("units",
							[] as Array[FabricUnit]) as Array[FabricUnit]
						if terminal_units.is_empty():
							fallback_failures.append(String(terminal.get(
								"failure", "terminal strip fallback rejected")))
							last_failure = "macro setback roof %d for %s and its complete fallbacks were rejected: %s" % [
								row_index, room_id, "; ".join(fallback_failures)]
							return [] as Array[FabricUnit]
						for terminal_unit: FabricUnit in terminal_units:
							if not probe.add_unit(terminal_unit):
								last_failure = "proved terminal roof fallback changed before commit for %s: %s" % [
									room_id, probe.last_rejection]
								return [] as Array[FabricUnit]
							out.append(terminal_unit)
							plot_flat_pitched_count += int(plot_flat and full \
								and not String(terminal_unit.recipe_id) \
									.begins_with("roof.flat."))
							cap_count += 1
							plain_cap_count += int(String(
								terminal_unit.recipe_id).begins_with(
									"roof.setback.cap."))
							lean_to_cap_count += int(String(
								terminal_unit.recipe_id).begins_with(
									"roof.setback.lean."))
							shed_cap_count += int(String(
								terminal_unit.recipe_id).begins_with(
									"roof.setback.shed."))
						realized_face_count += row.size()
						macro_gable_fallback_count += 1
						terminal_macro_cap_fallback_count += 1
						continue
					macro_gable_fallback_count += 1
				else:
					var alternate_selected := false
					if String(cap.recipe_id).begins_with("roof.setback.shed."):
						var alternate := cap.duplicate(true)
						var recipe_text := String(cap.recipe_id)
						alternate["recipe_id"] = StringName(
							recipe_text.trim_suffix("negative") + "positive" \
							if recipe_text.ends_with("negative") \
							else recipe_text.trim_suffix("positive") + "negative")
						var alternate_unit := _cap_unit(room_id, row_index, room,
							parent_unit, alternate, seams)
						_append_shallow_prior_roof_seams(alternate_unit,
							room_seams, out, program)
						_append_shallow_room_seams(alternate_unit,
							end_wall_room_ids, unit_by_room,
							unit_by_private_cell, program)
						var alternate_recipe := program.recipe(StringName(
							alternate.recipe_id))
						if alternate_recipe != null \
								and not _unit_touches_public_air(source.grid,
									alternate_unit, alternate_recipe) \
								and probe.add_unit(alternate_unit):
							cap = alternate
							cap_unit = alternate_unit
							alternate_selected = true
					if not alternate_selected:
						last_failure = "exact setback roof %d for %s was rejected after %s: %s" \
							% [row_index, room_id, "; ".join(attempt_failures),
								probe.last_rejection]
						return [] as Array[FabricUnit]
			out.append(cap_unit)
			plot_flat_pitched_count += int(plot_flat and full \
				and not String(
					cap_unit.recipe_id).begins_with("roof.flat."))
			realized_face_count += row.size()
			cap_count += 1
			plain_cap_count += int(not lid_repaired \
				and String(cap_unit.recipe_id).begins_with("roof.setback.cap."))
			lean_to_cap_count += int(String(cap_unit.recipe_id) \
				.begins_with("roof.setback.lean."))
			shed_cap_count += int(String(cap_unit.recipe_id) \
				.begins_with("roof.setback.shed."))
			macro_gable_cap_count += int(macro_piece and not String(
				cap_unit.recipe_id).begins_with("roof.flat."))
			terrace_cap_count += int(String(cap_unit.recipe_id) \
				.contains(".terrace."))
			garden_cap_count += int(String(cap_unit.recipe_id) \
				.contains(".garden."))
	var roof_unit_by_room: Dictionary = {}
	for roof_unit: FabricUnit in out:
		var roof_text := String(roof_unit.stable_id)
		if roof_text.begins_with("spatial.roof.") \
				and not roof_text.contains(".cap"):
			roof_unit_by_room[StringName(roof_text.trim_prefix(
				"spatial.roof."))] = roof_unit
	var roof_trim_count := 0
	var rejected_roof_trim_count := 0
	var rejected_roof_trim_details: Array[Dictionary] = []
	roof_stage_ms = _trace_stage("roof.selection", roof_stage_ms)
	for pending: Dictionary in pending_roof_trims:
		var room_id := StringName(pending.room_id)
		var parent_roof := roof_unit_by_room.get(room_id) as FabricUnit
		var component := pending.component as Dictionary
		if parent_roof == null:
			last_failure = "roof trim %s lost its bearing roof" % room_id
			return [] as Array[FabricUnit]
		var side := int(component.get("roof_junction_side", -1))
		var side_name := "negative" \
			if side == FabricRoofTopologyPlan.Side.EAVE_NEGATIVE else "positive"
		var seams: Array[StringName] = []
		for seam_value: Variant in component.get("neighbor_room_ids", []):
			var neighbor_room_id := StringName(seam_value)
			# A classified valley/eave trim physically seals to both the
			# neighboring roof and its wall plate.  The roof is not a proxy for
			# that room: on stepped contacts the authored trim deliberately
			# reaches the neighboring facade before it reaches the roof volume.
			var neighbor_room := unit_by_room.get(neighbor_room_id) as FabricUnit
			if neighbor_room != null:
				seams.append(neighbor_room.stable_id)
			var neighbor_roof := roof_unit_by_room.get(
				neighbor_room_id) as FabricUnit
			if neighbor_roof != null:
				seams.append(neighbor_roof.stable_id)
		seams = _unique_sorted_names(seams)
		var trim := FabricUnit.new(StringName("%s.trim.%02d" % [
			parent_roof.stable_id, roof_trim_count]),
			StringName(component.recipe_id), component.origin as Vector3i,
			int(component.yaw_quarters),
			[parent_roof.stable_id] as Array[StringName],
			[FabricUnit.bond(&"bearing.bottom", parent_roof.stable_id,
				StringName("bearing.junction.eave.%s" % side_name))] \
				as Array[Dictionary], &"", seams)
		if not probe.add_unit(trim):
			# The two complete roof shells remain watertight when optional flashing
			# cannot fit a third intersecting setback roof. Omitting that trim is a
			# coherent atomic fallback; never flatten just one side of the campaign.
			rejected_roof_trim_count += 1
			if rejected_roof_trim_details.size() < 16:
				rejected_roof_trim_details.append({"trim_id": trim.stable_id,
					"rejection": probe.last_rejection})
			continue
		out.append(trim)
		roof_trim_count += 1
	if realized_face_count != source_face_count:
		last_failure = "roof realization covered %d of %d authoritative faces" % [
			realized_face_count, source_face_count]
		return [] as Array[FabricUnit]
	if plain_cap_count != 0:
		last_failure = "roof campaign retained %d forbidden exposed modular caps" \
			% plain_cap_count
		return [] as Array[FabricUnit]
	# Direct whole-town scans bind branch-local counters to the construction that
	# will actually ship. In particular they distinguish public cap backing from
	# private exact gables and hard-reject any canopy/plank tile over a private
	# face. Read them before the dormer bar because that bar judges the same final
	# roofscape rather than a proposal branch.
	var isolated_flat := _maze_isolated_flat_crowns(room_by_id,
		maze_pitched_rooms, maze_flat_crown_rooms)
	var maze_pitched_preferred_rooms: Array[StringName] = []
	maze_pitched_preferred_rooms.assign(plot_pitched_room_ids.keys())
	maze_pitched_preferred_rooms.sort_custom(func(a: StringName,
			b: StringName) -> bool: return String(a) < String(b))
	var setback_cap_recipe_unit_count := 0
	var partial_gable_roof_count := 0
	var private_partial_plank_roof_count := 0
	var dormered_roof_unit_count := 0
	for scanned_unit: FabricUnit in out:
		var scanned_recipe_text := String(scanned_unit.recipe_id)
		setback_cap_recipe_unit_count += int(scanned_recipe_text \
			.begins_with("roof.setback.cap."))
		var scanned_recipe := program.recipe(scanned_unit.recipe_id)
		partial_gable_roof_count += int(scanned_recipe_text.begins_with(
			"roof.partial.gable."))
		if String(scanned_unit.stable_id).contains(".tile") \
				and (scanned_recipe_text.begins_with("roof.setback.cap.") \
					or scanned_recipe_text.begins_with("roof.setback.shed.")) \
				and scanned_recipe != null:
			for local_cell: Vector3i in _tile_footprint(scanned_recipe,
					scanned_unit.yaw_quarters):
				var air_cell := local_cell + scanned_unit.lattice_origin
				var floor_claim := source.grid.face_claim(air_cell,
					Vector3i.DOWN)
				if source.grid.use_at(air_cell) \
						!= WarrenSpatialGrid.Use.PUBLIC_AIR \
						or int(floor_claim.get("kind", -1)) \
							!= WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR:
					private_partial_plank_roof_count += 1
					break
		dormered_roof_unit_count += int(scanned_recipe != null \
			and scanned_recipe.has_tag(&"dormer"))
	if private_partial_plank_roof_count != 0:
		last_failure = "roof campaign retained %d private plank/canopy crown tiles" \
			% private_partial_plank_roof_count
		return [] as Array[FabricUnit]
	# TASK C5d RULING 1. The dormer bar is a SEARCHED town's quality rule: it
	# exists so a route-first roofscape cannot come out as an unarticulated
	# field of plain gables, and there the selector can go and choose another
	# composition. The plot model's roofscape is deliberately FLAT -- a tiered
	# hill town of slab crowns with the occasional pitched roof where one
	# fits -- so "no dormer anywhere" is its vernacular rather than its defect,
	# and there is no other composition to select: this gate simply threw the
	# town away (measured: seed 1/standard, `roof campaign has no integrated
	# dormer`).
	#
	# TASK F3 FIX 1, IMPORTANT 2. It used to read
	# `dormered_pitched_roof_count`, which sees only the two PITCHED branches.
	# `_setback_gable_placement` -- the macro-gable arm of the setback
	# vocabulary -- also selects an ordinary `roof.*.dormer.*` recipe, and that
	# arm is not maze-gated, so a town whose only dormers came from it read as
	# dormerless to this bar and would have been discarded for lacking exactly
	# the quality it has. That is not hypothetical: corpus town 9/standard has
	# `dormered_pitched_roof_count = 0` and TWO macro-gable dormers. It ships
	# today only because `maze_plot_model` skips the bar entirely.
	#
	# The bar now reads the roofscape's whole-town dormer count, which is what
	# its own failure message claims to be about. Behaviour-preserving on
	# everything that exists: the sum is >= the old term, so it can only refuse
	# FEWER towns, and every town this repository produces is a maze town that
	# never reaches the condition (`WarrenMazeVolumeAdapter` stamps
	# `maze_source_plan` on every volume `WarrenVolumetricSolver` composes, and
	# `compile_roof_units` has no other caller than `solve` and the compiler
	# fixture, which drives the same solver). Identity probe: empty diff on all
	# four planner towns.
	if dormered_roof_unit_count == 0 and not maze_plot_model:
		last_failure = ("roof campaign has no integrated dormer; select another " \
			+ "sealed composition instead of accepting an unarticulated roof field")
		return [] as Array[FabricUnit]
	last_audit = {
		"source_roof_face_count": source_face_count,
		"realized_roof_face_count": realized_face_count,
		"roofed_room_count": room_ids.size(),
		"roof_unit_count": out.size(),
		"pitched_roof_count": pitched_count,
		"integrated_bridge_roof_count": integrated_bridge_roof_count,
		"partial_plate_pitched_roof_count": partial_plate_pitched_count,
		"flat_roof_count": flat_count,
		"flat_roof_terrace_count": flat_terrace_count,
		"flat_roof_garden_count": flat_garden_count,
		"rich_flat_roof_garden_count": rich_flat_garden_count,
		"rich_flat_roof_garden_fallback_count":
			rich_flat_garden_fallback_count,
		"micro_flat_roof_garden_count": micro_flat_garden_count,
		"flat_roof_garden_rejections": flat_garden_rejections,
		"flat_roof_recipe_counts": flat_roof_recipe_counts,
		"lived_in_flat_roof_terrace_count": lived_in_flat_terrace_count,
		"awning_flat_roof_terrace_count": awning_flat_terrace_count,
		"furnished_flat_roof_terrace_count": furnished_flat_terrace_count,
		"lamped_flat_roof_terrace_count": lamped_flat_terrace_count,
		"plot_flat_roof_room_count": plot_flat_room_count,
		"plot_flat_roof_count": plot_flat_count,
		"plot_flat_roof_pitched_count": plot_flat_pitched_count,
		"plot_flat_roof_partial_plate_count": plot_flat_partial_plate_count,
		"plot_flat_roof_rejected_count": plot_flat_rejected_count,
		# TASK C5d RULING 2 -- the maze roof triple, so a reader finds every
		# half of one decision beside the others.
		#
		# `maze_flat_roof_count` is an ALIAS of `plot_flat_roof_count` two
		# lines up -- the same variable, published under the name the ruling
		# names. It is not an independent measurement and no test should
		# assert the two are equal.
		#
		# `maze_pitched_roof_count` is the crowns the seeded preference really
		# won. `maze_pitched_refused_count` is the preferred crowns whose
		# authored shell did not fit; each of those then tried its own slab.
		# `maze_crown_fell_through_count` is the complete plates that got
		# NEITHER -- neither a preferred shell nor a slab -- and went on to the
		# finite setback vocabulary, so a reader is never left assuming a
		# refused preference always landed on a slab.
		"maze_flat_roof_count": plot_flat_count,
		"maze_pitched_roof_count": maze_pitched_count,
		"maze_pitched_refused_count": maze_pitched_refused_count,
		"maze_pitched_refused_details": maze_pitched_refused_details,
		"maze_crown_fell_through_count": maze_crown_fell_through_count,
		"maze_pitched_roof_rooms": maze_pitched_rooms,
		# The final topology says yes to every free crown, so the accounting has
		# to close over it: a terminal crown either won its
		# shell (`maze_pitched_roof_count`), had it measured and rejected
		# (`_refused_count`), or never reached the branch at all because its
		# plate is partial or street-borne (`_partial_plate_count`). The three
		# sum to `maze_pitched_preferred_room_count`, and
		# `test_pitched_is_the_default_crown` asserts exactly that.
		# It is intentionally a room count from final exposed faces, not the source
		# plan's parcel preference count.
		"maze_pitched_preferred_room_count": plot_pitched_room_ids.size(),
		"maze_pitched_preferred_rooms": maze_pitched_preferred_rooms,
		"maze_pitched_partial_plate_count": maze_pitched_partial_plate_count,
		# TASK H2 PART 4 -- "boxes cluster, they don't sprinkle", measured.
		# A LINEAGE whose every crown is flat while every crown-adjacent
		# lineage is entirely pitched. Zero is not the target -- a house under
		# a stacked storey or a street has to be flat wherever it stands --
		# but a town full of them would mean the flat crowns are sprinkled
		# rather than blocked, which is the defect the second reference batch
		# names. `_details` carries up to eight of them so a render can be
		# read against a name.
		"maze_isolated_flat_crown_count": int(isolated_flat.count),
		"maze_flat_crown_lineage_count": int(isolated_flat.flat_lineages),
		"maze_pitched_crown_lineage_count": int(isolated_flat.pitched_lineages),
		"maze_isolated_flat_crown_details": isolated_flat.details,
		# TASK H2 PART 3 -- what the surviving terraces WEAR. `_dressed` and
		# `_bare` close over the plot-flat crowns that took their own slab
		# (`plot_flat_roof_count`); the three asset counts below are subsets of
		# `_dressed` and overlap by construction (a rich accent is a planter
		# AND a chimney or an awning).
		"maze_dressed_crown_count": maze_dressed_crown_count,
		"maze_bare_crown_count": maze_bare_crown_count,
		"maze_dressed_crown_ratio": float(maze_dressed_crown_count) \
			/ float(maxi(1, maze_dressed_crown_count + maze_bare_crown_count)),
		"maze_crown_chimney_count": maze_crown_chimney_count,
		"maze_crown_awning_count": maze_crown_awning_count,
		"maze_crown_planter_count": maze_crown_planter_count,
		"maze_crown_dressing_recipe_counts": maze_crown_dressing_recipe_counts,
		# The partial-plate triple. `_tiled_count` is the crowns whose uncovered
		# remainder was covered with topology-typed authored modules, `_tile_count`
		# the modules that took, and
		# `_refused_count` the crowns whose shape this vocabulary could not
		# cover and which therefore kept the finite setback vocabulary. The
		# three of them, plus `plot_flat_roof_partial_plate_count` above,
		# state the whole disposition of a maze town's partial plates:
		# `_tiled + _refused` is every partial flat plate, and
		# `plot_flat_roof_partial_plate_count` counts only the refused ones,
		# because a tiled crown never reaches the setback vocabulary at all.
		# FIX ROUND 1, MINOR 1 -- THESE THREE COUNT THE TILING BRANCH, NOT
		# "PARTIAL PLATES". C5e named them when the branch had exactly one
		# entry condition (a plate another storey stands on). Task E3b's gate 1
		# gave it a second (a plate a STREET stands on), which admits crowns
		# whose plate is COMPLETE, and the names were left behind: a full
		# street-borne crown has been counted as a tiled "partial plate" ever
		# since. The keys are kept -- they are pinned in the composition suite
		# and renaming them would strand the pin -- and the meaning is stated
		# here instead: crowns the tiling branch TILED, tiles it placed, and
		# crowns it refused, over BOTH entry conditions.
		# `maze_street_borne_full_plate_count` below is the term that makes
		# `tiled + refused` add up against an independently derived count of
		# partial crowns, which is how `test_partial_plates_are_tiled` reads it.
		"maze_partial_plate_tiled_count": maze_tiled_plate_count,
		"maze_partial_plate_tile_count": maze_plate_tile_count,
		"maze_partial_plate_refused_count": maze_plate_refused_count,
		# TASK E3b RULING 1 -- the two gates, published so a test can assert
		# them rather than infer them from a seal.
		#
		# `maze_street_borne_plate_count`: crowns that carry a street on part of
		# their plate and are TILED for it (gate 1). Before this task each of
		# them left the flat vocabulary entirely.
		# `maze_lid_repair_cap_count` / `_cell_count`: one-cell setback strips
		# kept as plank caps because the maze lid continues across them, and
		# `maze_cross_lineage_repairs` the subset whose continuing crown belongs
		# to ANOTHER lineage -- the sliver repair proper.
		"maze_street_borne_plate_count": maze_street_borne_plate_count,
		# FIX ROUND 1, MINOR 1. The FULL subset of the above -- crowns whose
		# plate is complete and which reach the tiling only because a street
		# stands on it. They are the reason `maze_partial_plate_tiled_count` is
		# not the count of PARTIAL plates any more (see its note), and the term
		# that makes the tiling identity add up:
		#   tiled + refused == partial crowns + street-borne FULL crowns.
		"maze_street_borne_full_plate_count":
			maze_street_borne_full_plate_count,
		"maze_lid_repair_cap_count": maze_lid_repair_cap_count,
		"maze_lid_repair_cell_count": maze_lid_repair_cell_count,
		"maze_cross_lineage_repairs": maze_cross_lineage_repairs,
		"maze_partial_plate_tile_recipe_counts": \
			maze_plate_tile_recipe_counts,
		"maze_construction_crown_unit_ids": maze_construction_crown_units,
		# A plot slab is a DELIBERATE closure, not the unarticulated lid the
		# review round complained about, so it is excluded from the bare count
		# rather than inflating it (Task C5 ruling 1).
		"bare_flat_roof_count": flat_count - flat_terrace_count \
			- flat_garden_count - plot_flat_count,
		"micro_flat_roof_count": 0,
		# THE UNITS THE FINITE SETBACK VOCABULARY EMITTED, whatever recipe each
		# one took: one per committed piece of a crown that reached that
		# vocabulary, so it is the denominator the six `setback_*` keys below
		# are subsets of.
		#
		# TASK F3 FIX 1, IMPORTANT 1 -- IT WAS CALLED `setback_cap_unit_count`,
		# AND THE NAME WAS THE DEFECT. It reads as "the count of setback cap
		# units", which is what F1 took it for -- F1 scanned the shipped town
		# for `roof.setback.cap.*`, found 8 against this counter's 0, and filed
		# a counter defect. F3 diagnosed that misreading correctly and then
		# made it again one file away, adding this key wholesale to a tiled-cap
		# total in a reconciliation that is arithmetically false on three
		# corpus towns and passed only because the production seed's
		# vocabulary emits nothing. A name that has caused two independent
		# misreadings is not a documentation problem, so it is renamed to what
		# it counts.
		#
		# For the town's `roof.setback.cap.*` unit count, use
		# `setback_cap_recipe_unit_count` beside it (the whole-town recipe
		# scan) or `maze_partial_plate_tile_recipe_counts` above (its
		# per-recipe half). MEASURED over 29 towns: those two are EQUAL on
		# every one, because the setback vocabulary has never emitted a plain
		# cap -- `setback_plain_cap_unit_count` below is the gate that keeps it
		# so. This key is 0 on 26 of the 29 and 1, 4, 4 on 8/compact,
		# 5/compact and 9/standard, whose units are sheds, lean-tos and macro
		# gables.
		"setback_vocabulary_unit_count": cap_count,
		"setback_cap_recipe_unit_count": setback_cap_recipe_unit_count,
		# Direct construction invariants for the partial-crown tiler. Private
		# weather faces are exact authored gable halves; plank/canopy tiles may
		# survive only on their own typed public-floor cells, so this second count
		# is a hard zero rather than a quality target.
		"partial_gable_roof_count": partial_gable_roof_count,
		"private_partial_plank_roof_count": private_partial_plank_roof_count,
		"setback_lean_to_unit_count": lean_to_cap_count,
		"setback_shed_unit_count": shed_cap_count,
		"setback_macro_gable_unit_count": macro_gable_cap_count,
		"setback_macro_gable_fallback_count": macro_gable_fallback_count,
		"setback_terminal_macro_fallback_count": \
			terminal_macro_cap_fallback_count,
		"setback_terrace_unit_count": terrace_cap_count,
		"setback_garden_unit_count": garden_cap_count,
		"setback_dressed_unit_count": terrace_cap_count + garden_cap_count,
		# The vocabulary's OWN `roof.setback.cap.*` units -- the exposed
		# modular lids the gate above refuses outright, so it is 0 on every
		# town that seals. It is the only term that belongs on the vocabulary
		# side of a `roof.setback.cap.*` reconciliation; the lid-repaired
		# strips (`maze_lid_repair_cap_count`) are the same recipe deliberately
		# excluded from it, and are also 0 corpus-wide.
		"setback_plain_cap_unit_count": plain_cap_count,
		"micro_setback_cap_unit_count": 0,
		"setback_terrace_fallback_count": terrace_cap_fallback_count,
		"setback_garden_fallback_count": garden_cap_fallback_count,
		"one_storey_chimney_roof_count": one_storey_chimney_roof_count,
		# TASK F3 MEMBER 2. `dormered_pitched_roof_count` and
		# `paired_dormer_roof_count` count what the two PITCHED branches chose:
		# crowns that took a dormered authored shell. They do not see the
		# macro-gable setback branch, whose `_setback_gable_placement` also
		# selects an ordinary `roof.*.dormer.*` recipe -- so on the three
		# corpus towns that reach it, the town has dormers these two do not
		# report, and on 9/standard they are ALL of them.
		# `dormered_roof_unit_count` is the whole-town scan: the number a
		# direct scan of the compiled units is held to, and, since task F3's
		# fix round, the number the dormer bar above reads. The difference
		# between the two IS the macro-gable branch, which is why both are
		# kept -- a reader asking "did the pitched campaign articulate its
		# roofs" and a reader asking "does this town have dormers" are asking
		# different questions.
		"dormered_pitched_roof_count": dormered_pitched_roof_count,
		"dormered_roof_unit_count": dormered_roof_unit_count,
		"paired_dormer_roof_count": paired_dormer_roof_count,
		"rejected_pitched_count": rejected_pitched_count,
		"rejected_pitched_details": rejected_pitched_details,
		"rejected_flat_count": rejected_flat_count,
		"pitched_roof_family_counts": pitched_roof_family_counts,
		"pitched_roof_recipe_counts": pitched_roof_recipe_counts,
		"exposed_roof_room_kind_counts": exposed_roof_room_kind_counts,
		"exposed_roof_feature_counts": exposed_roof_feature_counts,
		"alternate_pitched_roof_count": alternate_pitched_roof_count,
		"quarter_turned_square_roof_count": quarter_turned_square_roof_count,
		"roof_neighborhood_join_count": int(roof_neighborhood.get(
			"junction_count", 0)),
		"continuous_ridge_join_count": int(roof_neighborhood.get(
			"ridge_continuation_count", 0)),
		"parallel_valley_join_count": int(roof_neighborhood.get(
			"parallel_valley_count", 0)),
		"perpendicular_valley_join_count": int(roof_neighborhood.get(
			"perpendicular_valley_count", 0)),
		"roof_neighborhood_flattened_room_count": int(roof_neighborhood.get(
			"flattened_room_count", 0)),
		"roof_junction_trim_unit_count": roof_trim_count,
		"rejected_optional_roof_trim_count": rejected_roof_trim_count,
		"rejected_optional_roof_trim_details": rejected_roof_trim_details,
		"atomic_neighborhood_roof_count": atomic_neighborhood_roof_count,
		"broken_atomic_roof_neighborhood_count": 0,
		# Compatibility diagnostics retained at zero: collision failures now
		# reject the atomic campaign instead of mutating it into flat architecture.
		"collision_flattened_roof_room_count": 0,
		"collision_flattened_roof_component_count": 0,
		"collision_flatten_trigger_details": [] as Array[Dictionary],
	}
	return out


static func _roof_neighborhood_component(proposal_by_room: Dictionary,
		start_room_id: StringName) -> Array[StringName]:
	## Return the complete joined campaign around one measured collision.  The
	## graph includes stepped joins as well as equal-height continuations: a flat
	## interruption at either kind of authored seam is the visual defect this
	## retry exists to prevent.
	var out: Array[StringName] = []
	var pending: Array[StringName] = [start_room_id]
	var seen: Dictionary = {start_room_id: true}
	while not pending.is_empty():
		var room_id: StringName = pending.pop_back()
		out.append(room_id)
		var proposal := proposal_by_room.get(room_id, {}) as Dictionary
		for rule: Dictionary in proposal.get(
				"roof_junction_rules", []) as Array:
			var neighbor_id := StringName(rule.get("neighbor_id", &""))
			if neighbor_id == &"" or seen.has(neighbor_id) \
					or not proposal_by_room.has(neighbor_id):
				continue
			seen[neighbor_id] = true
			pending.append(neighbor_id)
	out.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	return out


static func _full_roof_unit(room_id: StringName, room: WarrenRoomStamp,
		parent_unit: FabricUnit, recipe_id: StringName,
		seams: Array[StringName], program: SettlementFabricProgram,
		yaw_offset: int = 0) -> FabricUnit:
	## Even-cell footprints have a half-cell centre. Turning a square crown while
	## keeping its lattice origin rotates that half-cell phase around the wrong
	## pivot and moves the roof by exactly one 1.5 m fine cell. Preserve the
	## parent's finished world-space plate centre, then bind the shifted roof's
	## bottom socket to the exact parent column beneath it. This is the same
	## phase-preserving construction rule for every rotatable full roof; no mesh
	## offset or recipe-specific correction is introduced.
	assert(program != null)
	var roof_recipe := program.recipe(recipe_id)
	assert(roof_recipe != null and not roof_recipe.solid_cells.is_empty())
	var roof_yaw := posmod(room.yaw_quarters + yaw_offset, 4)
	var roof_origin := _phase_aligned_full_roof_origin(room, roof_recipe,
		roof_yaw)
	var target_socket := &"bearing.top"
	if roof_origin.x != room.lattice_origin.x \
			or roof_origin.z != room.lattice_origin.z:
		var parent_local := _inverse_cell(roof_origin - Vector3i.UP,
			room.lattice_origin, room.yaw_quarters)
		target_socket = SettlementFabricProgram._bearing_cell_socket_id(&"top",
			parent_local.x, parent_local.z)
	return FabricUnit.new(StringName("spatial.roof.%s" % room_id), recipe_id,
		roof_origin, roof_yaw,
		[parent_unit.stable_id] as Array[StringName],
		[FabricUnit.bond(&"bearing.bottom", parent_unit.stable_id,
			target_socket)] as Array[Dictionary], &"", seams)


static func _phase_aligned_full_roof_origin(room: WarrenRoomStamp,
		roof_recipe: FabricRecipe, roof_yaw: int) -> Vector3i:
	var room_min := Vector2(INF, INF)
	var room_max := Vector2(-INF, -INF)
	for cell: Vector3i in room.private_cells:
		room_min = room_min.min(Vector2(cell.x, cell.z))
		room_max = room_max.max(Vector2(cell.x, cell.z))
	var roof_min := Vector2(INF, INF)
	var roof_max := Vector2(-INF, -INF)
	for cell: Vector3i in roof_recipe.solid_cells:
		roof_min = roof_min.min(Vector2(cell.x, cell.z))
		roof_max = roof_max.max(Vector2(cell.x, cell.z))
	var target_centre := (room_min + room_max) * 0.5
	var local_centre := (roof_min + roof_max) * 0.5
	var rotated_centre := local_centre
	match roof_yaw & 3:
		1:
			rotated_centre = Vector2(local_centre.y, -local_centre.x)
		2:
			rotated_centre = -local_centre
		3:
			rotated_centre = Vector2(-local_centre.y, local_centre.x)
	var horizontal_origin := target_centre - rotated_centre
	assert(is_equal_approx(horizontal_origin.x, roundf(horizontal_origin.x))
		and is_equal_approx(horizontal_origin.y, roundf(horizontal_origin.y)))
	return Vector3i(roundi(horizontal_origin.x), room.lattice_origin.y
		+ WarrenSpatialGrid.STOREY_CELLS, roundi(horizontal_origin.y))


static func _flat_roof_garden_unit(room_id: StringName,
		flat_roof: FabricUnit, recipe_id: StringName) -> FabricUnit:
	return FabricUnit.new(StringName("spatial.roof.%s.garden" % room_id),
		recipe_id, flat_roof.lattice_origin, flat_roof.yaw_quarters,
		[flat_roof.stable_id] as Array[StringName],
		[FabricUnit.bond(&"bearing.bottom", flat_roof.stable_id,
			&"bearing.top")] as Array[Dictionary])


static func _cap_unit(room_id: StringName, row_index: int,
		room: WarrenRoomStamp, parent_unit: FabricUnit, cap: Dictionary,
		seams: Array[StringName], stable_suffix: String = "") -> FabricUnit:
	var anchor_face := cap.anchor_face as Vector3i
	var parent_local := _inverse_cell(anchor_face, room.lattice_origin,
		room.yaw_quarters)
	var stable_id := StringName("spatial.roof.%s.cap%02d%s" % [room_id,
		row_index, "" if stable_suffix.is_empty() else ".%s" % stable_suffix])
	return FabricUnit.new(stable_id, StringName(cap.recipe_id),
		cap.origin as Vector3i,
		int(cap.yaw_quarters), [parent_unit.stable_id] as Array[StringName],
		[FabricUnit.bond(&"bearing.bottom", parent_unit.stable_id,
			SettlementFabricProgram._bearing_cell_socket_id(&"top",
				parent_local.x, parent_local.z))] as Array[Dictionary], &"", seams)


static func _maze_lid_repair_neighbors(row: Array[Vector3i],
		room_id: StringName, roof_room_id_by_face: Dictionary,
		plot_flat_room_ids: Dictionary,
		plot_pitched_room_ids: Dictionary) -> Dictionary:
	## TASK E3b RULING 1, GATE 2. Does the flat lid CONTINUE across this
	## setback strip's long edges? Returns `{}` when it does not -- the strip is
	## then the exposed shoulder the shed rule exists for -- and otherwise
	## `{cross_lineage}`, true when at least one continuing crown belongs to
	## another room.
	##
	## The proof, cell by cell: every cell of the strip must have at least one
	## horizontal neighbour AT ITS OWN BAND that is another room's or this
	## room's exposed ROOF FACE, and every such neighbour's room must be a maze
	## flat crown that is really going to be FLAT. Both halves matter. Without
	## the first, a strip hanging off the end of a crown would be repaired;
	## without the second, a pitched neighbour's weather shoulder would be read
	## as a continuing plank lid, which is exactly the modular-lid defect the
	## shed rule forbids. `plot_flat_room_ids` is EMPTY on every route-first and
	## mass-first plan, so no legacy strip can be repaired here.
	##
	## `plot_flat_room_ids` alone is NOT the second half. It holds every
	## flat-capable stamp, including complete terminal crowns that the sealed
	## topology requires us to try as houses (`plot_pitched_room_ids`, the
	## `pitched_preferred` branch above). A strip repaired against one of those
	## assumes a plank lid where a gable may be about to stand. Whether the exact
	## gable wins is decided later and in an order this scan cannot see, so those
	## terminal crowns are refused outright rather than raced.
	if row.is_empty() or plot_flat_room_ids.is_empty():
		return {}
	var strip: Dictionary = {}
	for cell: Vector3i in row:
		strip[cell] = true
	var cross_lineage := false
	for cell: Vector3i in row:
		var continued := false
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.FORWARD, Vector3i.BACK]:
			var neighbor := cell + direction
			if strip.has(neighbor):
				continue
			var neighbor_room := StringName(roof_room_id_by_face.get(neighbor,
				&""))
			if neighbor_room.is_empty():
				continue
			if not plot_flat_room_ids.has(neighbor_room) \
					or plot_pitched_room_ids.has(neighbor_room):
				# A neighbouring crown that is not a maze flat stamp cannot
				# carry the argument, and admitting it here would be the
				# lineage-agnostic rule reaching past the maze. One that only
				# is a terminal gable candidate cannot carry it either: see the header.
				return {}
			continued = true
			cross_lineage = cross_lineage or neighbor_room != room_id
		if not continued:
			return {}
	return {"cross_lineage": cross_lineage}


static func _tile_flat_plate(source: WarrenSpatialPlan,
		program: SettlementFabricProgram, probe: SettlementFabricPlan,
		room_id: StringName, room: WarrenRoomStamp, parent_unit: FabricUnit,
		face_cells: Array[Vector3i], room_seams: Array[StringName],
		prior_roofs: Array[FabricUnit],
		fixed_feature_units: Array[FabricUnit], unit_by_room: Dictionary,
		unit_by_private_cell: Dictionary) -> Dictionary:
	## Cover the exposed part of a compound crown with construction typed by the
	## finished topology, and return it as ONE transaction:
	## `{units, failure}` with an empty unit list when any part of the shape
	## has no module, exactly like `_terminal_macro_cap_fallback` beside it.
	##
	## The exposed cells are sorted once by (y, z, x). Private faces accept only
	## exact 3 m x 1.5 m authored gable halves; cells carrying an explicit
	## PUBLIC_FLOOR accept only structural deck backing. A candidate may cover
	## several cells only when every covered face has the same type. The first
	## exact-footprint candidate is placed at yaw 0 before yaw 1, with no repair,
	## scaling, or coordinate-specific exception. A mixed crown is therefore
	## partitioned by its own sealed face claims rather than by a crown-wide flag.
	##
	## Every tile is a REAL roof unit -- its own bearing bond onto the parent
	## room's own per-cell top socket, its own seams, and its faces counted in
	## `realized_roof_face_count` by the caller -- so a tiled crown satisfies
	## the same source-face identity a slab does.
	if face_cells.is_empty():
		return {"units": [] as Array[FabricUnit],
			"failure": "no exposed plate to tile"}
	var pending: Dictionary = {}
	for cell: Vector3i in face_cells:
		pending[cell] = true
	var order: Array[Vector3i] = []
	order.assign(face_cells)
	order.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		if a.y != b.y:
			return a.y < b.y
		return a.z < b.z if a.z != b.z else a.x < b.x)
	var tiles: Array[FabricUnit] = []
	var public_faces: Dictionary = {}
	var public_face_count := 0
	for face: Vector3i in face_cells:
		var air_cell := face + Vector3i.UP
		var floor_claim := source.grid.face_claim(air_cell, Vector3i.DOWN)
		public_faces[face] = source.grid.use_at(air_cell) \
			== WarrenSpatialGrid.Use.PUBLIC_AIR \
			and int(floor_claim.get("kind", -1)) \
				== WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR
		public_face_count += int(bool(public_faces[face]))
	# A private one-cell-deep remainder is roofed with exact 3 m x 1.5 m halves
	# of the authored compact gable. The source plate decides the exact cells;
	# the district decides only its palette, and both outward gable ends remain
	# finite measured alternatives. Public cells instead receive only the
	# structural plank backing required by their own already-sealed PUBLIC_FLOOR.
	# The vocabularies coexist in one transaction so a mixed crown is partitioned
	# by its typed faces; one public cell can never turn its private neighbours
	# into an unguarded board platform.
	var tile_recipes: Array[StringName] = []
	tile_recipes.assign(FLAT_PLATE_TILE_RECIPES)
	var theme := _architectural_roof_theme(room.lattice_origin,
		source.world_seed)
	var family := "orange" if theme == &"orange" else "blue"
	var side_phase := posmod(Helper._mix64(source.world_seed \
		^ String(room.stable_id).hash()), 2)
	for length_cells in [6, 4, 2]:
		for side_offset in 2:
			var side := "positive" \
				if (side_phase + side_offset) % 2 == 1 else "negative"
			tile_recipes.append(StringName(
				"roof.partial.gable.%s.%d.%s" % [family,
					length_cells, side]))
	for length_cells in [6, 4, 2, 1]:
		tile_recipes.append(StringName("roof.setback.cap.%d" % length_cells))
	for anchor: Vector3i in order:
		if not pending.has(anchor):
			continue
		var placed := false
		for recipe_id: StringName in tile_recipes:
			var recipe := program.recipe(recipe_id)
			if recipe == null:
				continue
			for yaw in 2:
				var footprint := _tile_footprint(recipe, yaw)
				if footprint.is_empty():
					continue
				var minimum := footprint[0] as Vector3i
				for local_cell: Vector3i in footprint:
					minimum = Vector3i(mini(minimum.x, local_cell.x), 0,
						mini(minimum.z, local_cell.z))
				# The module's own cells sit one band ABOVE the faces they
				# close, which is where every roof unit in this file stands.
				var origin := anchor + Vector3i.UP - minimum
				var covered: Array[Vector3i] = []
				var fits := true
				for local_cell: Vector3i in footprint:
					var face := local_cell + origin + Vector3i.DOWN
					fits = fits and pending.has(face)
					covered.append(face)
				var is_public_cap := String(recipe_id).begins_with(
					"roof.setback.cap.")
				var is_private_gable := String(recipe_id).begins_with(
					"roof.partial.gable.")
				for covered_face: Vector3i in covered:
					var face_is_public := bool(public_faces.get(covered_face, false))
					fits = fits and (face_is_public if is_public_cap \
						else not face_is_public if is_private_gable else false)
				if not fits:
					continue
				var parent_local := _inverse_cell(origin + Vector3i.DOWN,
					room.lattice_origin, room.yaw_quarters)
				var seam_roofs: Array[FabricUnit] = []
				seam_roofs.assign(prior_roofs)
				seam_roofs.append_array(tiles)
				var tile := FabricUnit.new(
					StringName("spatial.roof.%s.tile%02d" % [room_id,
						tiles.size()]), recipe_id, origin, yaw,
					[parent_unit.stable_id] as Array[StringName],
					[FabricUnit.bond(&"bearing.bottom", parent_unit.stable_id,
						SettlementFabricProgram._bearing_cell_socket_id(
							&"top", parent_local.x, parent_local.z))] \
						as Array[Dictionary], &"",
					_roof_seams_for_candidate(room_seams,
						parent_unit.stable_id, seam_roofs,
						fixed_feature_units))
				_append_shallow_prior_roof_seams(tile, room_seams, seam_roofs,
					program)
				_append_shallow_room_seams(tile, _setback_wall_room_ids(
					covered, unit_by_private_cell), unit_by_room,
					unit_by_private_cell, program)
				var public_terrace_backing := String(recipe_id).begins_with(
					"roof.setback.cap.")
				if not public_terrace_backing \
						and _unit_touches_public_air(source.grid, tile, recipe):
					continue
				for face: Vector3i in covered:
					pending.erase(face)
				tiles.append(tile)
				placed = true
				break
			if placed:
				break
		if not placed:
			return {"units": [] as Array[FabricUnit],
				"failure": ("no topology-typed roof module fits the plate at %s " \
					+ "(public faces=%d; source faces=%s; pending=%s)") % [
					anchor, public_face_count, face_cells, pending.keys()]}
	# The loop only ever leaves the sweep by covering the anchor or by
	# returning, so an uncovered cell here would mean a module reported a
	# footprint it did not claim -- the one way this could silently under-roof
	# a crown and still satisfy the caller's face identity.
	assert(pending.is_empty())
	# SettlementFabricPlan admits one unit at a time and cannot roll a set
	# back, so the whole tiling is proved on its own rebuilt probe before any
	# of it reaches the authoritative one.
	var fit := _roof_units_fit_probe(program, probe.units, tiles)
	if not bool(fit.get("fits", false)):
		return {"units": [] as Array[FabricUnit],
			"failure": String(fit.get("failure", "plate tiling rejected"))}
	return {"units": tiles}


static func _tile_footprint(recipe: FabricRecipe, yaw: int) -> Array[Vector3i]:
	## The cells one flat module really occupies at this yaw, taken from the
	## recipe rather than from a table: the authored thin plank cap claims its
	## strip as OCCLUDER cells only (it is a weather face, not mass), while
	## every `roof.flat.*` slab claims the same cells as solid.
	var out: Array[Vector3i] = []
	var seen: Dictionary = {}
	var local_cells: Array[Vector3i] = recipe.solid_cells \
		if not recipe.solid_cells.is_empty() else recipe.occluder_cells
	for local_cell: Vector3i in local_cells:
		var rotated := FabricRecipe.transform_cell(local_cell, Vector3i.ZERO,
			yaw)
		if seen.has(rotated):
			continue
		seen[rotated] = true
		out.append(rotated)
	return out


static func _terminal_macro_cap_fallback(source: WarrenSpatialPlan,
		program: SettlementFabricProgram, probe: SettlementFabricPlan,
		face_cells: Array[Vector3i], row_index: int, room_id: StringName,
		room: WarrenRoomStamp, parent_unit: FabricUnit,
		base_seams: Array[StringName], neighbor_room_unit_ids: Array[StringName],
		unit_by_room: Dictionary, unit_by_private_cell: Dictionary,
		prior_roofs: Array[FabricUnit], roof_room_id_by_face: Dictionary) \
		-> Dictionary:
	## Replace one colliding macro gable with a complete, lossless set of native
	## exact-footprint gable halves. These are the same clipped compact tile roofs
	## used by partial private crowns, not the former window-canopy/shed asset that
	## read as a board pasted over a wall. Every strip has two finite handed ends;
	## the complete combination set is measured atomically, so a neighboring room
	## selects a clean party seam without a coordinate or seed-specific repair.
	## Small flat full-room closures and broad plain strips remain forbidden: both
	## reproduce the detached modular lids that this fallback exists to remove.
	var rows := _terminal_cap_rows(face_cells)
	if rows.is_empty():
		return {"units": [] as Array[FabricUnit],
			"failure": "macro face set has no terminal strip partition"}
	var candidate_failure := "terminal gable transaction rejected"
	var transaction_failures := PackedStringArray()
	for side_mask in range(0, 1 << rows.size()):
		var candidates: Array[FabricUnit] = []
		candidate_failure = ""
		for strip_index in rows.size():
			var strip := rows[strip_index] as Array[Vector3i]
			var cap := _cap_placement(source.grid, strip, room,
				source.world_seed)
			if cap.is_empty():
				candidate_failure = "no native cap placement for terminal strip %d" \
					% strip_index
				break
			var roof_join := _setback_lean_to_placement(source, strip, room,
				cap, unit_by_private_cell)
			if roof_join.is_empty():
				roof_join = _setback_roof_join_placement(source, strip, room,
					cap, roof_room_id_by_face)
			var gable := _partial_gable_placement(strip, room,
				source.world_seed, cap, roof_join,
				-1 if (side_mask & (1 << strip_index)) == 0 else 1)
			if gable.is_empty():
				candidate_failure = "terminal strip %d has no exact partial gable" \
					% strip_index
				break
			cap = gable
			var seams: Array[StringName] = []
			seams.assign(base_seams)
			var upper_id := StringName(cap.get("upper_room_unit_id", &""))
			if not upper_id.is_empty() and not seams.has(upper_id):
				seams.append(upper_id)
			for upper_id_value: Variant in cap.get(
					"upper_room_unit_ids", []) as Array:
				var one_upper_id := StringName(upper_id_value)
				if not one_upper_id.is_empty() and not seams.has(one_upper_id):
					seams.append(one_upper_id)
			var roof_seam_room_id := StringName(cap.get(
				"roof_seam_room_id", &""))
			if not roof_seam_room_id.is_empty():
				for prior_roof: FabricUnit in prior_roofs:
					if String(prior_roof.stable_id).begins_with(
							"spatial.roof.%s" % roof_seam_room_id) \
							and not seams.has(prior_roof.stable_id):
						seams.append(prior_roof.stable_id)
			for earlier: FabricUnit in candidates:
				if not seams.has(earlier.stable_id):
					seams.append(earlier.stable_id)
			seams = _unique_sorted_names(seams)
			var unit := _cap_unit(room_id, row_index, room, parent_unit, cap,
				seams, "terminal%02d" % strip_index)
			_append_shallow_prior_roof_seams(unit, neighbor_room_unit_ids,
				prior_roofs, program)
			var shallow_room_ids: Array[StringName] = []
			shallow_room_ids.assign(neighbor_room_unit_ids)
			shallow_room_ids.append_array(_setback_wall_room_ids(strip,
				unit_by_private_cell))
			_append_shallow_room_seams(unit,
				_unique_sorted_names(shallow_room_ids),
				unit_by_room, unit_by_private_cell, program)
			var recipe := program.recipe(unit.recipe_id)
			if recipe == null or _unit_touches_public_air(source.grid, unit,
					recipe):
				candidate_failure = ("terminal strip %d enters public air or " \
					+ "lacks recipe %s") % [strip_index, unit.recipe_id]
				break
			candidates.append(unit)
		if not candidate_failure.is_empty():
			transaction_failures.append("mask%d: %s" % [side_mask,
				candidate_failure])
			continue
		var fit := _roof_units_fit_probe(program, probe.units, candidates)
		if bool(fit.get("fits", false)):
			return {"units": candidates}
		candidate_failure = String(fit.get("failure",
			"terminal gable transaction rejected"))
		transaction_failures.append("mask%d: %s" % [side_mask,
			candidate_failure])
	return {"units": [] as Array[FabricUnit],
		"failure": "; ".join(transaction_failures)}


static func _roof_units_fit_probe(program: SettlementFabricProgram,
		existing_units: Array[FabricUnit], candidates: Array[FabricUnit]) \
		-> Dictionary:
	## SettlementFabricPlan has transactional single-unit admission but not a
	## multi-unit rollback. Rebuild this rare fallback's small CPU-only probe so a
	## partial terminal roof can never leak into the authoritative transaction.
	var trial := SettlementFabricPlan.new(&"spatial.terminal-roof-probe")
	for recipe: FabricRecipe in program.recipes():
		if not trial.register_recipe(recipe):
			return {"fits": false, "failure": "could not register recipe %s" \
				% recipe.recipe_id}
	for existing: FabricUnit in existing_units:
		if not trial.add_unit(existing):
			return {"fits": false, "failure": "could not rebuild existing unit %s: %s" \
				% [existing.stable_id, trial.last_rejection]}
	for candidate: FabricUnit in candidates:
		if not trial.add_unit(candidate):
			return {"fits": false, "failure": trial.last_rejection}
	return {"fits": true}


static func _setback_lean_to_placement(source: WarrenSpatialPlan,
		face_cells: Array[Vector3i], room: WarrenRoomStamp,
		cap: Dictionary, unit_by_private_cell: Dictionary) -> Dictionary:
	## A lean-to is legal only where a complete long edge of the cap meets a
	## continuing upper room. A strip with both long edges completely bounded is
	## the typed narrow roof-trench case: one measured slope bridges the recess and
	## declares both upper walls as seams. Partial contacts and one-cell caps remain
	## invalid; they cannot be hidden by decoration.
	if source == null or face_cells.size() not in [2, 4, 6] \
			or cap.is_empty():
		return {}
	var origin := cap.origin as Vector3i
	var yaw := int(cap.yaw_quarters)
	var room_ids_by_side: Dictionary = {}
	for side in [-1, 1]:
		var side_room_ids: Dictionary = {}
		var complete := true
		for local_x in face_cells.size():
			var row_cell := FabricRecipe.transform_cell(
				Vector3i(local_x, 0, 0), origin, yaw)
			var side_direction := FabricRecipe.transform_direction(
				Vector3i(0, 0, side), yaw)
			var upper_neighbor := row_cell + Vector3i.UP + side_direction
			if source.grid.use_at(upper_neighbor) \
					!= WarrenSpatialGrid.Use.PRIVATE_VOLUME:
				complete = false
				break
			var room_unit_id := StringName(unit_by_private_cell.get(
				upper_neighbor, &""))
			if room_unit_id.is_empty():
				complete = false
				break
			side_room_ids[room_unit_id] = true
		if complete and not side_room_ids.is_empty():
			var exact_ids: Array[StringName] = []
			exact_ids.assign(side_room_ids.keys())
			room_ids_by_side[side] = _unique_sorted_names(exact_ids)
	if room_ids_by_side.size() not in [1, 2]:
		return {}
	var wall_sides: Array = room_ids_by_side.keys()
	wall_sides.sort()
	var wall_side := int(wall_sides[posmod(Helper._mix64(source.world_seed \
		^ String(room.stable_id).hash()), wall_sides.size())])
	var upper_room_unit_ids: Array[StringName] = []
	for side_value: Variant in room_ids_by_side.values():
		for room_id_value: Variant in side_value as Array:
			upper_room_unit_ids.append(StringName(room_id_value))
	upper_room_unit_ids = _unique_sorted_names(upper_room_unit_ids)
	var theme := _architectural_roof_theme(room.lattice_origin,
		source.world_seed)
	var family := "orange" if theme == &"orange" else "blue"
	return {
		"recipe_id": StringName("roof.setback.lean.%s.%d.%s" % [family,
			face_cells.size(), "negative" if wall_side < 0 else "positive"]),
		"origin": origin,
		"yaw_quarters": yaw,
		"anchor_face": cap.anchor_face,
		"upper_room_unit_id": upper_room_unit_ids[0],
		"upper_room_unit_ids": upper_room_unit_ids,
	}


static func _setback_roof_join_placement(source: WarrenSpatialPlan,
		face_cells: Array[Vector3i], room: WarrenRoomStamp,
		cap: Dictionary, roof_room_id_by_face: Dictionary) -> Dictionary:
	## A narrow lower roof may die into one complete neighboring roof edge at the
	## same band. This is the orthogonal roof-to-roof counterpart of the wall-bound
	## lean-to. Every cell along one long edge must meet roof faces owned by one
	## room; corner touches, partial contacts, and two-sided valleys remain invalid.
	if source == null or face_cells.size() not in [2, 4, 6] \
			or cap.is_empty():
		return {}
	var origin := cap.origin as Vector3i
	var yaw := int(cap.yaw_quarters)
	var neighbor_by_side: Dictionary = {}
	for side in [-1, 1]:
		var neighbor_ids: Dictionary = {}
		var complete := true
		for local_x in face_cells.size():
			var row_cell := FabricRecipe.transform_cell(
				Vector3i(local_x, 0, 0), origin, yaw) - Vector3i.UP
			var side_direction := FabricRecipe.transform_direction(
				Vector3i(0, 0, side), yaw)
			var neighbor_face := row_cell + side_direction
			var neighbor_id := StringName(roof_room_id_by_face.get(
				neighbor_face, &""))
			if neighbor_id.is_empty() or neighbor_id == room.stable_id:
				complete = false
				break
			neighbor_ids[neighbor_id] = true
		if complete and neighbor_ids.size() == 1:
			neighbor_by_side[side] = StringName(neighbor_ids.keys()[0])
	if neighbor_by_side.size() != 1:
		return {}
	var wall_side := int(neighbor_by_side.keys()[0])
	var theme := _architectural_roof_theme(room.lattice_origin,
		source.world_seed)
	var family := "orange" if theme == &"orange" else "blue"
	return {
		"recipe_id": StringName("roof.setback.lean.%s.%d.%s" % [family,
			face_cells.size(), "negative" if wall_side < 0 else "positive"]),
		"origin": origin,
		"yaw_quarters": yaw,
		"anchor_face": cap.anchor_face,
		"roof_seam_room_id": neighbor_by_side[wall_side],
	}


static func _setback_shed_placement(face_cells: Array[Vector3i],
		room: WarrenRoomStamp, world_seed: int, cap: Dictionary,
		join_hint: Dictionary = {}) -> Dictionary:
	## Close the exact one-cell-deep shoulder with the 1.55 m authored shed mesh,
	## not the old 3 m half-gable. A typed wall/roof join supplies the drainage
	## direction and its seam IDs. Open shoulders choose a stable direction, and
	## the measured transaction may retry the opposite orientation.
	if face_cells.size() not in [2, 4, 6] or cap.is_empty():
		return {}
	var theme := _architectural_roof_theme(room.lattice_origin, world_seed)
	var family := "orange" if theme == &"orange" else "blue"
	var side := "negative"
	var hinted_recipe := String(join_hint.get("recipe_id", &""))
	if hinted_recipe.ends_with("positive"):
		side = "positive"
	elif not hinted_recipe.ends_with("negative") \
			and posmod(Helper._mix64(world_seed \
				^ String(room.stable_id).hash() \
				^ (cap.anchor_face as Vector3i).x * 73856093 \
				^ (cap.anchor_face as Vector3i).z * 19349663), 2) == 1:
		side = "positive"
	var out := cap.duplicate(true)
	out["recipe_id"] = StringName("roof.setback.shed.%s.%d.%s" % [
		family, face_cells.size(), side])
	for key: String in ["upper_room_unit_id", "upper_room_unit_ids",
			"roof_seam_room_id"]:
		if join_hint.has(key):
			out[key] = join_hint[key]
	return out


static func _partial_gable_placement(face_cells: Array[Vector3i],
		room: WarrenRoomStamp, world_seed: int, cap: Dictionary,
		join_hint: Dictionary = {}, forced_side: int = 0) -> Dictionary:
	## Exact private-weather counterpart of `_setback_shed_placement`. The cap
	## supplies the strip's construction transform; the finite recipe supplies a
	## real clipped compact gable at native scale. `forced_side` lets the atomic
	## terminal transaction measure both handed party seams.
	if face_cells.size() not in [2, 4, 6] or cap.is_empty() \
			or forced_side not in [-1, 0, 1]:
		return {}
	var theme := _architectural_roof_theme(room.lattice_origin, world_seed)
	var family := "orange" if theme == &"orange" else "blue"
	var side := forced_side
	var hinted_recipe := String(join_hint.get("recipe_id", &""))
	if side == 0:
		side = 1 if hinted_recipe.ends_with("positive") else -1
		if not hinted_recipe.ends_with("positive") \
				and not hinted_recipe.ends_with("negative") \
				and posmod(Helper._mix64(world_seed \
					^ String(room.stable_id).hash() \
					^ (cap.anchor_face as Vector3i).x * 73856093 \
					^ (cap.anchor_face as Vector3i).z * 19349663), 2) == 1:
			side = 1
	var out := cap.duplicate(true)
	out["recipe_id"] = StringName("roof.partial.gable.%s.%d.%s" % [
		family, face_cells.size(), "negative" if side < 0 else "positive"])
	for key: String in ["upper_room_unit_id", "upper_room_unit_ids",
			"roof_seam_room_id"]:
		if join_hint.has(key):
			out[key] = join_hint[key]
	return out


static func _setback_gable_placement(piece: Dictionary,
		room: WarrenRoomStamp, world_seed: int) -> Dictionary:
	## A rectangular island inside a compound shoulder is a small complete house
	## crown, not a collection of deck tiles. Its exact stamp origin/yaw chooses
	## one of the ordinary measured pitched-roof recipes. It does not declare
	## neighboring upper rooms as visual seams: if the measured eave clips one,
	## the common transaction must select the plain or complete flat fallback.
	if StringName(piece.get("kind", &"")) != &"stamp":
		return {}
	var kind := StringName(piece.get("room_kind", &""))
	var origin := piece.get("origin", Vector3i.ZERO) as Vector3i
	var yaw := int(piece.get("yaw_quarters", 0))
	var cells := piece.get("cells", []) as Array[Vector3i]
	if cells.is_empty() or kind not in WarrenRoomStamp.KINDS:
		return {}
	origin.y = cells[0].y + 1
	var theme := _architectural_roof_theme(origin, world_seed)
	var family := "orange" if theme == &"orange" else "blue"
	var detail := posmod(Helper._mix64(world_seed ^ String(room.stable_id).hash()
		^ origin.x * 73856093 ^ origin.y * 83492791 ^ origin.z * 19349663), 4)
	var recipe_id: StringName
	match kind:
		&"tower":
			recipe_id = StringName("roof.tower.%s.dormer.%s" % [family,
				"left" if detail % 2 == 0 else "right"])
		&"slim":
			recipe_id = StringName("roof.slim.%s.dormer.%s" % [family,
				"left" if detail % 2 == 0 else "right"])
		&"row":
			recipe_id = StringName("roof.row.%s.dormer.%s" % [family,
				"left" if detail % 2 == 0 else "right"])
		&"building":
			recipe_id = StringName("roof.square.%s.dormer.%s" % [family,
				"left" if detail % 2 == 0 else "right"])
		&"long":
			recipe_id = StringName("roof.long.%s.dormer.%s%s" % [family,
				"pair." if detail >= 2 else "",
				"left" if detail % 2 == 0 else "right"])
		_:
			return {}
	return {"recipe_id": recipe_id, "origin": origin,
		"yaw_quarters": yaw, "anchor_face": origin - Vector3i.UP}


static func _room_bears_on_retained_stone(source: WarrenSpatialPlan,
		program: SettlementFabricProgram, room: WarrenRoomStamp,
		feature_portal_mask: int) -> bool:
	## TASK C5 RULING 2. A house stacked on a flat roof rests on the slab that
	## closes the parcel below it -- the authored one-band `roof.flat.*` unit
	## and the retained stone parapet above it -- and the parent's own top ROOM
	## stops one or two bands lower, so there is no socket down there to meet.
	## Structurally this is a room standing on a complete bearing plate,
	## exactly like a room standing on ground, and it is compiled as one: a
	## `base.*` recipe (no bearing parent) and no bond. Ruling 4 is what keeps
	## it out of STONE -- see `_room_recipe_id`.
	##
	## One statement of the decision, because the mandatory-shell pre-pass
	## (`_required_room_clearance`) and the selection loop must never disagree
	## about which recipe a room is required to take.
	return not room.terrain_bearing \
		and _bears_on_retained_stone(source.grid, room) \
		and program.recipe(_room_recipe_id(room, source.world_seed, true,
			feature_portal_mask, true)) != null


static func _room_recipe_id(room: WarrenRoomStamp, world_seed: int,
		allow_phase_b: bool = true, feature_portal_mask: int = 0,
		on_retained_stone: bool = false, chosen_material: bool = false,
		low_base_lineages: Dictionary = {},
		stone_base_lineages: Dictionary = {}) -> StringName:
	## TASK H1. `chosen_material` separates the shell a room RESERVES from the
	## shell it WEARS, and only `compile_room_units` -- the one pass that decides
	## what the town is built of -- passes `true`.
	##
	## Every other caller (the volumetric solver's composition preflight and
	## residual packing, the feature solver's balcony and skywalk siting, this
	## file's own `_required_room_clearance`) asks this question to reserve
	## SPACE, and a material choice may not reshuffle a bounded town search --
	## the reason `_preserve_lpfv_prefab_clearance` exists. The authored masonry
	## modules measure up to 3.085 m across and the authored timber modules
	## exactly 3.000 m, so a ground storey that changes family shrinks its
	## clearance box by up to 0.085 m. Left honest, that shrink admitted a
	## balcony the sealed plan had refused and moved the grid signature of a town
	## whose massing this task must not touch. With `chosen_material` false every
	## such caller keeps reserving the WIDEST shell the room could take, which is
	## the masonry one; the compiler then builds inside that reservation. Over-
	## reserving is always safe. Under-reserving is what is not.
	##
	## `low_base_lineages` is the datum half of the same decision and is read
	## only when `chosen_material` is true, which is why it can be a plain
	## default: no reservation caller needs it, and passing it nowhere else
	## keeps this a pure function of the stamp for all of them. See
	## `_low_base_lineages`.
	if not (room.audit.get("bridge_support_room_ids", []) as Array).is_empty():
		# A street-bridge room keeps its ordinary unaddressed shell but swaps
		# the bearing contract: normally two flank parents through span sockets;
		# the reviewed one-bay jetty uses one exact flank plus its separately
		# reserved measured bracket course.
		var bridge_theme := _architectural_district_theme(room.lattice_origin,
			world_seed)
		var bridge_family := "jetty" if bool(room.audit.get(
			"bridge_is_bracketed_jetty", false)) else "bridge"
		return StringName("room.%s.%s.%s" % [bridge_family,
			"slim" if room.kind == &"slim" else "tower",
			"orange" if bridge_theme == &"orange" else "blue"])
	var prefix := "room.long" if room.kind == &"long" \
		else "room.slim" if room.kind == &"slim" \
		else "room.row" if room.kind == &"row" \
		else "room.tower" if room.kind == &"tower" else "room"
	if room.terrain_bearing or on_retained_stone:
		# TASK C5 RULING 4 -- the stone base is a PLOT fact. A ground storey
		# that really stands on rock or terrain is built of rock; a house
		# standing on ANOTHER HOUSE's slab takes the same complete
		# no-bearing-parent `base.*` shell in its own district's timber
		# palette, because what carries it is that house, not the mountain.
		# `on_retained_stone` is false on every legacy stamp, so the rock
		# branch is byte-identical.
		#
		# TASK H1. Standing on rock is what LETS a ground storey be masonry; it
		# is no longer what MAKES it. Every terrain-bearing room used to take
		# `base.rock`, and since terrain bearing is "storey 0 with no stack
		# parent" that was two thirds of every town's room units in ashlar --
		# the fortress the user rejected. The choice is now two facts about the
		# BUILDING, never about the wall: `_takes_stone_base` (a seeded
		# minority) and `_low_base_lineages` (its ground storey really stands at
		# street level). Both answer once per lineage, so a house that does wear
		# a masonry ground storey wears it on every one of its ground rooms and
		# the rest are plank and plaster to the pavement. What a mason would
		# still build in stone regardless is untouched by this lever and reaches
		# the frame through its own channels: the retained massif skin
		# (`SettlementFabricAssembler.maze_stone_walls`), the retaining courses,
		# and the authored foundation plinth every house stands on
		# (`SettlementFabricAssembler.house_plinth_walls`).
		var takes_stone := stone_base_lineages.has(room.source_parcel_id) \
			if chosen_material and stone_base_lineages.has(
				STONE_BASE_SELECTION_MARKER) \
			else _takes_stone_base(room, world_seed)
		var base_theme := "rock" if room.terrain_bearing \
				and (not chosen_material \
					or takes_stone \
						and bool(low_base_lineages.get(room.source_parcel_id,
							true))) \
			else String(_architectural_district_theme(room.lattice_origin,
				world_seed))
		var terrain_recipe := StringName("%s.base.%s%s" % [prefix, base_theme,
			"" if room.addressed else ".closed"])
		if room.addressed:
			terrain_recipe = SettlementFabricProgram.address_door_phase_recipe_id(
				terrain_recipe, room.address_door_phase)
		return SettlementFabricProgram.feature_portal_recipe_id(terrain_recipe,
			feature_portal_mask) if feature_portal_mask > 0 else terrain_recipe
	var theme := String(_architectural_district_theme(room.lattice_origin,
		world_seed))
	# TASK H1. No upper storey the town WEARS is ever stone. What stood here was
	# a 1-in-6 "masonry plinth accent" on storeys 0-1 hashed on the room's own
	# LATTICE COLUMN rather than on its building -- so it landed on part of a
	# facade and not on the rest of it, which is exactly the fragmented base the
	# user named. Upper walls are plank and plaster; the ground storey decides
	# its own material once per lineage above. The accent survives as the
	# RESERVED shell only, for the reason `chosen_material` documents: the
	# masonry module is the wider of the two and every space reservation in the
	# pipeline was measured against it.
	if not chosen_material and room.source_storey_index <= 1 \
			and posmod(Helper._mix64(world_seed \
				^ room.lattice_origin.x * 73856093 \
				^ room.lattice_origin.z * 19349663 ^ 0x4d41534f4e5259), 6) == 0:
		theme = "stone"
	var addressed := ".address" if room.addressed else ""
	# Alternate complete facade recipes by storey. The phase-B vocabulary uses a
	# different authored module arrangement plus measured ivy, laundry, or sign
	# projections; its clearance envelope participates in the same compiler
	# transaction, so a detail is kept only when the dense 3D fabric really has
	# room for it. Hashing the horizontal slot prevents every neighboring stack
	# from changing phase on the same floor.
	var phase_b := allow_phase_b and posmod(room.source_storey_index \
		+ room.lattice_origin.x \
		+ room.lattice_origin.z + world_seed, 2) == 1
	var facade_phase := _building_style_index(room, world_seed) * 2 \
		+ int(phase_b)
	var base_recipe_id: StringName
	if room.kind == &"long":
		base_recipe_id = StringName("%s.upper%s.%s.%s" % [prefix, addressed, theme,
			SettlementFabricProgram._facade_phase_suffix(facade_phase, true)])
	else:
		base_recipe_id = StringName("%s.upper%s.%s%s" % [prefix, addressed, theme,
			SettlementFabricProgram._facade_phase_suffix(facade_phase)])
	if room.addressed:
		base_recipe_id = SettlementFabricProgram.address_door_phase_recipe_id(
			base_recipe_id, room.address_door_phase)
	return SettlementFabricProgram.feature_portal_recipe_id(base_recipe_id,
		feature_portal_mask) if feature_portal_mask > 0 else base_recipe_id


static func _low_base_lineages(source: WarrenSpatialPlan,
		rooms: Array[WarrenRoomStamp]) -> Dictionary:
	## TASK H1. STONE LOW. `{lineage id: its ground storey really stands at
	## street level}`, over every terrain-bearing room the town has.
	##
	## The seeded minority in `_takes_stone_base` decides WHICH houses may wear
	## masonry; this decides which houses are entitled to be asked. On a terraced
	## massif a house can be terrain-bearing -- rooted in the mountain, storey 0,
	## no stack parent -- and still stand many bands above the nearest public
	## floor its datum radius can find. Clad that in ashlar and it reads as a
	## keep on a crag, which is the fortress the user rejected however small its
	## share of the town. A lineage qualifies only when EVERY one of its ground
	## rooms sits within `WALL_BASE_BAND_OFFSET` of its own local street datum:
	## one decision per house, as coherent as the material choice it gates.
	##
	## The datum is `WarrenMazeSourcePlan.nearest_datum_band` -- the same
	## machinery `maze_stone_band_profile` and `exterior_wall_material_profile`
	## read, never a second derivation -- so "how much stone" and "how high the
	## stone stands" cannot disagree about where the ground is.
	##
	## Empty, meaning EVERY lineage qualifies, on a plan with no maze source: a
	## legacy town has no massif to be terraced against and its behaviour must
	## not depend on a datum that does not exist.
	var out: Dictionary = {}
	if source == null or source.source_volume == null:
		return out
	var maze_source := source.source_volume.mass_context.get(
		&"maze_source_plan") as WarrenMazeSourcePlan
	if maze_source == null or maze_source.massif == null:
		return out
	var candidates_by_column: Dictionary = {}
	for room: WarrenRoomStamp in rooms:
		if not room.terrain_bearing:
			continue
		var column := Vector2i(_macro_of(room.lattice_origin.x),
			_macro_of(room.lattice_origin.z))
		var low := true
		if maze_source.massif.has_column(column):
			if not candidates_by_column.has(column):
				candidates_by_column[column] = \
					maze_source.public_datum_candidates(column)
			low = room.lattice_origin.y \
				- WarrenMazeSourcePlan.nearest_datum_band(
					candidates_by_column[column] as Dictionary,
					room.lattice_origin.y,
					maze_source.massif.base_at(column)) \
				<= WALL_BASE_BAND_OFFSET
		out[room.source_parcel_id] = low \
			and bool(out.get(room.source_parcel_id, true))
	return out


static func _bounded_stone_base_lineages(source: WarrenSpatialPlan,
		rooms: Array[WarrenRoomStamp], low_base_lineages: Dictionary) -> Dictionary:
	## Select the hashed masonry candidates as whole lineages, then stop before
	## their visible lateral faces exceed the town-wide target. A fixed modulus
	## alone is not a visual bound: one candidate can own two faces in one town
	## and a third of every street-facing base in another.
	var selected: Dictionary = {}
	if source == null or source.grid == null or source.source_volume == null \
			or not source.source_volume.mass_context.has(&"maze_source_plan"):
		return selected
	selected[STONE_BASE_SELECTION_MARKER] = true
	var total_faces := 0
	var candidate_faces: Dictionary = {}
	for room: WarrenRoomStamp in rooms:
		var lineage := room.source_parcel_id
		var candidate := room.terrain_bearing \
			and bool(low_base_lineages.get(lineage, true)) \
			and _takes_stone_base(room, source.world_seed)
		for cell: Vector3i in room.private_cells:
			for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
					Vector3i.FORWARD, Vector3i.BACK]:
				if not EXTERIOR_WALL_NEIGHBOUR_USES.has(int(
						source.grid.use_at(cell + direction))):
					continue
				total_faces += 1
				if candidate:
					candidate_faces[lineage] = int(
						candidate_faces.get(lineage, 0)) + 1
	var candidates: Array[StringName] = []
	candidates.assign(candidate_faces.keys())
	candidates.sort_custom(func(a: StringName, b: StringName) -> bool:
		var rank_a := Helper._mix64(source.world_seed ^ String(a).hash() \
			^ 0x53544f4e45424153)
		var rank_b := Helper._mix64(source.world_seed ^ String(b).hash() \
			^ 0x53544f4e45424153)
		return rank_a < rank_b if rank_a != rank_b else String(a) < String(b))
	var budget := floori(float(total_faces) * STONE_BASE_FACE_RATIO_TARGET)
	var used := 0
	for lineage: StringName in candidates:
		var faces := int(candidate_faces[lineage])
		if used + faces > budget:
			continue
		selected[lineage] = true
		used += faces
	return selected


static func _takes_stone_base(room: WarrenRoomStamp,
		world_seed: int) -> bool:
	## TASK H1. Does this building's GROUND STOREY wear masonry?
	##
	## Keyed on the building lineage exactly as `_building_style_index` is, and
	## for the same reason: a material is a property of a house, not of a wall.
	## Every terrain-bearing room of one lineage answers the same way whatever
	## band, footprint kind or district it sits in, so a stone base runs the
	## whole length of that building's face and stops at its neighbour's seam --
	## coherent by construction rather than by a downstream repair pass. Two
	## neighbouring buildings may differ; that is a seam, not a fragment, and
	## `exterior_wall_material_profile` scores the difference accordingly.
	##
	## One lineage in `STONE_BASE_LINEAGE_MODULUS` takes it. The rest are plank
	## and plaster down to their plinth course, which is the reference frame's
	## reading: most houses timber to the pavement, some with a full masonry
	## ground storey.
	return posmod(Helper._mix64(world_seed \
		^ String(room.source_parcel_id).hash() ^ 0x53544f4e45424153),
		STONE_BASE_LINEAGE_MODULUS) == 0


static func _building_style_index(room: WarrenRoomStamp,
		world_seed: int) -> int:
	## One segment footprint chooses among complete authored construction
	## families by building lineage, not by streaming chunk or individual wall.
	## A stepped/tapered stack therefore keeps the same joinery vocabulary through
	## every storey even when its footprint kind changes higher up.
	var lineage_hash := String(room.source_parcel_id).hash()
	return posmod(Helper._mix64(world_seed ^ lineage_hash \
		^ 0x4255494c44494e47), SettlementFabricProgram.BUILDING_STYLE_COUNT)


static func _full_roof_recipe_id(room: WarrenRoomStamp,
		world_seed: int) -> StringName:
	var district_theme := _architectural_roof_theme(room.lattice_origin,
		world_seed)
	var orange := district_theme == &"orange"
	var theme := "orange" if orange else "blue"
	if room.kind == &"tower":
		if room.source_storey_index == 0:
			return StringName("roof.tower.short.%s" % theme)
		if room.roof_feature in [1, 2]:
			return StringName("roof.tower.%s.dormer.%s" % [theme,
				"left" if room.roof_feature == 1 else "right"])
		return StringName("roof.tower.chimney.%s" % theme) \
			if room.roof_feature == 3 else StringName("roof.tower.%s" % theme)
	if room.kind == &"slim":
		if room.source_storey_index == 0:
			return StringName("roof.slim.short.%s" % theme)
		if room.roof_feature in [1, 2]:
			return StringName("roof.slim.%s.dormer.%s" % [theme,
				"left" if room.roof_feature == 1 else "right"])
		return StringName("roof.slim.chimney.%s" % theme) \
			if room.roof_feature == 3 else StringName("roof.slim.%s" % theme)
	if room.kind == &"row":
		if room.source_storey_index == 0:
			return StringName("roof.row.short.%s" % theme)
		if room.roof_feature in [1, 2]:
			return StringName("roof.row.%s.dormer.%s" % [theme,
				"left" if room.roof_feature == 1 else "right"])
		return StringName("roof.row.chimney.%s" % theme) \
			if room.roof_feature == 3 else StringName("roof.row.%s" % theme)
	if room.kind == &"long":
		var feature := room.roof_feature
		if feature in [1, 2, 4, 5]:
			return StringName("roof.long.%s.dormer.%s%s" % [theme,
				"pair." if feature in [4, 5] else "",
				"left" if feature in [1, 4] else "right"])
		return StringName("roof.long.%s" % theme)
	if room.roof_feature in [1, 2]:
		return StringName("roof.square.%s.dormer.%s" % [theme,
			"left" if room.roof_feature == 1 else "right"])
	if room.roof_feature == 3:
		return &"roof.square.04" if orange else &"roof.square.blue.plain"
	# The complete boarded shell remains an authored chimney variant, but the
	# ordinary cool square roof should actually read blue. Routing every
	# non-orange square through the boarded LPFV shell was the main source of the
	# orange/brown roof sea despite the nominal 50/50 palette hash.
	return &"roof.square.01" if orange else &"roof.square.blue.plain"


static func _terminal_tight_gable_recipe_ids(room: WarrenRoomStamp,
		world_seed: int) -> Array[StringName]:
	## A complete room plate may only close with a complete pitched envelope.
	## The `terminal.step` and `terminal.profile` recipes are shallow seam pieces
	## assembled from facade/window canopies; admitting them here made a strip of
	## boards satisfy the semantic roof obligation for an entire house.  Those
	## pieces remain vocabulary for explicit junction trim, but they can never be
	## selected as a room's final roof.  If the measured full gable does not fit,
	## the caller must choose the already-supported flat structural cap or reject
	## the neighborhood transaction.
	var out: Array[StringName] = []
	if room == null or room.kind not in [&"tower", &"slim", &"row",
			&"building", &"long"]:
		return out
	var preferred := _full_roof_recipe_id(room, world_seed)
	var family := "orange" if _roof_recipe_family(preferred) == &"orange" \
		else "blue"
	out.append(StringName("roof.terminal.tight.%s.%s" % [room.kind, family]))
	return out


static func architectural_district_theme(origin: Vector3i,
		world_seed: int) -> StringName:
	## TASK I2. The district palette, in public. `SettlementFabricAssembler`
	## clads exposed mass faces in the timber family of the district they stand
	## in, so a fake storey and the real house across the alley are the same
	## authored wall vocabulary. It is the compiler's own field and not a second
	## one: this is a one-line delegation to the private function every room
	## recipe already goes through, so the two can never disagree.
	return _architectural_district_theme(origin, world_seed)


static func _architectural_district_theme(origin: Vector3i,
		world_seed: int) -> StringName:
	var owner := _architectural_district_owner(origin, world_seed)
	var phase := posmod(Helper._mix64(world_seed ^ owner.x * 73856093 \
		^ owner.y * 19349663 ^ 0x50414c45545445), 8)
	# Half the districts are blue, one quarter orange, and one quarter amber.
	# Amber facades also take cool roofs, deliberately offsetting the compact
	# tower vocabulary whose two honest authored roofs are both orange.
	return &"blue" if phase < 4 else &"orange" if phase < 6 else &"amber"


static func _architectural_roof_theme(origin: Vector3i,
		world_seed: int) -> StringName:
	## Roof material is a coherent district field of its own, not a lossy map
	## from three facade families onto two tiled roof families. The same jittered
	## owner keeps neighboring/equal-height campaigns joined; a separate salt and
	## an exact half split stop amber facades from making three quarters of the
	## skyline blue.
	var owner := _architectural_district_owner(origin, world_seed)
	var phase := posmod(Helper._mix64(world_seed ^ owner.x * 83492791 \
		^ owner.y * 2971215073 ^ 0x524f4f4650414c), 2)
	return &"blue" if phase == 0 else &"orange"


static func _architectural_district_owner(origin: Vector3i,
		world_seed: int) -> Vector2i:
	var base := Vector2i(
		floori(float(origin.x) / float(ARCHITECTURAL_DISTRICT_CELLS)),
		floori(float(origin.z) / float(ARCHITECTURAL_DISTRICT_CELLS)))
	var best_owner := base
	var best_distance := 9223372036854775807
	var best_tie := 9223372036854775807
	for district_z in range(base.y - 1, base.y + 2):
		for district_x in range(base.x - 1, base.x + 2):
			var owner := Vector2i(district_x, district_z)
			var owner_hash := Helper._mix64(world_seed \
				^ district_x * 73856093 ^ district_z * 19349663 \
				^ 0x4449535452494354)
			var jitter_x := posmod(Helper._mix64(owner_hash ^ 0x584a4954544552),
				ARCHITECTURAL_DISTRICT_JITTER * 2 + 1) \
				- ARCHITECTURAL_DISTRICT_JITTER
			var jitter_z := posmod(Helper._mix64(owner_hash ^ 0x5a4a4954544552),
				ARCHITECTURAL_DISTRICT_JITTER * 2 + 1) \
				- ARCHITECTURAL_DISTRICT_JITTER
			var centre := owner * ARCHITECTURAL_DISTRICT_CELLS \
				+ Vector2i(ARCHITECTURAL_DISTRICT_CELLS / 2 + jitter_x,
					ARCHITECTURAL_DISTRICT_CELLS / 2 + jitter_z)
			var delta := Vector2i(origin.x, origin.z) - centre
			var distance := delta.x * delta.x + delta.y * delta.y
			var tie := posmod(owner_hash, 2147483647)
			if distance < best_distance \
					or distance == best_distance and tie < best_tie:
				best_owner = owner
				best_distance = distance
				best_tie = tie
	return best_owner


static func _spatial_roof_neighborhood(source: WarrenSpatialPlan,
		room_by_id: Dictionary, roof_faces_by_room: Dictionary) -> Dictionary:
	## The occupancy grid owns the exposed faces, but a roof is selected from the
	## complete neighborhood. Treating each room independently and then declaring
	## every overlap a visual seam is exactly what produced broken ridges and
	## colliding eaves in dense captures. Reuse the measured junction classifier
	## and module table that already protects the route-first vocabulary.
	var proposals: Array[Dictionary] = []
	for room_id_value: Variant in roof_faces_by_room.keys():
		var room_id := StringName(room_id_value)
		var room := room_by_id.get(room_id) as WarrenRoomStamp
		if room == null:
			continue
		# Occupied bridge and bracketed-jetty rooms carry their pitched shell in
		# the same recipe as their two-sided/one-sided support contract.  They are
		# therefore already a sealed roof neighborhood and must not enter the
		# independent roof graph that is allowed to choose terraces.
		if not (room.audit.get("bridge_support_room_ids", []) as Array).is_empty():
			continue
		var face_cells := roof_faces_by_room[room_id] as Array[Vector3i]
		if _touches_public_air(source.grid, face_cells):
			continue
		if not _is_full_roof_plate(room, face_cells):
			# Phase E: a staggered shoulder whose exposed plate is exactly one
			# authored roof footprint joins the neighborhood as a first-class
			# pitched section with typed stepped junctions against its taller
			# neighbors, instead of bypassing the atomic solve and falling to
			# per-room caps that read as floating half-roofs.
			var plate := _exact_partial_plate_proposal(room, face_cells)
			if not plate.is_empty():
				proposals.append(plate)
			continue
		proposals.append({
			"stable_id": room_id,
			"kind": room.kind,
			"origin": room.lattice_origin,
			"yaw_quarters": room.yaw_quarters,
			"storeys": 1,
			"route_y": room.lattice_origin.y,
			"roof_feature": room.roof_feature,
			"theme": &"blue",
			"ground_theme": &"blue",
			"facade_phase": 0,
		})
	if proposals.is_empty():
		return {"proposal_by_room": {}, "junction_count": 0,
			"flattened_room_count": 0}
	var topology := FabricRoofTopologyPlan.build(proposals)
	if topology == null:
		last_failure = "could not classify the spatial roof neighborhood"
		return {}
	var by_id: Dictionary = {}
	for proposal: Dictionary in proposals:
		by_id[StringName(proposal.stable_id)] = proposal
	var flattened: Dictionary = {}
	var ids: Array[StringName] = []
	ids.assign(by_id.keys())
	ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	# Reject unsupported junction pairs locally. The fallback is an authored flat
	# terrace over the exact complete room, never an intersecting pitched shell.
	for owner_id: StringName in ids:
		for seam: Dictionary in topology.fact(owner_id).junctions as Array:
			var neighbor_id := StringName(seam.neighbor_id)
			if String(owner_id) >= String(neighbor_id):
				continue
			# Production admits one atomic perpendicular T-junction: the module
			# table substitutes a bisected host roof and an open-ended branch as one
			# construction. Parallel and higher-order valleys still flatten because
			# no complete authored crossing exists for them.
			if not _spatial_roof_join_supported(int(seam.kind)):
				flattened[owner_id] = true
				flattened[neighbor_id] = true
				continue
			var pair: Array[Dictionary] = [
				(by_id[owner_id] as Dictionary).duplicate(true),
				(by_id[neighbor_id] as Dictionary).duplicate(true),
			]
			var pair_topology := FabricRoofTopologyPlan.build(pair)
			if pair_topology == null or FabricRoofJunctionModuleTable.build(
					pair, pair_topology).is_empty():
				flattened[owner_id] = true
				flattened[neighbor_id] = true
	# One authored roof can carry one atomic T-junction. A multi-valley roof is
	# explicitly outside the finite vocabulary and therefore becomes a terrace.
	for owner_id: StringName in ids:
		var perpendicular_count := 0
		for seam: Dictionary in topology.fact(owner_id).junctions as Array:
			perpendicular_count += int(int(seam.kind) \
				== FabricRoofTopologyPlan.JunctionKind.PERPENDICULAR_VALLEY)
		if perpendicular_count > 1:
			flattened[owner_id] = true
	for room_id_value: Variant in flattened.keys():
		(by_id[StringName(room_id_value)] as Dictionary)["flat_roof"] = true
	var styled_proposals: Array[Dictionary] = []
	for room_id: StringName in ids:
		styled_proposals.append(by_id[room_id] as Dictionary)
	var junction_modules := FabricRoofJunctionModuleTable.build(
		styled_proposals, topology)
	if junction_modules.is_empty():
		# A higher-order signature can still be unsupported even when each pair is
		# legal alone. Flatten only the joined roofs and rebuild once; isolated
		# pitched roofs retain their silhouette and dormers.
		for room_id: StringName in ids:
			if not (topology.fact(room_id).junctions as Array).is_empty():
				flattened[room_id] = true
				(by_id[room_id] as Dictionary)["flat_roof"] = true
		styled_proposals.clear()
		for room_id: StringName in ids:
			styled_proposals.append(by_id[room_id] as Dictionary)
		junction_modules = FabricRoofJunctionModuleTable.build(
			styled_proposals, topology)
		if junction_modules.is_empty():
			last_failure = "spatial roof neighborhood has no sealed junction treatment: %s" \
				% FabricRoofJunctionModuleTable.last_failure
			return {}
	var rules_by_id := junction_modules.rules_by_id as Dictionary
	# Equal-height neighbors form one roof campaign. A shared ridge or valley
	# cannot change tile family halfway through merely because the two rooms have
	# different stable IDs; stepped roofs may still vary independently.
	var assigned_theme: Dictionary = {}
	for start_id: StringName in ids:
		if assigned_theme.has(start_id) or flattened.has(start_id):
			continue
		var component: Array[StringName] = []
		var pending: Array[StringName] = [start_id]
		var seen: Dictionary = {start_id: true}
		while not pending.is_empty():
			var current: StringName = pending.pop_back()
			component.append(current)
			for seam: Dictionary in topology.fact(current).junctions as Array:
				var neighbor := StringName(seam.neighbor_id)
				if int(seam.height_delta) != 0 or flattened.has(neighbor) \
						or seen.has(neighbor):
					continue
				seen[neighbor] = true
				pending.append(neighbor)
		component.sort_custom(func(a: StringName, b: StringName) -> bool:
			return String(a) < String(b))
		var anchor_room := room_by_id[component[0]] as WarrenRoomStamp
		var theme := _architectural_roof_theme(anchor_room.lattice_origin,
			source.world_seed)
		var roof_theme := &"orange" if theme == &"orange" else &"blue"
		for room_id: StringName in component:
			assigned_theme[room_id] = roof_theme
	for room_id: StringName in ids:
		var proposal := by_id[room_id] as Dictionary
		if not assigned_theme.has(room_id):
			var room := room_by_id[room_id] as WarrenRoomStamp
			var theme := _architectural_roof_theme(room.lattice_origin,
				source.world_seed)
			assigned_theme[room_id] = &"orange" \
				if theme == &"orange" else &"blue"
		proposal["roof_theme"] = assigned_theme[room_id]
		var rules: Array[Dictionary] = []
		rules.assign(rules_by_id.get(room_id, []) as Array)
		proposal["roof_junction_rules"] = rules
		proposal["roof_signature"] = StringName(topology.fact(room_id).signature)
		by_id[room_id] = proposal
	return {
		"proposal_by_room": by_id,
		"junction_count": int(topology.audit.junction_count),
		"ridge_continuation_count": int(topology.audit \
			.ridge_continuation_count),
		"parallel_valley_count": int(topology.audit.parallel_valley_count),
		"perpendicular_valley_count": int(topology.audit \
			.perpendicular_valley_count),
		"flattened_room_count": flattened.size(),
	}


static func _spatial_roof_join_supported(kind: int) -> bool:
	return kind in [
		FabricRoofTopologyPlan.JunctionKind.RIDGE_CONTINUATION,
		FabricRoofTopologyPlan.JunctionKind.PERPENDICULAR_VALLEY,
		FabricRoofTopologyPlan.JunctionKind.STEPPED_EAVE_WALL,
		FabricRoofTopologyPlan.JunctionKind.STEPPED_GABLE_WALL,
	]


static func _full_roof_candidates(room: WarrenRoomStamp,
		world_seed: int, neighborhood_proposal: Dictionary = {}) \
		-> Array[Dictionary]:
	## Construction gets a finite exact alternative set before falling back to a
	## flat cap. Decorative projections are removed first. Square floorplates may
	## also turn a reviewed roof profile by 90 degrees because their semantic
	## solid set is rotation-invariant; rectangular rooms may not rotate their
	## ridge sideways. No candidate moves or scales the authored asset.
	if not neighborhood_proposal.is_empty() \
			and bool(neighborhood_proposal.get("flat_roof", false)):
		return [] as Array[Dictionary]
	if room.kind == &"tower" \
			and room.audit.has("bridge_party_roof_yaw_quarters"):
		# An endpoint of an occupied bridge is not an isolated little house: its
		# crown terminates on the bridge's typed party plane.  Select the exact
		# seam-clipped gable and its source-planned ridge axis as one candidate;
		# a generic full-eave tower roof is not a valid fallback for this role.
		var family := _roof_recipe_family(_full_roof_recipe_id(room, world_seed))
		var party_id := StringName("roof.tower.party.%s" % [
			"orange" if family == &"orange" else "blue"])
		var absolute_yaw := int(room.audit[
			"bridge_party_roof_yaw_quarters"])
		return [{"recipe_id": party_id,
			"yaw_offset": posmod(absolute_yaw - room.yaw_quarters, 4)}] \
			as Array[Dictionary]
	if not neighborhood_proposal.is_empty() \
			and not (neighborhood_proposal.get(
				"roof_junction_rules", []) as Array).is_empty():
		var roof_component: Dictionary = {}
		var trim_components: Array[Dictionary] = []
		for component: Dictionary in StaggeredFabricCompiler \
				.proposal_components(neighborhood_proposal):
			var role := StringName(component.role)
			if role == &"roof":
				roof_component = component
			elif String(role).begins_with("roof.trim."):
				var trim := component.duplicate(true)
				var neighbors: Array[StringName] = []
				for rule: Dictionary in neighborhood_proposal \
						.roof_junction_rules as Array:
					if bool(rule.get("emits_module", false)) \
							and int(rule.side) == int(component \
								.roof_junction_side):
						neighbors.append(StringName(rule.neighbor_id))
				trim["neighbor_room_ids"] = neighbors
				trim_components.append(trim)
		if not roof_component.is_empty():
			var detailed_id := StringName(roof_component.recipe_id)
			var plain_joined_id := _plain_pitched_recipe_id(detailed_id)
			# The complete undecorated shell owns the structural reservation. A
			# chimney or dormer is optional roof dressing and may be attempted only
			# after that shell has proved the neighborhood; letting the tall detail
			# commit first can consume the only crown available to a later house.
			var joined_candidates: Array[Dictionary] = [{
				"recipe_id": detailed_id,
				"yaw_offset": posmod(int(roof_component.yaw_quarters) \
					- room.yaw_quarters, 4),
				"uses_roof_neighborhood": true,
				"trim_components": trim_components,
			}] as Array[Dictionary]
			if plain_joined_id != detailed_id:
				var plain_candidate := joined_candidates[0].duplicate(true)
				plain_candidate["recipe_id"] = plain_joined_id
				joined_candidates.append(plain_candidate)
			return joined_candidates
	var preferred := _full_roof_recipe_id(room, world_seed)
	var plain := _plain_pitched_recipe_id(preferred)
	var ids: Array[StringName] = [preferred]
	if preferred != plain:
		ids.append(plain)
	# Do not squeeze a terminal room into a gap with a canopy or dormer asset
	# masquerading as a roof. Every candidate below is a measured, complete
	# tiled gable. If its eaves do not fit, the atomic construction is rejected
	# and the bounded fabric search must choose a different massing proposal.
	if room.kind == &"building":
		var modular := &"roof.square.orange.plain" \
			if _roof_recipe_family(preferred) == &"orange" \
			else &"roof.square.blue.plain"
		if not ids.has(modular):
			ids.append(modular)
	var out: Array[Dictionary] = []
	for recipe_id: StringName in ids:
		out.append({"recipe_id": recipe_id, "yaw_offset": 0})
	# Compact tower and 6 x 6 square solids are unchanged by a quarter turn. The
	# measured eave/ridge AABB is not, so this often closes a tight party-wall
	# corner that otherwise became a conspicuous flat box.
	if room.kind in [&"tower", &"building"]:
		for recipe_id: StringName in ids:
			out.append({"recipe_id": recipe_id, "yaw_offset": 1})
	return out


static func _plain_pitched_recipe_id(recipe_id: StringName) -> StringName:
	var id := String(recipe_id)
	if id.begins_with("roof.long.") and id.contains(".dormer."):
		return StringName(id.get_slice(".dormer.", 0))
	if id.begins_with("roof.slim.chimney."):
		return StringName(id.replace("roof.slim.chimney.", "roof.slim."))
	if id.begins_with("roof.row.chimney."):
		return StringName(id.replace("roof.row.chimney.", "roof.row."))
	if id.begins_with("roof.tower.chimney."):
		return StringName(id.replace("roof.tower.chimney.", "roof.tower."))
	if id.begins_with("roof.slim.short."):
		return StringName(id.replace("roof.slim.short.", "roof.slim."))
	if id.begins_with("roof.row.short."):
		return StringName(id.replace("roof.row.short.", "roof.row."))
	if id.begins_with("roof.tower.short."):
		return StringName(id.replace("roof.tower.short.", "roof.tower."))
	if id.begins_with("roof.slim.") and id.contains(".dormer."):
		return StringName(id.get_slice(".dormer.", 0))
	if id.begins_with("roof.row.") and id.contains(".dormer."):
		return StringName(id.get_slice(".dormer.", 0))
	if id.begins_with("roof.tower.") and id.contains(".dormer."):
		return StringName(id.get_slice(".dormer.", 0))
	if id.begins_with("roof.square.") and id.contains(".dormer."):
		var theme := "orange" if id.contains(".orange.") else "blue"
		return StringName("roof.square.%s.plain" % theme)
	return recipe_id


static func _room_recipe_facade_family(recipe_id: StringName) -> StringName:
	var id := String(recipe_id)
	for family: String in ["stone", "blue", "orange", "amber", "rock"]:
		if id.contains(".%s" % family):
			return StringName(family)
	return &"other"


static func _roof_recipe_family(recipe_id: StringName) -> StringName:
	var id := String(recipe_id)
	if id.contains(".orange") or id.ends_with(".01") \
			or id.ends_with(".04"):
		return &"orange"
	if id.contains(".blue"):
		return &"blue"
	return &"boarded"


static func _flat_roof_recipe_id(room: WarrenRoomStamp) -> StringName:
	return _flat_roof_recipe_id_for_kind(room.kind)


static func _flat_roof_recipe_id_for_kind(kind: StringName) -> StringName:
	if kind == &"tower":
		return &"roof.flat.tower"
	if kind == &"slim":
		return &"roof.flat.slim"
	if kind == &"row":
		return &"roof.flat.row"
	if kind == &"long":
		return &"roof.flat.long"
	return &"roof.flat.square"


static func _maze_isolated_flat_crowns(room_by_id: Dictionary,
		pitched_rooms: Array[StringName],
		flat_rooms: Array[StringName]) -> Dictionary:
	## TASK H2 PART 4 -- "boxy looking buildings that look somewhat randomly
	## distributed ... they should ideally appear in blocks."  The offender
	## pattern, counted: `{count, flat_lineages, pitched_lineages, details}`.
	##
	## The unit of the complaint is a BUILDING, not a room, so this works in
	## source lineages (`WarrenRoomStamp.source_parcel_id`, the same key
	## `_building_style_index` and H1's stone base use). A lineage is FLAT when
	## every crown it got is flat and PITCHED when every one is pitched; a
	## lineage carrying both is neither, and is counted in neither total --
	## a tall house with a pitched top and a flat shoulder is not a box.
	##
	## A lineage is ISOLATED when it is flat, it has at least one crown
	## neighbour, and every neighbouring lineage that carries a crown is
	## pitched. Neighbour means 4-adjacent CROWN COLUMNS: the columns of one
	## lineage's crown rooms, touching the columns of another's, which is what
	## the eye reads across a roofscape. A flat lineage with no crown neighbour
	## at all is a house standing on its own and is not the sprinkle defect, so
	## it does not count.
	##
	## FIX ROUND 1, MINOR 7 -- THE NEIGHBOUR READING IS APPROXIMATE WHERE
	## CROWNS STACK, and saying so is cheaper than a caveat nobody can find
	## later. `lineage_by_column` holds ONE lineage per column, so where two
	## lineages crown the same column -- a house stacked on another house's
	## shoulder, which this town does build -- the last one written wins and
	## the other is invisible to its neighbours' lookups. The count is
	## therefore a lower-ish estimate on stacked columns rather than an
	## identity, which is why it is published as a watched CEILING
	## (`ISOLATED_FLAT_CROWN_CEILING`) and not asserted against a
	## re-derivation. `columns_by_lineage` is exact -- every lineage keeps all
	## of its own columns -- so a lineage's own flat/pitched/mixed kind is
	## never affected.
	var out := {"count": 0, "flat_lineages": 0, "pitched_lineages": 0,
		"details": [] as Array[Dictionary]}
	var kinds: Dictionary = {}
	var columns_by_lineage: Dictionary = {}
	var lineage_by_column: Dictionary = {}
	for entry: Dictionary in [{"rooms": pitched_rooms, "kind": &"pitched"},
			{"rooms": flat_rooms, "kind": &"flat"}]:
		for room_id: StringName in entry.rooms as Array[StringName]:
			var room := room_by_id.get(room_id) as WarrenRoomStamp
			if room == null:
				continue
			var lineage := room.source_parcel_id
			var seen := kinds.get(lineage, &"") as StringName
			kinds[lineage] = StringName(entry.kind) if seen.is_empty() \
				else (seen if seen == StringName(entry.kind) else &"mixed")
			if not columns_by_lineage.has(lineage):
				columns_by_lineage[lineage] = {}
			var columns := columns_by_lineage[lineage] as Dictionary
			for cell: Vector3i in room.private_cells:
				if cell.y != room.lattice_origin.y + 1:
					continue
				var column := Vector2i(cell.x, cell.z)
				columns[column] = true
				lineage_by_column[column] = lineage
	var lineages: Array[StringName] = []
	lineages.assign(kinds.keys())
	lineages.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	for lineage: StringName in lineages:
		var kind := kinds[lineage] as StringName
		out["flat_lineages"] = int(out.flat_lineages) + int(kind == &"flat")
		out["pitched_lineages"] = int(out.pitched_lineages) \
			+ int(kind == &"pitched")
		if kind != &"flat":
			continue
		var neighbours: Dictionary = {}
		for column_value: Variant in (columns_by_lineage[
				lineage] as Dictionary).keys():
			for direction: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT,
					Vector2i.UP, Vector2i.DOWN]:
				var neighbour := lineage_by_column.get(
					(column_value as Vector2i) + direction, &"") as StringName
				if neighbour.is_empty() or neighbour == lineage:
					continue
				neighbours[neighbour] = true
		if neighbours.is_empty():
			continue
		var all_pitched := true
		for neighbour_value: Variant in neighbours.keys():
			all_pitched = all_pitched \
				and kinds.get(neighbour_value, &"") == &"pitched"
		if not all_pitched:
			continue
		out["count"] = int(out.count) + 1
		if (out.details as Array[Dictionary]).size() < 8:
			(out.details as Array[Dictionary]).append({
				"lineage": lineage, "pitched_neighbours": neighbours.size()})
	return out


static func _maze_crown_dressing_candidates(room: WarrenRoomStamp,
		world_seed: int, slab_id: StringName) -> Array[StringName]:
	## TASK H2 PART 3 -- what this surviving terrace is offered, richest first.
	##
	## The seeded tier (`CROWN_DRESSING_TIERS`) picks where the crown ENTERS
	## the authored garden chain; the tail of the chain is the fallback, so a
	## crown whose rich accent measures into the storey jettied over it takes
	## the plain planter and then the flower rather than nothing. A bare tier
	## returns an EMPTY list -- the crown is deliberately undressed and does
	## not fall back into being dressed, which is what keeps the distribution
	## a distribution.
	##
	## The four `.micro.N` variants are corner offsets of one flower clump, and
	## the same room hash chooses among them, so two neighbouring bare-ish
	## terraces do not put their flower in the same corner.
	var phase := posmod(Helper._mix64(world_seed \
		^ String(room.stable_id).hash() ^ 0x43524f574e), 64)
	var tier := CROWN_DRESSING_TIERS[phase % CROWN_DRESSING_TIERS.size()]
	if tier.is_empty():
		return [] as Array[StringName]
	var base := "%s.garden" % String(slab_id)
	var micro := StringName("%s.micro.%d" % [base, (phase / 8) % 4])
	if tier == &"rich":
		return [StringName("%s.rich" % base), StringName(base),
			micro] as Array[StringName]
	if tier == &"plain":
		return [StringName(base), micro] as Array[StringName]
	return [micro] as Array[StringName]


static func _flat_roof_terrace_candidates(room: WarrenRoomStamp,
		world_seed: int) -> Array[StringName]:
	var base := String(_flat_roof_recipe_id(room))
	var sides: Array[StringName] = [&"north", &"east", &"south", &"west"]
	var phase := posmod(Helper._mix64(world_seed \
		^ String(room.stable_id).hash()), sides.size())
	var out: Array[StringName] = []
	for offset in sides.size():
		var side := sides[(phase + offset) % sides.size()]
		out.append(StringName("%s.terrace.%s.lived" % [base, side]))
		out.append(StringName("%s.terrace.%s" % [base, side]))
	return out


static func _roof_faces_by_room(source: WarrenSpatialPlan,
		room_id_by_cell: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for region: WarrenConstructionRegion in source.construction_plan \
			.regions_for_kind(WarrenSpatialGrid.FaceKind.ROOF):
		for cell: Vector3i in region.face_cells:
			var room_id := StringName(room_id_by_cell.get(cell, &""))
			if room_id.is_empty():
				continue
			if not out.has(room_id):
				out[room_id] = [] as Array[Vector3i]
			(out[room_id] as Array[Vector3i]).append(cell)
	return out


static func _is_full_roof_plate(room: WarrenRoomStamp,
		face_cells: Array[Vector3i]) -> bool:
	var top_count := 0
	for cell: Vector3i in room.private_cells:
		top_count += int(cell.y == room.lattice_origin.y + 1)
	return face_cells.size() == top_count


static func _exact_partial_plate_proposal(room: WarrenRoomStamp,
		face_cells: Array[Vector3i]) -> Dictionary:
	## A partial exposed plate participates in the roof neighborhood only when
	## it is exactly one authored roof footprint: the pitched shell then covers
	## the complete exposed region and the junction classifier owns every
	## contact. Irregular remainders keep the finite setback-cap vocabulary.
	if face_cells.is_empty():
		return {}
	var top_band := room.lattice_origin.y + 1
	var minimum := face_cells[0]
	var maximum := face_cells[0]
	for cell: Vector3i in face_cells:
		if cell.y != top_band:
			return {}
		minimum = Vector3i(mini(minimum.x, cell.x), top_band,
			mini(minimum.z, cell.z))
		maximum = Vector3i(maxi(maximum.x, cell.x), top_band,
			maxi(maximum.z, cell.z))
	var dims := Vector2i(maximum.x - minimum.x + 1, maximum.z - minimum.z + 1)
	if dims.x * dims.y != face_cells.size():
		return {}
	var kind := &""
	if dims == Vector2i(2, 2):
		kind = &"tower"
	elif dims == Vector2i(2, 4) or dims == Vector2i(4, 2):
		kind = &"slim"
	elif dims == Vector2i(4, 4):
		kind = &"building"
	elif dims == Vector2i(4, 6) or dims == Vector2i(6, 4):
		kind = &"long"
	else:
		return {}
	var plate_columns: Dictionary = {}
	for cell: Vector3i in face_cells:
		plate_columns[Vector2i(cell.x, cell.z)] = true
	# Keep the room's own yaw when the footprint allows it so facade cadence and
	# ridge orientation stay coherent; otherwise take the first quarter turn
	# that lands the authored centered footprint exactly on the plate.
	for yaw_offset in 4:
		var yaw := posmod(room.yaw_quarters + yaw_offset, 4)
		var zero_columns: Dictionary = {}
		var zero_minimum := Vector2i(2147483647, 2147483647)
		for cell: Vector3i in StaggeredFabricCompiler.proposal_occupied_cells({
				"kind": kind, "origin": Vector3i.ZERO, "yaw_quarters": yaw,
				"storeys": 1}):
			if cell.y != 0:
				continue
			var column := Vector2i(cell.x, cell.z)
			zero_columns[column] = true
			zero_minimum = Vector2i(mini(zero_minimum.x, column.x),
				mini(zero_minimum.y, column.y))
		var shift := Vector2i(minimum.x, minimum.z) - zero_minimum
		var matched := zero_columns.size() == plate_columns.size()
		for column_value: Variant in zero_columns.keys():
			matched = matched \
				and plate_columns.has(column_value as Vector2i + shift)
		if not matched:
			continue
		return {
			"stable_id": room.stable_id,
			"kind": kind,
			"origin": Vector3i(shift.x, room.lattice_origin.y, shift.y),
			"yaw_quarters": yaw,
			"storeys": 1,
			"route_y": room.lattice_origin.y,
			"roof_feature": 0,
			"theme": &"blue",
			"ground_theme": &"blue",
			"facade_phase": 0,
			"partial_plate": true,
		}
	return {}


static func _plate_roof_candidates(neighborhood_proposal: Dictionary) \
		-> Array[Dictionary]:
	## Mirror of the joined branch of _full_roof_candidates for admitted partial
	## plates: the exact roof and trim components come from the plate proposal
	## itself, so the pitched section lands on the plate rather than assuming
	## the room's complete footprint.
	var out: Array[Dictionary] = []
	if neighborhood_proposal.is_empty() \
			or bool(neighborhood_proposal.get("flat_roof", false)):
		return out
	var junction_rules := neighborhood_proposal.get(
		"roof_junction_rules", []) as Array
	var roof_component: Dictionary = {}
	var trim_components: Array[Dictionary] = []
	for component: Dictionary in StaggeredFabricCompiler \
			.proposal_components(neighborhood_proposal):
		var role := StringName(component.role)
		if role == &"roof":
			roof_component = component
		elif String(role).begins_with("roof.trim."):
			var trim := component.duplicate(true)
			var neighbors: Array[StringName] = []
			for rule: Dictionary in junction_rules:
				if bool(rule.get("emits_module", false)) \
						and int(rule.side) == int(component.roof_junction_side):
					neighbors.append(StringName(rule.neighbor_id))
			trim["neighbor_room_ids"] = neighbors
			trim_components.append(trim)
	if roof_component.is_empty():
		return out
	out.append({
		"recipe_id": StringName(roof_component.recipe_id),
		"yaw_offset": 0,
		"uses_roof_neighborhood": not junction_rules.is_empty(),
		"trim_components": trim_components,
	})
	var plain_id := _plain_pitched_recipe_id(
		StringName(roof_component.recipe_id))
	if plain_id != StringName(roof_component.recipe_id):
		var plain := (out[0] as Dictionary).duplicate(true)
		plain["recipe_id"] = plain_id
		out.append(plain)
	return out


static func _plate_roof_unit(room_id: StringName, room: WarrenRoomStamp,
		parent_unit: FabricUnit, recipe_id: StringName,
		plate_proposal: Dictionary, seams: Array[StringName]) -> FabricUnit:
	## The plate shell bears on the exact room top cell under its centered
	## bearing.bottom socket, exactly like a setback cap, so the strict mutual
	## socket-adjacency proof holds at the offset placement.
	var plate_origin := plate_proposal.origin as Vector3i
	var anchor_face := plate_origin + Vector3i.UP
	var parent_local := _inverse_cell(anchor_face, room.lattice_origin,
		room.yaw_quarters)
	return FabricUnit.new(StringName("spatial.roof.%s" % room_id), recipe_id,
		plate_origin + Vector3i.UP * WarrenSpatialGrid.STOREY_CELLS,
		int(plate_proposal.yaw_quarters),
		[parent_unit.stable_id] as Array[StringName],
		[FabricUnit.bond(&"bearing.bottom", parent_unit.stable_id,
			SettlementFabricProgram._bearing_cell_socket_id(&"top",
				parent_local.x, parent_local.z))] as Array[Dictionary],
		&"", seams)


static func _touches_public_air(grid: WarrenSpatialGrid,
		face_cells: Array[Vector3i]) -> bool:
	for cell: Vector3i in face_cells:
		if grid.use_at(cell + Vector3i.UP) == WarrenSpatialGrid.Use.PUBLIC_AIR:
			return true
	return false


static func _unit_touches_public_air(grid: WarrenSpatialGrid,
		unit: FabricUnit, recipe: FabricRecipe) -> bool:
	return not _unit_public_air_conflicts(grid, unit, recipe).is_empty()


static func _unit_public_air_conflicts(grid: WarrenSpatialGrid,
		unit: FabricUnit, recipe: FabricRecipe) -> Array[Vector3i]:
	## A pitched or staggered roof may occupy two or more lattice bands even when
	## the first band immediately over its source face is clear. Elevated streets
	## and galleries reserve their complete 3D headroom, so test both the
	## candidate's semantic solid volume and every collidable authored placement.
	## Rooms use both. Roof recipes deliberately use the measured collidable
	## placements only: their lattice `solid_cells` classify bearing/occlusion and
	## conservatively fill a complete 1.5 m band, while the actual pitched shell
	## occupies only part of it. Treating that coarse classification as player
	## collision rejects a safe gable above a lane and previously forced the
	## generator toward fake canopy roofs. The measured roof collider remains the
	## authoritative headroom proof, including its real eaves.
	var conflicts: Dictionary = {}
	if not recipe.has_tag(&"roof"):
		for local_cell: Vector3i in recipe.solid_cells:
			var world_cell := FabricRecipe.transform_cell(local_cell,
				unit.lattice_origin, unit.yaw_quarters)
			if grid.use_at(world_cell) == WarrenSpatialGrid.Use.PUBLIC_AIR:
				conflicts[world_cell] = true
	var unit_transform := unit.transform()
	for index in recipe.placement_bounds.size():
		if index >= recipe.placement_collision_pieces.size() \
				or recipe.placement_collision_pieces[index] <= 0:
			continue
		var box: AABB = unit_transform * recipe.placement_bounds[index]
		for cell: Vector3i in _box_public_air_conflicts(grid, box):
			conflicts[cell] = true
	var out: Array[Vector3i] = []
	out.assign(conflicts.keys())
	out.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		if a.y != b.y:
			return a.y < b.y
		if a.z != b.z:
			return a.z < b.z
		return a.x < b.x)
	return out


static func _box_touches_public_air(grid: WarrenSpatialGrid,
		box: AABB) -> bool:
	return not _box_public_air_conflicts(grid, box).is_empty()


static func _box_public_air_conflicts(grid: WarrenSpatialGrid,
		box: AABB) -> Array[Vector3i]:
	## Fine-grid X/Z coordinates name cell centres; Y names the public floor.
	## `PUBLIC_AIR` is a topological ownership fact: the carver reserves complete
	## 1.5 m bands so later structural transactions cannot fill a passage. It is
	## deliberately more conservative than the continuous finished space a body
	## needs. Intersecting a roof with every whole air band therefore rejects a
	## legitimate gable beginning at the 3 m storey seam and pressures generation
	## toward fake plank crowns.
	##
	## The downward PUBLIC_FLOOR face is the exact source of a walk datum. Test the
	## authored collider against one continuous clearance prism rising from that
	## datum instead. Its height and radius come from the same canonical traversal
	## contract as the live character. A higher street automatically raises this
	## prism, so a roof may never solve the problem by passing through an elevated
	## lane; a roof at 3 m over a ground-level lane remains legal by construction.
	var out: Array[Vector3i] = []
	if grid == null or not box.has_volume():
		return out
	var half := FabricRecipe.CELL_SIZE * 0.5
	var epsilon := 0.0001
	var low_x := floori((box.position.x + half) / FabricRecipe.CELL_SIZE)
	var low_z := floori((box.position.z + half) / FabricRecipe.CELL_SIZE)
	var high_x := floori((box.end.x + half - epsilon) \
		/ FabricRecipe.CELL_SIZE)
	var high_z := floori((box.end.z + half - epsilon) \
		/ FabricRecipe.CELL_SIZE)
	# Only floors whose continuous clearance interval can meet the box are
	# candidates. The extra lower band is harmless at a grid edge and preserves
	# exact discovery when the box bottom lies on a lattice boundary.
	var low_y := floori((box.position.y - TraversalEnvelope.MIN_HEADROOM) \
		/ FabricRecipe.CELL_SIZE) - 1
	var high_y := floori((box.end.y - epsilon) / FabricRecipe.CELL_SIZE)
	for y in range(low_y, high_y + 1):
		for z in range(low_z, high_z + 1):
			for x in range(low_x, high_x + 1):
				var cell := Vector3i(x, y, z)
				if grid.use_at(cell) != WarrenSpatialGrid.Use.PUBLIC_AIR:
					continue
				var floor_claim := grid.face_claim(cell, Vector3i.DOWN)
				if floor_claim.is_empty() or int(floor_claim.get("kind", -1)) \
						!= WarrenSpatialGrid.FaceKind.PUBLIC_FLOOR:
					continue
				var clearance_box := TraversalEnvelope.clearance_prism(cell,
					FabricRecipe.CELL_SIZE)
				if _boxes_share_volume(box, clearance_box):
					out.append(cell)
	return out


static func _cap_placement(grid: WarrenSpatialGrid,
		face_cells: Array[Vector3i], room: WarrenRoomStamp,
		world_seed: int) -> Dictionary:
	if face_cells.size() not in [1, 2, 4, 6]:
		return {}
	var targets: Dictionary = {}
	for cell: Vector3i in face_cells:
		targets[cell + Vector3i.UP] = true
	for yaw in 4:
		for anchor_face: Vector3i in face_cells:
			var target_anchor := anchor_face + Vector3i.UP
			var local_anchor := FabricRecipe.transform_cell(Vector3i.ZERO,
				Vector3i.ZERO, yaw)
			var origin := target_anchor - local_anchor
			var visible: Dictionary = {}
			for x in face_cells.size():
				visible[FabricRecipe.transform_cell(Vector3i(x, 0, 0),
					origin, yaw)] = true
			if not _same_cell_set(visible, targets):
				continue
			var recipe_id := StringName("roof.setback.cap.%d" \
				% face_cells.size())
			# Exposed shoulders remain roofs, not circulation. The former railing
			# treatment silently promoted every collision-free shelf to a balcony even
			# though no door, stair, or path reached it. A measured central garden can
			# enrich the cap without making a false accessibility claim; the separate
			# balcony/court solvers own all genuine exterior occupied floors.
			if String(recipe_id).begins_with("roof.setback.cap.") \
					and face_cells.size() >= 2 \
					and posmod(Helper._mix64(world_seed \
						^ String(room.stable_id).hash() ^ anchor_face.x * 53 \
						^ anchor_face.y * 97 ^ anchor_face.z * 193), 3) != 0:
				recipe_id = StringName("roof.setback.garden.%d" \
					% face_cells.size())
			return {"recipe_id": recipe_id, "origin": origin,
				"yaw_quarters": yaw, "anchor_face": anchor_face}
	return {}


static func _cap_pieces(face_cells: Array[Vector3i]) -> Array[Dictionary]:
	## Losslessly partition an arbitrary exposed plate into the largest complete
	## room-shaped roofs first, then finite native strips. This is the compiler's
	## macroscopic replacement pass: a 2x2 or 2x4 cluster becomes a recognisable
	## gabled house crown rather than four/eight visible voxel caps.
	var remaining: Dictionary = {}
	for cell: Vector3i in face_cells:
		remaining[cell] = true
	var out: Array[Dictionary] = []
	var y := face_cells[0].y if not face_cells.is_empty() else 0
	# Several recognizable crowns may share an irregular shoulder, but only
	# when they cannot touch: each additional stamp must keep at least one
	# clear strip cell (Chebyshev distance two) from every accepted crown, so
	# no sibling-gable valley can form and hide inside the parent's broad seam
	# exception — the modular roof pile seen in close review. Touching-crown
	# neighborhoods stay a future typed-valley transaction, not an overlap
	# waiver. Largest kinds are still tried first and the residual remains
	# terminal rows, so the planner's admitted compound grammar holds.
	var crown_cells: Dictionary = {}
	var crown_count := 0
	# TASK F2. The crown search below asks "does this authored stamp fit the
	# remaining plate" for 3 x 5 kinds x every remaining cell x 4 yaws x a 7 x 7
	# origin halo, and it used to derive the whole stamp -- an array of up to 48
	# transformed cells -- for every one of those probes. Only the cells in the
	# plate's own band can ever be in `top`, and the stamp at any origin is the
	# stamp at origin zero TRANSLATED (see `FabricRecipe.transform_cell`), so
	# each (kind, yaw) needs its band-zero offsets exactly once. Same offsets,
	# same order, so `top` and the first refusing cell are unchanged.
	var kinds: Array[StringName] = [&"long", &"building", &"slim", &"row",
		&"tower"]
	var band_offsets: Array[Array] = []
	for kind_index in kinds.size():
		var per_yaw: Array = []
		for yaw in 4:
			var band: Array[Vector3i] = []
			for offset: Vector3i in WarrenRoomStamp.expected_private_cells(
					kinds[kind_index], Vector3i.ZERO, yaw):
				if offset.y == 0:
					band.append(offset)
			per_yaw.append(band)
		band_offsets.append(per_yaw)
	while crown_count < 3:
		var found_macro := false
		# `remaining` cannot change while the kind loop runs -- the only write
		# to it sets `found_macro`, which breaks straight out -- so the ordered
		# anchor list is derived once per sweep instead of once per kind.
		var ordered: Array[Vector3i] = []
		ordered.assign(remaining.keys())
		ordered.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
			return a.z < b.z if a.z != b.z else a.x < b.x)
		for kind_index in kinds.size():
			var kind := kinds[kind_index]
			if found_macro:
				break
			for anchor: Vector3i in ordered:
				for yaw in 4:
					var offsets := band_offsets[kind_index][yaw] \
						as Array[Vector3i]
					# Search a small origin halo around the first occupied cell;
					# exact set containment is the authority, not this anchor
					# phase.
					for x in range(anchor.x - 3, anchor.x + 4):
						for z in range(anchor.z - 3, anchor.z + 4):
							var origin := Vector3i(x, y, z)
							var top: Array[Vector3i] = []
							var fits := true
							for offset: Vector3i in offsets:
								var cell := offset + origin
								top.append(cell)
								if not remaining.has(cell):
									fits = false
									break
							if fits and not top.is_empty() and crown_count > 0:
								for cell: Vector3i in top:
									for z_offset in range(-1, 2):
										for x_offset in range(-1, 2):
											if crown_cells.has(cell + Vector3i(
													x_offset, 0, z_offset)):
												fits = false
												break
										if not fits:
											break
									if not fits:
										break
							if not fits or top.is_empty():
								continue
							out.append({"kind": &"stamp", "room_kind": kind,
								"origin": origin, "yaw_quarters": yaw,
								"cells": top})
							for cell: Vector3i in top:
								remaining.erase(cell)
								crown_cells[cell] = true
							found_macro = true
							break
						if found_macro:
							break
					if found_macro:
						break
				if found_macro:
					break
		if not found_macro:
			break
		crown_count += 1
	while not remaining.is_empty():
		var ordered: Array[Vector3i] = []
		ordered.assign(remaining.keys())
		ordered.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
			if a.y != b.y:
				return a.y < b.y
			if a.z != b.z:
				return a.z < b.z
			return a.x < b.x)
		var start: Vector3i = ordered[0]
		var chosen: Array[Vector3i] = []
		for length: int in [6, 4, 2, 1]:
			for direction: Vector3i in [Vector3i.RIGHT, Vector3i.BACK]:
				var candidate: Array[Vector3i] = []
				var fits := true
				for offset: int in length:
					var cell: Vector3i = start + direction * offset
					if not remaining.has(cell):
						fits = false
						break
					candidate.append(cell)
				if fits:
					chosen = candidate
					break
			if not chosen.is_empty():
				break
		if chosen.is_empty():
			return [] as Array[Dictionary]
		out.append({"kind": &"row", "cells": chosen})
		for cell: Vector3i in chosen:
			remaining.erase(cell)
	return out


static func _cap_rows(face_cells: Array[Vector3i]) -> Array[Array]:
	## Compatibility helper for focused tests and diagnostics that only need the
	## terminal strip partition. Production uses `_cap_pieces` above.
	var out: Array[Array] = []
	for piece: Dictionary in _cap_pieces(face_cells):
		out.append(piece.cells as Array[Vector3i])
	return out


static func _terminal_cap_rows(face_cells: Array[Vector3i]) \
		-> Array[Array]:
	## Strip-only form used for conservative pre-reservation and as the conceptual
	## final fallback for a macro roof. It never recursively extracts another
	## gable, so callers can reason about a finite native closure.
	var remaining: Dictionary = {}
	for cell: Vector3i in face_cells:
		remaining[cell] = true
	var out: Array[Array] = []
	while not remaining.is_empty():
		var ordered: Array[Vector3i] = []
		ordered.assign(remaining.keys())
		ordered.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
			if a.y != b.y:
				return a.y < b.y
			if a.z != b.z:
				return a.z < b.z
			return a.x < b.x)
		var start := ordered[0] as Vector3i
		var chosen: Array[Vector3i] = []
		for length: int in [6, 4, 2, 1]:
			for direction: Vector3i in [Vector3i.RIGHT, Vector3i.BACK]:
				var candidate: Array[Vector3i] = []
				var fits := true
				for offset: int in length:
					var cell := start + direction * offset
					if not remaining.has(cell):
						fits = false
						break
					candidate.append(cell)
				if fits:
					chosen = candidate
					break
			if not chosen.is_empty():
				break
		if chosen.is_empty():
			return [] as Array[Array]
		out.append(chosen)
		for cell: Vector3i in chosen:
			remaining.erase(cell)
	return out


static func _roof_seams_for_candidate(room_seams: Array[StringName],
		parent_unit_id: StringName,
		prior_roofs: Array[FabricUnit],
		fixed_feature_units: Array[FabricUnit] = [],
		allow_room_overlap: bool = true) -> Array[StringName]:
	## A roof may meet a previously compiled roof only where their underlying
	## rooms share an exact party wall. Multiple native caps over one room are
	## also explicit pieces of the same authoritative roof region.
	var related_rooms: Dictionary = {parent_unit_id: true}
	for room_seam: StringName in room_seams:
		related_rooms[room_seam] = true
	var out: Array[StringName] = []
	# A pitched roof may use adjacent rooms to discover the corresponding roof
	# campaign, but it may not exempt the room volume itself from intersection
	# testing. That broad exemption let an intermediate-storey gable pass through
	# the next storey's facade. Flat structural caps retain their typed party-wall
	# seam; pitched callers pass false and must fit the final exposed envelope.
	if allow_room_overlap:
		out.append_array(room_seams)
	for feature_unit: FabricUnit in fixed_feature_units:
		var connected := feature_unit.parent_ids.has(parent_unit_id) \
			or feature_unit.visual_seam_ids.has(parent_unit_id)
		if not connected:
			for bond: Dictionary in feature_unit.socket_bonds:
				if StringName(bond.target_unit) == parent_unit_id:
					connected = true
					break
		if connected:
			out.append(feature_unit.stable_id)
	for prior: FabricUnit in prior_roofs:
		for prior_parent: StringName in prior.parent_ids:
			if related_rooms.has(prior_parent):
				out.append(prior.stable_id)
				break
	return _unique_sorted_names(out)


static func _append_explicit_roof_party_room_seams(candidate: FabricUnit,
		room: WarrenRoomStamp, unit_by_room: Dictionary) -> void:
	## Pitched roofs normally do not inherit a broad room-volume exemption: that
	## once allowed intermediate gables to pass through upper facades. A source
	## bridge endpoint is narrower and explicit. Its reversible compound names
	## the one future occupied-span room where the seam-clipped endpoint gable
	## terminates. Carry exactly that final unit id onto the roof so the plan can
	## validate the typed bridge-eave/gable lap; do not infer any seam by overlap.
	if candidate == null or room == null:
		return
	for party_room_id_value: Variant in room.audit.get(
			"roof_party_allowed_room_ids", []) as Array:
		var party_room := unit_by_room.get(StringName(
			party_room_id_value)) as FabricUnit
		if party_room != null \
				and not candidate.visual_seam_ids.has(party_room.stable_id):
			candidate.visual_seam_ids.append(party_room.stable_id)
	candidate.visual_seam_ids = _unique_sorted_names(
		candidate.visual_seam_ids)


static func _prior_roof_seams_for_neighbor_rooms(
		neighbor_room_unit_ids: Array[StringName],
		prior_roofs: Array[FabricUnit]) -> Array[StringName]:
	## A setback strip may close against a roof whose underlying room shares an
	## exact PARTY_WALL with this room.  Name only the roof unit: naming the room
	## itself would recreate the old broad exemption that let a gable eave pass
	## through the neighboring facade.
	var neighbors: Dictionary = {}
	for room_unit_id: StringName in neighbor_room_unit_ids:
		neighbors[room_unit_id] = true
	var out: Array[StringName] = []
	for prior: FabricUnit in prior_roofs:
		for parent_id: StringName in prior.parent_ids:
			if neighbors.has(parent_id):
				out.append(prior.stable_id)
				break
	return _unique_sorted_names(out)


static func _append_shallow_prior_roof_seams(candidate: FabricUnit,
		neighbor_room_unit_ids: Array[StringName],
		prior_roofs: Array[FabricUnit],
		program: SettlementFabricProgram) -> void:
	## Exact PARTY_WALL adjacency makes two roofs part of one construction, but it
	## does not excuse arbitrary interpenetration. Declare the roof-to-roof seam
	## only when the measured contact is shallow on two axes. A gable entering a
	## neighbor wall still has no relationship and remains a hard rejection.
	if candidate == null or program == null:
		return
	var candidate_recipe := program.recipe(candidate.recipe_id)
	if candidate_recipe == null:
		return
	var candidate_bounds := candidate.transform() \
		* candidate_recipe.local_clearance_bounds
	var candidate_roof_ids := _prior_roof_seams_for_neighbor_rooms(
		neighbor_room_unit_ids, prior_roofs)
	for prior: FabricUnit in prior_roofs:
		var typed_thin_cap := candidate_recipe.has_tag(&"thin_roof_face")
		var typed_shed := candidate_recipe.has_tag(&"setback_shed")
		if not typed_thin_cap \
				and not candidate_roof_ids.has(prior.stable_id):
			continue
		var prior_recipe := program.recipe(prior.recipe_id)
		if prior_recipe == null:
			continue
		var prior_bounds := prior.transform() \
			* prior_recipe.local_clearance_bounds
		var exact_pitched_edge := typed_shed \
			and candidate_roof_ids.has(prior.stable_id)
		var valid_contact := SettlementFabricPlan._is_typed_shed_roof_contact(
			candidate_bounds, prior_bounds) if exact_pitched_edge \
			else _is_shallow_flashing_contact(candidate_bounds, prior_bounds) \
				if typed_thin_cap \
			else SettlementFabricPlan._aabb_overlaps_volume(candidate_bounds,
				prior_bounds) and SettlementFabricPlan._is_edge_nick(
					candidate_bounds, prior_bounds)
		if valid_contact \
				and not candidate.visual_seam_ids.has(prior.stable_id):
			candidate.visual_seam_ids.append(prior.stable_id)
	candidate.visual_seam_ids = _unique_sorted_names(
		candidate.visual_seam_ids)


static func _setback_wall_room_ids(face_cells: Array[Vector3i],
		unit_by_private_cell: Dictionary) -> Array[StringName]:
	## The cell immediately above each authoritative roof face is the cap volume.
	## Any private cell directly across its horizontal perimeter is an exact upper
	## wall contact. A complete long-side contact may select the pitched lean-to;
	## partial sides and short ends can only receive the shallow flashing rule.
	var out: Array[StringName] = []
	if face_cells.is_empty():
		return out
	var cap_cells: Dictionary = {}
	for face: Vector3i in face_cells:
		cap_cells[face + Vector3i.UP] = true
	for cap_cell_value: Variant in cap_cells.keys():
		var cap_cell := cap_cell_value as Vector3i
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.FORWARD, Vector3i.BACK]:
			var neighbor := cap_cell + direction
			if cap_cells.has(neighbor):
				continue
			var room_unit_id := StringName(unit_by_private_cell.get(neighbor, &""))
			if not room_unit_id.is_empty() and not out.has(room_unit_id):
				out.append(room_unit_id)
	return _unique_sorted_names(out)


static func _setback_gable_end_room_ids(face_cells: Array[Vector3i],
		cap: Dictionary,
		unit_by_private_cell: Dictionary) -> Array[StringName]:
	## A complete pitched crown may terminate into a taller facade at either
	## gable end.  This is the exact T-building seam: every cell across that end
	## must meet one room at the cap's own band.  Long eaves, partial contacts,
	## mixed owners, and corner-only touches deliberately return no seam.
	var out: Array[StringName] = []
	if face_cells.is_empty() or cap.is_empty():
		return out
	var origin := cap.origin as Vector3i
	var yaw := int(cap.yaw_quarters)
	var cap_cells: Dictionary = {}
	var minimum := Vector2i(2147483647, 2147483647)
	var maximum := Vector2i(-2147483648, -2147483648)
	for face: Vector3i in face_cells:
		var cap_cell := face + Vector3i.UP
		cap_cells[cap_cell] = true
		var local := _inverse_cell(cap_cell, origin, yaw)
		minimum = minimum.min(Vector2i(local.x, local.z))
		maximum = maximum.max(Vector2i(local.x, local.z))
	if minimum.x > maximum.x or minimum.y > maximum.y:
		return out
	for side in [-1, 1]:
		var end_z := minimum.y if side < 0 else maximum.y
		var owner_id := &""
		var complete := true
		for local_x in range(minimum.x, maximum.x + 1):
			var edge_cell := FabricRecipe.transform_cell(
				Vector3i(local_x, 0, end_z), origin, yaw)
			if not cap_cells.has(edge_cell):
				complete = false
				break
			var outward := FabricRecipe.transform_direction(
				Vector3i(0, 0, side), yaw)
			var neighbor_id := StringName(unit_by_private_cell.get(
				edge_cell + outward, &""))
			if neighbor_id.is_empty() \
					or not owner_id.is_empty() and owner_id != neighbor_id:
				complete = false
				break
			owner_id = neighbor_id
		if complete and not owner_id.is_empty() and not out.has(owner_id):
			out.append(owner_id)
	return _unique_sorted_names(out)


static func _setback_complete_edge_roof_room_ids(
		face_cells: Array[Vector3i], cap: Dictionary,
		owner_room_id: StringName,
		roof_room_id_by_face: Dictionary) -> Array[StringName]:
	## Two complete pitched crowns may share one full source-face edge.  Naming
	## that exact edge is the construction fact behind a parallel valley or a
	## perpendicular T-roof; it is not inferred from their broad visual AABBs.
	## Partial edges and corner contacts remain unrelated and therefore collide.
	var out: Array[StringName] = []
	if face_cells.is_empty() or cap.is_empty():
		return out
	var origin := cap.origin as Vector3i
	var yaw := int(cap.yaw_quarters)
	var faces: Dictionary = {}
	var minimum := Vector2i(2147483647, 2147483647)
	var maximum := Vector2i(-2147483648, -2147483648)
	for face: Vector3i in face_cells:
		faces[face] = true
		var local := _inverse_cell(face + Vector3i.UP, origin, yaw)
		minimum = minimum.min(Vector2i(local.x, local.z))
		maximum = maximum.max(Vector2i(local.x, local.z))
	if minimum.x > maximum.x or minimum.y > maximum.y:
		return out
	for edge: Dictionary in [
		{"axis": &"x", "value": minimum.x, "side": -1},
		{"axis": &"x", "value": maximum.x, "side": 1},
		{"axis": &"z", "value": minimum.y, "side": -1},
		{"axis": &"z", "value": maximum.y, "side": 1},
	]:
		var neighbor_room_id := &""
		var complete := true
		var start := minimum.y if StringName(edge.axis) == &"x" else minimum.x
		var finish := maximum.y if StringName(edge.axis) == &"x" else maximum.x
		for along in range(start, finish + 1):
			var local := Vector3i(int(edge.value), 0, along) \
				if StringName(edge.axis) == &"x" \
				else Vector3i(along, 0, int(edge.value))
			var face := FabricRecipe.transform_cell(local, origin, yaw) \
				- Vector3i.UP
			if not faces.has(face):
				complete = false
				break
			var local_direction := Vector3i(int(edge.side), 0, 0) \
				if StringName(edge.axis) == &"x" \
				else Vector3i(0, 0, int(edge.side))
			var neighbor_face := face + FabricRecipe.transform_direction(
				local_direction, yaw)
			var one_neighbor := StringName(roof_room_id_by_face.get(
				neighbor_face, &""))
			if one_neighbor.is_empty() or one_neighbor == owner_room_id \
					or not neighbor_room_id.is_empty() \
						and neighbor_room_id != one_neighbor:
				complete = false
				break
			neighbor_room_id = one_neighbor
		if complete and not neighbor_room_id.is_empty() \
				and not out.has(neighbor_room_id):
			out.append(neighbor_room_id)
	return _unique_sorted_names(out)


static func _append_shallow_room_seams(candidate: FabricUnit,
		candidate_room_unit_ids: Array[StringName], unit_by_room: Dictionary,
		unit_by_private_cell: Dictionary,
		program: SettlementFabricProgram) -> void:
	## End-wall flashing is a measured shallow connection, not an envelope
	## exemption. The detailed terrace/garden remains rejected when its height
	## makes the overlap deep; the plain cap may tuck beneath the facade frame.
	if candidate == null or program == null:
		return
	var candidate_recipe := program.recipe(candidate.recipe_id)
	if candidate_recipe == null:
		return
	var candidate_bounds := candidate.transform() \
		* candidate_recipe.local_clearance_bounds
	var adjacent_room_ids: Array[StringName] = []
	adjacent_room_ids.assign(candidate_room_unit_ids)
	var candidate_solid_cells: Dictionary = {}
	var local_contact_cells: Array[Vector3i] = []
	local_contact_cells.assign(candidate_recipe.solid_cells)
	for occluder_cell: Vector3i in candidate_recipe.occluder_cells:
		if not local_contact_cells.has(occluder_cell):
			local_contact_cells.append(occluder_cell)
	for local_cell: Vector3i in local_contact_cells:
		candidate_solid_cells[FabricRecipe.transform_cell(local_cell,
			candidate.lattice_origin, candidate.yaw_quarters)] = true
	for cell_value: Variant in candidate_solid_cells.keys():
		var cell := cell_value as Vector3i
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.FORWARD, Vector3i.BACK]:
			var neighbor := cell + direction
			if candidate_solid_cells.has(neighbor):
				continue
			var room_unit_id := StringName(unit_by_private_cell.get(neighbor,
				&""))
			if not room_unit_id.is_empty() \
					and not adjacent_room_ids.has(room_unit_id):
				adjacent_room_ids.append(room_unit_id)
	# A one-cell structural setback can still be closed by an authored facade
	# projection reaching the thin cap. The lattice alone cannot name that seam,
	# so let the measured envelopes discover it below; the strict shallow-depth
	# test remains the authority and rejects a tall terrace or deep intersection.
	for room_unit_value: Variant in unit_by_room.values():
		var room_unit := room_unit_value as FabricUnit
		if room_unit != null \
				and not adjacent_room_ids.has(room_unit.stable_id):
			adjacent_room_ids.append(room_unit.stable_id)
	adjacent_room_ids = _unique_sorted_names(adjacent_room_ids)
	for room_unit_id: StringName in adjacent_room_ids:
		var room_unit := _room_unit_with_stable_id(unit_by_room, room_unit_id)
		if room_unit == null:
			continue
		var room_recipe := program.recipe(room_unit.recipe_id)
		if room_recipe == null:
			continue
		var room_bounds := room_unit.transform() \
			* room_recipe.local_clearance_bounds
		var typed_shed_wall := candidate_recipe.has_tag(&"setback_shed")
		var valid_contact := SettlementFabricPlan._is_typed_shed_wall_contact(
			candidate_bounds, room_bounds) if typed_shed_wall \
			else _is_shallow_flashing_contact(candidate_bounds, room_bounds)
		if valid_contact \
				and not candidate.visual_seam_ids.has(room_unit_id):
			candidate.visual_seam_ids.append(room_unit_id)
	candidate.visual_seam_ids = _unique_sorted_names(
		candidate.visual_seam_ids)


static func _room_unit_with_stable_id(unit_by_room: Dictionary,
		stable_unit_id: StringName) -> FabricUnit:
	for unit_value: Variant in unit_by_room.values():
		var unit := unit_value as FabricUnit
		if unit != null and unit.stable_id == stable_unit_id:
			return unit
	return null


static func _is_shallow_flashing_contact(left: AABB, right: AABB) -> bool:
	if not SettlementFabricPlan._aabb_overlaps_volume(left, right):
		return false
	var overlap := SettlementFabricPlan._overlap_size(left, right)
	return overlap.y <= SHALLOW_FLASHING_MAX_HEIGHT_M \
		and minf(overlap.x, overlap.z) <= SHALLOW_FLASHING_MAX_OVERLAP_M


static func _cap_failure_diagnostic(grid: WarrenSpatialGrid,
		face_cells: Array[Vector3i]) -> String:
	var parts := PackedStringArray()
	for face: Vector3i in face_cells:
		var above := face + Vector3i.UP
		for z in range(-1, 2):
			for x in range(-1, 2):
				var cell := above + Vector3i(x, 0, z)
				parts.append("%d:%d:%d=%d/%s" % [cell.x, cell.y, cell.z,
					grid.use_at(cell), String(grid.owner_name_at(cell))])
	parts.sort()
	return ",".join(parts)


static func _roof_room_seams(grid: WarrenSpatialGrid,
		room: WarrenRoomStamp, unit_by_private_cell: Dictionary,
		own_unit_id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for cell: Vector3i in room.private_cells:
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD, Vector3i.BACK]:
			var neighbor := cell + direction
			if not unit_by_private_cell.has(neighbor):
				continue
			var claim := grid.face_claim(cell, direction)
			var neighbor_id := StringName(unit_by_private_cell[neighbor])
			if int(claim.get("kind", -1)) \
					== WarrenSpatialGrid.FaceKind.PARTY_WALL \
					and neighbor_id != own_unit_id and not out.has(neighbor_id):
				out.append(neighbor_id)
	return _unique_sorted_names(out)


static func _same_cell_set(left: Dictionary, right: Dictionary) -> bool:
	if left.size() != right.size():
		return false
	for value: Variant in left.keys():
		if not right.has(value):
			return false
	return true


static func _unique_sorted_names(values: Array[StringName]) \
		-> Array[StringName]:
	var unique: Dictionary = {}
	for value: StringName in values:
		if not value.is_empty():
			unique[value] = true
	var out: Array[StringName] = []
	out.assign(unique.keys())
	out.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	return out


static func _recipe_stays_inside_stamp(recipe: FabricRecipe,
		room: WarrenRoomStamp) -> bool:
	var allowed: Dictionary = {}
	for cell: Vector3i in room.private_cells:
		allowed[cell] = true
	var claimed: Dictionary = {}
	for source_cells: Array[Vector3i] in [recipe.solid_cells,
			recipe.headroom_cells, recipe.inhabited_cells]:
		for local_cell: Vector3i in source_cells:
			var cell := FabricRecipe.transform_cell(local_cell,
				room.lattice_origin, room.yaw_quarters)
			if not allowed.has(cell):
				return false
			claimed[cell] = true
	return not claimed.is_empty()


static func _entrance_matches(recipe: FabricRecipe,
		room: WarrenRoomStamp) -> bool:
	if room.addressed and recipe.entrances.size() != 1:
		return false
	if not room.addressed:
		return recipe.entrances.is_empty()
	var entrance := recipe.entrances[0] as Dictionary
	return FabricRecipe.transform_cell(entrance.cell as Vector3i,
		room.lattice_origin, room.yaw_quarters) == room.threshold_cell \
		and FabricRecipe.transform_direction(entrance.facing as Vector3i,
			room.yaw_quarters) == room.frontage_direction


static func _bridge_span_bond(room: WarrenRoomStamp, recipe: FabricRecipe,
		flank_room: WarrenRoomStamp, flank_unit: FabricUnit,
		program: SettlementFabricProgram) -> Dictionary:
	## Bind one side of a street-bridge room to a flanking room: the bridge's
	## per-cell span socket must exactly meet the flank's centred cardinal
	## bearing socket — the same mutual adjacency SettlementFabricPlan
	## enforces, computed here so the unit is authored with the one true bond.
	var flank_recipe := program.recipe(flank_unit.recipe_id)
	if flank_recipe == null:
		return {}
	for socket: Dictionary in recipe.sockets:
		var own_socket_id := StringName(socket.id)
		if not String(own_socket_id).begins_with("bearing.span."):
			continue
		var own_cell := FabricRecipe.transform_cell(socket.cell as Vector3i,
			room.lattice_origin, room.yaw_quarters)
		var own_facing := FabricRecipe.transform_direction(
			socket.facing as Vector3i, room.yaw_quarters)
		for flank_name: StringName in [&"bearing.east", &"bearing.west",
				&"bearing.north", &"bearing.south"]:
			var flank_socket := flank_recipe.socket(flank_name)
			if flank_socket.is_empty():
				continue
			var flank_cell := FabricRecipe.transform_cell(
				flank_socket.cell as Vector3i, flank_room.lattice_origin,
				flank_room.yaw_quarters)
			var flank_facing := FabricRecipe.transform_direction(
				flank_socket.facing as Vector3i, flank_room.yaw_quarters)
			if own_cell + own_facing == flank_cell \
					and flank_cell + flank_facing == own_cell:
				return FabricUnit.bond(own_socket_id, flank_unit.stable_id,
					flank_name)
	return {}


static func _bearing_bond(upper: WarrenRoomStamp,
		lower: WarrenRoomStamp, lower_unit_id: StringName) -> Dictionary:
	var lower_columns: Dictionary = {}
	for cell: Vector3i in lower.private_cells:
		lower_columns[Vector2i(cell.x, cell.z)] = true
	var shared: Array[Vector2i] = []
	for cell: Vector3i in upper.private_cells:
		var column := Vector2i(cell.x, cell.z)
		if lower_columns.has(column) and not shared.has(column):
			shared.append(column)
	shared.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or a.y == b.y and a.x < b.x)
	if shared.is_empty():
		return {}
	var column := shared[0]
	var upper_world := Vector3i(column.x, upper.lattice_origin.y, column.y)
	var lower_world := Vector3i(column.x, lower.lattice_origin.y + 1, column.y)
	var upper_local := _inverse_cell(upper_world, upper.lattice_origin,
		upper.yaw_quarters)
	var lower_local := _inverse_cell(lower_world, lower.lattice_origin,
		lower.yaw_quarters)
	return FabricUnit.bond(SettlementFabricProgram._bearing_cell_socket_id(
		&"bottom", upper_local.x, upper_local.z), lower_unit_id,
		SettlementFabricProgram._bearing_cell_socket_id(&"top", lower_local.x,
		lower_local.z))


static func _bears_on_retained_stone(grid: WarrenSpatialGrid,
		room: WarrenRoomStamp) -> bool:
	## Every column of this room's floor plate rests on a cell the plot model
	## kept as STONE. That is a complete bearing plate -- the flat roof unit
	## and its parapet course are construction, and the retained rock is the
	## mountain -- so the room needs no socket bond to a lower room.
	##
	## Deliberately strict: one column short of a complete plate is a
	## cantilever, which has its own typed transaction, so this returns false
	## and the ordinary support-parent path decides.
	if grid == null:
		return false
	var columns := 0
	for cell: Vector3i in room.private_cells:
		if cell.y != room.lattice_origin.y:
			continue
		columns += 1
		var below := cell + Vector3i.DOWN
		if grid.use_at(below) != WarrenSpatialGrid.Use.STRUCTURAL_VOLUME \
				or grid.owner_name_at(below) != MAZE_RETAINED_STONE_ID:
			return false
	return columns > 0


static func _physical_support_parent(upper: WarrenRoomStamp,
		room_by_private_cell: Dictionary,
		preferred: WarrenRoomStamp) -> WarrenRoomStamp:
	## Cross-lineage recomposition is keyed by absolute 1.5 m bands. A source
	## lineage handoff remains useful ancestry, but after per-storey splitting its
	## relative storey number need not name the room directly below every overlap
	## column. Construction binds the authoritative spatial fact: the room whose
	## top cell is immediately below the upper room's bottom plate.
	var counts: Dictionary = {}
	var room_by_id: Dictionary = {}
	for cell: Vector3i in upper.private_cells:
		if cell.y != upper.lattice_origin.y:
			continue
		var candidate := room_by_private_cell.get(cell + Vector3i.DOWN) \
			as WarrenRoomStamp
		if candidate == null or candidate.stable_id == upper.stable_id:
			continue
		counts[candidate.stable_id] = int(counts.get(candidate.stable_id, 0)) + 1
		room_by_id[candidate.stable_id] = candidate
	if counts.is_empty():
		return preferred
	var ids: Array[StringName] = []
	ids.assign(counts.keys())
	ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		if int(counts[a]) != int(counts[b]):
			return int(counts[a]) > int(counts[b])
		if preferred != null and (a == preferred.stable_id) \
				!= (b == preferred.stable_id):
			return a == preferred.stable_id
		return String(a) < String(b))
	return room_by_id[ids[0]] as WarrenRoomStamp


static func _rooms_in_support_order(rooms: Array[WarrenRoomStamp],
		room_by_source_level: Dictionary,
		room_by_private_cell: Dictionary) -> Array[WarrenRoomStamp]:
	## Stable Kahn traversal of the room bearing DAG. Bridge rooms name both
	## lateral support rooms explicitly; ordinary upper rooms name the physical
	## room under their final recomposed plate. Missing parents remain a later
	## construction error, but a present parent can never be compiled after its
	## child merely because their bands or IDs happened to sort that way.
	var room_by_id: Dictionary = {}
	var dependencies: Dictionary = {}
	for room: WarrenRoomStamp in rooms:
		room_by_id[room.stable_id] = room
	for room: WarrenRoomStamp in rooms:
		var required: Dictionary = {}
		var bridge_supports := room.audit.get(
			"bridge_support_room_ids", []) as Array
		if not bridge_supports.is_empty():
			for support_value: Variant in bridge_supports:
				var support_id := StringName(support_value)
				if room_by_id.has(support_id) and support_id != room.stable_id:
					required[support_id] = true
		elif not room.terrain_bearing:
			var preferred := room_by_source_level.get(_source_level_key(
				room.support_parent_parcel_id,
				room.support_parent_storey_index)) as WarrenRoomStamp
			var physical := _physical_support_parent(room,
				room_by_private_cell, preferred)
			if physical != null and physical.stable_id != room.stable_id:
				required[physical.stable_id] = true
		dependencies[room.stable_id] = required
	var pending := room_by_id.duplicate()
	var out: Array[WarrenRoomStamp] = []
	while not pending.is_empty():
		var ready: Array[StringName] = []
		for id_value: Variant in pending.keys():
			var room_id := StringName(id_value)
			var blocked := false
			for dependency_value: Variant in (dependencies.get(room_id, {}) \
					as Dictionary).keys():
				if pending.has(StringName(dependency_value)):
					blocked = true
					break
			if not blocked:
				ready.append(room_id)
		ready.sort_custom(func(a: StringName, b: StringName) -> bool:
			return String(a) < String(b))
		if ready.is_empty():
			var cycle_ids: Array[StringName] = []
			cycle_ids.assign(pending.keys())
			cycle_ids.sort_custom(func(a: StringName, b: StringName) -> bool:
				return String(a) < String(b))
			last_failure = "room bearing graph contains a cycle: %s" % cycle_ids
			return [] as Array[WarrenRoomStamp]
		for room_id: StringName in ready:
			out.append(pending[room_id] as WarrenRoomStamp)
			pending.erase(room_id)
	return out


static func _room_feature_envelope_conflict(source: WarrenSpatialPlan,
		program: SettlementFabricProgram, room: WarrenRoomStamp,
		recipe: FabricRecipe) -> StringName:
	var room_bounds := FabricRecipe.lattice_transform(room.lattice_origin,
		room.yaw_quarters) * recipe.local_clearance_bounds
	for feature: WarrenFeatureReservation in source.features:
		# An interstitial strip occupies proven-vacant trapped cells and can
		# never displace a room; an eave or bay grazing the strip from above
		# is a typed reveal, declared as a seam on the strip's own unit. Every
		# other feature keeps the hard displacement gate.
		if feature.kind == &"interstitial_join":
			continue
		if feature.construction_records.is_empty() \
				or _feature_is_related_to_room(source, feature, room):
			continue
		for record: Dictionary in feature.construction_records:
			var feature_recipe := program.recipe(StringName(record.recipe_id))
			if feature_recipe == null:
				return feature.stable_id
			var feature_bounds := FabricRecipe.lattice_transform(
				record.origin as Vector3i, int(record.yaw_quarters)) \
				* feature_recipe.local_clearance_bounds
			if SettlementFabricPlan._aabb_overlaps_volume(room_bounds,
					feature_bounds):
				return feature.stable_id
	return &""


static func _feature_is_related_to_room(source: WarrenSpatialPlan,
		feature: WarrenFeatureReservation, room: WarrenRoomStamp) -> bool:
	var room_id := room.stable_id
	for key: String in ["annex_room_id", "balcony_room_id",
			"market_backing_room_id", "courtyard_bridge_house_room_id",
			"outcrop_upper_room_id", "outcrop_lower_room_id", "gateway_room_id",
			"arcade_upper_room_id", "arcade_lower_room_id",
			"overhang_upper_room_id", "overhang_lower_room_id"]:
		if StringName(feature.audit.get(key, &"")) == room_id:
			return true
	for neighbor_value: Variant in feature.audit.get(
			"outcrop_support_neighbor_room_ids", []):
		if StringName(neighbor_value) == room_id:
			return true
	for neighbor_value: Variant in feature.audit.get(
			"overhang_support_neighbor_room_ids", []):
		if StringName(neighbor_value) == room_id:
			return true
	for neighbor_value: Variant in feature.audit.get(
			"gateway_support_neighbor_room_ids", []):
		if StringName(neighbor_value) == room_id:
			return true
	for neighbor_value: Variant in feature.audit.get(
			"arcade_support_neighbor_room_ids", []):
		if StringName(neighbor_value) == room_id:
			return true
	# An interstitial join is by definition wedged against its named wall,
	# bearing, and continuing-upper owners; the strip's authored ridge/board
	# seam may cross their conservative AABBs while the occupied cells remain
	# disjoint. Every other room still treats the sealed strip as a hard limit.
	if feature.kind == &"interstitial_join":
		var owner_ids: Array = (feature.audit.get(
			"interstitial_wall_owner_ids", []) as Array).duplicate()
		owner_ids.append_array(feature.audit.get(
			"interstitial_cover_owner_ids", []) as Array)
		owner_ids.append(feature.audit.get(
			"interstitial_bearing_owner_id", &""))
		owner_ids.append(feature.audit.get(
			"interstitial_upper_owner_id", &""))
		var room_lineage_prefix := "spatial.%s.part" % room.source_parcel_id
		for owner_value: Variant in owner_ids:
			var owner_id := String(StringName(owner_value))
			if owner_id.is_empty():
				continue
			if String(room_id).begins_with(owner_id + ".room"):
				return true
			# The strip is wedged into this parcel's recomposed lineage; every
			# storey of that lineage shares the sealed reveal relationship,
			# exactly like the balcony/annex lineage exceptions above.
			if owner_id.begins_with(room_lineage_prefix):
				return true
		# Physical contact is itself the sealed relationship: any room whose
		# occupied cells touch the strip (including a storey stepping
		# diagonally over or under it) legitimately shares the reveal, while
		# genuinely detached rooms keep the hard envelope limit.
		var strip_set: Dictionary = {}
		for strip_cell: Vector3i in feature.reserved_cells:
			strip_set[strip_cell] = true
		var contact_directions: Array[Vector3i] = [Vector3i.LEFT,
			Vector3i.RIGHT, Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD,
			Vector3i.BACK]
		for side: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.FORWARD, Vector3i.BACK]:
			contact_directions.append(Vector3i.UP + side)
			contact_directions.append(Vector3i.DOWN + side)
		for room_cell: Vector3i in room.private_cells:
			for direction: Vector3i in contact_directions:
				if strip_set.has(room_cell + direction):
					return true
	# A balcony, annex, or market is selected against every measured room in its
	# recomposed source lineage. Its brackets/eaves may legitimately cross the
	# conservative AABB of the storey directly below even though the occupied
	# cells remain disjoint. Preserve that authored construction seam here.
	for key: String in ["annex_source_parcel_id",
			"balcony_source_parcel_id", "market_backing_parcel_id",
			"courtyard_bridge_house_source_parcel_id"]:
		if StringName(feature.audit.get(key, &"")) == room.source_parcel_id:
			return true
	for binding_value: Variant in feature.audit.get(
			"skywalk_endpoint_bindings", []):
		var endpoint_room_id := StringName((binding_value as Dictionary).get(
			"room_id", &""))
		if endpoint_room_id == room_id:
			return true
		for building: WarrenBuildingVolume in source.buildings:
			for endpoint_room: WarrenRoomStamp in building.room_records:
				if endpoint_room.stable_id == endpoint_room_id \
						and endpoint_room.source_parcel_id \
						== room.source_parcel_id:
					return true
	return false


## TASK I4 ROUND 7 -- how much shared volume makes a module BURIED rather than
## touching. One centimetre on every axis: an order of magnitude under the
## smallest real overlap the r6 review measured (0.135 m, the ivy leaf's own
## depth inside a rock panel) and an order over the tolerance these modules were
## authored to, so a coplanar face cannot read as an intersection.
const BURIED_MODULE_TOLERANCE := 0.01


static func _suppress_intruding_modules(plan: SettlementFabricPlan,
		reachable_terraces: Dictionary = {}) \
		-> Dictionary:
	## TASK I4 ROUND 7, PARTS 1 AND 2 -- the two authored modules a finished town
	## may not carry, withdrawn per unit through the machinery the party wall
	## already uses (`FabricUnit.suppressed_placement_ids`).
	##
	## 1. BURIED DRESSING. A `SettlementFabricProgram.DECOR_MODULE_ASSETS` module
	##    sharing real volume with the vertical skin THIS COMPILE lays. That is
	##    the user's own note -- "one of the plants is glitched into the wall" --
	##    and the r6 review measured it: the roof garden's planter on 12/compact
	##    shares 0.66 x 0.74 x 0.93 m with `maze-stone/-3/5/0/1` and `/1/1`, two
	##    `sfv.fabric.wall.rock.plain.001` panels sited by
	##    `SettlementFabricAssembler.maze_stone_walls`. The wall is the fabric's,
	##    so the fix is the fabric's, and it costs no recipe geometry: dressing is
	##    the one class of module a building can be built without.
	##
	##    AGAINST THE EXACT PANELS SINCE THIS FIX ROUND, and against the covered
	##    market's contents as well as the rooms' -- see the skin derivation below
	##    and `DECOR_STRUCTURAL_PLACEMENTS`.
	##
	## 2. A COLLIDER OVER A STREET. A DECOR or OUTRIGGER module that BAKES a
	##    collider and stands it inside the body column of a cell the public realm
	##    walks. Round 6 filed eight such pinches as a ruled exception; the r6
	##    review then loaded each one's baked shapes and found three of them are
	##    not a look at all -- `sfbp.wwall.support.s.002` twice (a 0.316 m slab
	##    from 0.894 m to 4.500 m) and `sfv.fabric.brace.wood.002` once (from
	##    1.600 m) -- standing in streets a body cannot walk down. The clearance
	##    row could not see them: it commits the fabric dressing and no buildings
	##    (`warren_maze_mode_sweep.gd`'s own scope note), so the two censuses cover
	##    disjoint collision sets and both were honestly green.
	##
	##    WHAT `placement_collision_pieces` REALLY SAYS, because the sentence
	##    above is stronger than the test (r7+r8 review minor 3): it is
	##    `EnvironmentAssetDescriptor.collision_piece_count`, a PER-ASSET count,
	##    and the geometry this rule then measures is the placement's VISUAL box.
	##    No individual collider hull is ever consulted. So the gate reads "this
	##    asset bakes collision AND its drawn geometry is in the body column",
	##    which is one-sided in the safe direction for a census and NOT the same
	##    statement as "a body walks into this hull": a brace whose baked shape
	##    hugs the wall can be withdrawn on the strength of a box that reaches
	##    into the street. Three withdrawals ride on it, each one measured in the
	##    r6 review by loading the shapes.
	##
	## THE RULE IS DECOR-ONLY FOR BURIAL AND THAT IS A DECISION (review minor 8).
	## Only branch 1 is gated on `is_decor`; an OUTRIGGER module buried in the
	## cladding is never withdrawn, and 93 brace and support placements across
	## seven towns do share volume with the exact skin. They are not defects: a
	## diagonal brace is AUTHORED to meet a wall, and its world AABB is a rotated
	## box that hugely overstates the hull it draws -- the same argument this
	## round makes for the plaza tree's crown, and the reason the collider branch
	## above rules the braces instead. Withdrawing a brace because its bounding
	## box meets the masonry it leans on would take out the timber that reads as
	## holding the storey up, to fix nothing anybody can see.
	##
	## OPTIONAL DRESSING NEVER OCCUPIES THE PLAYER'S EXTERIOR SWEPT PRISM. This
	## includes collider-free ivy, flowers, and planters: walking through a white
	## leaf shard is still a visible defect even when physics permits it. The
	## canonical exterior network (sealed public floors plus reachable roof
	## terraces) is computed before suppression, so this is one geometric
	## contract rather than asset-name exceptions.
	##
	## WHY THIS IS NOT A SECOND COMPILE. Both inputs are already here and neither
	## depends on the outcome: `maze_skin_panel_boxes` is a pure function of the
	## retained, solid, paved and plinth cell sets, and `walked_floor_cells` is
	## the surface plan's. A suppression removes a VISUAL placement and nothing
	## else -- no semantic cell, no envelope, no bound -- so nothing upstream of
	## this point can change under it and nothing downstream sees a town it was
	## not built from.
	var out: Dictionary = {"suppressed_buried_decor_module_count": 0,
		"suppressed_exterior_traversal_decor_module_count": 0,
		"suppressed_street_collider_module_count": 0,
		"suppressed_intruding_module_details": [] as Array[String]}
	if plan == null or plan.is_sealed():
		return out
	var retained := plan.retained_terrace_cells
	var solids := plan.transformed_cells(&"solid")
	var paved := SettlementFabricAssembler.public_floor_cells(plan.surface_plan)
	var plinths := SettlementFabricAssembler.plinth_faces(retained, solids,
		plan.transformed_cells(&"terrain_bearing"))
	var walked := SettlementFabricAssembler.walked_floor_cells(
		plan.surface_plan)
	var exterior_traversal := walked.duplicate()
	for cell_value: Variant in reachable_terraces.keys():
		exterior_traversal[cell_value as Vector3i] = true
	# THE EXACT SKIN, AND NOT THE CONSERVATIVE UNION (r7+r8 review I2). Round 7
	# withdrew against `MAZE_SKIN_PANEL_HALF_DEPTH` for every panel, which charges
	# a coursed masonry face 0.221 m of depth it does not occupy -- and the review
	# measured the cost: THREE of this pass's 66 withdrawals shared no volume at
	# all with the cladding their towns really build (12/compact's
	# `garden.flower` at -0.189 m, 1/grand's `facade.sign` at -0.104 m,
	# 9/standard's `garden.flower` at -0.051 m). Three modules were deleted from
	# finished towns for a wall that is not there.
	#
	# WHY THE TREATMENTS CAN BE READ HERE WITHOUT A FEEDBACK LOOP, which is the
	# objection `MAZE_SKIN_PANEL_HALF_DEPTH` was written against. Only the SIDE
	# faces carry a depth into `maze_skin_panel_boxes`, and a side face's
	# treatment is decided by its BANK HEIGHT alone -- `maze_bank_height` over
	# `exposed`, plus the natural-cut fallback, none of which reads the footprint
	# index. The footprints steer cap faces only (`_maze_cap_is_free` and the
	# small-garden demotion), and a cap contributes either a soffit box, whose
	# depth is fixed, or -- for a sky-facing cap -- no box at all. So the panel
	# boxes are the same array with the index and without it, and this pass
	# passes NO footprints on purpose: the one input that could move under its own
	# outcome is the one input it does not take.
	#
	# The stand-off in `_frontage_window_offsets` keeps the union, and keeps it
	# for its own reason: standing a barrel 0.221 m further off a wall than it
	# strictly must is free, while withdrawing a flower from a wall that is not
	# there is not.
	var shell := SettlementFabricAssembler.maze_ground_skin_transaction(plan) \
		.shell as Dictionary
	var skin := SettlementFabricAssembler.maze_skin_panel_boxes(retained,
		solids, paved, plinths, shell.treatments as Dictionary, shell)
	if skin.is_empty() and exterior_traversal.is_empty():
		return out
	var decor: Dictionary = {}
	for asset: StringName in SettlementFabricProgram.DECOR_MODULE_ASSETS:
		decor[asset] = true
	var outrigger: Dictionary = {}
	for asset: StringName in SettlementFabricProgram.OUTRIGGER_MODULE_ASSETS:
		outrigger[asset] = true
	var body_half := SettlementFabricAssembler.NATURAL_ROCK_CUT_BODY_WIDTH * 0.5
	var body_height := SettlementFabricAssembler.NATURAL_ROCK_CUT_BODY_HEIGHT
	var withdrawals: Array[Dictionary] = []
	# The units in their own order, and each recipe's placements in theirs, so the
	# withdrawal list is a function of the plan and not of a dictionary's
	# iteration order.
	for unit: FabricUnit in plan.units:
		var recipe := plan.recipe(unit.recipe_id)
		if recipe == null or recipe.placements.is_empty():
			continue
		var unit_transform := unit.transform()
		for index in recipe.placements.size():
			var placement := recipe.placements[index] as Dictionary
			var asset := StringName(placement.asset_id)
			var placement_id := StringName(placement.id)
			# BY PLACEMENT AND NOT BY ASSET ALONE (r7+r8 review I3). The roof
			# terrace's awning is dressing where a terrace wears it and it is a
			# covered market's whole canopy where a bazaar does, and nothing but
			# the placement id tells the two apart -- see
			# `SettlementFabricProgram.DECOR_STRUCTURAL_PLACEMENTS`, which is also
			# where the reason a canopy is never withdrawn is written down.
			var is_decor := SettlementFabricProgram.decor_module_is_dressing(
				asset, placement_id, decor)
			if not is_decor and not outrigger.has(asset):
				continue
			if unit.suppressed_placement_ids.has(placement_id):
				continue
			if index >= recipe.placement_bounds.size():
				continue
			var box: AABB = unit_transform * recipe.placement_bounds[index]
			if not box.has_volume():
				continue
			var reason := &""
			var against := ""
			if is_decor:
				for panel: AABB in skin:
					if not _boxes_share_volume(box, panel):
						continue
					reason = &"buried"
					against = "panel(%.2f,%.2f,%.2f)" % [panel.position.x,
						panel.position.y, panel.position.z]
					break
			if reason.is_empty() and is_decor:
				var traversal_cell: Variant = _exterior_surface_intrusion(
					box, exterior_traversal, body_half, body_height)
				if traversal_cell != null:
					reason = &"exterior_traversal"
					against = str(traversal_cell)
			var pieces: int = recipe.placement_collision_pieces[index] \
				if index < recipe.placement_collision_pieces.size() else 0
			if reason.is_empty() and pieces > 0:
				var stance: Variant = _walked_cell_under_module(box, walked,
					body_half, body_height)
				if stance != null:
					reason = &"street_collider"
					against = str(stance)
			if reason.is_empty():
				continue
			withdrawals.append({"unit": unit.stable_id,
				"placement": placement_id, "asset": asset, "reason": reason,
				"against": against})
	var details: Array[String] = []
	for withdrawal: Dictionary in withdrawals:
		var reason := StringName(withdrawal.reason)
		var against := String(withdrawal.against)
		if not plan.suppress_placement(withdrawal.unit as StringName,
				withdrawal.placement as StringName):
			# A refusal here is a defect in the rule, not in the town: the only
			# refusals `suppress_placement` has are an unknown id and a
			# construction run, and this loop reads the recipe's own placements.
			# Counted and named rather than swallowed.
			reason = &"refused"
			against = plan.last_rejection
		elif reason == &"buried":
			out["suppressed_buried_decor_module_count"] = int(
				out["suppressed_buried_decor_module_count"]) + 1
		elif reason == &"exterior_traversal":
			out["suppressed_exterior_traversal_decor_module_count"] = int(
				out["suppressed_exterior_traversal_decor_module_count"]) + 1
		else:
			out["suppressed_street_collider_module_count"] = int(
				out["suppressed_street_collider_module_count"]) + 1
		details.append("%s/%s %s %s %s" % [withdrawal.unit,
			withdrawal.placement, withdrawal.asset, reason, against])
	out["suppressed_intruding_module_details"] = details
	return out


static func _exterior_surface_intrusion(box: AABB, surfaces: Dictionary,
		body_half: float, body_height: float) -> Variant:
	## Exact swept prism over every canonical exterior surface. Unlike the older
	## collider-only street test this applies to all optional dressing and begins
	## at the floor plane, so flowers, ivy, and planters cannot remain as visual
	## shards in a walkway merely because their source asset has no collision.
	var found: Variant = null
	for cell_value: Variant in surfaces.keys():
		var cell := cell_value as Vector3i
		var centre := Vector3(cell) * FabricRecipe.CELL_SIZE
		var body := AABB(Vector3(centre.x - body_half, centre.y + 0.001,
			centre.z - body_half), Vector3(body_half * 2.0,
			body_height - 0.001, body_half * 2.0))
		if not _boxes_share_volume(box, body):
			continue
		if found == null or SettlementFabricAssembler._cell_before(cell,
				found as Vector3i):
			found = cell
	return found


static func _boxes_share_volume(a: AABB, b: AABB) -> bool:
	## Real shared volume on every axis, past BURIED_MODULE_TOLERANCE. `AABB.
	## intersects` calls two boxes meeting at a face an intersection, which is
	## exactly what a module standing AGAINST a wall does.
	return a.position.x + a.size.x - b.position.x > BURIED_MODULE_TOLERANCE \
		and b.position.x + b.size.x - a.position.x > BURIED_MODULE_TOLERANCE \
		and a.position.y + a.size.y - b.position.y > BURIED_MODULE_TOLERANCE \
		and b.position.y + b.size.y - a.position.y > BURIED_MODULE_TOLERANCE \
		and a.position.z + a.size.z - b.position.z > BURIED_MODULE_TOLERANCE \
		and b.position.z + b.size.z - a.position.z > BURIED_MODULE_TOLERANCE


static func _walked_cell_under_module(box: AABB, walked: Dictionary,
		body_half: float, body_height: float) -> Variant:
	## The lowest-ordered walked cell this module hangs into the body column of,
	## or `null`. The arithmetic is `SettlementFabricAssembler.
	## maze_footprint_headroom`'s, asked from the module's side: a walked cell
	## floors at its own bottom, and a module whose UNDERSIDE is above that floor
	## by less than a body's height stands in the way of anybody crossing it.
	##
	## Over the BODY's own footprint at the cell centre rather than over the whole
	## cell, for that rule's own reason: a brace clipping the corner of a 1.5 m
	## street still leaves the 0.795 m a body needs.
	var found: Variant = null
	for cell_value: Variant in walked.keys():
		var cell := cell_value as Vector3i
		var floor_y := float(cell.y) * FabricRecipe.CELL_SIZE
		var rise := box.position.y - floor_y
		if rise <= SettlementFabricAssembler.FOOTPRINT_EPSILON \
				or rise >= body_height:
			continue
		var centre := Vector3(cell) * FabricRecipe.CELL_SIZE
		if box.position.x >= centre.x + body_half \
				or box.position.x + box.size.x <= centre.x - body_half \
				or box.position.z >= centre.z + body_half \
				or box.position.z + box.size.z <= centre.z - body_half:
			continue
		if found == null or SettlementFabricAssembler._cell_before(cell,
				found as Vector3i):
			found = cell
	return found


static func _suppressed_party_wall_placements(grid: WarrenSpatialGrid,
		room: WarrenRoomStamp, recipe: FabricRecipe) -> Array[StringName]:
	## Translate the sealed fine-grid PARTY_WALL field into whole authored facade
	## modules. A 3 m module is omitted only when both of its horizontal cells,
	## across both 1.5 m height bands, meet private volume through the same typed
	## seam. This keeps partial contacts visible and closes the old loophole where
	## two composable rooms still rendered coincident timber/stone skins.
	var minimum := Vector2i.ZERO
	var maximum := Vector2i.ZERO
	match room.kind:
		&"tower":
			minimum = Vector2i(-1, -1)
			maximum = Vector2i(0, 0)
		&"slim":
			minimum = Vector2i(-1, -2)
			maximum = Vector2i(0, 1)
		&"row":
			minimum = Vector2i(-2, -1)
			maximum = Vector2i(1, 0)
		&"building":
			minimum = Vector2i(-2, -2)
			maximum = Vector2i(1, 1)
		&"long":
			minimum = Vector2i(-2, -3)
			maximum = Vector2i(1, 2)
		_:
			return [] as Array[StringName]
	var available: Dictionary = {}
	for placement: Dictionary in recipe.placements:
		available[StringName(placement.id)] = true
	var suppressed: Dictionary = {}
	var front_ids: Array[StringName] = []
	var x_segments := int((maximum.x - minimum.x + 1) / 2)
	for index in x_segments:
		var x0 := minimum.x + index * 2
		var front_id := StringName("south") if room.kind in [&"tower", &"slim"] \
			else StringName("front.%d" % index)
		var back_id := StringName("north") if room.kind in [&"tower", &"slim"] \
			else StringName("back.%d" % index)
		front_ids.append(front_id)
		_suppress_complete_party_wall_segment(grid, room, available,
			suppressed, front_id, Vector3i.BACK, [
				Vector3i(x0, 0, maximum.y),
				Vector3i(x0 + 1, 0, maximum.y),
			])
		_suppress_complete_party_wall_segment(grid, room, available,
			suppressed, back_id, Vector3i.FORWARD, [
				Vector3i(x0, 0, minimum.y),
				Vector3i(x0 + 1, 0, minimum.y),
			])
	var z_segments := int((maximum.y - minimum.y + 1) / 2)
	for index in z_segments:
		var z0 := minimum.y + index * 2
		var west_id := StringName("west") if room.kind == &"tower" \
			else StringName("left.%d" % index) if room.kind == &"building" \
			else StringName("west.%d" % index)
		var east_id := StringName("east") if room.kind == &"tower" \
			else StringName("right.%d" % index) if room.kind == &"building" \
			else StringName("east.%d" % index)
		_suppress_complete_party_wall_segment(grid, room, available,
			suppressed, west_id, Vector3i.LEFT, [
				Vector3i(minimum.x, 0, z0),
				Vector3i(minimum.x, 0, z0 + 1),
			])
		_suppress_complete_party_wall_segment(grid, room, available,
			suppressed, east_id, Vector3i.RIGHT, [
				Vector3i(maximum.x, 0, z0),
				Vector3i(maximum.x, 0, z0 + 1),
			])
	var complete_front_is_hidden := not front_ids.is_empty()
	for placement_id: StringName in front_ids:
		complete_front_is_hidden = complete_front_is_hidden \
			and suppressed.has(placement_id)
	if complete_front_is_hidden:
		for placement: Dictionary in recipe.placements:
			var placement_id := StringName(placement.id)
			if String(placement_id).begins_with("facade."):
				suppressed[placement_id] = true
	var out: Array[StringName] = []
	out.assign(suppressed.keys())
	out.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	return out


static func _suppress_complete_party_wall_segment(grid: WarrenSpatialGrid,
		room: WarrenRoomStamp, available: Dictionary, suppressed: Dictionary,
		placement_id: StringName, local_direction: Vector3i,
		local_columns: Array[Vector3i]) -> void:
	if not available.has(placement_id):
		return
	var direction := FabricRecipe.transform_direction(local_direction,
		room.yaw_quarters)
	for local_column: Vector3i in local_columns:
		for y in WarrenSpatialGrid.STOREY_CELLS:
			var local_cell := Vector3i(local_column.x, y, local_column.z)
			var cell := FabricRecipe.transform_cell(local_cell,
				room.lattice_origin, room.yaw_quarters)
			var neighbor := cell + direction
			var claim := grid.face_claim(cell, direction)
			if room.has_private_cell(neighbor) \
					or grid.use_at(neighbor) \
						!= WarrenSpatialGrid.Use.PRIVATE_VOLUME \
					or int(claim.get("kind", -1)) \
						!= WarrenSpatialGrid.FaceKind.PARTY_WALL:
				return
	suppressed[placement_id] = true


static func _prior_visual_seam_units(grid: WarrenSpatialGrid,
		room: WarrenRoomStamp, prior_unit_by_cell: Dictionary,
		building_by_room: Dictionary, probe: SettlementFabricPlan,
		current_recipe: FabricRecipe) -> Array[StringName]:
	## Face-adjacent rooms use the shell's explicit PARTY_WALL fact. A second,
	## genuinely 3D seam exists where two occupied stamps meet along one lattice
	## edge: their cells differ by one on exactly two axes. Admit that seam only
	## when the measured construction overlap is shallow on those same axes;
	## nearby but unrelated shells remain an error.
	var unique: Dictionary = {}
	var own_building := StringName(building_by_room.get(room.stable_id, &""))
	for cell: Vector3i in room.private_cells:
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.UP, Vector3i.DOWN, Vector3i.FORWARD, Vector3i.BACK]:
			var neighbor := cell + direction
			if not prior_unit_by_cell.has(neighbor):
				continue
			var claim := grid.face_claim(cell, direction)
			if int(claim.get("kind", -1)) \
					== WarrenSpatialGrid.FaceKind.PARTY_WALL \
					and grid.owner_name_at(neighbor) != own_building:
				unique[StringName(prior_unit_by_cell[neighbor])] = true
	var current_bounds := FabricRecipe.lattice_transform(room.lattice_origin,
		room.yaw_quarters) * current_recipe.local_clearance_bounds
	var edge_offsets: Array[Vector3i] = []
	for first_axis in 3:
		for second_axis in range(first_axis + 1, 3):
			for first_sign in [-1, 1]:
				for second_sign in [-1, 1]:
					var offset := Vector3i.ZERO
					offset[first_axis] = first_sign
					offset[second_axis] = second_sign
					edge_offsets.append(offset)
	for cell: Vector3i in room.private_cells:
		for offset: Vector3i in edge_offsets:
			var prior_id := StringName(prior_unit_by_cell.get(cell + offset, &""))
			if prior_id.is_empty() or unique.has(prior_id):
				continue
			var prior_unit := probe.unit(prior_id)
			var prior_recipe := probe.recipe(prior_unit.recipe_id) \
				if prior_unit != null else null
			if prior_recipe == null or prior_recipe.placements.is_empty():
				continue
			var prior_bounds := prior_unit.transform() \
				* prior_recipe.local_clearance_bounds
			if SettlementFabricPlan._aabb_overlaps_volume(current_bounds,
					prior_bounds) and SettlementFabricPlan._is_edge_nick(
						current_bounds, prior_bounds):
				unique[prior_id] = true
	var out: Array[StringName] = []
	out.assign(unique.keys())
	out.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	return out


static func _inverse_cell(world: Vector3i, origin: Vector3i,
		yaw_quarters: int) -> Vector3i:
	return FabricRecipe.transform_cell(world - origin, Vector3i.ZERO,
		-yaw_quarters)


static func _source_level_key(parcel_id: StringName, level: int) -> String:
	return "%s/%d" % [String(parcel_id), level]
