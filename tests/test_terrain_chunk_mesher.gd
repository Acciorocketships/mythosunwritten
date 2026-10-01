extends GutTest
const Mesher := preload("res://scripts/terrain/field/TerrainChunkMesher.gd")
const Plan := preload("res://scripts/terrain/heightfield/HeightfieldPlan.gd")

class DryWaterPlan extends WaterPlan:
	func _init() -> void:
		super(7, 1.0, 1)
	func bodies_near(_center_cell: Vector2i, _radius_cells: int) -> Dictionary:
		return {"ponds": [], "rivers": []}

func _feature_context(coverage: Rect2, surface_rects: Array[Rect2],
		clearance_rects: Array[Rect2], limit: float) -> FeatureContext:
	var surfaces: Array[FeatureGroundShape] = []
	var clearances: Array[FeatureGroundShape] = []
	for rect: Rect2 in surface_rects:
		surfaces.append(FeatureGroundShape.axis_rect(rect,
			FeatureGroundField.WORN_PATH))
	for rect: Rect2 in clearance_rects:
		clearances.append(FeatureGroundShape.axis_rect(rect))
	var ground := FeatureGroundField.new(surfaces, clearances, limit)
	return FeatureContext.new(coverage, ground, EnvironmentInstancePayload.new())

func _plan():
	var p := Plan.new(7, 56.0, 12, "mean")
	return p

func _region_for(plan, chunk: Vector2i) -> HeightfieldRegion:
	var centre := chunk * Mesher.POINTS_PER_CHUNK \
		+ Vector2i.ONE * (Mesher.POINTS_PER_CHUNK / 2)
	return plan.compute_region(centre.x, centre.y, Mesher.POINTS_PER_CHUNK)


func test_structural_terrain_uses_the_world_slope_kernel_at_its_own_scale() -> void:
	var tops: Dictionary = {}
	for z in range(-1, 2):
		for x in range(-1, 3):
			tops[Vector2i(x, z)] = 1
	tops[Vector2i.ZERO] = 2
	var region := LatticeTerrainSurfaceRegion.new(tops, 1.5, 1)
	var cells := {
		Vector3i(0, 1, 0): true,
		Vector3i(1, 0, 0): true,
	}
	var payload := Mesher.field_ground_surface(cells, region, 1.5, 0.0,
		&"test-structural-terrain")
	assert_false(payload.is_empty())
	var vertices := payload.vertices as PackedVector3Array
	var high_centre := -INF
	var shared_edge_min := INF
	var shared_edge_max := -INF
	for vertex: Vector3 in vertices:
		if is_zero_approx(vertex.x) and is_zero_approx(vertex.z):
			high_centre = maxf(high_centre, vertex.y)
		if is_equal_approx(vertex.x, 0.75) and is_zero_approx(vertex.z):
			# Both owners emit the seam. They must name the same value.
			shared_edge_min = minf(shared_edge_min, vertex.y)
			shared_edge_max = maxf(shared_edge_max, vertex.y)
	assert_almost_eq(high_centre, 3.0, 0.0001)
	# Village cells are lattice POINTS of the dual-grid kernel at 1.5 m: a
	# one-band step is one 1.5 m slope tile from centre to centre, so the
	# dual-cell border between the owners sits at the smootherstep midpoint
	# (the retired cell kernel put the lower value there). Both owners emit it,
	# and it is exactly what the streamed-world kernel samples at this scale.
	assert_almost_eq(shared_edge_min, 2.25, 0.0001)
	assert_almost_eq(shared_edge_max, 2.25, 0.0001)
	assert_almost_eq(shared_edge_min, TerrainTileField.surface_y(region, 0.75, 0.0), 0.0001,
		"the village sheet is the world kernel at its own lattice scale")
	assert_false(TerrainTileField.is_exposed_edge(region, Vector2i(0, 0),
		Vector2i.RIGHT), "a one-band transition is a slope, not a lipped cliff")
	var indices := payload.indices as PackedInt32Array
	var front_a := vertices[indices[0]]
	var front_b := vertices[indices[1]]
	var front_c := vertices[indices[2]]
	assert_lt((front_b - front_a).cross(front_c - front_a).y, 0.0,
		"Godot's clockwise terrain top face must be visible from above")


func test_flat_structural_terrain_uses_visible_top_face_winding() -> void:
	var payload := Mesher.flat_ground_surface({Vector3i.ZERO: true},
		1.5, 0.0, &"test-flat-terrain")
	var vertices := payload.vertices as PackedVector3Array
	var indices := payload.indices as PackedInt32Array
	var front_a := vertices[indices[0]]
	var front_b := vertices[indices[1]]
	var front_c := vertices[indices[2]]
	assert_lt((front_b - front_a).cross(front_c - front_a).y, 0.0,
		"flat village turf must use the same visible winding as world terrain")


