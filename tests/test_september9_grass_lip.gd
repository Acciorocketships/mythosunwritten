extends GutTest

const A = preload("res://scripts/terrain/features/villages/fabric/SettlementFabricAssembler.gd")
const Frozen = preload("res://tests/fixtures/frozen_maze_source.gd")
var program: SettlementFabricProgram
var transaction: Dictionary
var controls: Dictionary

func before_all() -> void:
	program = SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var spatial := Frozen.spatial(Frozen.read("res://tests/fixtures/september9-east-source.txt"), program)
	var plan := spatial.compiled_fabric_cache()
	transaction = A.maze_ground_skin_transaction(plan)
	controls = A.maze_terrain_control_surface_cells(plan)

func _rotate(cell: Vector3i, turns: int) -> Vector3i:
	for turn in turns: cell = Vector3i(-cell.z, cell.y, cell.x)
	return cell

func _rotated(cells: Dictionary, turns: int) -> Dictionary:
	var out := {}
	for cell: Vector3i in cells: out[_rotate(cell, turns)] = cells[cell]
	return out

func _payload(turns: int, owned: bool) -> EnvironmentInstancePayload:
	var caps := _rotated(transaction.capped_ground, turns)
	var region := A.maze_terrain_surface_region(caps, _rotated(controls, turns))
	# With explicit capped cells, the finished terrain field owns every rim.
	# Retaining shell faces only establish that this is a dressed settlement.
	return A.maze_green_rim_walls({}, {}, {}, {}, {},
		{"exposed": {Vector4i.ZERO: true}, "treatments": {}}, {}, caps, true, region,
		program.asset_wall_interfaces if owned else {})

func _cell_triangles(payload: EnvironmentInstancePayload, cell: Vector3i) -> PackedVector3Array:
	var out := PackedVector3Array()
	var center := Vector3(cell) * FabricRecipe.CELL_SIZE
	for mesh: Dictionary in payload.surface_meshes:
		if absf(mesh.anchor.x - center.x) < 0.001 and absf(mesh.anchor.z - center.z) < 0.001:
			out.append_array(mesh.vertices)
	for asset: StringName in payload.batches:
		for pose: Transform3D in payload.batches[asset].transforms:
			if absf(pose.origin.x - center.x) > 0.001 or absf(pose.origin.z - center.z) > 0.001: continue
			for surface: Dictionary in program.asset_wall_interfaces[asset].complete_surfaces:
				for vertex: Dictionary in surface.triangles: out.append(pose * vertex.position)
	return out

func _covered(vertices: PackedVector3Array, point: Vector2) -> bool:
	for index in range(0, vertices.size(), 3):
		var a := Vector2(vertices[index].x, vertices[index].z)
		var b := Vector2(vertices[index+1].x, vertices[index+1].z)
		var c := Vector2(vertices[index+2].x, vertices[index+2].z)
		if absf((b-a).cross(c-a)) < 0.000001: continue
		if Geometry2D.point_is_inside_triangle(point, a, b, c): return true
	return false

func test_reported_narrow_strip_and_end_keep_a_closed_rolled_edge_in_four_orientations() -> void:
	for turns in 4:
		var before := _payload(turns, false)
		var after := _payload(turns, true)
		assert_true(after.validate())
		for original: Vector3i in [Vector3i(-3,0,-5), Vector3i(-3,0,-6), Vector3i(-3,0,-4)]:
			var cell := _rotate(original, turns)
			var old := _cell_triangles(before, cell)
			var fixed := _cell_triangles(after, cell)
			var center := Vector3(cell) * FabricRecipe.CELL_SIZE
			var outward := Vector3(_rotate(Vector3i.RIGHT, turns))
			var before_extent := -INF
			var after_extent := -INF
			for vertex in old: before_extent = maxf(before_extent, (vertex-center).dot(outward))
			for vertex in fixed: after_extent = maxf(after_extent, (vertex-center).dot(outward))
			assert_gt(before_extent, 0.70, "Original native back protrudes past the opposite rolled nose")
			assert_almost_eq(after_extent, 0.625, 0.00001, "Only the authored nose reaches the lawn boundary")
			assert_gt(fixed.size(), 0)
			# The middle remains filled after splitting the overlapping source;
			# trimming must not replace the overhang with a hole at the shared center.
			for x in range(-4,5):
				for z in range(-4,5):
					assert_true(_covered(fixed, Vector2(center.x+x*0.1, center.z+z*0.1)), "Native top remains covered")
		# Visual-only native lips do not change the underlying collision surface.
		for mesh: Dictionary in after.surface_meshes:
			assert_true(mesh.visual_only)
			assert_true(mesh.collision_faces.is_empty())
			assert_eq(mesh.vertices.size(), mesh.uvs.size())

func test_native_lip_collision_and_world_tint_contract_survive_surface_ownership() -> void:
	var catalog := EnvironmentCatalog.load_default()
	for asset: StringName in [A.GREEN_RIM_EDGE, A.GREEN_RIM_OUTER_CORNER, A.GREEN_RIM_INNER_CORNER]:
		assert_eq(catalog.descriptor(asset).collision_piece_count, 0, "Field owns collision; lips only finish its edge")
	var payload := _payload(0, true)
	assert_gt(payload.surface_meshes.size(), 0)
	var frame := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*2), Vector3(238.5,8.08,-365.5))
	for mesh: Dictionary in payload.surface_meshes:
		var world := VillageWarrenFabricSolver._world_surface_mesh(mesh, frame, &"test", 2697992464)
		var expected := CliffDressing.tint_at(frame*Transform3D(Basis.IDENTITY,mesh.anchor), 2697992464)
		assert_eq(world.uvs, mesh.uvs, "Authored texture coordinates survive world placement")
		for index in mesh.colors.size(): assert_eq(world.colors[index], mesh.colors[index]*expected)
