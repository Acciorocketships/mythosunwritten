extends GutTest

const FoldedProof = preload("res://tests/fixtures/warren_folded_proof.gd")
var _compiled_program: SettlementFabricProgram
var _folded_plan: SettlementFabricPlan


func _program() -> SettlementFabricProgram:
	if _compiled_program == null:
		_compiled_program = SettlementFabricProgram.compile(
			EnvironmentCatalog.load_default())
	return _compiled_program


func _folded_proof() -> SettlementFabricPlan:
	if _folded_plan == null:
		_folded_plan = FoldedProof.solve(_program())
	return _folded_plan


func _route_specs() -> Array[Dictionary]:
	return [
		SettlementFabricSolver.unit_spec(&"route.entry", &"route.landing",
			Vector3i.ZERO),
		SettlementFabricSolver.unit_spec(&"route.east", &"route.corner",
			Vector3i(2, 0, 0), 0, [], [
				FabricUnit.bond(&"walk.west", &"route.entry", &"walk.east"),
			]),
		SettlementFabricSolver.unit_spec(&"route.north", &"route.corner",
			Vector3i(2, 0, -2), 0, [], [
				FabricUnit.bond(&"walk.south", &"route.east", &"walk.north"),
			]),
	]


func _route_plan() -> SettlementFabricPlan:
	var program := _program()
	return SettlementFabricSolver.new(program).solve_authored(
		&"warren.test.route", _route_specs())


func _party_wall_suppression(complete: bool) -> Array[StringName]:
	var grid := WarrenSpatialGrid.new(Vector3i(-4, 0, -4),
		Vector3i(9, 4, 9))
	var room := WarrenRoomStamp.new(&"room", &"parcel", &"building",
		Vector3i.ZERO, 0, 0, true, false)
	var room_cells := WarrenRoomStamp.expected_private_cells(&"building",
		Vector3i.ZERO, 0)
	assert_true(room.add_private_cells(room_cells))
	var neighbor_cells: Array[Vector3i] = []
	for y in WarrenSpatialGrid.STOREY_CELLS:
		for x in [-2, -1]:
			neighbor_cells.append(Vector3i(x, y, 2))
	var transaction := grid.begin_transaction(&"party-wall")
	assert_true(transaction.assign_use(room_cells,
		WarrenSpatialGrid.Use.PRIVATE_VOLUME, &"building.a"))
	assert_true(transaction.assign_use(neighbor_cells,
		WarrenSpatialGrid.Use.PRIVATE_VOLUME, &"building.b"))
	for index in neighbor_cells.size():
		if not complete and index == neighbor_cells.size() - 1:
			continue
		var neighbor := neighbor_cells[index]
		assert_true(transaction.claim_face(neighbor + Vector3i.FORWARD,
			Vector3i.BACK, WarrenSpatialGrid.FaceKind.PARTY_WALL, &"joint"))
	assert_true(transaction.commit(), transaction.last_rejection)
	assert_true(room.seal(grid, &"building.a"), room.last_rejection)
	assert_true(grid.seal())
	return WarrenSpatialFabricCompiler._suppressed_party_wall_placements(
		grid, room, _program().recipe(&"room.base.rock"))


func _sectional_route() -> SectionalPublicRealmPlan:
	var realm := SectionalPublicRealmPlan.new(&"warren.test.sectional.realm")
	var entry_cells := FabricRecipe.box_cells(Vector3i(-1, 0, -1),
		Vector3i(2, 1, 2))
	var turn_cells := FabricRecipe.box_cells(Vector3i(1, 0, -1),
		Vector3i(2, 1, 2))
	var exit_cells := FabricRecipe.box_cells(Vector3i(1, 0, -3),
		Vector3i(2, 1, 2))
	var nodes: Array[PublicRealmNode] = [
		PublicRealmNode.new(&"episode.entry", PublicRealmNode.EpisodeKind.STREET,
			PublicRealmSurfacePlan.SurfaceKind.TERRAIN_STREET,
			PublicRealmNode.AirRealm.EXTERIOR,
			PublicRealmNode.CoverPolicy.OPEN, entry_cells,
			_air_for_surfaces(entry_cells), 0, 0, true, true),
		PublicRealmNode.new(&"episode.turn", PublicRealmNode.EpisodeKind.UNDERCROFT,
			PublicRealmSurfacePlan.SurfaceKind.TERRAIN_STREET,
			PublicRealmNode.AirRealm.EXTERIOR,
			PublicRealmNode.CoverPolicy.COVERED, turn_cells,
			_air_for_surfaces(turn_cells), 0, 0, true),
		PublicRealmNode.new(&"episode.exit", PublicRealmNode.EpisodeKind.TERRACE,
			PublicRealmSurfacePlan.SurfaceKind.TERRAIN_STREET,
			PublicRealmNode.AirRealm.EXTERIOR,
			PublicRealmNode.CoverPolicy.OPEN, exit_cells,
			_air_for_surfaces(exit_cells), 0, 0, true),
	]
	for node_value: PublicRealmNode in nodes:
		assert_true(node_value.seal())
		assert_true(realm.add_node(node_value))
	var first := PublicRealmEdge.new(&"edge.entry.turn", &"episode.entry",
		&"episode.turn", PublicRealmEdge.TransitionKind.LEVEL)
	first.add_seam(Vector3i(0, 0, -1), Vector3i(1, 0, -1))
	first.add_seam(Vector3i(0, 0, 0), Vector3i(1, 0, 0))
	assert_true(realm.add_edge(first))
	var second := PublicRealmEdge.new(&"edge.turn.exit", &"episode.turn",
		&"episode.exit", PublicRealmEdge.TransitionKind.LEVEL)
	second.add_seam(Vector3i(1, 0, -1), Vector3i(1, 0, -2))
	second.add_seam(Vector3i(2, 0, -1), Vector3i(2, 0, -2))
	assert_true(realm.add_edge(second))
	realm.set_primary_itinerary([
		&"episode.entry", &"episode.turn", &"episode.exit",
	])
	for node_value: PublicRealmNode in nodes:
		for cell: Vector3i in node_value.surface_cells:
			realm.require_classification(cell)
	realm.require_classification(Vector3i(0, 1, -2))
	realm.add_daylight_void(Vector3i(0, 1, -2))
	assert_true(realm.seal(), realm.last_rejection)
	return realm


func _air_for_surfaces(cells: Array[Vector3i]) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for cell: Vector3i in cells:
		out.append(cell)
		out.append(cell + Vector3i.UP)
	return out


func test_surface_audit_distinguishes_narrow_gallery_from_broad_plaza() -> void:
	var gallery := PublicRealmSurfacePlan.new(&"test.gallery")
	for z in 8:
		for x in 2:
			assert_true(gallery.add_claim(Vector3i(x, 2, z),
				PublicRealmSurfacePlan.SurfaceKind.STRUCTURAL_COURT,
				&"gallery"))
	assert_eq(int(gallery.audit().structural_court_interior_cell_count), 0,
		"a long two-lane route is path-like even when its total area is large")
	var plaza := PublicRealmSurfacePlan.new(&"test.plaza")
	for z in 4:
		for x in 4:
			assert_true(plaza.add_claim(Vector3i(x, 2, z),
				PublicRealmSurfacePlan.SurfaceKind.STRUCTURAL_COURT,
				&"plaza"))
	assert_eq(int(plaza.audit().structural_court_interior_cell_count), 4,
		"a broad empty floor has an interior independent of its perimeter")


func test_structural_support_rhythm_anchors_corners_and_native_edge_pitch() \
		-> void:
	assert_true(SettlementFabricAssembler._is_structural_support_anchor(
		Vector3i(3, 4, 5), [Vector3i.LEFT, Vector3i.FORWARD] \
			as Array[Vector3i]), "every exposed corner needs a post")
	assert_true(SettlementFabricAssembler._is_structural_support_anchor(
		Vector3i(3, 4, 6), [Vector3i.LEFT] as Array[Vector3i]),
		"a north/south edge repeats supports every two fine cells")
	assert_false(SettlementFabricAssembler._is_structural_support_anchor(
		Vector3i(3, 4, 5), [Vector3i.LEFT] as Array[Vector3i]))


func test_every_modular_room_shell_has_four_symmetric_corner_posts() -> void:
	var program := _program()
	for recipe_id: StringName in [
		&"room.base.rock", &"room.tower.base.rock",
		&"room.slim.base.rock", &"room.row.base.rock",
		&"room.long.base.rock", &"room.pier.base.rock",
	]:
		var recipe_value := program.recipe(recipe_id)
		assert_not_null(recipe_value, "missing modular recipe %s" % recipe_id)
		if recipe_value == null:
			continue
		var posts := SettlementFabricAssembler \
			._modular_room_corner_transforms(recipe_value)
		assert_eq(posts.size(), 4,
			"%s needs one explicit timber post at every corner" % recipe_id)
		var positions: Dictionary = {}
		for post: Transform3D in posts:
			var origin := post.origin
			positions[Vector2(origin.x, origin.z)] = true
		assert_eq(positions.size(), 4,
			"corner framing may not double one side and omit the other")


func test_named_upper_courtyard_uses_distinct_collision_aligned_paving() \
		-> void:
	var surfaces := PublicRealmSurfacePlan.new(&"test.named.courtyard")
	for z in 4:
		for x in 4:
			assert_true(surfaces.add_claim(Vector3i(x, 4, z),
				PublicRealmSurfacePlan.SurfaceKind.STRUCTURAL_COURT,
				StringName("volume.courtyard.%02d" % (z * 4 + x))))
	assert_true(surfaces.seal(), surfaces.last_rejection)
	assert_eq(surfaces.cells_owned_by_prefix("volume.courtyard.").size(), 16)
	var payload := SettlementFabricAssembler.surface_visual_payload(surfaces)
	assert_true(payload.validate())
	assert_true(payload.batches.has(SettlementFabricAssembler.PLANK_SINGLE))
	var transforms := (payload.batches[SettlementFabricAssembler.PLANK_SINGLE] \
		as Dictionary).transforms as Array
	assert_eq(transforms.size(), 16)
	var visual_centres: Dictionary = {}
	for transform: Transform3D in transforms:
		# The S-floor source pivot sits 0.75 m beyond its mesh centre on local
		# +X. Verify the realised board centre, not merely its transform origin.
		var centre := transform.origin \
			+ transform.basis * Vector3(-0.75, 0.0, 0.0)
		visual_centres[Vector3i(roundi(centre.x / FabricRecipe.CELL_SIZE - 0.5),
			roundi(centre.y / FabricRecipe.CELL_SIZE),
			roundi(centre.z / FabricRecipe.CELL_SIZE - 0.5))] = true
	assert_eq(visual_centres.size(), 16,
		"every courtyard board must centre on a distinct logical floor cell")
	for z in 4:
		for x in 4:
			assert_true(visual_centres.has(Vector3i(x, 4, z)))
	assert_false(payload.batches.has(SettlementFabricAssembler.PLANK_FLOOR),
		"the named court must not be hidden beneath ordinary broad deck tiles")
	assert_true(payload.batches.has(SettlementFabricAssembler.COURTYARD_PLANTER))
	var planter_batch := payload.batches[
		SettlementFabricAssembler.COURTYARD_PLANTER] as Dictionary
	assert_eq((planter_batch.transforms as Array).size(), 2,
		"two perimeter planters make the open-air court legible without " \
		+ "blocking its clear centre")
	for transform: Transform3D in planter_batch.transforms as Array:
		var cell := Vector3i(floori(transform.origin.x / FabricRecipe.CELL_SIZE),
			4, floori(transform.origin.z / FabricRecipe.CELL_SIZE))
		assert_true(surfaces.has_cell(cell),
			"courtyard furniture must stand on the sealed court union")
	var paving_colors := (payload.batches[
		SettlementFabricAssembler.PLANK_SINGLE] as Dictionary).colors as Array
	var unique_paving_colors: Dictionary = {}
	for color: Color in paving_colors:
		unique_paving_colors[color] = true
	assert_eq(unique_paving_colors.size(), 2,
		"courtyard paving must differ visibly from an ordinary timber gallery")