func test_lattice_turf_clips_only_visuals_behind_authored_lips() -> void:
	var cells := {Vector3i.ZERO: true, Vector3i.RIGHT: true}
	var region := LatticeTerrainSurfaceRegion.new(
		{Vector2i.ZERO: 1, Vector2i.RIGHT: 1}, 1.5, 0)
	# The same 2.4 m lip-back overlap as streamed terrain, at half asset scale.
	var cache := SettlementFabricAssembler.maze_turf_clip_cache(cells, region,
		{"faces": [Vector4i(0, 0, 0, SettlementFabricAssembler.FACE_DIRECTIONS.find(
			Vector3i.RIGHT))], "corners": []})
	# A continued/capped run holds its clip all the way to both endpoints.
	cache[Vector2i.ZERO].corners = {Vector2i(1, -1): "outer", Vector2i(1, 1): "outer"}
	var clipped := Mesher.field_ground_surface(cells, region, 1.5, 0.0,
		&"test-lip-clip", true, 2, cache)
	var plain := Mesher.field_ground_surface(cells, region, 1.5, 0.0,
		&"test-lip-plain")
	assert_eq(clipped.collision_faces, plain.collision_faces,
		"lip trimming must not shrink the walkable collision sheet")
	assert_eq(clipped.logical_cells, plain.logical_cells,
		"a lip can cover a whole narrow cell without deleting its logical owner")
	var leak := false
	var unclipped_neighbour := false
	for vertex: Vector3 in clipped.vertices:
		leak = leak or (vertex.x > -0.4259 and vertex.x < 0.7499)
		unclipped_neighbour = unclipped_neighbour or vertex.x > 2.249
	assert_false(leak, "the square green sheet must stop behind the rounded lip")
	assert_true(unclipped_neighbour, "unlipped cells keep their full sheet")
	for index in clipped.vertices.size():
		var owner: Vector3i = clipped.logical_cells[index / 16]
		assert_eq(clipped.vertices[index], Mesher._clip_vert(region, cache,
			owner.x, owner.z, plain.vertices[index]),
			"city turf must use the production vertex clipping kernel, not a second trim")


func test_lattice_inner_corner_uses_the_world_rock_backing_classification() -> void:
	var cells := {Vector3i.ZERO: true}
	var region := LatticeTerrainSurfaceRegion.new({Vector2i.ZERO: 1}, 1.5, 0)
	var cache := SettlementFabricAssembler.maze_turf_clip_cache(cells, region,
		{"faces": [], "corners": [], "inner_corners": [Vector4i(0, 0, 0, 3)]})
	var clipped := Mesher.field_ground_surface(cells, region, 1.5, 0.0,
		&"test-inner-turf", true, 2, cache)
	var plain := Mesher.field_ground_surface(cells, region, 1.5, 0.0,
		&"test-inner-plain")
	var rock_vertices: PackedInt32Array = clipped.get("terrain_rock_vertices", PackedInt32Array())
	assert_gt(rock_vertices.size(), 0,
		"the corner tuck must be rock backing, not a green flap below the lip")
	for index in range(0, clipped.indices.size(), 3):
		var expected_rock := false
		for corner in 3:
			expected_rock = expected_rock or Mesher._inner_corner_vertex(region,
				cache, 0, 0, plain.vertices[plain.indices[index + corner]])
		for corner in 3:
			assert_eq(rock_vertices.has(clipped.indices[index + corner]), expected_rock,
				"both terrain producers classify each complete tuck triangle identically")
	assert_eq(clipped.collision_faces, plain.collision_faces)


static func _triangle_y_at_xz(a: Vector3, b: Vector3, c: Vector3,
		p: Vector2) -> float:
	var denom: float = (b.z - c.z) * (a.x - c.x) \
		+ (c.x - b.x) * (a.z - c.z)
	if absf(denom) < 0.000001:
		return -INF
	var wa: float = ((b.z - c.z) * (p.x - c.x)
		+ (c.x - b.x) * (p.y - c.z)) / denom
	var wb: float = ((c.z - a.z) * (p.x - c.x)
		+ (a.x - c.x) * (p.y - c.z)) / denom
	var wc: float = 1.0 - wa - wb
	if wa < -0.0001 or wb < -0.0001 or wc < -0.0001:
		return -INF
	return wa * a.y + wb * b.y + wc * c.y


static func _surface_y_at(mi: MeshInstance3D, p: Vector2) -> float:
	var arrays: Array = mi.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx_v: Variant = arrays[Mesh.ARRAY_INDEX]
	var idx: PackedInt32Array = idx_v if idx_v != null else PackedInt32Array()
	var count: int = idx.size() if not idx.is_empty() else verts.size()
	var best := -INF
	for ti in range(0, count, 3):
		var ia: int = idx[ti] if not idx.is_empty() else ti
		var ib: int = idx[ti + 1] if not idx.is_empty() else ti + 1
		var ic: int = idx[ti + 2] if not idx.is_empty() else ti + 2
		best = maxf(best, _triangle_y_at_xz(verts[ia], verts[ib], verts[ic], p))
	return best


static func _surface_uv_at(mi: MeshInstance3D, p: Vector2) -> Vector2:
	var arrays: Array = mi.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var idx_v: Variant = arrays[Mesh.ARRAY_INDEX]
	var idx: PackedInt32Array = idx_v if idx_v != null else PackedInt32Array()
	var count: int = idx.size() if not idx.is_empty() else verts.size()
	var best_y := -INF
	var best_uv := Vector2.INF
	for ti in range(0, count, 3):
		var ia: int = idx[ti] if not idx.is_empty() else ti
		var ib: int = idx[ti + 1] if not idx.is_empty() else ti + 1
		var ic: int = idx[ti + 2] if not idx.is_empty() else ti + 2
		var y: float = _triangle_y_at_xz(verts[ia], verts[ib], verts[ic], p)
		if y > best_y:
			best_y = y
			best_uv = uvs[ia]
	return best_uv


