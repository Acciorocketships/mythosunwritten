class_name SettlementFabricAssembler
extends RefCounted

## Main-thread adapter for a sealed fabric plan. The worker-facing output is an
## ordinary resource-free EnvironmentInstancePayload, so the eventual
## procedural solver can reuse the existing commit and streaming path.
const PLANK_FLOOR := &"sfv.fabric.floor.l.001"
const PLANK_GALLERY := &"sfv.fabric.gallery.floor.m.001"
const PLANK_SINGLE := &"sfv.deck.floor.s.001"
const PLANK_RAILING := &"sfv.deck.railing.s.001"
const TIMBER_SUPPORT := &"sfv.deck.pillar.001"
const LOW_RETAINING_WALL := &"sfv.fabric.wall.rock.plain.001"
## The authored foundation piece, not a wall panel pressed into service as one.
## Same measured envelope as LOW_RETAINING_WALL (1.77 x 3.00 x 0.66, pivot at
## the bottom centre), so it drops into the same lattice slot, but it reads as
## the base course of a building rather than a length of retaining wall.
const HOUSE_PLINTH := &"sfv.foundation.rock.001"
const PLANK_Y_OFFSET := -0.12
## Every authored module that reads as coursed rock, whether a recipe places it
## as a house's ground storey or this assembler places it as a plinth. The
## budget below is measured across the union, because a viewer sees one
## continuous masonry face and does not care which stage emitted it.
const STONE_FACADE_ASSETS: Array[StringName] = [
	&"sfv.fabric.wall.rock.plain.001",
	&"sfv.fabric.wall.rock.door.005",
	&"sfv.fabric.wall.rock.window.010",
	&"sfv.foundation.rock.001",
]
## REVIEWER BUDGET (round 3, binding): "almost no stone should be visible, it
## should only be used sparingly to make a house one storey taller." One storey
## is two bands, which is exactly one upright 3 m rock module. No continuous
## stone face anywhere in a town may be taller than this.
const STONE_BUDGET_BANDS := 2
const FACE_DIRECTIONS: Array[Vector3i] = [Vector3i.LEFT, Vector3i.RIGHT,
	Vector3i.FORWARD, Vector3i.BACK]


static func payload(plan: SettlementFabricPlan) -> EnvironmentInstancePayload:
	assert(plan != null and plan.is_sealed() and plan.validate())
	var out := EnvironmentInstancePayload.new()
	for placement: Dictionary in plan.expanded_placements():
		out.add(StringName(placement.asset_id),
			placement.transform as Transform3D, Color.WHITE,
			StringName(placement.stable_id))
	assert(out.validate())
	return out


static func commit(parent: Node3D, plan: SettlementFabricPlan,
		catalog: EnvironmentCatalog, include_collision: bool = true) -> Dictionary:
	assert(OS.get_thread_caller_id() == OS.get_main_thread_id())
	assert(parent != null and catalog != null and plan != null \
		and plan.is_sealed())
	var cache := EnvironmentRenderCache.new(catalog)
	var surface_instances := surface_visual_payload(plan.surface_plan)
	var instances := payload(plan)
	var support_instances := structural_support_payload(plan)
	instances.append_from(support_instances)
	var demanded_assets := instances.asset_ids()
	for asset_id: StringName in surface_instances.asset_ids():
		if not demanded_assets.has(asset_id):
			demanded_assets.append(asset_id)
	demanded_assets.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	assert(cache.prepare(demanded_assets))
	var collision_count := 0
	if include_collision:
		collision_count = EnvironmentCollisionBuilder.commit(parent, instances,
			cache, &"FabricCollision")
	var queue := EnvironmentCommitQueue.new(cache, &"FabricVisuals")
	queue.register_chunk(Vector2i.ZERO, 1)
	queue.enqueue(Vector2i.ZERO, 1, parent, instances)
	queue.enqueue(Vector2i.ZERO, 1, parent, surface_instances)
	while queue.pending_count() > 0:
		queue.drain(64)
	var surface_commit := _commit_surfaces(parent, plan.surface_plan,
		include_collision)
	# The retained hill has NO generated skin. Round-3 review: flat slabs in an
	# earth palette read as boxes, and a town must be built out of catalog
	# assets -- buildings, paths, supports -- not primitives. An unfronted cut
	# face is therefore honestly nothing; a terrain-integrated hill is a
	# separate direction and this must not pre-empt it with a placeholder.
	return {
		"instance_count": instances.instance_count + surface_instances.instance_count,
		"fabric_instance_count": instances.instance_count,
		"surface_visual_instance_count": surface_instances.instance_count,
		"structural_support_instance_count": support_instances.instance_count,
		"collision_piece_count": collision_count \
			+ int(surface_commit.collision_piece_count),
		"asset_count": instances.asset_ids().size(),
		"surface_patch_count": plan.surface_plan.patches.size(),
		"surface_triangle_count": int(surface_commit.triangle_count),
	}