func test_irregular_upper_courtyard_furniture_never_uses_a_missing_aabb_corner() \
		-> void:
	var surfaces := PublicRealmSurfacePlan.new(&"test.irregular.courtyard")
	var court_cells: Array[Vector3i] = []
	for z in 4:
		for x in 4:
			if x >= 2 and z >= 2:
				continue
			var cell := Vector3i(x, 4, z)
			court_cells.append(cell)
			assert_true(surfaces.add_claim(cell,
				PublicRealmSurfacePlan.SurfaceKind.STRUCTURAL_COURT,
				&"volume.courtyard.rooftop.test"))
	assert_true(surfaces.seal(), surfaces.last_rejection)
	var payload := SettlementFabricAssembler.surface_visual_payload(surfaces)
	var planter_batch := payload.batches[
		SettlementFabricAssembler.COURTYARD_PLANTER] as Dictionary
	assert_eq((planter_batch.transforms as Array).size(), 2)
	for transform: Transform3D in planter_batch.transforms as Array:
		var cell := Vector3i(floori(transform.origin.x / FabricRecipe.CELL_SIZE),
			4, floori(transform.origin.z / FabricRecipe.CELL_SIZE))
		assert_true(court_cells.has(cell),
			"an L-shaped court may never furnish its absent bounding-box corner")


func test_surface_audit_detects_plaza_split_across_public_claim_kinds() -> void:
	var surfaces := PublicRealmSurfacePlan.new(&"test.mixed_plaza")
	for z in 4:
		for x in 4:
			var kind := PublicRealmSurfacePlan.SurfaceKind.TERRAIN_STREET \
				if x < 2 else PublicRealmSurfacePlan.SurfaceKind.STRUCTURAL_COURT
			assert_true(surfaces.add_claim(Vector3i(x, 0, z), kind,
				&"mixed.owner"))
	assert_eq(int(surfaces.audit().structural_court_interior_cell_count), 0,
		"neither claim family alone contains a plaza interior")
	assert_eq(int(surfaces.audit().exterior_public_interior_cell_count), 4,
		"the combined exterior public floor must still expose the plaza")
	assert_eq(int(surfaces.audit().max_exterior_public_interior_component_size),
		4, "the broad interior is one connected plaza rather than scattered turns")


func _sectional_route_specs() -> Array[Dictionary]:
	return [
		SettlementFabricSolver.unit_spec(&"route.entry", &"route.landing",
			Vector3i.ZERO, 0, [], [], &"episode.entry"),
		SettlementFabricSolver.unit_spec(&"route.east", &"route.corner",
			Vector3i(2, 0, 0), 0, [], [
				FabricUnit.bond(&"walk.west", &"route.entry", &"walk.east"),
			], &"episode.turn"),
		SettlementFabricSolver.unit_spec(&"route.north", &"route.corner",
			Vector3i(2, 0, -2), 0, [], [
				FabricUnit.bond(&"walk.south", &"route.east", &"walk.north"),
			], &"episode.exit"),
	]