static func _surface_uv_layers_at(arrays: Array, p: Vector2,
		skip_uv := Vector2.INF) -> Array[Vector2]:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var idx_v: Variant = arrays[Mesh.ARRAY_INDEX]
	var idx: PackedInt32Array = idx_v if idx_v != null else PackedInt32Array()
	var count: int = idx.size() if not idx.is_empty() else verts.size()
	var found: Array[Vector2] = []
	for ti in range(0, count, 3):
		var ia: int = idx[ti] if not idx.is_empty() else ti
		var ib: int = idx[ti + 1] if not idx.is_empty() else ti + 1
		var ic: int = idx[ti + 2] if not idx.is_empty() else ti + 2
		if _triangle_y_at_xz(verts[ia], verts[ib], verts[ic], p) == -INF \
				or uvs[ia].is_equal_approx(skip_uv):
			continue
		var already := false
		for value: Vector2 in found:
			already = already or value.is_equal_approx(uvs[ia])
		if not already:
			found.append(uvs[ia])
	return found

static func _has_axis_aligned_t_junction(arrays: Array) -> bool:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx_v: Variant = arrays[Mesh.ARRAY_INDEX]
	var idx: PackedInt32Array = idx_v if idx_v != null else PackedInt32Array()
	var horizontal: Dictionary = {} # quantized (z,y) -> x coordinates
	var vertical: Dictionary = {} # quantized (x,y) -> z coordinates
	for vertex: Vector3 in verts:
		var hkey := Vector2i(roundi(vertex.z * 4096.0), roundi(vertex.y * 4096.0))
		var vkey := Vector2i(roundi(vertex.x * 4096.0), roundi(vertex.y * 4096.0))
		if not horizontal.has(hkey):
			horizontal[hkey] = []
		if not vertical.has(vkey):
			vertical[vkey] = []
		if not (horizontal[hkey] as Array).has(vertex.x):
			(horizontal[hkey] as Array).append(vertex.x)
		if not (vertical[vkey] as Array).has(vertex.z):
			(vertical[vkey] as Array).append(vertex.z)
	var count: int = idx.size() if not idx.is_empty() else verts.size()
	for ti in range(0, count, 3):
		var triangle := [
			idx[ti] if not idx.is_empty() else ti,
			idx[ti + 1] if not idx.is_empty() else ti + 1,
			idx[ti + 2] if not idx.is_empty() else ti + 2,
		]
		for edge_index in 3:
			var a: Vector3 = verts[triangle[edge_index]]
			var b: Vector3 = verts[triangle[(edge_index + 1) % 3]]
			if absf(a.z - b.z) <= 0.00001 and absf(a.y - b.y) <= 0.00001:
				var hkey := Vector2i(roundi(a.z * 4096.0), roundi(a.y * 4096.0))
				for x: float in horizontal[hkey]:
					if x > minf(a.x, b.x) + 0.00001 \
							and x < maxf(a.x, b.x) - 0.00001:
						return true
			elif absf(a.x - b.x) <= 0.00001 and absf(a.y - b.y) <= 0.00001:
				var vkey := Vector2i(roundi(a.x * 4096.0), roundi(a.y * 4096.0))
				for z: float in vertical[vkey]:
					if z > minf(a.z, b.z) + 0.00001 \
							and z < maxf(a.z, b.z) - 0.00001:
						return true
	return false


static func _contains_scene_or_server_resource(value: Variant) -> bool:
	if value is Node or value is Mesh or value is Shape3D \
			or value is Material or value is MultiMesh:
		return true
	if value is Array:
		for item: Variant in value:
			if _contains_scene_or_server_resource(item):
				return true
	elif value is Dictionary:
		for item: Variant in value.values():
			if _contains_scene_or_server_resource(item):
				return true
	return false


func test_compute_chunk_payload_is_safe_to_cross_the_worker_boundary():
	var p = _plan()
	var m := Mesher.new()
	m.prepare_resources()
	var region = _region_for(p, Vector2i.ZERO)
	var payload: Dictionary = m.compute_chunk(Vector2i.ZERO, region)
	assert_false(payload.is_empty(), "worker produces a terrain payload")
	assert_false(_contains_scene_or_server_resource(payload),
		"worker payload contains data only; nodes, meshes, materials, and shapes are committed on the main thread")

func test_path_boundary_partitions_are_welded_and_preserve_the_ground_triangle() -> void:
	var vertices: Array[Vector3] = [Vector3(0,1,0),Vector3(1,2,0),Vector3(0,1,1)]
	var colors: Array[Color] = [Color.RED,Color.GREEN,Color.BLUE]
	var predicate := func(p: Vector2) -> bool: return p.x + p.y > 0.37
	var parts := Mesher.partition_paint_triangle(vertices, colors, [false,true,true], predicate)
	var area := 0.0
	var boundary: Array[Vector3] = []
	for part: Dictionary in parts:
		for index in range(1, part.vertices.size() - 1):
			area += (part.vertices[index] - part.vertices[0]).cross(
				part.vertices[index+1] - part.vertices[0]).length() * 0.5
		for point: Vector3 in part.vertices:
			assert_almost_eq(point.y, 1.0 + point.x, 0.00001, "paint remains on the original triangle")
			if absf(point.x + point.z - 0.37) < 0.0001:
				boundary.append(point)
	assert_almost_eq(area, 0.5 * sqrt(2.0), 0.00001, "no overlap and no removed area")
	assert_eq(boundary.size(), 4)
	assert_eq(boundary[0], boundary[2], "both paint owners use bit-identical boundary vertices")
	assert_eq(boundary[1], boundary[3])
	var reversed := Mesher.partition_paint_triangle(
		[vertices[2],vertices[1],vertices[0]], [colors[2],colors[1],colors[0]],
		[true,true,false], predicate)
	for point: Vector3 in boundary:
		assert_true(reversed[0].vertices.has(point), "reversed neighbouring winding cannot move the seam")