static func structural_support_payload(plan: SettlementFabricPlan) \
		-> EnvironmentInstancePayload:
	## Sparse fixed-module supports derive from the same continuous structural
	## surface that owns traversal. A support is never emitted through a lower
	## public route or occupied room column; those columns are already visibly
	## carried by the city below. Odd half-level heights bury the bottom half of
	## one ordinary 3 m module instead of stretching it.
	var out := EnvironmentInstancePayload.new()
	if plan == null or plan.surface_plan == null:
		return out
	out.append_from(low_retaining_payload(plan))
	out.append_from(terrace_retaining_payload(plan))
	var solids := plan.transformed_cells(&"solid")
	var structural := plan.surface_plan.cells_for_kind(
		PublicRealmSurfacePlan.SurfaceKind.STRUCTURAL_COURT)
	var structural_set: Dictionary = {}
	for cell: Vector3i in structural:
		structural_set[cell] = true
	for cell: Vector3i in structural:
		var support_base := plan.surface_plan.support_base_at(cell)
		if cell.y <= support_base \
				or (plan.surface_plan.has_support_base(cell) \
					and cell.y - support_base == 1) \
				or posmod(cell.x * 17 + cell.z * 31, 3) != 0:
			continue
		var boundary_neighbors := 0
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.FORWARD, Vector3i.BACK]:
			if structural_set.has(cell + direction):
				boundary_neighbors += 1
		if boundary_neighbors >= 4 or _column_is_occupied_below(plan, solids, cell):
			continue
		var surface_y := float(cell.y) * FabricRecipe.CELL_SIZE
		var segment_top := surface_y
		var base_y := float(support_base) * FabricRecipe.CELL_SIZE
		var segment := 0
		while segment_top > base_y + 0.001:
			var origin_y := segment_top - 3.0
			var transform := Transform3D(Basis.IDENTITY,
				Vector3(float(cell.x) * FabricRecipe.CELL_SIZE, origin_y,
					float(cell.z) * FabricRecipe.CELL_SIZE))
			out.add(TIMBER_SUPPORT, transform, Color.WHITE,
				StringName("public-support/%d/%d/%d/%d" % [cell.x, cell.y,
					cell.z, segment]))
			segment_top -= 3.0
			segment += 1
	assert(out.validate())
	return out