func test_program_compiles_one_common_recipe_vocabulary() -> void:
	var program := _program()
	var catalog := EnvironmentCatalog.load_default()
	assert_not_null(program)
	assert_not_null(program.recipe(&"route.landing"))
	assert_not_null(program.recipe(&"room.base.rock"))
	assert_null(program.recipe(&"room.bay.base.rock"),
		"a wide, shallow mass is an attachment, never a standalone house recipe")
	assert_null(program.recipe(&"roof.bay.blue"))
	assert_not_null(program.recipe(&"room.stair_house.blue"))
	var balcony := program.recipe(&"balcony.bracketed.left.blue.planted")
	assert_not_null(balcony)
	assert_true(balcony.asset_ids().has(SettlementFabricProgram.ROOF_PLANTER))
	assert_true(balcony.asset_ids().has(SettlementFabricProgram.ROOF_FLOWER_TALL),
		"balcony vegetation must remain inside the measured recipe")
	assert_eq(balcony.walk_cells.size(), 4,
		"a compact private walk-out owns one continuous 6 m deck")
	assert_eq(balcony.headroom_cells.size(), 8)
	assert_false(balcony.socket(&"room.back").is_empty(),
		"the walk-out is entered through one exact parent-room portal")
	var balcony_socket_x := (balcony.socket(&"room.back").cell as Vector3i).x
	assert_gte(balcony_socket_x + 2, 1)
	assert_gte(1 - balcony_socket_x, 1,
		"the door bay needs one full cell of clearance from both side guards")
	assert_true(balcony.socket(&"stair.high").is_empty())
	assert_true(balcony.socket(&"stair.low").is_empty(),
		"the compact walk-out must not advertise a stair that reaches no floor")
	assert_eq(balcony.placements.filter(func(placement: Dictionary) -> bool:
		return String(placement.id).begins_with("guard.")).size(), 4,
		"the outer and side perimeter is completely guarded")
	assert_eq(balcony.placements.filter(func(placement: Dictionary) -> bool:
		return placement.asset_id == SettlementFabricProgram.RAILING_MEDIUM
	).size(), 2, "the 6 m front guard uses two complete authored runs")
	assert_eq(balcony.placements.filter(func(placement: Dictionary) -> bool:
		return String(placement.id).begins_with("brace.")).size(), 4,
		"the overhang remains visibly bracket-supported")
	var deep_balcony := program.recipe(
		&"balcony.walkout.deep.left.blue.planted")
	assert_not_null(deep_balcony)
	assert_true(deep_balcony.has_tag(&"deep_walkout"))
	assert_true(deep_balcony.has_tag(&"diagonal_support"))
	assert_eq(deep_balcony.walk_cells.size(), 8,
		"the preferred walk-out keeps the rail two cells from the door")
	assert_eq(deep_balcony.headroom_cells.size(), 16)
	assert_eq(deep_balcony.placements.filter(func(placement: Dictionary) -> bool:
		return String(placement.id).begins_with("guard.")).size(), 6,
		"the deep deck closes its outer edge and both two-cell returns")
	assert_eq(deep_balcony.placements.filter(func(placement: Dictionary) -> bool:
		return placement.asset_id == SettlementFabricProgram.RAILING_MEDIUM
	).size(), 2, "the 6 m front guard uses two complete authored runs")
	assert_eq(deep_balcony.placements.filter(func(placement: Dictionary) -> bool:
		return String(placement.id).begins_with("support.diagonal.")).size(), 4,
		"the deeper projection needs legible full-storey diagonal supports")
	var market := program.recipe(&"market.covered.01.garden")
	assert_not_null(market)
	assert_true(market.asset_ids().has(SettlementFabricProgram.ROOF_FLOWER_SMALL))
	assert_true(market.asset_ids().has(SettlementFabricProgram.ROOF_FLOWER_PALE))
	var awning_market := program.recipe(&"market.covered.05.garden")
	assert_not_null(awning_market)
	assert_true(awning_market.asset_ids().has(
		SettlementFabricProgram.ROOF_TERRACE_AWNING),
		"the full framed awning belongs to a measured covered bazaar")
	var micro := program.recipe(&"room.micro.terrain.blue")
	assert_not_null(micro)
	assert_eq(micro.entrances.size(), 1,
		"a visible micro-house door must be a real circulation address")
	assert_gt(micro.headroom_cells.size(), 0)
	assert_gt(micro.inhabited_cells.size(), 0)
	assert_gt(micro.local_bounds.size.z, micro.local_bounds.size.x,
		"the smallest standalone house must render narrow/deep, never sideways")
	assert_almost_eq(micro.local_bounds.size.z, 6.486891, 0.001)
	assert_almost_eq(micro.local_bounds.size.x, 3.468661, 0.001)
	var slim_base := program.recipe(&"room.slim.base.rock")
	var slim_upper := program.recipe(&"room.slim.upper.address.blue")
	var slim_roof := program.recipe(&"roof.slim.blue")
	assert_not_null(slim_base)
	assert_not_null(slim_upper)
	assert_not_null(slim_roof)
	var stone_upper := program.recipe(&"room.slim.upper.address.stone")
	assert_not_null(stone_upper)
	assert_eq(stone_upper.entrances.size(), 1)
	assert_true(stone_upper.has_tag(&"room"))
	assert_false(stone_upper.has_tag(&"terrain_bearing"),
		"masonry is a facade construction family, not permission for an upper room to bear on terrain")
	assert_gt(slim_base.local_bounds.size.z, slim_base.local_bounds.size.x,
		"stackable infill must remain narrow/deep in its canonical frame")
	assert_eq(slim_upper.entrances.size(), 1)
	assert_true(slim_roof.has_tag(&"roof"))
	assert_true(slim_roof.has_tag(&"ridge_z"))
	assert_gt(slim_roof.local_bounds.size.z, slim_roof.local_bounds.size.x,
		"the townhouse roof ridge must follow its long parcel axis")
	assert_gt(slim_roof.placements.size(), 0,
		"a narrow townhouse still terminates in a real pitched roof")
	assert_not_null(program.recipe(&"stair.facade.full.terrain.orange"))
	assert_not_null(program.recipe(&"court.supported.12x6"))
	assert_not_null(program.recipe(&"outcrop.blue"))
	var corner_left := program.recipe(&"outcrop.corner.left.blue")
	var corner_right := program.recipe(&"outcrop.corner.right.blue")
	assert_not_null(corner_left)
	assert_not_null(corner_right)
	assert_true(corner_left.has_tag(&"corner_outcropping"))
	assert_true(corner_right.has_tag(&"corner_outcropping"))
	assert_ne(corner_left.socket(&"room.back").cell,
		corner_right.socket(&"room.back").cell,
		"opposite corner bays must frame into opposite halves of the facade")
	for outcrop: FabricRecipe in [corner_left, corner_right]:
		var roof_placements := 0
		var roof_asset_id := &""
		var left_wall := Vector3.INF
		var right_wall := Vector3.INF
		for placement: Dictionary in outcrop.placements:
			if String(placement.id).begins_with("roof"):
				roof_placements += 1
				roof_asset_id = StringName(placement.asset_id)
			elif StringName(placement.id) == &"left":
				left_wall = (placement.transform as Transform3D).origin
			elif StringName(placement.id) == &"right":
				right_wall = (placement.transform as Transform3D).origin
		assert_gt(roof_placements, 0,
			"every occupied projection must compile a real roof")
		assert_false(left_wall.is_equal_approx(Vector3.INF))
		assert_false(right_wall.is_equal_approx(Vector3.INF))
		assert_lte(absf(right_wall.x - left_wall.x), 3.1,
			"the textured side panels must close the one-module bay shell")
		assert_lte(outcrop.local_bounds.size.z, outcrop.local_bounds.size.x,
			"an outcropping is a shallow facade bay, not an independent room")
		# The clipped gable keeps the authored exterior end but terminates at its
		# exact three-metre party seam. Clearance may add only its normal tolerance.
		assert_lte(outcrop.local_bounds.size.z, 3.80,
			"occupied bays may not protrude an entire room depth from the parent")
		assert_eq(roof_asset_id,
			SettlementFabricProgram.COMPACT_ROOF_ORANGE_FRONT \
			if String(outcrop.recipe_id).ends_with("orange") \
			else SettlementFabricProgram.COMPACT_ROOF_SLATE_FRONT,
			"the bay roof must keep one exterior gable and one open party seam")
	for diagonal_id: StringName in [
		&"outcrop.corner.wrap.left.blue",
		&"outcrop.corner.wrap.right.blue",
		&"outcrop.corner.wrap.left.orange",
		&"outcrop.corner.wrap.right.orange",
		&"outcrop.corner.wrap.left.amber",
		&"outcrop.corner.wrap.right.amber",
	]:
		var diagonal := program.recipe(diagonal_id)
		assert_not_null(diagonal)
		assert_true(diagonal.has_tag(&"full_scale_diagonal_overlap"))
		assert_true(diagonal.has_tag(&"compound_union_shell"))
		assert_true(diagonal.has_tag(&"no_duplicate_overlap_shell"))
		assert_true(diagonal.has_tag(&"exterior_only_union_roof"))
		assert_eq(diagonal.solid_cells.size(), 6,
			"the exterior L owns three fine columns across two occupied bands")
		var union_cap_count := 0
		var union_pitch_count := 0
		for placement: Dictionary in diagonal.placements:
			union_cap_count += int(String(placement.id).begins_with("roof.cap."))
			union_pitch_count += int(String(placement.id).begins_with(
				"roof.pitch.") and String(placement.asset_id).ends_with(".trimmed"))
			assert_false(String(placement.asset_id).contains("roof.compact"),
				"the diagonal union may not intersect a second complete gable")
		assert_eq(union_cap_count, 0,
			"the occupied corner union may not expose a wooden tabletop")
		assert_eq(union_pitch_count, 2,
			"the exterior union closes under two opposed trimmed low pitches")
	for embedded_id: StringName in [
		&"outcrop.embedded.blue", &"outcrop.embedded.orange",
		&"outcrop.embedded.amber",
	]:
		var embedded := program.recipe(embedded_id)
		assert_not_null(embedded)
		assert_true(embedded.has_tag(&"embedded_oriel"))
		assert_true(embedded.has_tag(&"partial_extrusion"))
		assert_eq(embedded.solid_cells.size(), 2,
			"the oriel owns one half-width exterior column, not another room")
		for required_piece: StringName in [&"bay.face", &"bay.post.left",
				&"bay.post.right",
				&"bay.cheek.left",
				&"bay.cheek.right", &"bay.sill", &"bay.canopy",
				&"bay.corbel.left", &"bay.corbel.right"]:
			assert_true(embedded.placements.any(func(value: Dictionary) -> bool:
				return StringName(value.id) == required_piece))
		var front := embedded.placements.filter(func(value: Dictionary) -> bool:
			return StringName(value.id) == &"bay.face")[0] as Dictionary
		assert_true(String(front.asset_id).contains("wall.wood.window.s"),
			"the partial extrusion uses one normally proportioned window face")
		assert_true(embedded.has_tag(&"partial_height_bay"))
		var terminal_post := embedded.placements.filter(
			func(value: Dictionary) -> bool:
				return StringName(value.id) == &"bay.post.right")[0] as Dictionary
		assert_eq(StringName(terminal_post.asset_id),
			SettlementFabricProgram.PORTAL_JAMB)
		assert_lt(embedded.local_bounds.position.z, -0.75,
			"the bay must extend behind the parent facade plane")
		assert_gt(embedded.local_bounds.end.z, -0.75,
			"the same shell must project beyond the parent facade plane")
		assert_lt(embedded.local_bounds.size.x, 3.2,
			"the window bay must remain narrower than a generated room")
		assert_lte(embedded.local_bounds.end.z, 0.25,
			"the shallow oriel body and its measured trim must remain partial")
		assert_lt(embedded.local_bounds.size.z, 3.2,
			"the authored tiled eave may overhang, but not by a room depth")
	assert_not_null(program.recipe(&"outcrop.half.blue"))
	assert_not_null(program.recipe(&"skywalk.6.orange"))
	assert_not_null(program.recipe(&"anchor.prefab.00"))
	assert_eq(SettlementFabricProgram.PREFAB_ANCHORS.size(), 32,
		"the segmenter must see every visually distinct reviewed complete building")
	for index in 7:
		var house_id := StringName("lpfv.building.house.%02d" % (index + 1))
		var recipe_index := 10 + index
		assert_eq(SettlementFabricProgram.PREFAB_ANCHORS[recipe_index], house_id)
		assert_has(catalog.descriptor(house_id).tags, &"complete_house")
		var compact_recipe := program.recipe(StringName(
			"anchor.prefab.%02d" % recipe_index))
		assert_not_null(compact_recipe,
			"every reviewed compact complete house must be selectable as a whole building")
	for recipe_index in range(17, SettlementFabricProgram.PREFAB_ANCHORS.size()):
		var complete_id := SettlementFabricProgram.PREFAB_ANCHORS[recipe_index]
		var descriptor := catalog.descriptor(complete_id)
		assert_not_null(descriptor)
		assert_has(descriptor.tags, &"complete_building")
		assert_has(descriptor.tags, &"prefab_anchor")
		assert_not_null(program.recipe(StringName(
			"anchor.prefab.%02d" % recipe_index)))
	for index in SettlementFabricProgram.MARKET_STALLS.size():
		assert_not_null(program.recipe(StringName("market.stall.%02d" % index)))
		var market_asset := SettlementFabricProgram.MARKET_STALLS[index]
		assert_true(catalog.descriptor(market_asset).tags.has(&"stocked_market"),
			"the compiled market vocabulary may contain only reviewed populated prefabs")
	for empty_canopy: StringName in [
		&"sfm.stall.alchemy.001", &"sfm.stall.forge.001",
		&"sfm.stall.butcher.001", &"sfm.stall.butcher.003",
		&"sfm.stall.blue.007", &"sfm.stall.orange.006",
		&"sfm.stall.teal.008", &"sfm.stall.neutral.009",
	]:
		assert_false(SettlementFabricProgram.MARKET_STALLS.has(empty_canopy),
			"bare canopy/frame components must never masquerade as markets")
	for asset_id: StringName in program.referenced_asset_ids:
		assert_false(String(asset_id).begins_with("sfbp.tent"), String(asset_id))


func test_dormer_styles_keep_steep_gables_and_replace_the_weak_shell_with_sheds() -> void:
	var program := _program()
	for recipe_id: StringName in [
		&"roof.tower.blue.dormer.left",
		&"roof.slim.blue.dormer.left",
		&"roof.row.blue.dormer.left",
	]:
		var recipe := program.recipe(recipe_id)
		assert_not_null(recipe)
		assert_true(recipe.has_tag(&"authored_gabled_dormer"))
		assert_true(recipe.placements.any(func(placement: Dictionary) -> bool:
			return String(placement.id).contains("dormer") \
				and StringName(placement.asset_id) \
					== SettlementFabricProgram.ROOF_WINDOW_02),
			"the reviewed steep-sided gable is the retained gabled family")
	for recipe_id: StringName in [
		&"roof.tower.orange.dormer.right",
		&"roof.slim.orange.dormer.right",
		&"roof.row.orange.dormer.right",
	]:
		var recipe := program.recipe(recipe_id)
		assert_not_null(recipe)
		assert_true(recipe.has_tag(&"authored_shed_dormer"))
		assert_true(recipe.placements.any(func(placement: Dictionary) -> bool:
			return String(placement.id).contains("dormer") \
				and StringName(placement.asset_id) \
					== SettlementFabricProgram.ROOF_WINDOW_04),
			"the weaker shallow gable is replaced by the complete shed shell")


func test_addressed_room_vocabulary_has_two_exact_door_phases() -> void:
	var program := _program()
	assert_not_null(program)
	if program == null:
		return
	for base_id: StringName in [&"room.base.rock",
			&"room.slim.base.rock", &"room.row.base.rock",
			&"room.tower.base.rock",
			&"room.long.base.rock"]:
		var primary := program.recipe(base_id)
		var alternate := program.recipe(
			SettlementFabricProgram.address_door_phase_recipe_id(base_id, 1))
		assert_not_null(primary, String(base_id))
		assert_not_null(alternate, "%s alternate" % base_id)
		if primary == null or alternate == null:
			continue
		assert_eq(primary.entrances.size(), 1)
		assert_eq(alternate.entrances.size(), 1)
		var first := primary.entrances[0] as Dictionary
		var second := alternate.entrances[0] as Dictionary
		assert_eq(second.cell as Vector3i,
			(first.cell as Vector3i) + Vector3i.LEFT,
			"the second threshold must be the other half of one 3 m module")
		assert_eq(second.facing, first.facing)
		assert_eq(alternate.placements.size(), primary.placements.size(),
			"door phase may not add a facade overlay")
		for index in primary.placements.size():
			var primary_asset := StringName(primary.placements[index].asset_id)
			var expected_asset := primary_asset
			if SettlementFabricProgram.WOOD_DOORS.has(primary_asset) \
					or SettlementFabricProgram.ROCK_DOORS.has(primary_asset):
				expected_asset = StringName(String(primary_asset) + ".mirror_x")
			assert_eq(StringName(alternate.placements[index].asset_id),
				expected_asset,
				"phase B must move the visible aperture with baked handed geometry")
			assert_eq(alternate.placements[index].transform,
				primary.placements[index].transform)
		for y_offset in 2:
			var old_cell := (first.cell as Vector3i) + Vector3i.UP * y_offset
			var new_cell := (second.cell as Vector3i) + Vector3i.UP * y_offset
			assert_has(alternate.solid_cells, old_cell,
				"the unused threshold half must be a real wall")
			assert_does_not_have(alternate.occluder_cells, new_cell,
				"the selected threshold half must be an aperture")
			assert_has(alternate.headroom_cells, new_cell)