func test_path_paint_changes_only_walkable_sheet_uvs() -> void:
	var p = _plan()
	var m := Mesher.new()
	m.prepare_resources()
	var region: HeightfieldRegion = _region_for(p, Vector2i.ZERO)
	var core := Rect2(Vector2.ZERO, Vector2.ONE * Mesher.CHUNK_WORLD)
	var water := WaterFieldContext.build(DryWaterPlan.new(), core, region, 0.0)
	var corridor := Rect2(Vector2(46.0, 0.0), Vector2(4.0, Mesher.CHUNK_WORLD))
	var features := _feature_context(core, [corridor], [corridor], 2.0)
	var grass := m.compute_chunk(Vector2i.ZERO, region)
	var painted := m.compute_chunk(Vector2i.ZERO, region, water, features)
	var before: Array = grass.surface_arrays
	var after: Array = painted.surface_arrays
	assert_eq(painted.collision_faces, grass.collision_faces,
		"path styling never changes physical terrain")
	var before_vertices: PackedVector3Array = before[Mesh.ARRAY_VERTEX]
	var after_vertices: PackedVector3Array = after[Mesh.ARRAY_VERTEX]
	var before_bounds := AABB(before_vertices[0], Vector3.ZERO)
	var after_bounds := AABB(after_vertices[0], Vector3.ZERO)
	for vertex: Vector3 in before_vertices:
		before_bounds = before_bounds.expand(vertex)
	for vertex: Vector3 in after_vertices:
		after_bounds = after_bounds.expand(vertex)
	assert_almost_eq(after_bounds.position.x, before_bounds.position.x, 0.0001)
	assert_almost_eq(after_bounds.position.z, before_bounds.position.z, 0.0001)
	assert_almost_eq(after_bounds.size.x, before_bounds.size.x, 0.0001)
	assert_almost_eq(after_bounds.size.z, before_bounds.size.z, 0.0001)
	assert_lte(after_bounds.end.y, before_bounds.end.y + Mesher.PATH_SPOT_LIFT + 0.0001,
		"visual-only path spots add no meaningful terrain height")
	var uvs: PackedVector2Array = after[Mesh.ARRAY_TEX_UV]
	var colors: PackedColorArray = after[Mesh.ARRAY_COLOR]
	assert_true(uvs.has(SlopeAtlas.path_uv()))
	assert_true(uvs.has(m._grass_uv),
		"ground outside the path keeps the shared grass palette")
	assert_true(uvs.has(SlopeAtlas.path_spot_uv()),
		"sparse darker circles are folded into the same terrain surface")
	var found_darker_spot := false
	for i in uvs.size():
		if uvs[i].is_equal_approx(SlopeAtlas.path_spot_uv()) \
				and colors[i].r <= Mesher.PATH_SPOT_DARKEN + 0.0001:
			found_darker_spot = true
			break
	assert_true(found_darker_spot,
		"circle vertices explicitly darken the nearby path hue")
	var layers := _surface_uv_layers_at(after, Vector2(48.37, 48.37),
		SlopeAtlas.path_spot_uv())
	assert_eq(layers.size(), 1,
		"path paint replaces the local grass patch instead of adding a depth-fighting sheet")
	assert_true(not layers.is_empty() and layers[0].is_equal_approx(SlopeAtlas.path_uv()),
		"the single ground layer at the reported path is the path palette")
	assert_false(_has_axis_aligned_t_junction(after),
		"adaptive path patches stitch every fine boundary vertex into coarse grass")

func test_graded_terrain_has_one_visible_sheet_and_matching_collision() -> void:
	var p = _plan()
	p.set_raw_height_override(func(_x: int, _z: int) -> float: return 0.0)
	var region := _region_for(p, Vector2i.ZERO).with_terrain_grades([
		TerrainGradePatch.new(&"graded", {Vector2i.ZERO: 1.08}, Vector2(49.5, 49.5), 3.0)])
	var m := Mesher.new()
	m.prepare_resources()
	var payload := m.compute_chunk(Vector2i.ZERO, region)
	var arrays: Array = payload.surface_arrays
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var collisions: PackedVector3Array = payload.collision_faces
	var visual_points: Dictionary = {}
	for vertex: Vector3 in vertices:
		visual_points[vertex] = true
	var mismatches := 0
	var checked := 0
	for vertex: Vector3 in collisions:
		if Rect2(40, 40, 18, 18).has_point(Vector2(vertex.x, vertex.z)):
			checked += 1
			if not visual_points.has(vertex):
				mismatches += 1
	assert_gt(checked, 100, "graded collision follows the fine terrain tessellation")
	assert_eq(mismatches, 0, "collision and visual terrain use identical vertices")
	assert_eq(_surface_uv_layers_at(arrays, Vector2(49.37, 49.41),
		SlopeAtlas.path_spot_uv()).size(), 1, "no second ground sheet")
	assert_false(_has_axis_aligned_t_junction(arrays), "grade collar joins coarse terrain")


func test_build_returns_meshinstance_with_geometry():
	var p = _plan()
	var node: Node3D = Mesher.new().build_chunk(p, Vector2i(0, 0))
	var mi := node.find_child("Surface", true, false) as MeshInstance3D
	assert_not_null(mi, "chunk has a Surface MeshInstance3D")
	assert_gt(mi.mesh.get_surface_count(), 0, "mesh has geometry")
	node.free()