static func low_retaining_payload(plan: SettlementFabricPlan) \
		-> EnvironmentInstancePayload:
	## A platform only 1.5 m above its terrain datum cannot be a traversable
	## undercroft. Render it as a retained stone terrace, with fixed 3 m wall
	## modules half-buried, instead of exposing a crawl-height lawn beneath sparse
	## timber posts. Full-headroom surfaces continue to use open timber support.
	##
	## Within the round-3 stone budget by construction: exactly one module per
	## exposed face of a ONE-band step, which can never stack.
	var out := EnvironmentInstancePayload.new()
	if plan == null or plan.surface_plan == null:
		return out
	var solids := plan.transformed_cells(&"solid")
	var retained: Dictionary = {}
	for cell: Vector3i in plan.surface_plan.cells_for_kind(
			PublicRealmSurfacePlan.SurfaceKind.STRUCTURAL_COURT):
		if plan.surface_plan.has_support_base(cell) \
				and cell.y - plan.surface_plan.support_base_at(cell) == 1:
			retained[cell] = true
	for cell_value: Variant in retained.keys():
		var cell := cell_value as Vector3i
		var surface_y := float(cell.y) * FabricRecipe.CELL_SIZE
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.FORWARD, Vector3i.BACK]:
			var neighbor := cell + direction
			if retained.has(neighbor) or solids.has(neighbor) \
					or solids.has(neighbor - Vector3i.UP):
				continue
			var midpoint := Vector3(cell) * FabricRecipe.CELL_SIZE \
				+ Vector3(direction) * FabricRecipe.CELL_SIZE * 0.5
			midpoint.y = surface_y - 3.0
			var yaw := PI * 0.5 if direction.x != 0 else 0.0
			out.add(LOW_RETAINING_WALL,
				Transform3D(Basis(Vector3.UP, yaw), midpoint), Color.WHITE,
				StringName("retaining-wall/%d/%d/%d/%d/%d" % [cell.x,
					cell.y, cell.z, direction.x, direction.z]))
	assert(out.validate())
	return out


static func terrace_retaining_payload(plan: SettlementFabricPlan) \
		-> EnvironmentInstancePayload:
	## Stone appears in exactly ONE role, and only under a building: the house
	## PLINTH -- the authored foundation piece, one course, where a house stopped
	## descending short of its own ground. This is the "stone to make a house one
	## storey taller" the directive allows, and it is where the liked
	## wood-over-stone junction happens.
	## THE MOUNTAIN SUBSTRATE ROLE IS GONE (terrain milestone Wave 4, design
	## §3.4). `hill_substrate_walls` used to tile the riser a house stood on with
	## whole rock modules, because the fabric owned the hill and an undrawn hill
	## left its houses floating. SettlementReliefPlan now stamps that hill into
	## the heightfield, so the terrain mesh renders it, CliffDressing dresses its
	## faces and the chunk collider carries it -- re-drawing it here would put a
	## masonry collider inside the terrain's own volume and rebuild the monument
	## rounds 2 and 3 rejected. WarrenFabricCompiler no longer declares the
	## remainder either, so this function's input is already only plinths.
	if plan == null:
		return EnvironmentInstancePayload.new()
	var retained := plan.retained_terrace_cells
	var solids := plan.transformed_cells(&"solid")
	var out := house_plinth_walls(retained, solids)
	assert(out.validate())
	return out


static func building_ceiling(solids: Dictionary) -> Dictionary:
	## Highest band a building occupies in each column, as Vector2i -> int. A
	## retained cell below that band is mass the town stands ON: whatever of it
	## shows is read against the house above it, not as bare masonry.
	var out: Dictionary = {}
	for cell_value: Variant in solids.keys():
		var cell := cell_value as Vector3i
		var column := Vector2i(cell.x, cell.z)
		out[column] = maxi(int(out.get(column, cell.y)), cell.y)
	return out


static func house_plinth_walls(retained: Dictionary,
		solids: Dictionary) -> EnvironmentInstancePayload:
	## One authored HOUSE_PLINTH foundation piece per exposed plinth face, and
	## never a second. Its top is flush with the house floor it carries and its
	## bottom is buried in the bank below -- the same half-burial the one-band
	## court in low_retaining_payload already relies on, and the reason no asset
	## is ever scaled. A deeper bank is NOT tiled with further courses: nothing
	## below the declared run (bounded at construction by
	## WarrenMassif.PLINTH_BUDGET_BANDS) is ever rendered.
	##
	## Pure function of integer cell sets whose every loop runs over a sorted
	## key list, so the payload is byte-identical for identical input.
	var out := EnvironmentInstancePayload.new()
	var keys: Array[Vector4i] = []
	keys.assign(plinth_faces(retained, solids).keys())
	keys.sort_custom(_face_before)
	for key: Vector4i in keys:
		var direction := FACE_DIRECTIONS[key.w]
		var midpoint := Vector3(float(key.x), 0.0, float(key.z)) \
			* FabricRecipe.CELL_SIZE \
			+ Vector3(direction) * FabricRecipe.CELL_SIZE * 0.5
		midpoint.y = float(key.y + 1) * FabricRecipe.CELL_SIZE - 3.0
		var yaw := PI * 0.5 if direction.x != 0 else 0.0
		out.add(HOUSE_PLINTH,
			Transform3D(Basis(Vector3.UP, yaw), midpoint), Color.WHITE,
			StringName("house-plinth/%d/%d/%d/%d" % [key.x, key.y, key.z,
				key.w]))
	assert(out.validate())
	return out