func test_rowhouse_is_one_broad_frontage_and_one_coherent_roof() -> void:
	var program := _program()
	var room := program.recipe(&"room.row.base.rock")
	var roof := program.recipe(&"roof.row.blue")
	assert_not_null(room)
	assert_not_null(roof)
	if room == null or roof == null:
		return
	assert_true(room.has_tag(&"row_building"))
	assert_eq((room.entrances[0] as Dictionary).cell, Vector3i(-1, 0, 0),
		"the rowhouse door belongs to its broad eave, not the narrow gable")
	assert_eq(room.placements.filter(func(placement: Dictionary) -> bool:
		return String(placement.id).begins_with("front.")).size(), 2,
		"two former towers must compile as one two-module street facade")
	assert_eq(WarrenRoomStamp.expected_private_cells(&"row", Vector3i.ZERO,
		0).size(), 16)
	assert_true(roof.has_tag(&"ridge_x"))
	assert_true(roof.has_tag(&"staggered_roof"))
	assert_eq(roof.placements.filter(func(placement: Dictionary) -> bool:
		return String(placement.id).begins_with("roof.")).size(), 2,
		"the complete row crown owns both staggered gables transactionally")
	assert_not_null(program.recipe(&"room.row.base.rock.door_b"))
	assert_not_null(program.recipe(&"room.row.base.rock.portal.4"),
		"a rowhouse may terminate an occupied link through its broad facade")


func test_module_contracts_pin_floor_facade_and_roof_datums() -> void:
	var program := _program()
	var catalog := EnvironmentCatalog.load_default()
	var room := program.recipe(&"room.base.rock")
	var floor_count := 0
	for placement: Dictionary in room.placements:
		var asset_id := StringName(placement.asset_id)
		var placed_bounds := (placement.transform as Transform3D) * \
			catalog.descriptor(asset_id).measured_aabb
		if asset_id == SettlementFabricProgram.FLOOR:
			floor_count += 1
			assert_almost_eq(placed_bounds.end.y, 0.0, 0.001,
				"every authored floor top is the logical walk plane")
		if StringName(placement.id) == &"front.0":
			assert_almost_eq(placed_bounds.end.z, 2.25, 0.001,
				"the measured facade outer face ends at the half-cell boundary")
	assert_eq(floor_count, 4, "a 6 m room has a complete two-by-two floor")
	assert_lte(room.local_bounds.size.x, 6.10)
	assert_lte(room.local_bounds.size.z, 6.10)

	var roof := program.recipe(&"roof.blue")
	assert_eq(roof.construction_runs.size(), 1)
	var run := roof.construction_runs[0]
	assert_eq(StringName(run.kind), &"roof")
	assert_eq((run.placement_ids as Array).size(), 6)
	assert_almost_eq(float(run.start_seam), -3.0, 0.001)
	assert_almost_eq(float(run.end_seam), 3.0, 0.001)
	assert_almost_eq(float(run.repeat_pitch), 3.0, 0.001)
	var roof_contract := program.module_program.contract(
		SettlementFabricProgram.ROOF_BLUE)
	assert_eq(roof_contract.pair_axis, Vector3i.RIGHT)
	assert_almost_eq(roof_contract.pair_offset, 1.6217227, 0.001)
	var roof_peak_y := -INF
	var gable_peak_y := -INF
	for placement: Dictionary in roof.placements:
		var descriptor := catalog.descriptor(StringName(placement.asset_id))
		var bounds := (placement.transform as Transform3D) * descriptor.measured_aabb
		if StringName(placement.asset_id) == SettlementFabricProgram.GABLE:
			gable_peak_y = maxf(gable_peak_y, bounds.end.y)
		else:
			assert_almost_eq(bounds.position.y, 0.0, 0.001,
				"every repeated roof shell sits on the logical wall-top plane")
			roof_peak_y = maxf(roof_peak_y, bounds.end.y)
	assert_almost_eq(gable_peak_y, roof_peak_y, 0.001,
		"gable closure peak and repeated roof ridge share one datum")
	for recipe_id: StringName in [&"roof.square.01", &"roof.square.05",
			&"roof.tower.blue", &"roof.slim.orange", &"roof.row.blue"]:
		var complete_roof := program.recipe(recipe_id)
		assert_not_null(complete_roof, String(recipe_id))
		if complete_roof == null:
			continue
		var shell_bearings: Array[float] = []
		for placement: Dictionary in complete_roof.placements:
			if not String(placement.id).begins_with("roof"):
				continue
			var descriptor := catalog.descriptor(StringName(placement.asset_id))
			var bounds := (placement.transform as Transform3D) * \
				descriptor.measured_aabb
			shell_bearings.append(bounds.position.y)
			assert_almost_eq(bounds.position.y, 0.0, 0.001,
				"%s has a roof shell lifted off its wall bearing" % recipe_id)
		if shell_bearings.size() > 1:
			assert_almost_eq(shell_bearings.min(), shell_bearings.max(), 0.001,
				"%s gives adjacent roof shells different datums" % recipe_id)
		if recipe_id == &"roof.slim.orange":
			var rear := complete_roof.placements.filter(
				func(value: Dictionary) -> bool:
					return StringName(value.id) == &"roof.rear")[0] as Dictionary
			var front := complete_roof.placements.filter(
				func(value: Dictionary) -> bool:
					return StringName(value.id) == &"roof.front")[0] as Dictionary
			var rear_bounds := (rear.transform as Transform3D) * catalog.descriptor(
				StringName(rear.asset_id)).measured_aabb
			var front_bounds := (front.transform as Transform3D) * catalog.descriptor(
				StringName(front.asset_id)).measured_aabb
			assert_almost_eq(rear_bounds.end.z, front_bounds.position.z, 0.001,
				"narrow-house roof ends must touch at one exact party seam")
			assert_almost_eq(rear_bounds.size.z, 3.0, 0.001)
			assert_almost_eq(front_bounds.size.z, 3.0, 0.001)
		if recipe_id == &"roof.row.blue":
			var left := complete_roof.placements.filter(
				func(value: Dictionary) -> bool:
					return StringName(value.id) == &"roof.left")[0] as Dictionary
			var right := complete_roof.placements.filter(
				func(value: Dictionary) -> bool:
					return StringName(value.id) == &"roof.right")[0] as Dictionary
			var left_bounds := (left.transform as Transform3D) * catalog.descriptor(
				StringName(left.asset_id)).measured_aabb
			var right_bounds := (right.transform as Transform3D) * catalog.descriptor(
				StringName(right.asset_id)).measured_aabb
			assert_almost_eq(left_bounds.end.x, right_bounds.position.x, 0.001,
				"row-house roof ends must touch at one exact party seam")
			assert_almost_eq(left_bounds.size.x, 3.0, 0.001)
			assert_almost_eq(right_bounds.size.x, 3.0, 0.001)
	assert_false(program.module_program.add_roof_run(
		FabricRecipe.new(&"bad.roof", [&"roof"], 0), &"bad.run",
		SettlementFabricProgram.ROOF_BLUE, SettlementFabricProgram.GABLE,
		Vector3.ZERO, 0.0, 0.0, 5.0),
		"a non-integral roof run is rejected instead of repaired with an offset")

	# The route recipe claims the two cell centres x=-1 and x=0, whose combined
	# corridor spans [-2.25, 0.75]. Both full and repeated half-flight visuals
	# must be centred on that same interval rather than half a cell to its right.
	for stair_id: StringName in [&"stair.full", &"stair.half"]:
		var stair := program.recipe(stair_id)
		var stair_min_x := INF
		var stair_max_x := -INF
		for placement: Dictionary in stair.placements:
			var descriptor := catalog.descriptor(StringName(placement.asset_id))
			var bounds := (placement.transform as Transform3D) * \
				descriptor.measured_aabb
			stair_min_x = minf(stair_min_x, bounds.position.x)
			stair_max_x = maxf(stair_max_x, bounds.end.x)
		assert_almost_eq((stair_min_x + stair_max_x) * 0.5, -0.75, 0.03,
			"stair collision/visual lanes share the public corridor centre")
		assert_lte(absf(stair_min_x - -2.25), 0.05)
		assert_lte(absf(stair_max_x - 0.75), 0.05)


