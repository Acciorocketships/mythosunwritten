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
const PLANK_Y_OFFSET := -0.12


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
	## The hill a house stands on when it stops descending at its terrace
	## (WarrenParcelConstruction.retained_terrace_cells). Same authored 3 m rock
	## module low_retaining_payload uses for a one-band court, STACKED rather
	## than stretched, so an eight-band hill is four modules and no asset is
	## scaled. Without it a short house on a high terrace floats: nothing else
	## in the fabric renders unbuilt source mass.
	var out := EnvironmentInstancePayload.new()
	if plan == null:
		return out
	return retaining_walls(plan.retained_terrace_cells,
		plan.transformed_cells(&"solid"))


static func retaining_walls(retained: Dictionary,
		solids: Dictionary) -> EnvironmentInstancePayload:
	## Stone on every lateral face of `retained` that neither the hill itself
	## nor a building already closes; nothing on the top, which is what the
	## house sits on. Faces are grouped into vertical runs first, so a run is
	## tiled by whole modules from its top down and the lowest one buries its
	## remainder exactly as the one-band court does -- never two coplanar
	## modules on the same face.
	##
	## Pure function of two integer cell sets, and every loop runs over a sorted
	## key list, so the payload is byte-identical for identical input.
	var out := EnvironmentInstancePayload.new()
	var runs: Dictionary = {}
	var cells: Array[Vector3i] = []
	cells.assign(retained.keys())
	cells.sort_custom(_cell_before)
	for cell: Vector3i in cells:
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT,
				Vector3i.FORWARD, Vector3i.BACK]:
			var neighbor := cell + direction
			if retained.has(neighbor) or solids.has(neighbor):
				continue
			var key := Vector4i(cell.x, cell.z, direction.x, direction.z)
			if not runs.has(key):
				runs[key] = {}
			(runs[key] as Dictionary)[cell.y] = true
	var keys: Array[Vector4i] = []
	keys.assign(runs.keys())
	keys.sort_custom(func(a: Vector4i, b: Vector4i) -> bool:
		if a.x != b.x:
			return a.x < b.x
		if a.y != b.y:
			return a.y < b.y
		if a.z != b.z:
			return a.z < b.z
		return a.w < b.w)
	for key: Vector4i in keys:
		var bands: Array[int] = []
		bands.assign((runs[key] as Dictionary).keys())
		bands.sort()
		var direction := Vector3i(key.z, 0, key.w)
		var index := 0
		while index < bands.size():
			var last := index
			while last + 1 < bands.size() and bands[last + 1] == bands[last] + 1:
				last += 1
			_stack_retaining_run(out, Vector2i(key.x, key.y), direction,
				bands[index], bands[last] + 1)
			index = last + 1
	assert(out.validate())
	return out


static func _stack_retaining_run(out: EnvironmentInstancePayload,
		column: Vector2i, direction: Vector3i, floor_band: int,
		ceiling_band: int) -> void:
	## Fixed 3 m modules from the run's top downward. The last one may reach
	## below the run, which buries it in the terrain or the mass beneath -- the
	## same half-burial the one-band court already relies on, and the reason no
	## module is ever scaled to fit.
	var yaw := PI * 0.5 if direction.x != 0 else 0.0
	var top := ceiling_band
	while top > floor_band:
		var midpoint := Vector3(float(column.x), 0.0, float(column.y)) \
			* FabricRecipe.CELL_SIZE \
			+ Vector3(direction) * FabricRecipe.CELL_SIZE * 0.5
		midpoint.y = float(top) * FabricRecipe.CELL_SIZE - 3.0
		out.add(LOW_RETAINING_WALL,
			Transform3D(Basis(Vector3.UP, yaw), midpoint), Color.WHITE,
			StringName("terrace-wall/%d/%d/%d/%d/%d" % [column.x, column.y,
				direction.x, direction.z, top]))
		top -= 2


static func _cell_before(left: Vector3i, right: Vector3i) -> bool:
	if left.y != right.y:
		return left.y < right.y
	if left.z != right.z:
		return left.z < right.z
	return left.x < right.x


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