static func plinth_faces(retained: Dictionary, solids: Dictionary) -> Dictionary:
	## The faces stone is allowed to claim, keyed Vector4i(x, band, z, direction
	## index into FACE_DIRECTIONS) at the TOP band of the run. A face qualifies
	## only when a building stands directly on that cell (so the stone is part
	## of that house rather than a retaining wall in its own right) and the
	## side is one nothing else already closes.
	##
	## NOT gated on whether the house's own ground storey already reads as rock.
	## Round 5 shipped that gate and it refused all 216 houses the stamped-hill
	## corpus declared a plinth for, because every ground storey is
	## unconditionally rock (WarrenAssetCompiler builds every stack's base from
	## `room.*.base.rock`) -- the test was "does this house wear any stone",
	## which is always true, rather than "how much stone would this add"
	## (task-24-report.md concern #2). A plinth is FRONTED stone: the check
	## just below already requires a building to stand directly on the cell, so
	## it can never be a bare retaining face. It is bounded on its own terms by
	## the declaration side (WarrenParcelConstruction.resolve_support_band,
	## budgeted at WarrenMassif.PLINTH_BUDGET_BANDS) rather than by
	## tallest_bare_stone_stack_bands, which governs masonry nothing stands
	## over and must not be weakened to make room for this. Whether the ground
	## storey above also happens to be rock is the separate, already-accepted
	## "stone feature" the reviewer praised, not a reason to refuse the
	## foundation course beneath it.
	##
	## The 3 m module hung from this band also covers the band below it, which
	## is why the earth skin skips both.
	var out: Dictionary = {}
	var cells: Array[Vector3i] = []
	cells.assign(retained.keys())
	cells.sort_custom(_cell_before)
	for cell: Vector3i in cells:
		var above := cell + Vector3i.UP
		if not solids.has(above):
			continue
		for index in FACE_DIRECTIONS.size():
			var neighbor := cell + FACE_DIRECTIONS[index]
			if retained.has(neighbor) or solids.has(neighbor):
				continue
			out[Vector4i(cell.x, cell.y, cell.z, index)] = true
	return out


static func _column_is_covered(origin: Vector3,
		covered_columns: Dictionary) -> bool:
	## A wall module sits ON a cell boundary, half a cell out from the cell it
	## retains, so it belongs to BOTH adjacent columns. If a building stands over
	## either one, the stone is read against that building.
	if covered_columns.is_empty():
		return false
	var x := origin.x / FabricRecipe.CELL_SIZE
	var z := origin.z / FabricRecipe.CELL_SIZE
	for column_x: int in [floori(x), ceili(x)]:
		for column_z: int in [floori(z), ceili(z)]:
			if covered_columns.has(Vector2i(column_x, column_z)):
				return true
	return false


static func _is_assembler_stone(stable_id: String) -> bool:
	## Rock this file placed, as opposed to a rock module inside a house recipe.
	## The asset ids overlap, so provenance lives in the stable id.
	return stable_id.begins_with("house-plinth/") \
		or stable_id.begins_with("retaining-wall/")