func test_circulation_recipes_express_section_changes_and_local_ground() -> void:
	var program := _program()
	var prefab := program.recipe(&"anchor.prefab.00")
	assert_true(prefab.has_tag(&"terrain_bearing"))
	assert_gt(prefab.terrain_bearing_cells.size(), 0)
	for bearing_cell: Vector3i in prefab.terrain_bearing_cells:
		assert_eq(bearing_cell.y, 0)
	var prefab_xz: Dictionary = {}
	for bearing_cell: Vector3i in prefab.terrain_bearing_cells:
		prefab_xz[Vector2i(bearing_cell.x, bearing_cell.z)] = true
	assert_eq(prefab_xz.size(), prefab.terrain_bearing_cells.size(),
		"a prefab declares one complete, non-dilated load footprint")
	var prefab_bounds := prefab.local_clearance_bounds
	var bounding_cell_count := ceili(prefab_bounds.size.x / FabricRecipe.CELL_SIZE) \
		* ceili(prefab_bounds.size.z / FabricRecipe.CELL_SIZE)
	assert_lt(prefab.terrain_bearing_cells.size(), bounding_cell_count,
		"authored feet do not turn the prefab's complete eave bounds into terrain")

	var stair_house := program.recipe(&"room.stair_house.blue")
	assert_true(stair_house.has_tag(&"circulation_building"))
	assert_true(stair_house.has_tag(&"interior_walk"))
	assert_false(stair_house.has_tag(&"public_walk"))
	assert_eq((stair_house.socket(&"walk.low").cell as Vector3i).y, 0)
	assert_eq((stair_house.socket(&"walk.high").cell as Vector3i).y, 4)
	assert_gt(stair_house.solid_cells.size(), 0)
	assert_gt(stair_house.walk_cells.size(), 0)
	assert_eq(stair_house.public_air_cells.size(), 0)

	var exterior_stair := program.recipe(&"stair.facade.full.terrain.orange")
	assert_true(exterior_stair.has_tag(&"exterior_stair"))
	assert_true(exterior_stair.has_tag(&"public_walk"))
	assert_false(exterior_stair.has_tag(&"interior_walk"))
	assert_eq((exterior_stair.socket(&"walk.low").cell as Vector3i).y, 0)
	assert_eq((exterior_stair.socket(&"walk.high").cell as Vector3i).y, 2)
	assert_eq(exterior_stair.entrances.size(), 1,
		"the occupied stair facade needs one real external address")
	var stair_entrance := exterior_stair.entrances[0] as Dictionary
	assert_eq(stair_entrance.cell as Vector3i, Vector3i(1, 0, 0))
	assert_eq(stair_entrance.facing as Vector3i, Vector3i.RIGHT)
	assert_true(exterior_stair.walk_cells.has(Vector3i(2, 0, 0)),
		"the east doorway must meet the low stair tread at equal elevation")
	for air_cell: Vector3i in exterior_stair.public_air_cells:
		assert_false(exterior_stair.inhabited_cells.has(air_cell),
			"facade stair air remains outside the inhabited envelope")

	var court := program.recipe(&"court.supported.12x6")
	assert_true(court.has_tag(&"structural_court"))
	assert_true(court.has_tag(&"topology_only"))
	assert_false(court.has_tag(&"terrain_bearing"))
	assert_true(court.terrain_bearing_cells.is_empty())
	assert_eq(court.bearing_parent_count, 2)
	assert_eq(court.placements.size(), 0)
	assert_eq(court.walk_cells.size(), 31)
	assert_eq(court.daylight_void_cells.size(), 1)
	assert_false(court.walk_cells.has(court.daylight_void_cells[0]))

	var addressed_room := program.recipe(&"room.base.rock")
	var closed_upper := program.recipe(&"room.upper.blue")
	assert_eq(addressed_room.entrances.size(), 1)
	assert_true(closed_upper.entrances.is_empty())
	assert_true(closed_upper.solid_cells.has(Vector3i(-1, 0, 1)),
		"an unaddressed upper storey must not retain a fake open door")


func test_deferred_passage_surface_stays_private_but_reaches_its_portals() -> void:
	var passage := _program().recipe(&"room.passage.blue")
	assert_true(passage.has_tag(&"interior_walk"))
	assert_false(passage.has_tag(&"public_walk"))
	assert_true(passage.public_air_cells.is_empty())
	for socket_id: StringName in [
			&"walk.north", &"walk.south", &"walk.east", &"walk.west"]:
		var socket := passage.socket(socket_id)
		assert_true(passage.walk_cells.has(socket.cell as Vector3i),
			"%s must terminate on the claimed public surface" % socket_id)
		assert_false(passage.solid_cells.has(socket.cell as Vector3i),
			"%s must remain a clear opening" % socket_id)


func test_occupied_skywalk_is_private_overhead_mass() -> void:
	var skywalk := _program().recipe(&"skywalk.6.orange")
	assert_true(skywalk.has_tag(&"interior_walk"))
	assert_false(skywalk.has_tag(&"public_walk"))
	assert_true(skywalk.public_air_cells.is_empty())
	assert_gt(skywalk.inhabited_cells.size(), 0)
	assert_false(skywalk.socket(&"room.west").is_empty())
	assert_false(skywalk.socket(&"room.east").is_empty())
	assert_true(skywalk.placements.any(func(value: Dictionary) -> bool:
		return String(value.id).begins_with("floor.")),
		"a private occupied skywalk still owns a real floor")
	for end_id: StringName in [&"threshold.west", &"threshold.east"]:
		assert_true(skywalk.placements.any(func(value: Dictionary) -> bool:
			return StringName(value.id) == end_id \
				and StringName(value.asset_id) \
					== SettlementFabricProgram.SETBACK_CAP),
			"every occupied span must carry its authored floor across %s" % end_id)


func test_feature_portal_room_variants_finish_exact_private_socket_facades() \
		-> void:
	var program := _program()
	var cases: Array[Dictionary] = [
		{"base": &"room.upper.blue", "mask": 1,
			"cell": Vector3i(0, 0, -2), "placement": &"back.1"},
		{"base": &"room.upper.stone", "mask": 1,
			"cell": Vector3i(0, 0, -2), "placement": &"back.1"},
		{"base": &"room.long.upper.orange.b", "mask": 2,
			"cell": Vector3i(1, 0, 0), "placement": &"east.1"},
		{"base": &"room.slim.upper.amber", "mask": 4,
			"cell": Vector3i(0, 0, 1), "placement": &"south"},
		{"base": &"room.tower.upper.blue.b", "mask": 8,
			"cell": Vector3i(-1, 0, 0), "placement": &"west"},
	]
	for sample: Dictionary in cases:
		var base := program.recipe(StringName(sample.base))
		var variant_id := SettlementFabricProgram.feature_portal_recipe_id(
			StringName(sample.base), int(sample.mask))
		var variant := program.recipe(variant_id)
		assert_not_null(variant, "%s is missing" % variant_id)
		if base == null or variant == null:
			continue
		assert_true(variant.has_tag(&"feature_portal"))
		assert_eq(variant.entrances, base.entrances,
			"a private feature portal must not invent a public entrance")
		var cell := sample.cell as Vector3i
		for y in 2:
			var aperture := cell + Vector3i.UP * y
			assert_false(variant.solid_cells.has(aperture))
			assert_false(variant.occluder_cells.has(aperture))
			assert_true(variant.headroom_cells.has(aperture))
			assert_true(variant.inhabited_cells.has(aperture))
		var portal_placement: Dictionary = {}
		for placement: Dictionary in variant.placements:
			if StringName(placement.id) == StringName(sample.placement):
				portal_placement = placement
				break
		assert_false(portal_placement.is_empty())
		if not portal_placement.is_empty():
			var portal_asset := String(portal_placement.asset_id)
			assert_true(portal_asset == String(
				SettlementFabricProgram.WOOD_DOOR_CLOSED) \
				or portal_asset == String(
					SettlementFabricProgram.WOOD_DOOR_CLOSED) + ".mirror_x",
				"the exact facade phase may mirror the same authored private door")
		var jamb_count := 0
		for placement: Dictionary in variant.placements:
			jamb_count += int(String(placement.id).begins_with(
				"portal.jamb.%d." % int(sample.mask)) \
				and StringName(placement.asset_id) \
					== SettlementFabricProgram.PORTAL_JAMB)
		assert_eq(jamb_count, 2,
			"a feature portal needs a complete symmetric timber joint")
	var balcony := program.recipe(&"balcony.bracketed.left.blue")
	assert_true(balcony.has_tag(&"requires_room_portal"))
	assert_false(balcony.has_tag(&"facade_door"))
	assert_false(balcony.placements.any(func(placement: Dictionary) -> bool:
		return String(placement.id) == "door"),
		"the balcony must not paste a second doorway over its parent shell")


func test_route_spanning_overhang_is_a_four_sided_foundation_shell() -> void:
	var program := _program()
	for mask in range(1, SettlementFabricProgram.FEATURE_PORTAL_MASK_ALL + 1):
		var recipe := program.recipe(SettlementFabricProgram \
			.arcade_overhang_foundation_recipe_id(mask))
		assert_not_null(recipe, "mask %x" % mask)
		if recipe == null:
			continue
		assert_true(recipe.has_tag(&"cantilever_support"))
		assert_true(recipe.has_tag(&"arcade_portal_support"))
		assert_true(recipe.has_tag(&"route_spanning_overhang"))
		assert_true(recipe.has_tag(&"four_sided_foundation_shell"))
		assert_eq(recipe.placements.size(), 4,
			"every gatehouse must close north/east/south/west")
		var ids: Dictionary = {}
		var portal_count := 0
		for placement: Dictionary in recipe.placements:
			ids[StringName(placement.id)] = true
			portal_count += int(StringName(placement.asset_id) \
				== SettlementFabricProgram.ROCK_DOOR)
		assert_eq(ids.size(), 4)
		for side: StringName in [&"north", &"east", &"south", &"west"]:
			assert_true(ids.has(side), "foundation omits %s" % side)
		assert_eq(portal_count, WarrenSpatialFeatureSolver._bit_count_4(mask),
			"only route continuation faces may be arches")


func test_recomposed_room_door_phase_is_derived_from_final_geometry() -> void:
	var kinds := {
		&"tower": Vector3i(0, 0, 0),
		&"slim": Vector3i(0, 0, 1),
		&"row": Vector3i(-1, 0, 0),
		&"building": Vector3i(-1, 0, 1),
		&"long": Vector3i(-1, 0, 2),
	}
	var origin := Vector3i(17, 9, -23)
	for kind_value: Variant in kinds:
		var kind := StringName(kind_value)
		var phase_zero := kinds[kind] as Vector3i
		for yaw in 4:
			var frontage := FabricRecipe.transform_direction(Vector3i.BACK, yaw)
			for phase in 2:
				var threshold := FabricRecipe.transform_cell(
					phase_zero + Vector3i.LEFT * phase, origin, yaw)
				assert_eq(WarrenParcelConstruction.address_door_phase_for_room(
					kind, origin, yaw, threshold, frontage), phase,
					"%s yaw %d must bind the exact phase-%d threshold" \
						% [kind, yaw, phase])
			assert_eq(WarrenParcelConstruction.address_door_phase_for_room(
				kind, origin, yaw, origin + Vector3i(20, 0, 20), frontage), -1)
			assert_eq(WarrenParcelConstruction.address_door_phase_for_room(
				kind, origin, yaw,
				FabricRecipe.transform_cell(phase_zero, origin, yaw),
				-frontage), -1)