func test_chunk_has_collision():
	var node: Node3D = Mesher.new().build_chunk(_plan(), Vector2i(0, 0))
	var body := node.find_child("Body", true, false) as StaticBody3D
	assert_not_null(body, "chunk has a StaticBody3D")
	var cs := body.find_child("CollisionShape3D", true, false) as CollisionShape3D
	assert_not_null(cs)
	assert_true(cs.shape is ConcavePolygonShape3D, "trimesh collision")
	node.free()

func test_no_floating_water_planes():
	# Owner screenshot (seed 3846192678): the per-chunk water quads sat at y=2 over
	# flat storey-0 ground with no basin around them, textured with the ground-material fallback
	# (water.tres doesn't exist) — reading as weird floating brown planes. The owner asked to
	# remove them; the global WaterSurface scene is the water visual instead.
	var m := Mesher.new()
	m.set_seed(3846192678)
	var p := Plan.new(3846192678, 22.0, 8, "mean", 3)
	var node: Node3D = m.build_chunk(p, Vector2i(0, -1))
	var water := node.find_child("Water", true, false) as MeshInstance3D
	assert_true(water == null or water.mesh == null, "chunks emit no floating water quads")
	node.free()

func test_terrain_mesher_does_not_own_dressing():
	var node: Node3D = Mesher.new().build_chunk(_plan(), Vector2i(0, 0))
	assert_null(node.find_child("Decorations", true, false),
		"visual dressing is a sibling streamer payload, not terrain geometry")
	node.free()

# --- point-lattice fixtures ------------------------------------------------------
# Heights live on 12 m lattice points (dual-grid terrain tiles). A chunk's sheet
# is its 192 m square; its walls are those of points 16k .. 16k+15.

## A region from explicit point heights (metres; storey = floor(h/4)), over a
## window comfortably larger than chunks (0,0)/(1,0) and their halos.
static func _points(heights: Callable) -> HeightfieldRegion:
	var storeys := {}
	var levels := {}
	for j in range(-24, 41):
		for i in range(-24, 57):
			var h: float = heights.call(i, j)
			storeys[Vector2i(i, j)] = floori(h / 4.0)
			levels[Vector2i(i, j)] = floori(fposmod(h, 4.0))
	return HeightfieldRegion.new(storeys, levels)

## A plateau 3 storeys high west of the wall x = 12*7 + 6 = 90, with an
## outer corner at z = 12*9 + 6 = 114, a one-storey slope step on its top,
## an E2 cliff end into a slope and a level step: every wall/slope case.
static func _mixed_region() -> HeightfieldRegion:
	return _points(func(i: int, j: int) -> float:
		if i <= 7 and j <= 9:
			if i == 3 and j == 3: return 16.0   # one-storey bump on the plateau (slope)
			return 12.0
		if i == 8 and j == 10: return 4.0      # slope beside the wall's low side (E2 end)
		if i >= 20: return 1.0                 # level step east
		return 0.0)

static func _cliff_region() -> HeightfieldRegion:
	return _points(func(i: int, _j: int) -> float: return 12.0 if i <= 7 else 0.0)

## Heights compare as the float32 vertex components hold them.
static func _f32(value: float) -> float:
	return Vector3(value, 0.0, 0.0).x

func _mesher() -> TerrainChunkMesher:
	var m := Mesher.new()
	m.prepare_resources()
	return m

static func _sheet_triangles(arrays: Array) -> Array:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var out: Array = []
	for t in range(0, idx.size(), 3):
		out.append([verts[idx[t]], verts[idx[t + 1]], verts[idx[t + 2]]])
	return out

## The walls a chunk owns: wall segments whose high owner is one of its points.
static func _owned_walls(region, chunk: Vector2i) -> Array:
	var lo := chunk * Mesher.POINTS_PER_CHUNK
	var owned := Rect2i(lo, Vector2i.ONE * Mesher.POINTS_PER_CHUNK)
	var rect := Rect2(Vector2(lo) * 12.0 - Vector2.ONE * 6.0, Vector2.ONE * 192.0)
	var out: Array = []
	for wall: Dictionary in TerrainTileField.wall_segments(region, rect):
		if owned.has_point(wall.high):
			out.append(wall)
	return out