static func tallest_bare_stone_stack_bands(payload: EnvironmentInstancePayload,
		covered_columns: Dictionary = {}) -> int:
	## Measures the round-3b budget: the tallest run of contiguous bands of BARE
	## stone -- rock this assembler placed on a column no building stands over.
	## Substrate under a house is read against that house and is deliberately
	## exempt (the reviewer wants the mountain the town is draped on); an
	## uncovered face is a uniform masonry field and may not exceed
	## STONE_BUDGET_BANDS.
	##
	## `covered_columns` is a set of Vector2i lattice columns a building
	## occupies -- see building_ceiling. Recipe facades are excluded outright:
	## a house's own wall is a building, which is exactly what the town is
	## supposed to be made of.
	##
	## A module is 3 m wide but the plinth lattice is offset half a cell from the
	## room lattice, so width is resolved in 0.75 m slots; two modules that
	## overlap laterally at all count as the same face.
	var planes: Dictionary = {}
	for asset_id: StringName in STONE_FACADE_ASSETS:
		var batch := payload.batches.get(asset_id, {}) as Dictionary
		var ids: Array = batch.get("ids", [])
		var transforms: Array = batch.get("transforms", [])
		for order in transforms.size():
			var placement := transforms[order] as Transform3D
			if placement.basis.y.y < 0.5 \
					or not _is_assembler_stone(String(ids[order])) \
					or _column_is_covered(placement.origin, covered_columns):
				continue
			var yaw_index := posmod(roundi(placement.basis.get_euler().y
				/ (PI * 0.5)), 2)
			var plane := placement.origin.z if yaw_index == 0 \
				else placement.origin.x
			var tangent := placement.origin.x if yaw_index == 0 \
				else placement.origin.z
			var base_band := roundi(placement.origin.y / FabricRecipe.CELL_SIZE)
			var first_slot := roundi((tangent - 1.5) / 0.75)
			for slot in 4:
				var key := Vector3i(yaw_index, roundi(plane / 0.75),
					first_slot + slot)
				if not planes.has(key):
					planes[key] = {}
				(planes[key] as Dictionary)[base_band] = true
				(planes[key] as Dictionary)[base_band + 1] = true
	var tallest := 0
	for key_value: Variant in planes.keys():
		var bands: Array = (planes[key_value] as Dictionary).keys()
		bands.sort()
		var index := 0
		while index < bands.size():
			var last := index
			while last + 1 < bands.size() \
					and int(bands[last + 1]) == int(bands[last]) + 1:
				last += 1
			tallest = maxi(tallest, last - index + 1)
			index = last + 1
	return tallest


static func _cell_before(left: Vector3i, right: Vector3i) -> bool:
	if left.y != right.y:
		return left.y < right.y
	if left.z != right.z:
		return left.z < right.z
	return left.x < right.x


static func _face_before(left: Vector4i, right: Vector4i) -> bool:
	if left.y != right.y:
		return left.y < right.y
	if left.z != right.z:
		return left.z < right.z
	if left.x != right.x:
		return left.x < right.x
	return left.w < right.w


static func _column_is_occupied_below(plan: SettlementFabricPlan,
		solids: Dictionary, top: Vector3i) -> bool:
	for y in range(0, top.y):
		var cell := Vector3i(top.x, y, top.z)
		if solids.has(cell) or plan.surface_plan.has_cell(cell):
			return true
	return false


static func surface_visual_payload(plan: PublicRealmSurfacePlan) \
		-> EnvironmentInstancePayload:
	## The continuous union remains the sole collision authority. Reviewed
	## fixed-size plank meshes tile structural portions of that union without
	## scaling an asset or allowing independently placed decks to define
	## connectivity. The generated structural skin is deliberately not rendered.
	var out := EnvironmentInstancePayload.new()
	if plan == null or not plan.is_sealed():
		return out
	for kind in [PublicRealmSurfacePlan.SurfaceKind.STRUCTURAL_COURT,
			PublicRealmSurfacePlan.SurfaceKind.BRIDGE]:
		_append_plank_tiles(out, plan.cells_for_kind(kind), int(kind))
	for segment: Dictionary in plan.guard_segments:
		var a := segment.a as Vector3
		var b := segment.b as Vector3
		var delta := b - a
		assert(is_equal_approx(delta.length(), FabricRecipe.CELL_SIZE))
		var yaw := atan2(-delta.z, delta.x)
		out.add(PLANK_RAILING,
			Transform3D(Basis(Vector3.UP, yaw), (a + b) * 0.5),
			Color.WHITE, StringName("public-guard/%s" % segment.stable_key))
	assert(out.validate())
	return out