func test_flat_roof_fallbacks_have_measured_guarded_terrace_variants() -> void:
	var program := _program()
	for kind: String in ["tower", "slim", "row", "square", "long"]:
		for side: String in ["north", "east", "south", "west"]:
			var recipe_id := StringName("roof.flat.%s.terrace.%s" % [kind, side])
			var recipe_value := program.recipe(recipe_id)
			assert_not_null(recipe_value, "%s is missing" % recipe_id)
			if recipe_value == null:
				continue
			assert_true(recipe_value.has_tag(&"flat_roof"))
			assert_true(recipe_value.has_tag(&"flat_roof_terrace"))
			assert_true(recipe_value.walk_cells.is_empty(),
				"a visual roof treatment must not invent public circulation")
			assert_true(recipe_value.placements.any(
				func(placement: Dictionary) -> bool:
					return String(placement.id).begins_with("guard.")),
				"%s must carry a complete authored railing run" % recipe_id)
			var lived_id := StringName("%s.lived" % recipe_id)
			var lived := program.recipe(lived_id)
			assert_not_null(lived, "%s is missing" % lived_id)
			if lived != null:
				assert_true(lived.has_tag(&"lived_in_roof_terrace"))
				assert_true(lived.placements.any(
					func(placement: Dictionary) -> bool:
						return String(placement.id).begins_with(
							"terrace.planter.")))
				var should_have_chimney := kind in ["slim", "row"] \
					or kind == "square" and side in ["east", "west"]
				assert_eq(lived.placements.any(
					func(placement: Dictionary) -> bool:
						return String(placement.id) == "terrace.chimney"),
					should_have_chimney,
					"narrow lived-in terraces need a measured vertical stone core")
				var should_have_awning := kind == "long" \
					or kind == "square" and side in ["north", "south"]
				assert_eq(lived.placements.any(
					func(placement: Dictionary) -> bool:
						return String(placement.id) == "terrace.awning"),
					should_have_awning,
					"broad lived-in terraces need a complete measured canopy")
	for length_cells: int in [1, 2, 4, 6]:
		for side: String in ["left", "right"]:
			var setback := program.recipe(StringName(
				"roof.setback.terrace.%d.%s" % [length_cells, side]))
			assert_not_null(setback)
			if setback == null:
				continue
			assert_eq(setback.placements.any(
				func(placement: Dictionary) -> bool:
					return String(placement.id) == "terrace.planter"),
				length_cells >= 2,
				"usable setback strips need measured lived-in dressing")
			assert_eq(setback.placements.any(
				func(placement: Dictionary) -> bool:
					return String(placement.id) == "terrace.chimney"),
				length_cells == 6,
				"only the rare longest setback receives a stone vertical core")
	for length_cells: int in [2, 4, 6]:
		var garden := program.recipe(StringName(
			"roof.setback.garden.%d" % length_cells))
		assert_not_null(garden)
		if garden != null:
			assert_true(garden.has_tag(&"setback_garden"))
			assert_true(garden.walk_cells.is_empty(),
				"private roof dressing must not invent circulation")
			assert_true(garden.placements.any(
				func(placement: Dictionary) -> bool:
					return String(placement.id) == "garden.planter"),
				"enclosed setback bands need a measured inhabited detail")
	for kind: String in ["tower", "slim", "square", "long"]:
		var rich := program.recipe(StringName(
			"roof.flat.%s.garden.rich" % kind))
		assert_not_null(rich)
		if rich == null:
			continue
		assert_true(rich.has_tag(&"rich_roof_garden"))
		assert_true(rich.walk_cells.is_empty(),
			"a decorated service roof is private unless circulation addresses it")
		var broad := kind in ["square", "long"]
		assert_eq(rich.has_tag(&"roof_garden_awning"), broad)
		assert_eq(rich.has_tag(&"chimney"), not broad)
	for family: String in ["blue", "orange"]:
		for length_cells: int in [2, 4, 6]:
			for side: String in ["negative", "positive"]:
				var lean_id := StringName("roof.setback.lean.%s.%d.%s" % [
					family, length_cells, side])
				var lean := program.recipe(lean_id)
				assert_not_null(lean, "%s is missing" % lean_id)
				if lean != null:
					assert_true(lean.has_tag(&"setback_lean_to"))
					assert_true(lean.walk_cells.is_empty())
				var shed_id := StringName("roof.setback.shed.%s.%d.%s" % [
					family, length_cells, side])
				var shed := program.recipe(shed_id)
				assert_not_null(shed, "%s is missing" % shed_id)
				if shed != null:
					assert_true(shed.has_tag(&"setback_shed"))
					assert_true(shed.has_tag(&"pitched_roof"))
					assert_true(shed.walk_cells.is_empty())
					assert_eq(shed.placements.size(), length_cells / 2,
						"one unscaled 3 m shed should close each two-cell run")


func test_exterior_builder_rejects_deferred_interior_route_units() -> void:
	var program := _program()
	var specs: Array[Dictionary] = [
		SettlementFabricSolver.unit_spec(&"route.entry", &"route.landing",
			Vector3i.ZERO),
		SettlementFabricSolver.unit_spec(&"interior.stair",
			&"room.stair_house.terrain.orange", Vector3i(10, 0, 0)),
	]
	assert_null(SectionalPublicRealmBuilder.from_specs(&"interior.rejected",
		program, specs, [&"route.entry", &"interior.stair"]))
	assert_true(SectionalPublicRealmBuilder.last_failure.contains(
		"is not a public unit"))


func test_public_node_requires_full_exterior_headroom() -> void:
	var surface_cells: Array[Vector3i] = [Vector3i.ZERO]
	var incomplete_air: Array[Vector3i] = [Vector3i.ZERO]
	var node_value := PublicRealmNode.new(&"bad.headroom",
		PublicRealmNode.EpisodeKind.STREET,
		PublicRealmSurfacePlan.SurfaceKind.TERRAIN_STREET,
		PublicRealmNode.AirRealm.EXTERIOR,
		PublicRealmNode.CoverPolicy.OPEN, surface_cells, incomplete_air,
		0, 0, true, true)
	assert_false(node_value.seal())


func test_volume_proof_rejects_occupied_and_disconnected_public_air() -> void:
	var air_claims := {
		Vector3i.ZERO: {"owners": [&"entry"]},
		Vector3i.UP: {"owners": [&"entry"]},
	}
	var occupied := {Vector3i.UP: &"room"}
	var overlap := FabricVolumePlan.new(&"volume.overlap")
	assert_false(overlap.seal(air_claims, [Vector3i.ZERO], occupied, {}))
	assert_eq(overlap.occupied_air_overlaps, [Vector3i.UP])

	air_claims[Vector3i(20, 0, 20)] = {"owners": [&"island"]}
	var disconnected := FabricVolumePlan.new(&"volume.disconnected")
	assert_false(disconnected.seal(air_claims, [Vector3i.ZERO], {}, {}))
	assert_eq(disconnected.unreachable_air_cells, [Vector3i(20, 0, 20)])

	var occupied_probe := FabricVolumePlan.new(&"volume.occupied_probe")
	assert_true(occupied_probe.seal({
		Vector3i.ZERO: {"owners": [&"entry"]},
		Vector3i.UP: {"owners": [&"entry"]},
	}, [Vector3i.ZERO], {Vector3i(4, 1, 0): &"wall"}, {}))
	assert_true(occupied_probe.has_occupied_cell(Vector3i(4, 1, 0)))
	assert_false(occupied_probe.has_occupied_cell(Vector3i.UP))


func test_folded_route_uses_socket_bonds_and_reaches_one_landing() -> void:
	var plan := _route_plan()
	assert_not_null(plan)
	assert_true(plan.is_sealed())
	assert_true(plan.validate())
	assert_eq(plan.audit.public_walk_unit_count, 3)
	assert_eq(plan.audit.tent_count, 0)
	assert_eq(plan.audit.isolated_platform_count, 0)


func test_disconnected_public_walk_is_rejected() -> void:
	var specs := _route_specs()
	specs.append(SettlementFabricSolver.unit_spec(&"route.orphan",
		&"route.corner", Vector3i(20, 0, 20)))
	var plan := SettlementFabricSolver.new(_program()).solve_authored(
		&"warren.test.orphan", specs)
	assert_null(plan)


func test_solid_or_headroom_overlap_is_rejected_during_construction() -> void:
	var specs := _route_specs()
	specs.append(SettlementFabricSolver.unit_spec(&"route.overlap",
		&"route.corner", Vector3i(2, 0, 0), 0, [], [
			FabricUnit.bond(&"walk.west", &"route.entry", &"walk.east"),
		]))
	var plan := SettlementFabricSolver.new(_program()).solve_authored(
		&"warren.test.overlap", specs)
	assert_null(plan)


func test_visual_rejection_rolls_back_staged_semantic_claims() -> void:
	var plan := SettlementFabricPlan.new(&"warren.test.visual-rollback")
	var catalog := EnvironmentCatalog.load_default()
	var recipe_value := FabricRecipe.new(&"test.visual-rollback",
		[&"generated_building"], 0)
	recipe_value.add_placement(&"floor", SettlementFabricProgram.FLOOR)
	recipe_value.solid_cells.append(Vector3i.ZERO)
	var visual_bounds := catalog.descriptor(
		SettlementFabricProgram.FLOOR).measured_aabb
	assert_true(recipe_value.set_local_clearance_bounds(
		visual_bounds.grow(0.5)))
	assert_true(recipe_value.seal(catalog), recipe_value.last_rejection)
	assert_true(plan.register_recipe(recipe_value))
	var left := FabricUnit.new(&"room.left", recipe_value.recipe_id,
		Vector3i.ZERO, 0)
	assert_true(plan.add_unit(left), plan.last_rejection)
	var unseamed := FabricUnit.new(&"room.right", recipe_value.recipe_id,
		Vector3i(1, 0, 0), 0)
	assert_false(plan.add_unit(unseamed),
		"adjacent authored facade envelopes require an explicit party-wall seam")
	assert_true(plan.last_rejection.contains("visual envelope"),
		plan.last_rejection)
	var retry := FabricUnit.new(&"room.right", recipe_value.recipe_id,
		Vector3i(1, 0, 0), 0, [], [], &"", [&"room.left"])
	assert_true(plan.add_unit(retry),
		"the rejected attempt must not retain ghost semantic claims: %s" \
			% plan.last_rejection)
	assert_eq(plan.units.size(), 2)


func test_stacked_room_requires_the_declared_bearing_parent_socket() -> void:
	var specs := _route_specs()
	specs.append(SettlementFabricSolver.unit_spec(&"room.base",
		&"room.base.rock.closed", Vector3i(8, 0, 0)))
	specs.append(SettlementFabricSolver.unit_spec(&"room.upper",
		&"room.upper.blue", Vector3i(8, 2, 0), 0, [&"room.base"], [
			FabricUnit.bond(&"bearing.bottom", &"room.base", &"bearing.top"),
		]))
	var plan := SettlementFabricSolver.new(_program()).solve_authored(
		&"warren.test.stack", specs)
	assert_not_null(plan)
	assert_true(plan.validate())

	var invalid_specs := _route_specs()
	invalid_specs.append(SettlementFabricSolver.unit_spec(&"room.base",
		&"room.base.rock.closed", Vector3i(8, 0, 0)))
	invalid_specs.append(SettlementFabricSolver.unit_spec(&"room.upper",
		&"room.upper.blue", Vector3i(8, 2, 0), 0, [&"room.base"]))
	assert_null(SettlementFabricSolver.new(_program()).solve_authored(
		&"warren.test.unsupported", invalid_specs))