## Required (task 4): along every wall the skirt's top welds the high owner's
## sheet and its bottom the low owner's sheet: both are bit-identical sheet
## boundary vertices at every 2 m sample of the wall line.
func test_skirt_top_welds_the_high_sheet_and_bottom_the_low_sheet_along_every_wall() -> void:
	for region: HeightfieldRegion in [_mixed_region(), _cliff_region()]:
		var data := _mesher().compute_chunk(Vector2i.ZERO, region)
		var sheet: Dictionary = {}
		for v: Vector3 in (data.surface_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			var key := Vector2(v.x, v.z)
			if not sheet.has(key): sheet[key] = {}
			sheet[key][v.y] = true
		var skirt: Dictionary = {}
		for v: Vector3 in (data.wall_collision_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			var key := Vector2(v.x, v.z)
			if not skirt.has(key): skirt[key] = {}
			skirt[key][v.y] = true
		var walls := _owned_walls(region, Vector2i.ZERO)
		assert_gt(walls.size(), 0, "fixture has walls")
		var checked := 0
		for wall: Dictionary in walls:
			var a: Vector2 = wall.a
			var b: Vector2 = wall.b
			var along := (b - a).normalized()
			for k in 4:
				var p := a + along * (2.0 * k)
				var top := _f32(TerrainTileField.surface_y_on_side(region, p.x, p.y, wall.high))
				var bottom := _f32(TerrainTileField.surface_y_on_side(region, p.x, p.y, wall.low))
				if top <= bottom + 0.001:
					continue
				assert_true(skirt.has(p) and skirt[p].has(top) and skirt[p].has(bottom),
					"skirt spans %s..%s at %s" % [bottom, top, p])
				if p.x >= 0.0 and p.x <= 192.0 and p.y >= 0.0 and p.y <= 192.0:
					assert_true(sheet.has(p) and sheet[p].has(top), "high sheet welds the skirt top at %s" % p)
					assert_true(sheet.has(p) and sheet[p].has(bottom), "low sheet welds the skirt bottom at %s" % p)
					checked += 1
		assert_gt(checked, 10, "wall samples inside the sheet were checked")

## Required: no sheet triangle straddles a wall. Every triangle lies in one
## lattice point's dual cell and every vertex is that point's own surface.
func test_no_sheet_triangle_straddles_a_wall() -> void:
	var region := _mixed_region()
	var data := _mesher().compute_chunk(Vector2i.ZERO, region)
	var bad := 0
	for tri: Array in _sheet_triangles(data.surface_arrays):
		var c: Vector3 = (tri[0] + tri[1] + tri[2]) / 3.0
		var owner := Vector2i(TerrainTileField.point_of(c.x), TerrainTileField.point_of(c.z))
		for v: Vector3 in tri:
			var inside := absf(v.x - owner.x * 12.0) <= 6.0 and absf(v.z - owner.y * 12.0) <= 6.0
			if not inside or v.y != _f32(TerrainTileField.surface_y_on_side(region, v.x, v.z, owner)):
				bad += 1
	assert_eq(bad, 0, "every sheet vertex is its triangle's owner surface, inside its dual cell")

## Required: seam equality between adjacent chunks. Their sheets share every
## border vertex exactly, and each wall is skirted by exactly one of them.
func test_adjacent_chunks_share_border_vertices_and_each_wall_once() -> void:
	var region := _points(func(i: int, j: int) -> float:
		# Walls cross the chunk border x = 192 (points 15|16) along z = 12*5+6,
		# and stand right on the dual border x = 186 (points 15|16 at i = 15.5).
		if j <= 5 and i >= 10 and i <= 22: return 12.0
		if i == 15 and j >= 10: return 20.0
		return 0.0)
	var m := _mesher()
	var left := m.compute_chunk(Vector2i(0, 0), region)
	var right := m.compute_chunk(Vector2i(1, 0), region)
	var border := func(data: Dictionary) -> Dictionary:
		var out := {}
		for v: Vector3 in (data.surface_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			if v.x == 192.0:
				out[v] = true
		return out
	var a: Dictionary = border.call(left)
	var b: Dictionary = border.call(right)
	assert_gt(a.size(), 96, "the border column is present")
	assert_eq(a.keys().size(), b.keys().size(), "same border vertex count")
	for v: Vector3 in a:
		assert_true(b.has(v), "right chunk has the left chunk's border vertex %s" % v)
	var quads := {}
	var duplicated := 0
	for data: Dictionary in [left, right]:
		var verts: PackedVector3Array = data.wall_collision_arrays[Mesh.ARRAY_VERTEX]
		var seen := {}
		for t in range(0, verts.size(), 12):
			var key := [verts[t], verts[t + 1], verts[t + 2]]
			key.sort()
			if seen.has(key):
				continue
			seen[key] = true
			if quads.has(key):
				duplicated += 1
			quads[key] = true
	assert_eq(duplicated, 0, "no wall face is emitted by both chunks")
	# Every wall of both chunks' points is skirted somewhere.
	for chunk: Vector2i in [Vector2i(0, 0), Vector2i(1, 0)]:
		for wall: Dictionary in _owned_walls(region, chunk):
			var p: Vector2 = wall.a
			var covered := false
			for key: Array in quads:
				for v: Vector3 in key:
					covered = covered or Vector2(v.x, v.z) == p
			assert_true(covered, "wall at %s is skirted" % p)

## Required: the collision sheet covers the visual sheet (no lip clip: the
## visible ground and the walkable ground are the same triangles).
func test_collision_covers_the_sheet() -> void:
	var data := _mesher().compute_chunk(Vector2i.ZERO, _mixed_region())
	var collision := {}
	var faces: PackedVector3Array = data.collision_faces
	for t in range(0, faces.size(), 3):
		var key := [faces[t], faces[t + 1], faces[t + 2]]
		key.sort()
		collision[key] = true
	var missing := 0
	var tris := _sheet_triangles(data.surface_arrays)
	for tri: Array in tris:
		var key := tri.duplicate()
		key.sort()
		if not collision.has(key):
			missing += 1
	assert_eq(tris.size(), faces.size() / 3, "one collision triangle per sheet triangle")
	assert_eq(missing, 0, "every visible sheet triangle is walkable collision")

func test_chunk_emits_a_rock_cliff_wall_without_native_pieces():
	var m := _mesher()
	var data := m.compute_chunk(Vector2i.ZERO, _cliff_region())
	# (The visual skirt faces the slope sheet buries are withdrawn; the
	# collision arrays keep every face with the same UVs.)
	var uvs: PackedVector2Array = data.wall_collision_arrays[Mesh.ARRAY_TEX_UV]
	assert_gt(uvs.size(), 0)
	for uv: Vector2 in uvs:
		assert_true(uv.is_equal_approx(m._skirt_uv), "the three-storey skirt is rock, never grass")
	var node := m.commit_chunk(data)
	var body := node.find_child("Body", true, false) as StaticBody3D
	assert_not_null(body.get_node_or_null("CollisionShape3D_walls"), "collision wall present")
	assert_null(node.find_child("Cliffs", true, false), "world terrain places no KayKit wall/lip pieces")
	assert_null(node.find_child("Aprons", true, false), "no aprons: nothing is recessed to seal")
	node.free()

func test_cliff_skirt_stands_on_the_wall_line_with_no_cap():
	# The 3-storey cliff between points 7 and 8 stands on x = 90, the dual border.
	var data := _mesher().compute_chunk(Vector2i.ZERO, _cliff_region())
	for key: String in ["wall_arrays", "wall_collision_arrays"]:
		if (data[key] as Array).is_empty():
			assert_eq(key, "wall_arrays", "only the visual skirt may be wholly buried by the slope")
			continue
		var verts: PackedVector3Array = data[key][Mesh.ARRAY_VERTEX]
		assert_gt(verts.size(), 0)
		var horizontal := 0
		for t in range(0, verts.size(), 3):
			var n := (verts[t + 1] - verts[t]).cross(verts[t + 2] - verts[t])
			if n.length() > 0.0 and absf(n.normalized().y) > 0.3: horizontal += 1
			for v: Vector3 in [verts[t], verts[t + 1], verts[t + 2]]:
				assert_eq(v.x, 90.0, "%s vertex on the wall line" % key)
				assert_true(v.y == 12.0 or v.y == 0.0, "%s spans exactly the two owners' surfaces" % key)
		assert_eq(horizontal, 0, "no horizontal cap triangles")

func test_outer_corner_skirts_meet_at_the_corner_point():
	# Plateau x <= 7, z <= 9: walls x = 90 (z <= 114) and z = 114 (x <= 90).
	var region := _points(func(i: int, j: int) -> float: return 12.0 if i <= 7 and j <= 9 else 0.0)
	var verts: PackedVector3Array = _mesher().compute_chunk(Vector2i.ZERO, region).wall_collision_arrays[Mesh.ARRAY_VERTEX]
	var east_max_z := -INF
	var south_max_x := -INF
	for v: Vector3 in verts:
		if v.x == 90.0: east_max_z = maxf(east_max_z, v.z)
		if v.z == 114.0: south_max_x = maxf(south_max_x, v.x)
	assert_eq(east_max_z, 114.0, "the east face ends at the corner (no fin past it)")
	assert_eq(south_max_x, 90.0, "the south face ends at the corner")

func test_skirt_follows_a_dipping_neighbour_slope():
	# The low side of the x = 90 wall slopes down along the wall (point (8,5)
	# is a storey below its neighbours): the skirt bottom follows it to y = 0.
	var region := _points(func(i: int, j: int) -> float:
		if i <= 7: return 12.0
		if i == 8 and j == 5: return 0.0
		return 4.0)
	var verts: PackedVector3Array = _mesher().compute_chunk(Vector2i.ZERO, region).wall_collision_arrays[Mesh.ARRAY_VERTEX]
	var lowest := INF
	for v: Vector3 in verts:
		if v.x == 90.0 and absf(v.z - 60.0) < 6.5:
			lowest = minf(lowest, v.y)
	assert_eq(lowest, 0.0, "the skirt reaches the dipped neighbour surface, not the storey line")

func test_level_and_one_storey_steps_are_continuous_without_a_vertical_wall():
	var region := _points(func(i: int, j: int) -> float:
		if i == 3 and j == 3: return 4.1   # level steps
		if i == 4 and j == 3: return 4.9
		if i >= 6: return 1.6             # one storey below: a slope
		return 5.6)
	var data := _mesher().compute_chunk(Vector2i.ZERO, region)
	assert_true((data.wall_arrays as Array).is_empty(), "slopes meet as one sheet; no wall exists")
	assert_true((data.wall_collision_arrays as Array).is_empty())

func test_collision_wall_is_flush_with_the_wall_line_no_pocket():
	var node := _mesher().commit_chunk(_mesher().compute_chunk(Vector2i.ZERO, _cliff_region()))
	var cs := node.find_child("Body", true, false).get_node("CollisionShape3D_walls") as CollisionShape3D
	var faces: PackedVector3Array = (cs.shape as ConcavePolygonShape3D).get_faces()
	assert_gt(faces.size(), 0, "collision wall has geometry")
	var top := -1e9
	for v in faces:
		assert_eq(v.x, 90.0, "collision wall sits ON the wall line")
		top = maxf(top, v.y)
	assert_eq(top, 12.0, "collision wall reaches the cliff top")
	node.free()

func test_cliff_top_sheet_and_collision_reach_the_wall_line():
	var data := _mesher().compute_chunk(Vector2i.ZERO, _cliff_region())
	var visual := false
	for v: Vector3 in (data.surface_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array):
		visual = visual or (v.y == 12.0 and v.x == 90.0)
	var walkable := false
	for v: Vector3 in (data.collision_faces as PackedVector3Array):
		walkable = walkable or (v.y == 12.0 and v.x == 90.0)
	assert_true(visual, "the visible cliff top runs flat to its wall (no lip clip)")
	assert_true(walkable, "collision covers the cliff top to the wall line")

func test_sheet_and_skirt_share_one_material():
	# One shared runtime ground-palette material for sheet and skirt.
	var mesher := _mesher()
	var node := mesher.commit_chunk(mesher.compute_chunk(Vector2i.ZERO, _cliff_region()))
	var mi := node.find_child("Surface", true, false) as MeshInstance3D
	var sheet_mat := mi.mesh.surface_get_material(0) as ShaderMaterial
	assert_same(sheet_mat, mesher._skirt_material, "sheet and skirt share the complete ground style")
	assert_same(sheet_mat.get_shader_parameter("ground_palette_texture"), CliffDressing.ground_texture(),
		"one palette remains the source for turf, paths and rock")
	# the sheet's grass texel comes from the lip piece's grass top, not the terrain atlas
	var arr = (CliffDressing._pieces["lip"][0] as Mesh).surface_get_arrays(0)
	var lverts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var lnorms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var luvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var m := Mesher.new()
	m._ensure_skirt_style()
	var from_lip_top := false
	for i in lverts.size():
		if lnorms[i].y > 0.9 and lverts[i].y > -0.05 and luvs[i].is_equal_approx(m._grass_uv):
			from_lip_top = true
	assert_true(from_lip_top, "the sheet's grass texel is sampled from the lip piece's top face")
	node.free()

func test_skirt_material_has_no_specular_sheen():
	var m := Mesher.new()
	m._ensure_skirt_style()
	var mat := m._skirt_material as ShaderMaterial
	assert_true(mat.shader.code.contains("ROUGHNESS = 1.0"), "matte ground")
	assert_true(mat.shader.code.contains("SPECULAR = 0.0"), "no angle-dependent sheen")

func test_surface_is_gap_free_for_any_heightfield():
	# Every grid quad is rendered (two triangles), on wild cliff-riddled fields.
	var expected := Mesher.GRID * Mesher.GRID * 2
	for seed in [1, 7, 42, 999]:
		var p := Plan.new(seed, 40.0, 12, "mean", 3)
		var node := Mesher.new().build_chunk(p, Vector2i(0, 0))
		var mi := node.find_child("Surface", true, false) as MeshInstance3D
		var idx: PackedInt32Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX]
		assert_eq(idx.size() / 3, expected, "seed %d: every quad rendered (gap-free surface)" % seed)
		node.free()

func test_no_grass_triangle_spans_a_cliff():
	var data := _mesher().compute_chunk(Vector2i.ZERO, _cliff_region())
	var worst := 0.0
	for tri: Array in _sheet_triangles(data.surface_arrays):
		worst = maxf(worst, maxf(maxf(tri[0].y, tri[1].y), tri[2].y) - minf(minf(tri[0].y, tri[1].y), tri[2].y))
	assert_lt(worst, 6.0, "no sheet triangle spans a cliff's height (cliff faces are the skirt)")

func test_collision_sheet_faces_cover_full_grid():
	var p := HeightfieldPlan.new(4242, 40.0, 8, "mean")
	var region := p.compute_region(8, 8, 16)
	var data := _mesher().compute_chunk(Vector2i.ZERO, region)
	var faces: PackedVector3Array = data.collision_faces
	assert_eq(faces.size(), Mesher.GRID * Mesher.GRID * 6, "2 triangles (6 vertices) per grid quad, full extent")
	var owner := Vector2i(TerrainTileField.point_of(Mesher.STEP * 0.5), TerrainTileField.point_of(Mesher.STEP * 0.5))
	assert_eq(faces[0].y, TerrainTileField.surface_y_on_side(region, 0.0, 0.0, owner),
		"collision tracks the pinned surface")

func test_vertex_owner_candidates_tie_on_the_dual_border():
	assert_eq(Mesher._owner_candidates(90.0, 12.0), [8, 7] as Array[int], "x = 90 lies between points 7 and 8")
	assert_eq(Mesher._owner_candidates(-6.0, 12.0), [-1, 0] as Array[int])
	assert_eq(Mesher._owner_candidates(88.0, 12.0), [7] as Array[int])

## A graded street across a natural cliff leaves no cliff collision above it
## (September 13; re-pinned on points). Town grades reach the terrain as
## per-point controls (HeightfieldRegion.native_control_heights, what
## with_terrain_grades writes): here the street's points are supplied directly,
## so the invariant does not depend on the grade solver (NativeTerrainGrade).
func test_graded_street_leaves_no_cliff_collision_above_it():
	# A 12 m plateau (points x <= 0) walls down to 0 m on x = 6; the street
	# levels points z in [-1, 1], x in [-2, 3] at 4 m across that wall.
	var region := _points(func(i: int, _j: int) -> float: return 12.0 if i <= 0 else 0.0)
	for j in range(-1, 2):
		for i in range(-2, 4):
			region.native_control_heights[Vector2i(i, j)] = 4.0
	var vertices: PackedVector3Array = _mesher().compute_chunk(Vector2i.ZERO, region) \
		.wall_collision_arrays[Mesh.ARRAY_VERTEX]
	var intrusions := 0
	var outside := 0
	for v: Vector3 in vertices:
		if v.x == 6.0 and absf(v.z) < 12.0 and v.y > 4.01:
			intrusions += 1
		if v.x == 6.0 and v.z > 24.0 and v.y > 4.01:
			outside += 1
	assert_eq(intrusions, 0, "the old cliff cannot remain as an invisible barrier above the graded street")
	assert_gt(outside, 0, "the natural cliff beyond the street remains")