static func production_surface_payload(plan: PublicRealmSurfacePlan) \
		-> EnvironmentInstancePayload:
	## Streaming cannot commit the review harness' generated ArrayMesh from a
	## worker payload.  Tile the *same sealed surface union* with collision-
	## bearing fixed modules instead.  This is deliberately a second adapter,
	## not a second topology. Ground streets are NOT planked: they keep the
	## worn-path paint on real terrain, so the lower town reads as dirt paths
	## carved between building masses; timber belongs to genuinely structural
	## surfaces only.
	var out := EnvironmentInstancePayload.new()
	if plan == null or not plan.is_sealed():
		return out
	for kind in [PublicRealmSurfacePlan.SurfaceKind.STRUCTURAL_COURT,
			PublicRealmSurfacePlan.SurfaceKind.INTERIOR_PASSAGE,
			PublicRealmSurfacePlan.SurfaceKind.BRIDGE]:
		_append_plank_tiles(out, plan.cells_for_kind(kind), int(kind))
	for segment: Dictionary in plan.guard_segments:
		var a := segment.a as Vector3
		var b := segment.b as Vector3
		var delta := b - a
		assert(is_equal_approx(delta.length(), FabricRecipe.CELL_SIZE))
		var yaw := atan2(-delta.z, delta.x)
		out.add(PLANK_RAILING,
			Transform3D(Basis(Vector3.UP, yaw), (a + b) * 0.5),
			Color.WHITE, StringName("public-guard/%s" % segment.stable_key))
	assert(out.validate())
	return out


static func production_surface_bundle(plan: PublicRealmSurfacePlan) \
		-> EnvironmentInstancePayload:
	## Production adapter: plank instances plus the sealed plan's generated
	## stair/ramp meshes in one streamable payload. Patch skins stay review
	## diagnostics; only collision-bearing transition geometry may stream, so a
	## STAIR claim can never remain an invisible hole between plank runs.
	var out := production_surface_payload(plan)
	if plan == null or not plan.is_sealed():
		return out
	for mesh: Dictionary in plan.mesh_payloads:
		if not bool(mesh.get("is_transition", false)):
			continue
		var entry := mesh.duplicate(true)
		var claim_cells := entry.get("claim_cells", []) as Array
		assert(not claim_cells.is_empty())
		var first_cell := claim_cells[0] as Vector3i
		entry["anchor"] = (Vector3(first_cell) + Vector3(0.5, 0.0, 0.5)) \
			* FabricRecipe.CELL_SIZE
		entry["stable_id"] = StringName("public-transition/%s" \
			% StringName(mesh.get("stable_id", "")))
		out.add_surface_mesh(entry)
	assert(out.validate())
	return out