func test_enclosed_skywalk_requires_two_independent_bearing_ends() -> void:
	var program := _program()
	var plan := SettlementFabricPlan.new(&"warren.test.span")
	for recipe_value: FabricRecipe in program.recipes():
		assert_true(plan.register_recipe(recipe_value))
	var left := FabricUnit.new(&"room.left", &"room.base.rock",
		Vector3i(-3, 2, 0), 0)
	var right := FabricUnit.new(&"room.right", &"room.base.rock",
		Vector3i(3, 2, 0), 0)
	assert_true(plan.add_unit(left))
	assert_true(plan.add_unit(right))
	var span := FabricUnit.new(&"skywalk", &"skywalk.3.blue",
		Vector3i(0, 2, 0), 0, [&"room.left", &"room.right"], [
			FabricUnit.bond(&"bearing.west", &"room.left", &"bearing.east"),
			FabricUnit.bond(&"bearing.east", &"room.right", &"bearing.west"),
		])
	assert_true(plan.add_unit(span))

	var invalid := FabricUnit.new(&"bad.skywalk", &"skywalk.3.blue",
		Vector3i(0, 6, 0), 0, [&"room.left"], [
			FabricUnit.bond(&"bearing.west", &"room.left", &"bearing.east"),
		])
	assert_false(plan.add_unit(invalid))


func test_composite_recipes_expand_to_stable_asset_placements() -> void:
	var plan := _route_plan()
	var placements := plan.expanded_placements()
	assert_eq(placements.size(), 0,
		"topology-only route units never emit independent floor assets")
	assert_not_null(plan.surface_plan)
	assert_eq(plan.surface_plan.claim_count(), 12)
	assert_eq(plan.surface_plan.mesh_payloads.size(), 1)
	var payload := SettlementFabricAssembler.payload(plan)
	assert_eq(payload.instance_count, 0)
	assert_true(payload.validate())


func test_fabric_unit_omits_only_declared_recipe_placements() -> void:
	var program := _program()
	var recipe := program.recipe(&"room.base.rock")
	assert_not_null(recipe)
	var plan := SettlementFabricPlan.new(&"warren.test.suppressed-placement")
	for recipe_value: FabricRecipe in program.recipes():
		assert_true(plan.register_recipe(recipe_value))
	var unit := FabricUnit.new(&"room", recipe.recipe_id, Vector3i.ZERO, 0,
		[], [], &"", [], [&"front.0"])
	assert_true(plan.add_unit(unit), plan.last_rejection)
	assert_eq(plan.expanded_placements().size(), recipe.placements.size() - 1)
	for placement: Dictionary in plan.expanded_placements():
		assert_ne(StringName(placement.stable_id), &"room/front.0")

	var invalid := SettlementFabricPlan.new(&"warren.test.bad-suppression")
	for recipe_value: FabricRecipe in program.recipes():
		assert_true(invalid.register_recipe(recipe_value))
	assert_false(invalid.add_unit(FabricUnit.new(&"room", recipe.recipe_id,
		Vector3i.ZERO, 0, [], [], &"", [], [&"missing.module"])))
	assert_string_contains(invalid.last_rejection, "missing placement")


func test_party_wall_suppression_requires_a_complete_authored_module() -> void:
	var complete := _party_wall_suppression(true)
	assert_has(complete, &"front.0")
	assert_does_not_have(complete, &"front.1")
	var partial := _party_wall_suppression(false)
	assert_does_not_have(partial, &"front.0",
		"one unjoined fine-grid face must preserve the complete facade module")


func test_sectional_plan_binds_units_and_seals_one_surface_union() -> void:
	var realm := _sectional_route()
	var solver := SettlementFabricSolver.new(_program())
	var plan := solver.solve_sectional(&"warren.test.sectional", realm,
		_sectional_route_specs())
	assert_not_null(plan, solver.failure_reason)
	if plan == null:
		return
	assert_true(plan.validate())
	assert_eq(plan.public_realm.deterministic_signature(),
		realm.deterministic_signature())
	assert_eq(int(plan.audit.public_realm_node_count), 3)
	assert_eq(int(plan.audit.unclassified_interval_count), 0)
	assert_eq(int(plan.audit.visual_envelope_overlap_count), 0)
	assert_true(plan.visual_envelope_conflicts().is_empty())
	assert_eq(int(plan.audit.unreachable_exterior_air_count), 0)
	assert_eq(int(plan.audit.public_air_occupied_overlap_count), 0)
	assert_eq(int(plan.audit.enclosure_route_cell_count), 4,
		"the enclosure denominator excludes the landing and open terrace")
	assert_eq(int(plan.audit.ground_enclosure_route_cell_count), 4)
	assert_eq(int(plan.audit.overhead_route_cell_count), 0)
	assert_not_null(plan.solid_void_plan)
	assert_true(plan.solid_void_plan.is_sealed())
	assert_gt(int(plan.audit.exterior_air_cell_count), 0)
	assert_eq(plan.surface_plan.claim_count(), 12)
	assert_eq(plan.expanded_placements().size(), 0)


func test_sectional_surface_rejects_an_unclassified_required_interval() -> void:
	# Deliberately require one interval that neither surface nor another
	# classification owns.
	var surface := PublicRealmSurfacePlan.new(&"surface.unclassified")
	assert_true(surface.add_claim(Vector3i.ZERO,
		PublicRealmSurfacePlan.SurfaceKind.TERRAIN_STREET, &"owner"))
	assert_false(surface.seal([Vector3i(50, 2, 50)]))
	assert_eq(surface.unclassified_required_cells, [Vector3i(50, 2, 50)])


func test_sectional_surface_rejects_an_exterior_door_without_a_landing() -> void:
	var surface := PublicRealmSurfacePlan.new(&"surface.midair-door")
	assert_true(surface.add_claim(Vector3i.ZERO,
		PublicRealmSurfacePlan.SurfaceKind.TERRAIN_STREET, &"street"))
	var entrance := {
		"stable_id": &"door.midair",
		"landing_cell": Vector3i(3, 2, 0),
		"facing": Vector3i.BACK,
	}
	assert_false(surface.seal([], {}, {}, [entrance]),
		"an exterior door may not survive without its exact public landing")
	assert_eq(surface.unserved_entrances.size(), 1)
	assert_true(surface.last_rejection.contains("no exact public landing"))

	var served := PublicRealmSurfacePlan.new(&"surface.served-door")
	assert_true(served.add_claim(Vector3i(3, 2, 0),
		PublicRealmSurfacePlan.SurfaceKind.STRUCTURAL_COURT, &"landing"))
	assert_true(served.seal([], {}, {}, [entrance]),
		"the same doorway is valid once its landing belongs to the union")
	assert_true(served.validate())


func test_generated_door_opens_both_guard_halves_of_its_authored_facade() \
		-> void:
	var surface := PublicRealmSurfacePlan.new(&"surface.wide-door")
	for cell: Vector3i in [Vector3i.ZERO, Vector3i.LEFT, Vector3i.RIGHT,
			Vector3i.BACK, Vector3i.LEFT + Vector3i.BACK]:
		assert_true(surface.add_claim(cell,
			PublicRealmSurfacePlan.SurfaceKind.STRUCTURAL_COURT, &"landing"))
	var entrance := {
		"stable_id": &"door.phase-zero",
		"landing_cell": Vector3i.ZERO,
		"facing": Vector3i.BACK,
		"door_phase": 0,
	}
	assert_true(surface.seal([], {}, {}, [entrance]))
	assert_true(surface.validate())
	assert_eq(int(surface.audit().wide_entrance_guard_opening_count), 1)
	assert_eq(int(surface.audit().entrance_guard_conflict_count), 0)
	var guarded_edges: Dictionary = {}
	for segment: Dictionary in surface.guard_segments:
		guarded_edges[String(segment.stable_key)] = true
	for landing: Vector3i in [Vector3i.ZERO, Vector3i.LEFT]:
		assert_false(guarded_edges.has("%d:%d:%d:0:-1" % [landing.x,
			landing.y, landing.z]),
			"no authored railing may cut across either half of the 3 m door")
func test_handed_door_forecourt_uses_one_guard_run_without_a_centre_post() \
		-> void:
	var surface := PublicRealmSurfacePlan.new(&"surface.door-forecourt")
	# Phase zero's optional facade companion is LEFT, while this real forecourt
	# continues RIGHT. The post repair must follow the finished public surface,
	# not assume the optional second doorway lane exists.
	for cell: Vector3i in [Vector3i.ZERO, Vector3i.RIGHT]:
		assert_true(surface.add_claim(cell,
			PublicRealmSurfacePlan.SurfaceKind.STRUCTURAL_COURT, &"landing"))
	var entrance := {
		"stable_id": &"door.phase-zero.shallow",
		"landing_cell": Vector3i.ZERO,
		"facing": Vector3i.BACK,
		"door_phase": 0,
	}
	assert_true(surface.seal([], {}, {}, [entrance]))
	assert_true(surface.validate())
	assert_eq(int(surface.audit().wide_entrance_guard_opening_count), 0)
	assert_eq(int(surface.audit().entrance_forecourt_join_count), 1,
		"the two short outer guards share one doorway-axis post omission")
	var joined_segments := 0
	for segment: Dictionary in surface.guard_segments:
		joined_segments += int(segment.has("visual_join_point"))
	assert_eq(joined_segments, 2)
	var payload := SettlementFabricAssembler.surface_visual_payload(surface)
	assert_true(payload.validate())
	assert_has(payload.asset_ids(), &"sfv.deck.railing.m.001")
	assert_eq((payload.batches[&"sfv.deck.railing.m.001"] \
		as Dictionary).transforms.size(), 1,
		"one authored 3 m run replaces the pair with a centre post")


func test_minimum_requirements_reject_incomplete_visual_slice() -> void:
	var plan := SettlementFabricSolver.new(_program()).solve_authored(
		&"warren.test.requirements", _route_specs(), {
			&"skywalk_count": 2,
			&"outcropping_count": 4,
			&"market_family_count": 4,
		})
	assert_null(plan)