static func _append_plank_tiles(out: EnvironmentInstancePayload,
		cells: Array[Vector3i], kind: int) -> void:
	var pending: Dictionary = {}
	for cell: Vector3i in cells:
		pending[cell] = true
	for cell: Vector3i in cells:
		if not pending.has(cell):
			continue
		var east := cell + Vector3i.RIGHT
		var south := cell + Vector3i.BACK
		var southeast := east + Vector3i.BACK
		if pending.has(east) and pending.has(south) and pending.has(southeast):
			_add_plank_tile(out, PLANK_FLOOR,
				Vector3(cell) + Vector3(0.5, 0.0, 0.5), 0, kind)
			pending.erase(cell)
			pending.erase(east)
			pending.erase(south)
			pending.erase(southeast)
		elif pending.has(east):
			_add_plank_tile(out, PLANK_GALLERY,
				Vector3(cell) + Vector3(0.5, 0.0, 0.0), 0, kind)
			pending.erase(cell)
			pending.erase(east)
		elif pending.has(south):
			_add_plank_tile(out, PLANK_GALLERY,
				Vector3(cell) + Vector3(0.0, 0.0, 0.5), 1, kind)
			pending.erase(cell)
			pending.erase(south)
		else:
			# The reviewed 1.5 m deck module closes odd residual cells without
			# scaling a 3 m floor or exposing the plain diagnostic underlay. Its
			# authored pivot lies on the local +X seam, hence the half-cell pivot
			# correction in _add_plank_tile().
			_add_plank_tile(out, PLANK_SINGLE, Vector3(cell), 0, kind)
			pending.erase(cell)


static func _add_plank_tile(out: EnvironmentInstancePayload,
		asset_id: StringName, lattice_center: Vector3, yaw_quarters: int,
		kind: int) -> void:
	var world_origin := lattice_center * FabricRecipe.CELL_SIZE
	world_origin.y += PLANK_Y_OFFSET
	var basis := Basis(Vector3.UP, float(yaw_quarters) * PI * 0.5)
	if asset_id == PLANK_SINGLE:
		world_origin += basis * Vector3(FabricRecipe.CELL_SIZE * 0.5, 0, 0)
	var transform := Transform3D(basis, world_origin)
	var stable_id := StringName("public-surface/%d/%d/%d/%d/%s" % [kind,
		roundi(lattice_center.x * 2.0), roundi(lattice_center.y * 2.0),
		roundi(lattice_center.z * 2.0), asset_id])
	out.add(asset_id, transform, Color.WHITE, stable_id)


static func _commit_surfaces(parent: Node3D, plan: PublicRealmSurfacePlan,
		include_collision: bool) -> Dictionary:
	assert(plan != null and plan.is_sealed())
	var root := Node3D.new()
	root.name = "PublicRealmSurfaces"
	parent.add_child(root)
	var collision_body: StaticBody3D
	if include_collision:
		collision_body = StaticBody3D.new()
		collision_body.name = "PublicRealmCollision"
		root.add_child(collision_body)
	var triangle_count := 0
	var collision_piece_count := 0
	var payloads: Array[Dictionary] = []
	payloads.assign(plan.mesh_payloads)
	if not plan.guard_mesh_payload.is_empty():
		payloads.append(plan.guard_mesh_payload)
	for payload: Dictionary in payloads:
		var vertices := payload.vertices as PackedVector3Array
		var indices := payload.indices as PackedInt32Array
		if vertices.is_empty() or indices.is_empty():
			continue
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = payload.normals as PackedVector3Array
		arrays[Mesh.ARRAY_TEX_UV] = payload.uvs as PackedVector2Array
		arrays[Mesh.ARRAY_INDEX] = indices
		var kind := int(payload.kind)
		# Structural courts, bridges, and guards are completely covered by the
		# reviewed authored plank/rail payload above. Rendering their generated
		# collision underlay through the gaps between boards produced the dark,
		# rectangular "platform texture" seen in review captures. Keep the exact
		# union as collision authority, but do not draw that duplicate skin.
		var render_underlay := renders_generated_surface_underlay(kind)
		var instance_name := "Surface_%s" % _surface_kind_name(kind)
		if render_underlay:
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			mesh.surface_set_material(0, _surface_material(kind))
			var instance := MeshInstance3D.new()
			instance.name = instance_name
			instance.mesh = mesh
			root.add_child(instance)
		triangle_count += indices.size() / 3
		if include_collision:
			var faces := payload.collision_faces as PackedVector3Array
			if not faces.is_empty():
				var shape := ConcavePolygonShape3D.new()
				shape.set_faces(faces)
				var shape_node := CollisionShape3D.new()
				shape_node.name = "%sCollision" % instance_name
				shape_node.shape = shape
				collision_body.add_child(shape_node)
				collision_piece_count += 1
	return {
		"triangle_count": triangle_count,
		"collision_piece_count": collision_piece_count,
	}


static func renders_generated_surface_underlay(kind: int) -> bool:
	## Authored plank modules completely cover structural courts and bridges.
	## Their generated union remains collision authority but must not peek
	## through board seams as a dark duplicate skin. Guards likewise have no
	## horizontal diagnostic underlay.
	return kind != PublicRealmSurfacePlan.SurfaceKind.STRUCTURAL_COURT \
		and kind != PublicRealmSurfacePlan.SurfaceKind.BRIDGE and kind != -1


static func _surface_material(kind: int) -> Material:
	# Surface union UVs are world-continuous and must not sample a source asset's
	# atlas as though they were authored mesh UVs. Deliberate flat materials keep
	# closure readable now; a future dedicated tiling plank material can replace
	# this without changing topology or geometry.
	if kind == PublicRealmSurfacePlan.SurfaceKind.STAIR:
		return _transition_plank_material()
	var material := StandardMaterial3D.new()
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	match kind:
		PublicRealmSurfacePlan.SurfaceKind.TERRAIN_STREET:
			# Ground streets are diagnostic dirt in the isolated review scene, not
			# timber platforms. Lit like every neighbouring surface so review
			# captures show the same light/shadow the streamed town has.
			material.albedo_color = Color("cbb584")
		PublicRealmSurfacePlan.SurfaceKind.INTERIOR_PASSAGE:
			material.albedo_color = Color("765b3b")
		PublicRealmSurfacePlan.SurfaceKind.BRIDGE:
			material.albedo_color = Color("9a7044")
		-1:
			material.albedo_color = Color("69472c")
		_:
			material.albedo_color = Color("a98050")
	return material


static func _transition_plank_material() -> Material:
	## Ramps and stair flights are one continuous generated collision surface, so
	## fixed horizontal deck meshes cannot represent them. A world-stable board
	## pattern gives that exact sloped surface a deliberate timber finish without
	## stretching an asset or letting render geometry redefine traversal.
	## The swatch pair matches the SFV plank atlas, alternating per board, with a
	## muted seam instead of a near-black groove. The constants are authored as
	## sRGB display colours, but ALBEDO is a linear-light input: writing them raw
	## desaturated every transition to ivory ("white walkways"), so they pass
	## through srgb_to_linear first. Boards are lit like the plank assets around
	## them; the old near-black lit look was the (since fixed) top-face winding.
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_disabled;

vec3 srgb_to_linear(vec3 srgb) {
	return pow(srgb, vec3(2.2));
}

void fragment() {
	vec2 board_uv = UV * vec2(3.0, 2.0);
	vec2 within = fract(board_uv);
	float seam = max(step(0.94, within.x), step(0.94, within.y));
	float alternate = mod(floor(board_uv.x) + floor(board_uv.y), 2.0);
	vec3 board_a = srgb_to_linear(vec3(0.718, 0.549, 0.361));
	vec3 board_b = srgb_to_linear(vec3(0.647, 0.494, 0.325));
	vec3 timber = mix(board_a, board_b, alternate);
	ALBEDO = mix(timber, srgb_to_linear(vec3(0.51, 0.38, 0.25)), seam);
	ROUGHNESS = 1.0;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


static func _surface_kind_name(kind: int) -> String:
	match kind:
		PublicRealmSurfacePlan.SurfaceKind.TERRAIN_STREET:
			return "TerrainStreet"
		PublicRealmSurfacePlan.SurfaceKind.STRUCTURAL_COURT:
			return "StructuralCourt"
		PublicRealmSurfacePlan.SurfaceKind.INTERIOR_PASSAGE:
			return "InteriorPassage"
		PublicRealmSurfacePlan.SurfaceKind.BRIDGE:
			return "Bridge"
		-1:
			return "DerivedGuards"
		_:
			return "Unknown"