func test_plot_void_stairs_have_square_landings_and_no_disconnected_flights() \
		-> void:
	var plan := WarrenPlotVoidPlanner.new().solve(_program(), 0)
	assert_not_null(plan)
	if plan == null:
		return
	assert_eq(int(plan.audit.stair_endpoint_gap_count), 0,
		"both player-width stair lanes must physically meet their neighbors")
	assert_eq(int(plan.audit.stair_endpoint_missing_landing_count), 0,
		"every stair end must meet a level two-by-two landing")
	assert_eq(int(plan.audit.stair_to_stair_edge_count), 0,
		"successive flights must be separated by a square landing")
	assert_eq(int(plan.audit.platform_dead_end_count), 0,
		"every elevated platform must continue into a stair, path, or entrance")
	assert_eq(int(plan.audit.isolated_platform_count), 0)
	assert_eq(int(plan.audit.unsupported_platform_count), 0)
	assert_eq(int(plan.audit.unsupported_stair_count), 0)
	assert_eq(int(plan.audit.stair_count), 7,
		"the reviewed through-route must keep all seven external flights")
	assert_gte(int(plan.audit.vertical_span_cells), 5,
		"the route must climb through more than one token upper floor")
	assert_eq(int(plan.audit.detached_building_stack_count), 0,
		"every inhabited stack must reach a served path through occupied seams")
	assert_eq(int(plan.audit.connected_building_stack_count),
		int(plan.audit.building_stack_count))
	assert_gte(int(plan.audit.skywalk_link_count), 1,
		"the inhabited circulation graph must include an occupied skywalk link")
	assert_eq(int(plan.audit.prefab_anchor_count), 1,
		"one source-pack building must participate in the coupled massing")
	assert_gte(int(plan.audit.market_count), 2)
	assert_gte(int(plan.audit.market_family_count), 2,
		"the alley must use varied stocked market prefabs")
	for proposal: Dictionary in plan.embedding_plan.barrier_proposals:
		assert_ne(StringName(proposal.kind), &"bay",
			"a shallow facade bay must never become a sideways standalone house")
		if StringName(proposal.kind) == &"slim":
			var cells := StaggeredFabricCompiler.proposal_occupied_cells(proposal)
			var minimum := Vector2i(2147483647, 2147483647)
			var maximum := Vector2i(-2147483648, -2147483648)
			for cell: Vector3i in cells:
				minimum = minimum.min(Vector2i(cell.x, cell.z))
				maximum = maximum.max(Vector2i(cell.x, cell.z))
			var footprint := maximum - minimum + Vector2i.ONE
			assert_ne(footprint.x, footprint.y,
				"the townhouse proposal must retain its narrow/deep footprint")


func test_seed_changes_the_actual_maze_geometry() -> void:
	var signatures: Dictionary = {}
	var canonical_signatures: Dictionary = {}
	# Cover every low-bit sectional family: four route motifs, two ordinary
	# turn phases, and four vertical profiles. A seed may not merely recolour or
	# cardinally rotate a shared town.
	for world_seed in 32:
		var grammar: WarrenPlotVoidPlan
		for attempt in 64:
			grammar = WarrenPlotVoidGrammar.build(world_seed, attempt)
			if grammar != null:
				break
		assert_not_null(grammar)
		if grammar == null:
			continue
		var signature := grammar.geometry_signature()
		assert_false(signatures.has(signature),
			"seeds must not be cosmetic variants of one underlying route")
		signatures[signature] = true
		var canonical := grammar.canonical_coarse_route_signature()
		assert_false(canonical_signatures.has(canonical),
			"seed %d must not reuse seed %s under a cardinal rotation" % [
				world_seed, canonical_signatures.get(canonical, "none")])
		canonical_signatures[canonical] = world_seed
	assert_eq(signatures.size(), 32)
	assert_eq(canonical_signatures.size(), 32)


func test_seeded_maze_grammar_always_interposes_square_stair_landings() -> void:
	## This cheap property corpus guards the construction rule before the slower
	## exact fabric transaction: every flight ends at a full two-by-two corner
	## module, and another flight can attach only through that landing.
	for world_seed in 64:
		var grammar: WarrenPlotVoidPlan
		for attempt in WarrenPlotVoidPlanner.MAX_GRAMMAR_ATTEMPTS:
			grammar = WarrenPlotVoidGrammar.build(world_seed, attempt)
			if grammar != null:
				break
		assert_not_null(grammar, "seed %d must produce a route grammar" % world_seed)
		if grammar == null:
			continue
		for index in grammar.route_steps.size():
			var step := grammar.route_steps[index]
			if not String(step.recipe_id).begins_with("stair."):
				continue
			assert_lt(index + 1, grammar.route_steps.size())
			if index + 1 >= grammar.route_steps.size():
				continue
			var landing := grammar.route_steps[index + 1]
			assert_true(StringName(landing.recipe_id) in [
				&"route.corner", &"deck.corner",
			], "seed %d stair %s needs a square landing" % [
				world_seed, step.stable_id])
			assert_eq(StringName(landing.parent_id), StringName(step.stable_id))
			if index + 2 < grammar.route_steps.size() \
					and String(grammar.route_steps[index + 2].recipe_id).begins_with(
						"stair."):
				assert_eq(StringName(grammar.route_steps[index + 2].parent_id),
					StringName(landing.stable_id),
					"turning flights must join through their square landing")


func test_folded_visual_proof_passes_the_common_transaction() -> void:
	var plan: SettlementFabricPlan = _folded_proof()
	assert_not_null(plan)
	if plan == null:
		return
	assert_true(plan.is_sealed())
	assert_eq(int(plan.audit.tent_count), 0)
	assert_eq(int(plan.audit.isolated_platform_count), 0)
	assert_gte(int(plan.audit.stair_count), 2)
	# Skywalk construction has dedicated bearing/seam tests above, while the
	# procedural plot-void planner applies the per-town skywalk minimum. This
	# older folded fixture proves its route/court transaction only.
	assert_gte(int(plan.audit.vertical_span_cells), 6)
	assert_gte(int(plan.audit.sectional_elevation_change_count), 6)
	assert_true(bool(plan.audit.primary_has_court))
	assert_gte(int(plan.audit.primary_exterior_stair_count), 5)
	assert_eq(int(plan.audit.public_interior_node_count), 0)
	assert_eq(int(plan.audit.unreachable_exterior_air_count), 0)
	assert_eq(int(plan.audit.public_air_occupied_overlap_count), 0)
	assert_not_null(plan.solid_void_plan)
	assert_true(plan.solid_void_plan.is_sealed())
	assert_not_null(plan.embedding_plan)
	assert_true(plan.embedding_plan.validate())
	assert_gt(int(plan.audit.proposed_closed_boundary_count), 0)
	assert_lt(int(plan.audit.unbounded_route_side_count),
		int(plan.audit.boundary_obligation_count),
		"compiled occupied barriers must close part of the public boundary")
	assert_gt(int(plan.audit.building_base_band_count), 2)
	assert_gte(int(plan.audit.structural_court_cell_count), 31)
	assert_eq(int(plan.audit.stair_endpoint_gap_count), 0)
	assert_eq(int(plan.audit.platform_dead_end_count), 0)
	assert_eq(int(plan.audit.daylight_void_cell_count), 1)
	assert_eq(int(plan.audit.daylight_void_bounded_edge_count), 4)
	assert_eq(int(plan.audit.daylight_void_unbounded_edge_count), 0)
	assert_eq(int(plan.audit.unsupported_platform_count), 0)
	assert_eq(int(plan.audit.unsupported_stair_count), 0)
	assert_gte(int(plan.audit.platform_bearing_parent_count), 2)
	assert_gt(int(plan.audit.served_entrance_count), 0)
	assert_eq(int(plan.audit.unserved_entrance_count), 0)
	assert_gt(int(plan.audit.served_structural_entrance_count), 0)
	assert_eq(int(plan.audit.entrance_guard_conflict_count), 0)
	assert_gte(int(plan.audit.derived_guard_segment_count), 4)
	assert_false(plan.surface_plan.guard_mesh_payload.is_empty())
	assert_gt((plan.surface_plan.guard_mesh_payload.collision_faces \
		as PackedVector3Array).size(), 0)
	assert_eq(int(plan.audit.unclassified_interval_count), 0)
	var surface_visuals := SettlementFabricAssembler.surface_visual_payload(
		plan.surface_plan)
	assert_true(surface_visuals.validate())
	assert_gt(surface_visuals.instance_count, 0)
	assert_true(surface_visuals.asset_ids().has(
		SettlementFabricAssembler.PLANK_FLOOR))
	assert_false(SettlementFabricAssembler.renders_generated_surface_underlay(
		PublicRealmSurfacePlan.SurfaceKind.STRUCTURAL_COURT),
		"authored platform boards must not reveal a dark duplicate mesh below")
	assert_false(SettlementFabricAssembler.renders_generated_surface_underlay(
		PublicRealmSurfacePlan.SurfaceKind.BRIDGE))
	assert_true(SettlementFabricAssembler.renders_generated_surface_underlay(
		PublicRealmSurfacePlan.SurfaceKind.TERRAIN_STREET))


func test_staggered_embedder_closes_route_sides_without_entering_public_air() \
		-> void:
	var plan: SettlementFabricPlan = _folded_proof()
	assert_not_null(plan)
	if plan == null:
		return
	var proposal := plan.embedding_plan
	assert_not_null(proposal)
	if proposal == null:
		return
	assert_true(proposal.validate())
	assert_gt(int(proposal.audit().proposed_barrier_count), 0)
	assert_gt(int(proposal.audit().proposed_closed_boundary_count), 0)
	assert_gt(int(proposal.audit().proposed_base_band_count), 1)
	# The addressed court stack now owns one of the height bands that used to be
	# emitted by this pass. Staggering is a completed-city invariant, not an
	# implementation detail of one particular solver phase.
	assert_gt(int(plan.audit.half_level_neighbor_pair_count), 0)
	assert_gte(int(proposal.audit().proposed_storey_variant_count), 1,
		"the filler may prune tall variants near measured overhang envelopes")
	assert_gt(int(proposal.audit().proposed_market_frontage_count), 0)
	var public_air := plan.public_realm.air_claims()
	for barrier: Dictionary in proposal.barrier_proposals:
		if StringName(barrier.kind) == &"market":
			assert_eq(int(barrier.storeys), 0)
		else:
			assert_true(int(barrier.storeys) >= 1 and int(barrier.storeys) <= 4)
		var support_mode := StringName(barrier.support_mode)
		assert_true(support_mode == &"grounded_stack" \
			or support_mode == &"retained_half_perch")
		assert_eq((barrier.origin as Vector3i).y, 0 \
			if support_mode == &"grounded_stack" else 1)
		for cell: Vector3i in barrier.occupied_cells as Array[Vector3i]:
			assert_false(public_air.has(cell))


func test_critical_review_succeeds_by_reporting_current_visual_issues() -> void:
	var plan: SettlementFabricPlan = _folded_proof()
	assert_not_null(plan)
	if plan == null:
		return
	var failures := SettlementFabricSolver.requirement_failures(plan.audit,
		FoldedProof.REVIEW_TARGETS)
	assert_gt(failures.size(), 0, "review should find an issue in the current slice")
	assert_true(failures.any(func(value: String) -> bool:
		return value.begins_with("frontage_ratio=")))
	assert_true(failures.any(func(value: String) -> bool:
		return value.begins_with("overhead_route_ratio=")))
	assert_true(failures.any(func(value: String) -> bool:
		return value.begins_with("through_sightline_count=")))
	# The compact-cap pass brought both core dimensions under their review cap;
	# keep that gain pinned while the issue-seeking review continues to require
	# enclosure, overhead, and sightline failures until the coupled maze lands.
	assert_false(failures.any(func(value: String) -> bool:
		return value.begins_with("solid_void_core_width_cells=") \
			or value.begins_with("solid_void_core_depth_cells=")))
