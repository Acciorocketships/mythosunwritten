# scripts/terrain/field/TerrainChunkMesher.gd
# Builds ONE continuous surface mesh for a chunk by sampling the dual-grid tile
# kernel (TerrainTileField) on a shared 2 m grid. Every 2 m quad is pinned to the
# 12 m lattice point owning its centre; adjacent chunks sample the same boundary
# coordinates, so there are no seams. Walls (dual-cell borders where two points'
# surfaces differ) get a vertical rock skirt between the two owners' surfaces.
class_name TerrainChunkMesher
extends RefCounted

const CLIFF_ROCKS := preload("res://scripts/terrain/field/CliffRockDressing.gd")
const ARCHES := preload("res://scripts/terrain/field/NaturalArches.gd")

## The 24 m lattice: biome tint corners and the road (path) cells. A chunk is
## 8 x 8 of them.
const CELL := 24.0
const CELLS_PER_CHUNK := 8
## The 12 m terrain lattice points a chunk owns per axis: 16 k .. 16 k + 15.
const POINTS_PER_CHUNK := 16
# 12 samples per 24 m (2 m resolution) tessellates the smootherstep slope band
# finely enough to read as a smooth curve rather than a few flat facets, and puts
# a grid line on every wall (x or z = 12 i + 6).
const SAMPLES_PER_CELL := 12
const CHUNK_WORLD := CELL * CELLS_PER_CHUNK          # 192
const STEP := CELL / SAMPLES_PER_CELL                # 2.0
const GRID := CELLS_PER_CHUNK * SAMPLES_PER_CELL     # 96 quads per axis

var _material: Material = null
var profile_enabled := false
## Complete deterministic operations only; observer never owns geometry.
var phase_callback := Callable()
var _fine_vertices_usec := 0
var _fine_paint_usec := 0
var _ground_tinted: Material = null
var _grass_uv: Vector2 = SlopeAtlas.grass_uv()
var _path_uv: Vector2 = SlopeAtlas.path_uv()
var _path_spot_uv: Vector2 = SlopeAtlas.path_spot_uv()
var _cliff_uv: Vector2 = SlopeAtlas.cliff_uv()
# The skirt renders with THE shared terrain material and the rock texel of the KayKit wall
# piece's mesh (the terrain atlas rock read as a clearly different colour, owner's round 3).
var _skirt_material: Material = null
var _skirt_uv := Vector2.ZERO

func _ensure_skirt_style() -> void:
	if _skirt_material != null:
		return
	CliffDressing._ensure_loaded()
	var wall_mesh: Mesh = CliffDressing._pieces["wall"][0]
	# THE shared de-sheened terrain material (also overridden onto every dressing piece)
	_skirt_material = CliffDressing.shared_material()
	var uvs: PackedVector2Array = wall_mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
	if uvs.size() > 0:
		_skirt_uv = uvs[0]
	if _skirt_material == null:
		_skirt_material = _material
		_skirt_uv = _cliff_uv
		return
	# ONE material for every terrain surface (owner round 8: "the cliff lip, the skirt, and
	# the slope are all different colours... it would be nice if they all used the same
	# [texture]"): the walkable sheet renders with the same de-sheened KayKit palette,
	# grass texel sampled from the lip piece's top face — so lips, walls, skirt, sheet and
	# slopes all share one texture that can be retinted in one place.
	_material = _skirt_material
	_grass_uv = CliffDressing.ground_uv()

# The walkable sheet renders with THE shared material itself (it already reads
# COLOR — CliffDressing.shared_material sets vertex_color_use_as_albedo), so the
# sheet, skirt and every dressing piece share literally ONE Material
# instance: change the palette once, everything follows (owner: "pulling from
# the exact same colour/material"). _ensure_skirt_style() first (idempotent) so
# `_material` has become that shared palette.
func _ground_tinted_mat() -> Material:
	if _ground_tinted == null:
		_ensure_skirt_style()
		if _material is StandardMaterial3D:
			(_material as StandardMaterial3D).vertex_color_use_as_albedo = true
		_ground_tinted = _material
	return _ground_tinted

var _water_seed: int = 0   # set by streamer via set_seed(); 0 in tests

func set_seed(seed: int) -> void:
	_water_seed = seed


## Build a flat, visual-only union on an arbitrary procedural lattice using the
## same payload contract, palette marker, winding, and exact shared boundaries
## as the terrain sheet. Settlement terraces call this instead of scaling and
## overlapping authored grass panels. Resource binding remains a main-thread
## commit concern; this worker-safe function returns plain arrays only.
static func flat_ground_surface(cells: Dictionary, cell_size: float,
		lift: float, stable_id: StringName,
		include_collision: bool = true) -> Dictionary:
	assert(cell_size > 0.0 and not stable_id.is_empty())
	if cells.is_empty():
		return {}
	var ordered: Array[Vector3i] = []
	ordered.assign(cells.keys())
	ordered.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		if a.y != b.y:
			return a.y < b.y
		return a.z < b.z if a.z != b.z else a.x < b.x)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var collision_faces := PackedVector3Array()
	vertices.resize(ordered.size() * 4)
	normals.resize(vertices.size())
	uvs.resize(vertices.size())
	indices.resize(ordered.size() * 6)
	if include_collision:
		collision_faces.resize(ordered.size() * 6)
	var half := cell_size * 0.5
	for cell_index in ordered.size():
		var cell := ordered[cell_index]
		var centre := Vector3(float(cell.x) * cell_size,
			float(cell.y + 1) * cell_size + lift,
			float(cell.z) * cell_size)
		var vi := cell_index * 4
		vertices[vi] = centre + Vector3(-half, 0.0, -half)
		vertices[vi + 1] = centre + Vector3(half, 0.0, -half)
		vertices[vi + 2] = centre + Vector3(half, 0.0, half)
		vertices[vi + 3] = centre + Vector3(-half, 0.0, half)
		for corner in 4:
			normals[vi + corner] = Vector3.UP
			# Main-thread terrain binding replaces this worker-safe sentinel
			# with `CliffDressing.ground_uv()`.
			uvs[vi + corner] = Vector2.ZERO
		var ii := cell_index * 6
		# Godot treats clockwise triangles as front-facing.  Keep this in the
		# same XZ order as the streamed sheet (`p00, p10, p11`): reversing these
		# indices leaves collision intact but culls the turf from every camera
		# above it.
		indices[ii] = vi
		indices[ii + 1] = vi + 1
		indices[ii + 2] = vi + 2
		indices[ii + 3] = vi
		indices[ii + 4] = vi + 2
		indices[ii + 5] = vi + 3
		if include_collision:
			for corner in 6:
				collision_faces[ii + corner] = vertices[indices[ii + corner]]
	return {
		"stable_id": stable_id,
		"anchor": vertices[0],
		# Preserve the exact selected owners beside their tessellation. Consumers
		# must not reverse-engineer a logical cell from a sloped sub-quad's centre:
		# one cell deliberately emits several patches at different heights.
		"logical_cells": ordered,
		"vertices": vertices,
		"normals": normals,
		"uvs": uvs,
		"indices": indices,
		"collision_faces": collision_faces,
		"visual_only": not include_collision,
		"terrain_ground": true,
	}


## The scale-independent form of the production terrain sheet. `cells` selects
## which lattice points emit their dual cells, while `region` decides every
## slope and cliff exactly as TerrainTileField does for the streamed world. This is intentionally not a village-specific tiler: any structural
## terrain column field can use the same pure payload path.
static func field_ground_surface(cells: Dictionary, region,
		cell_size: float, lift: float, stable_id: StringName,
		include_collision: bool = true, samples_per_cell: int = 2,
		clip_cache: Dictionary = {}) -> Dictionary:
	assert(region != null and is_equal_approx(
		TerrainTileField.spacing(region), cell_size))
	assert(samples_per_cell >= 1 and not stable_id.is_empty())
	if cells.is_empty():
		return {}
	var ordered: Array[Vector3i] = []
	ordered.assign(cells.keys())
	ordered.sort_custom(func(a: Vector3i, b: Vector3i) -> bool:
		if a.y != b.y:
			return a.y < b.y
		return a.z < b.z if a.z != b.z else a.x < b.x)
	var quad_count := ordered.size() * samples_per_cell * samples_per_cell
	var rock_vertices := PackedInt32Array()
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var collision_faces := PackedVector3Array()
	vertices.resize(quad_count * 4)
	normals.resize(vertices.size())
	uvs.resize(vertices.size())
	indices.resize(quad_count * 6)
	if include_collision:
		collision_faces.resize(quad_count * 6)
	var half := cell_size * 0.5
	var step := cell_size / float(samples_per_cell)
	var quad_index := 0
	for cell: Vector3i in ordered:
		var point := Vector2i(cell.x, cell.z)
		var baked := TerrainTileField.bake_point(region, point)
		var field_min_x := float(cell.x) * cell_size - half
		var field_min_z := float(cell.z) * cell_size - half
		for iz in samples_per_cell:
			for ix in samples_per_cell:
				var field_x0 := field_min_x + float(ix) * step
				var field_x1 := field_x0 + step
				var field_z0 := field_min_z + float(iz) * step
				var field_z1 := field_z0 + step
				var v00 := Vector3(field_x0, TerrainTileField.sample_baked(
					baked, point, field_x0, field_z0, region) + lift,
					field_z0)
				var v10 := Vector3(field_x1, TerrainTileField.sample_baked(
					baked, point, field_x1, field_z0, region) + lift,
					field_z0)
				var v11 := Vector3(field_x1, TerrainTileField.sample_baked(
					baked, point, field_x1, field_z1, region) + lift,
					field_z1)
				var v01 := Vector3(field_x0, TerrainTileField.sample_baked(
					baked, point, field_x0, field_z1, region) + lift,
					field_z1)
				var vi := quad_index * 4
				vertices[vi] = v00
				vertices[vi + 1] = v10
				vertices[vi + 2] = v11
				vertices[vi + 3] = v01
				# Match the production winding. Averaging its two triangle normals
				# gives a stable up-facing normal even on a 2-D corner patch.
				var normal := ((v11 - v00).cross(v10 - v00) \
					+ (v01 - v00).cross(v11 - v00)).normalized()
				for corner in 4:
					normals[vi + corner] = normal
					uvs[vi + corner] = Vector2.ZERO
				var ii := quad_index * 6
				# Match the clockwise top-face winding used by the production
				# SurfaceTool sheet.  The former reverse order made this otherwise
				# valid surface visible only from below.
				indices[ii] = vi
				indices[ii + 1] = vi + 1
				indices[ii + 2] = vi + 2
				indices[ii + 3] = vi
				indices[ii + 4] = vi + 2
				indices[ii + 5] = vi + 3
				if include_collision:
					for corner in 6:
						collision_faces[ii + corner] = vertices[
							indices[ii + corner]]
				# The very same lip/corner clipping kernel as streamed terrain.
				# Save the full collision sheet first: dressing never shrinks walking.
				if not clip_cache.is_empty():
					var raw := [v00, v10, v11, v01]
					for corner in 4:
						vertices[vi + corner] = _clip_vert(region, clip_cache,
							cell.x, cell.z, vertices[vi + corner])
					# Match the streamed sheet's complete-triangle rock treatment
					# below concave lips. Split only these triangles so the adjacent
					# lawn can keep its grass UV without interpolation across a seam.
					for triangle in 2:
						var offset := ii + triangle * 3
						var is_backing := false
						for corner in 3:
							is_backing = is_backing or _inner_corner_vertex(region,
								clip_cache, cell.x, cell.z, raw[indices[offset + corner] - vi])
						if not is_backing:
							continue
						for corner in 3:
							var original := indices[offset + corner]
							indices[offset + corner] = vertices.size()
							rock_vertices.append(vertices.size())
							vertices.append(vertices[original])
							normals.append(normals[original])
							uvs.append(Vector2.ZERO)
				quad_index += 1
	var payload := {
		"stable_id": stable_id,
		"anchor": vertices[0],
		# One selected owner intentionally tessellates into several patches. Keep
		# the topology beside the mesh so audits and downstream adapters do not
		# infer a different cell from each sloped patch centre.
		"logical_cells": ordered,
		"vertices": vertices,
		"normals": normals,
		"uvs": uvs,
		"indices": indices,
		"collision_faces": collision_faces,
		"visual_only": not include_collision,
		"terrain_ground": true,
		"terrain_rock_vertices": rock_vertices,
	}
	return payload



# Chunk (ccx,ccz) covers the 192 m square from this world origin (min corner).
# Its sheet is that square; its walls are those of its lattice points
# 16 ccx .. 16 ccx + 15 (their dual cells span [192 ccx - 6, 192 ccx + 186]).
func _origin(chunk: Vector2i) -> Vector2:
	return Vector2(float(chunk.x) * CHUNK_WORLD, float(chunk.y) * CHUNK_WORLD)

## Main-thread resource warm-up. The streamer calls this before starting its
## worker; compute_chunk then touches only worker-owned data and SurfaceTool's
## CPU-side arrays. Keeping lazy resource loads out of compute_chunk is
## load-bearing: render resources may not be created or modified on the
## project's default render model from a background thread.
func prepare_resources() -> void:
	_ensure_skirt_style()
	_ground_tinted_mat()
	CLIFF_ROCKS.prepare()


## Worker-safe half of chunk generation. Returns CPU-side mesh arrays,
## collision faces, transforms, and colours only. commit_chunk owns every
## Node/ArrayMesh/MultiMesh/Shape creation and must run on the main thread.
func compute_chunk(chunk: Vector2i, region: HeightfieldRegion,
		water: WaterFieldContext = null, features: FeatureContext = null) -> Dictionary:
	if _skirt_material == null:
		push_error("TerrainChunkMesher.prepare_resources() must run on the main thread before compute_chunk()")
		return {}
	assert(region != null)
	var profile_started := Time.get_ticks_usec() if profile_enabled else 0
	_fine_vertices_usec = 0
	_fine_paint_usec = 0
	var path_usec := 0
	var fine_quads := 0
	var graded_quads := 0
	var o := _origin(chunk)
	var st := SurfaceTool.new()    # the walkable sheet
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# The collision sheet: raw triangle soup straight into a
	# ConcavePolygonShape3D — no SurfaceTool, no ArrayMesh, no
	# create_trimesh_shape re-extraction.
	var col_faces := PackedVector3Array()
	col_faces.resize(GRID * GRID * 6)
	var col_i := 0
	var graded_collision: Array[Vector3] = []
	# Per-quad collision corner heights (v00, v10, v11, v01) and graded flags,
	# from which wall-free tiles become heightmap shapes (_collision_tiles).
	var quad_heights := PackedFloat32Array()
	quad_heights.resize(GRID * GRID * 4)
	var quad_graded := PackedByteArray()
	quad_graded.resize(GRID * GRID)
	var baked_cache := {}          # per-point baked surface samplers
	# Biome ground tint sampled at the coarse 24 m lattice (CELLS_PER_CHUNK+1
	# per axis) then bilinearly expanded to the per-vertex lattice — the biome
	# field is smooth, so this matches per-vertex sampling at ~1% of the noise
	# cost and stays seam-continuous (chunk boundaries fall on shared corners).
	var cn := CELLS_PER_CHUNK + 1
	var corner_tints: Array[Color] = []
	corner_tints.resize(cn * cn)
	for ccz in cn:
		for ccx in cn:
			var cw := Vector3(o.x + ccx * CELL, 0.0, o.y + ccz * CELL)
			corner_tints[ccz * cn + ccx] = BiomeRegistry.ground_tint_at(cw, _water_seed)
	var tints: Array[Color] = []
	tints.resize((GRID + 1) * (GRID + 1))
	for tz in GRID + 1:
		var fz := float(tz) / float(SAMPLES_PER_CELL)
		var cz0 := mini(int(fz), cn - 2)
		var dz := fz - float(cz0)
		for tx in GRID + 1:
			var fx := float(tx) / float(SAMPLES_PER_CELL)
			var cx0 := mini(int(fx), cn - 2)
			var dx := fx - float(cx0)
			var a := (corner_tints[cz0 * cn + cx0] as Color).lerp(corner_tints[cz0 * cn + cx0 + 1], dx)
			var b := (corner_tints[(cz0 + 1) * cn + cx0] as Color).lerp(corner_tints[(cz0 + 1) * cn + cx0 + 1], dx)
			tints[tz * (GRID + 1) + tx] = a.lerp(b, dz)
	# Pass 1: every quad corner on the side of its quad's centre owner (see
	# the PIN note below), sampled as one batch over the chunk's dense window.
	var corner_x := PackedFloat64Array(); corner_x.resize(GRID * GRID * 4)
	var corner_z := PackedFloat64Array(); corner_z.resize(GRID * GRID * 4)
	var corner_oi := PackedInt32Array(); corner_oi.resize(GRID * GRID * 4)
	var corner_oj := PackedInt32Array(); corner_oj.resize(GRID * GRID * 4)
	var owner_lo := Vector2i(1 << 30, 1 << 30)
	var owner_hi := Vector2i(-(1 << 30), -(1 << 30))
	for iz in GRID:
		for ix in GRID:
			var x0 := o.x + ix * STEP
			var x1 := x0 + STEP
			var z0 := o.y + iz * STEP
			var z1 := z0 + STEP
			var centre := Vector2((x0 + x1) * 0.5, (z0 + z1) * 0.5)
			var owner := Vector2i(TerrainTileField.point_of(centre.x, region),
				TerrainTileField.point_of(centre.y, region))
			owner_lo = owner_lo.min(owner)
			owner_hi = owner_hi.max(owner)
			var c := (iz * GRID + ix) * 4
			corner_x[c] = x0; corner_z[c] = z0
			corner_x[c + 1] = x1; corner_z[c + 1] = z0
			corner_x[c + 2] = x1; corner_z[c + 2] = z1
			corner_x[c + 3] = x0; corner_z[c + 3] = z1
			for n in 4:
				corner_oi[c + n] = owner.x; corner_oj[c + n] = owner.y
	var corner_y := TerrainTileField.sample_window(
		TerrainTileField.dense_window(region, owner_lo - Vector2i.ONE, owner_hi - owner_lo + Vector2i(3, 3)),
		corner_x, corner_z, corner_oi, corner_oj)
	if TerrainTileField.grades(region):
		for n in corner_y.size():
			corner_y[n] = TerrainTileField._apply_grade(region, corner_x[n], corner_z[n], corner_y[n])
	for iz in GRID:
		for ix in GRID:
			var x0 := o.x + ix * STEP
			var x1 := x0 + STEP
			var z0 := o.y + iz * STEP
			var z1 := z0 + STEP
			# PIN the quad to the lattice point owning its centre: all four
			# corners are evaluated on that point's side, so a cliff top renders
			# FLAT right up to its wall. Walls lie on the dual-cell borders
			# (x or z = 12 i + 6), which are lines of this 2 m grid, so no quad
			# straddles one. Where two owners differ the shared border vertices
			# land at different y and don't weld — a clean vertical gap the rock
			# skirt (below) fills. On flats and slopes they match and weld.
			var centre := Vector2((x0 + x1) * 0.5, (z0 + z1) * 0.5)
			var owner := Vector2i(TerrainTileField.point_of(centre.x, region),
				TerrainTileField.point_of(centre.y, region))
			var baked: PackedFloat32Array = baked_cache.get(owner, PackedFloat32Array())
			if baked.is_empty():
				baked = TerrainTileField.bake_point(region, owner)
				baked_cache[owner] = baked
			var quad_index := iz * GRID + ix
			var v00 := Vector3(x0, corner_y[quad_index * 4], z0)
			var v10 := Vector3(x1, corner_y[quad_index * 4 + 1], z0)
			var v11 := Vector3(x1, corner_y[quad_index * 4 + 2], z1)
			var v01 := Vector3(x0, corner_y[quad_index * 4 + 3], z1)
			var graded := region.has_grade_in(Rect2(Vector2(x0, z0), Vector2.ONE * STEP))
			quad_heights[quad_index * 4] = v00.y
			quad_heights[quad_index * 4 + 1] = v10.y
			quad_heights[quad_index * 4 + 2] = v11.y
			quad_heights[quad_index * 4 + 3] = v01.y
			quad_graded[quad_index] = 1 if graded else 0
			if not graded:
				col_faces[col_i] = v00
				col_faces[col_i + 1] = v10
				col_faces[col_i + 2] = v11
				col_faces[col_i + 3] = v00
				col_faces[col_i + 4] = v11
				col_faces[col_i + 5] = v01
				col_i += 6
			var t00: Color = tints[iz * (GRID + 1) + ix]
			var t10: Color = tints[iz * (GRID + 1) + ix + 1]
			var t11: Color = tints[(iz + 1) * (GRID + 1) + ix + 1]
			var t01: Color = tints[(iz + 1) * (GRID + 1) + ix]
			# A path quad is subdivided IN PLACE, with each fine patch choosing
			# grass or path UV. The former second sheet sat only 1 cm above this
			# one and depth-fought into detached strips at gameplay distance.
			# One surface layer cannot z-fight with itself and still preserves the
			# rounded 0.25 m path boundary. Paths keep the 24 m road lattice.
			var road := Vector2i(roundi(centre.x / CELL), roundi(centre.y / CELL))
			var path_started := Time.get_ticks_usec() if profile_enabled else 0
			var path_state := _emit_path_surface(st, region, water, features,
				owner, road, x0, z0, [t00, t10, t11, t01], baked, graded_collision)
			if profile_enabled:
				path_usec += Time.get_ticks_usec() - path_started
				if path_state != 0: fine_quads += 1
				if graded: graded_quads += 1
			if path_state == 0:
				_tri_tinted(st, [v00, v10, v11], _grass_uv, [t00, t10, t11])
				_tri_tinted(st, [v00, v11, v01], _grass_uv, [t00, t11, t01])
			if path_state == 2:
				_emit_path_spot(st, region, water, features, centre, owner, road,
					x0, z0, [t00, t10, t11, t01])
	var surface_finished := Time.get_ticks_usec() if profile_enabled else 0
	col_faces.resize(col_i)
	col_faces.append_array(PackedVector3Array(graded_collision))
	var collision_tiles := _collision_tiles(o, quad_heights, quad_graded,
		PackedVector3Array(graded_collision))
	# Cliff FACES: a VERTICAL rock skirt on every wall this chunk owns (the
	# walls whose HIGH owner is one of its lattice points), filling the gap the
	# pinned sheet leaves between the two owners' surfaces. It doubles as the
	# collision wall so the player can't walk through; double-sided so it never
	# reads as see-through. The slope sheet covers it where it rounds the wall.
	var skirt := SurfaceTool.new()
	skirt.begin(Mesh.PRIMITIVE_TRIANGLES)
	var skirtc := SurfaceTool.new()   # collision wall: the same planes
	skirtc.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any_wall := _emit_walls(skirt, skirtc, region, chunk)

	# Weld coincident grid vertices BEFORE generating normals so shared vertices get
	# averaged (smooth) normals instead of per-face (flat) ones — this is what makes
	# the slopes read as smooth curves rather than angular facets.
	var normals_started := Time.get_ticks_usec() if profile_enabled else 0
	st.index()
	var surface_arrays: Array = st.commit_to_arrays()
	surface_arrays[Mesh.ARRAY_NORMAL] = field_normals(
		surface_arrays[Mesh.ARRAY_VERTEX], region, baked_cache)
	var surface_vertices: PackedVector3Array = surface_arrays[Mesh.ARRAY_VERTEX]
	var normals_finished := Time.get_ticks_usec() if profile_enabled else 0

	# NO per-chunk water quads: WaterSurfaceBuilder owns the one water visual.
	var wall_arrays: Array = []
	var wall_collision_arrays: Array = []
	if any_wall:
		skirt.generate_normals()
		wall_arrays = skirt.commit_to_arrays()
		wall_collision_arrays = skirtc.commit_to_arrays()

	var timings := {}
	if profile_enabled:
		timings = {"fine_vertices": _fine_vertices_usec, "fine_paint": _fine_paint_usec,
			"surface": surface_finished - profile_started, "paths": path_usec,
			"normals": normals_finished - normals_started,
			"walls": Time.get_ticks_usec() - normals_finished}
	var lo := chunk * POINTS_PER_CHUNK
	if phase_callback.is_valid(): phase_callback.call(chunk, &"terrain_arches")
	var arches := ARCHES.compute(region, lo.x, lo.y, POINTS_PER_CHUNK, _water_seed, features, _skirt_uv)
	if phase_callback.is_valid(): phase_callback.call(chunk, &"cliff_formations")
	var rocks := CLIFF_ROCKS.compute(region, chunk, _water_seed, features, water,
		_canonical_water_blocks(region, water))
	# The slope solid buries most of each skirt; the faces it covers are withdrawn.
	wall_arrays = rocks.sheet_cover.uncovered_faces(wall_arrays)
	rocks.erase("sheet_cover")
	return {
		"profile": timings,
		"profile_counts": {"fine_quads": fine_quads, "graded_quads": graded_quads,
			"vertices": surface_vertices.size(), "collision_triangles": col_faces.size() / 3} if profile_enabled else {},
		"chunk": chunk,
		"surface_arrays": surface_arrays,
		# The complete walkable sheet (tests and the camera's ground-depth pass
		# read it); physics uses the heightmap tiles plus the residual trimesh.
		"collision_faces": col_faces,
		"collision_heightmaps": collision_tiles.heightmaps,
		"collision_trimesh_faces": collision_tiles.residual,
		"wall_arrays": wall_arrays,
		"wall_collision_arrays": wall_collision_arrays,
		# (The key keeps its historical name: the streamer reads the cliff
		# dressing's ground reservations and grass supports from it.)
		"cliff_terraces": rocks,
		"natural_arches": arches,
		"structure_clearance": arches.clearance,
		"world_seed": _water_seed,
	}


## The cliff slope reads water levels per world block
## (CliffSlopeField._water_level). Block levels are pure functions of the
## plans, so the worker's own field cache (`water_blocks`, set by the
## streamer) serves every chunk; without one the mesher keeps its own.
## Building them per chunk rebuilt the neighbours' water for every chunk.
var water_blocks: WorldFieldBlockCache
var _own_water_blocks: WorldFieldBlockCache
func _canonical_water_blocks(region: HeightfieldRegion, water: WaterFieldContext) -> WorldFieldBlockCache:
	if water == null or region.plan == null:
		return null
	var water_plan: WaterPlan = water.raw_context().water
	if water_blocks != null and water_blocks.serves(region.plan, water_plan):
		return water_blocks
	if _own_water_blocks == null or not _own_water_blocks.serves(region.plan, water_plan):
		_own_water_blocks = WorldFieldBlockCache.new(region.plan, water_plan, 0.0, 0.0, 16)
	return _own_water_blocks


## Main-thread half of chunk generation. This is deliberately the only path
## below that creates render/physics resources and nodes.
func commit_chunk(data: Dictionary) -> Node3D:
	var steps := commit_steps(data)
	for step: Callable in steps.steps:
		step.call()
	return steps.root


## commit_chunk as separate main-thread steps (surface, cliff dressing,
## collision, cliff faces) so the streamer can spread one chunk over several
## frames under a time budget. Running every step in order builds exactly the
## node commit_chunk returns.
func commit_steps(data: Dictionary) -> Dictionary:
	assert(not data.is_empty())
	var chunk: Vector2i = data["chunk"]
	var root := Node3D.new()
	root.name = "Chunk_%d_%d" % [chunk.x, chunk.y]
	var steps: Array[Callable] = [func() -> void: _commit_surface(root, data)]
	var cliffs: Dictionary = CLIFF_ROCKS.build_steps(data.get("cliff_terraces", {}),
		data["world_seed"])
	steps.append(func() -> void: root.add_child(cliffs.root))
	steps.append_array(cliffs.steps)
	steps.append(func() -> void: _commit_arches(root, data))
	steps.append(func() -> void: _commit_collision(root, data))
	# The residual ground trimesh (cliffy ground the heightmap tiles cannot
	# carry; 18k triangles on a cliffy chunk, ~10 ms of BVH) joins the body in
	# pieces after its first, one step each, like the cliff sheet's below.
	var ground_faces: PackedVector3Array = data.get("collision_trimesh_faces", data["collision_faces"])
	var ground_floats := ROCK_COLLISION_PIECE_TRIANGLES * 3
	for piece in range(1, ceili(float(ground_faces.size()) / float(ground_floats))):
		steps.append(func() -> void:
			var shape := ConcavePolygonShape3D.new()
			shape.set_faces(ground_faces.slice(piece * ground_floats, (piece + 1) * ground_floats))
			var ground_collision := CollisionShape3D.new()
			ground_collision.name = "GroundTrimesh%d" % (piece + 1)
			ground_collision.shape = shape
			(root.get_node("Body") as StaticBody3D).add_child(ground_collision))
	# The cliff sheet's own collision is often 10-50k triangles; it joins the
	# body as several shapes (the same triangles) so no one step builds it all.
	var rock_faces: PackedVector3Array = (data.get("cliff_terraces", {}) as Dictionary) \
		.get("collision_faces", PackedVector3Array())
	var piece_floats := ROCK_COLLISION_PIECE_TRIANGLES * 3
	var piece_count := ceili(float(rock_faces.size()) / float(piece_floats))
	for piece in piece_count:
		steps.append(func() -> void:
			var shape := ConcavePolygonShape3D.new()
			shape.set_faces(rock_faces.slice(piece * piece_floats, (piece + 1) * piece_floats))
			var rock_collision := CollisionShape3D.new()
			rock_collision.name = "CliffRocks" if piece == 0 else "CliffRocks%d" % (piece + 1)
			rock_collision.shape = shape
			(root.get_node("Body") as StaticBody3D).add_child(rock_collision))
	steps.append(func() -> void: _commit_wall_collision(root, data))
	steps.append(func() -> void: _commit_cliff_faces(root, data))
	return {"root": root, "steps": steps}

## Each piece's BVH build is one integration step on the main thread:
## ~1 ms per 1,000 triangles, so 3,000 keeps a step inside the streamer's
## 6 ms frame budget (12,000 made every cliffy chunk a run of 10-15 ms frames).
const ROCK_COLLISION_PIECE_TRIANGLES := 3000


func _commit_surface(root: Node3D, data: Dictionary) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Surface"
	mi.add_to_group("tactical_solid_earth", true)
	mi.mesh = _mesh_from_arrays(data["surface_arrays"], _ground_tinted_mat())
	root.add_child(mi)


func _commit_arches(root: Node3D, data: Dictionary) -> void:
	var arch_data: Dictionary = data.get("natural_arches",{})
	var arch_arrays: Array = arch_data.get("arrays",[])
	if not arch_arrays.is_empty():
		var arch_mesh := MeshInstance3D.new()
		arch_mesh.name = "NaturalArches"
		arch_mesh.mesh = _mesh_from_arrays(arch_arrays,_skirt_material)
		root.add_child(arch_mesh)


func _commit_collision(root: Node3D, data: Dictionary) -> void:
	var arch_data: Dictionary = data.get("natural_arches",{})
	# Collision: the full walkable sheet plus cliff-wall, arch and rock trimeshes.
	var body := StaticBody3D.new()
	body.name = "Body"
	var cs := CollisionShape3D.new()
	cs.name = "CollisionShape3D"
	cs.add_to_group("tactical_terrain_volume", true)
	var col_shape := ConcavePolygonShape3D.new()
	# The first ROCK_COLLISION_PIECE_TRIANGLES; commit_steps adds the rest as
	# GroundTrimesh<N> shapes (same triangles).
	var ground_faces: PackedVector3Array = data.get("collision_trimesh_faces", data["collision_faces"])
	col_shape.set_faces(ground_faces.slice(0, ROCK_COLLISION_PIECE_TRIANGLES * 3))
	cs.shape = col_shape
	# The ground-depth pass draws the complete sheet, heightmap tiles included.
	cs.set_meta(&"terrain_faces", data["collision_faces"])
	body.add_child(cs)
	var tile_index := 0
	for tile: Dictionary in data.get("collision_heightmaps", []):
		var heightmap := HeightMapShape3D.new()
		heightmap.map_width = COLLISION_TILE_QUADS + 1
		heightmap.map_depth = COLLISION_TILE_QUADS + 1
		heightmap.map_data = tile.data
		var tile_shape := CollisionShape3D.new()
		tile_shape.name = "GroundTile%d" % tile_index
		tile_shape.shape = heightmap
		tile_shape.transform = Transform3D(COLLISION_TILE_BASIS, tile.centre)
		body.add_child(tile_shape)
		tile_index += 1
	var arch_faces: PackedVector3Array = arch_data.get("collision_faces",PackedVector3Array())
	if not arch_faces.is_empty():
		var arch_shape := ConcavePolygonShape3D.new()
		arch_shape.set_faces(arch_faces)
		var arch_collision := CollisionShape3D.new()
		arch_collision.name = "NaturalArches"
		arch_collision.shape = arch_shape
		body.add_child(arch_collision)
	root.add_child(body)


func _commit_wall_collision(root: Node3D, data: Dictionary) -> void:
	var body := root.get_node("Body") as StaticBody3D
	var wall_collision: Array = data["wall_collision_arrays"]
	if not wall_collision.is_empty():
		var wall_shape := ConcavePolygonShape3D.new()
		wall_shape.set_faces(wall_collision[Mesh.ARRAY_VERTEX])
		var cs2 := CollisionShape3D.new()
		cs2.name = "CollisionShape3D_walls"
		cs2.shape = wall_shape
		body.add_child(cs2)


func _commit_cliff_faces(root: Node3D, data: Dictionary) -> void:
	var wall_arrays: Array = data["wall_arrays"]
	if not wall_arrays.is_empty():
		var skirt_mesh := _mesh_from_arrays(wall_arrays, _skirt_material)
		var sf := MeshInstance3D.new()
		sf.name = "CliffFaces"
		sf.mesh = skirt_mesh
		root.add_child(sf)


## Main-thread compatibility wrapper used by unit tests and offline harnesses.
func build_chunk(plan, chunk: Vector2i, region = null,
		water: WaterFieldContext = null,
		features: FeatureContext = null) -> Node3D:
	## Offline review harnesses use this compatibility adapter too.  Accept the
	## same immutable water/feature context as `compute_chunk()` so a screenshot
	## of production terrain cannot silently omit canonical village streets.
	prepare_resources()
	var block_region: HeightfieldRegion = region if region != null \
		else plan.compute_region(chunk.x * POINTS_PER_CHUNK + POINTS_PER_CHUNK / 2,
			chunk.y * POINTS_PER_CHUNK + POINTS_PER_CHUNK / 2, POINTS_PER_CHUNK)
	return commit_chunk(compute_chunk(chunk, block_region, water, features))


## Collision for wall-free ground is a HeightMapShape3D per 24 m tile: its
## build is ~300x cheaper than the trimesh BVH (0.06 vs 20-25 ms per chunk
## sheet), which was the largest main-thread cost of integrating a chunk.
## A tile qualifies when it has no graded quad and every lattice vertex is
## shared by all its quads at one height (no wall line runs through it);
## other quads stay in the residual trimesh, in their original order. Godot
## splits a heightmap cell along its other diagonal, so the shape is turned
## +90 degrees about Y: the split then matches the mesher's v00-v11 one and
## both shapes contain exactly the same triangles. The basis is exact (0, +-2):
## uniform scale 2 maps the unit cells to 2 m quads, so heights are halved.
const COLLISION_TILE_QUADS := 12
const COLLISION_TILE_BASIS := Basis(Vector3(0.0, 0.0, -STEP), Vector3(0.0, STEP, 0.0),
	Vector3(STEP, 0.0, 0.0))

static func _collision_tiles(origin: Vector2, quad_heights: PackedFloat32Array,
		quad_graded: PackedByteArray, graded_faces: PackedVector3Array) -> Dictionary:
	var n := COLLISION_TILE_QUADS + 1
	var tiles_per_axis := GRID / COLLISION_TILE_QUADS
	var tile_ok := PackedByteArray()
	tile_ok.resize(tiles_per_axis * tiles_per_axis)
	var heightmaps: Array[Dictionary] = []
	for tz in tiles_per_axis:
		for tx in tiles_per_axis:
			var grid := PackedFloat32Array()
			grid.resize(n * n)
			grid.fill(NAN)
			var ok := true
			for lz in COLLISION_TILE_QUADS:
				for lx in COLLISION_TILE_QUADS:
					var q := (tz * COLLISION_TILE_QUADS + lz) * GRID + tx * COLLISION_TILE_QUADS + lx
					if quad_graded[q] != 0:
						ok = false
						break
					# Corners in quad_heights order: v00, v10, v11, v01.
					for corner in 4:
						var cx := lx + (1 if corner == 1 or corner == 2 else 0)
						var cz := lz + (1 if corner >= 2 else 0)
						var h := quad_heights[q * 4 + corner]
						var existing := grid[cz * n + cx]
						if is_nan(existing):
							grid[cz * n + cx] = h
						elif existing != h:
							ok = false
							break
					if not ok: break
				if not ok: break
			if not ok:
				continue
			tile_ok[tz * tiles_per_axis + tx] = 1
			# World vertex (a, b) of the tile lies at local (u, v) = (12 - b, a)
			# of the turned shape; heights halve under the uniform scale.
			var data := PackedFloat32Array()
			data.resize(n * n)
			for b in n:
				for a in n:
					data[a * n + (COLLISION_TILE_QUADS - b)] = grid[b * n + a] * 0.5
			var half := COLLISION_TILE_QUADS * STEP * 0.5
			heightmaps.append({"centre": Vector3(origin.x + tx * COLLISION_TILE_QUADS * STEP + half,
				0.0, origin.y + tz * COLLISION_TILE_QUADS * STEP + half), "data": data})
	var residual := PackedVector3Array()
	for iz in GRID:
		for ix in GRID:
			var q := iz * GRID + ix
			if quad_graded[q] != 0 \
					or tile_ok[(iz / COLLISION_TILE_QUADS) * tiles_per_axis + ix / COLLISION_TILE_QUADS] != 0:
				continue
			var x0 := origin.x + ix * STEP
			var z0 := origin.y + iz * STEP
			var v00 := Vector3(x0, quad_heights[q * 4], z0)
			var v10 := Vector3(x0 + STEP, quad_heights[q * 4 + 1], z0)
			var v11 := Vector3(x0 + STEP, quad_heights[q * 4 + 2], z0 + STEP)
			var v01 := Vector3(x0, quad_heights[q * 4 + 3], z0 + STEP)
			residual.append_array([v00, v10, v11, v00, v11, v01])
	residual.append_array(graded_faces)
	return {"heightmaps": heightmaps, "residual": residual}


func _mesh_from_arrays(arrays: Array, material: Material) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if material != null:
		mesh.surface_set_material(0, material)
	return mesh

## Lighting normals of the walkable sheet: the exact gradient of the field
## surface each vertex lies on. Facet-averaged normals depended on the 2 m
## tessellation and on which faces a chunk owns, so they shaded differently
## either side of every chunk border and disagreed with the slope sheet's own
## gradient normals wherever the two surfaces meet (owner, September 28:
## seams between flat ground and slopes). The field is C1 away from walls, so
## the two owners of a slope seam name the same normal; a vertex on a wall
## belongs to the lattice point whose pinned surface it lies on.
const NORMAL_STEP := 0.25
## The steepest ordinary slope: one storey plus three levels over one tile, at
## the smootherstep's peak. A half-step steeper than WALL_LIKE times it is no
## tile's slope but a drop (a wall, or the ramp at a cliff's end).
const STEEPEST_SLOPE := 1.875 * (TerrainTileField.STOREY + 3.0) / TerrainTileField.SPACING
const WALL_LIKE := 1.5
static func field_normals(vertices: PackedVector3Array, region,
		baked_cache: Dictionary = {}) -> PackedVector3Array:
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	var spacing := TerrainTileField.spacing(region)
	for i in vertices.size():
		var v := vertices[i]
		var owner := _vertex_owner(region, baked_cache, v, spacing)
		var gx := _field_slope(region, baked_cache, owner, v, Vector2i(1, 0), spacing)
		var gz := _field_slope(region, baked_cache, owner, v, Vector2i(0, 1), spacing)
		normals[i] = Vector3(-gx, 1.0, -gz).normalized()
	return normals


## The owner surface's slope at v along `axis` (a central difference). A
## sample beyond the owner's dual cell continues on the neighbour's surface
## where the border is not a wall there (one continuous tile), and otherwise
## the difference is one-sided: an owner's pinned sampler clamps at its
## border, which would flatten half the difference at every 12 m seam.
static func _field_slope(region, baked_cache: Dictionary, owner: Vector2i, v: Vector3,
		axis: Vector2i, spacing: float) -> float:
	var baked: PackedFloat32Array = baked_cache[owner]
	var plus := _slope_sample(region, baked_cache, baked, owner, v, axis, 1, spacing)
	var minus := _slope_sample(region, baked_cache, baked, owner, v, axis, -1, spacing)
	var centre := TerrainTileField.sample_baked(baked, owner, v.x, v.z, region)
	# A half-step that drops like a wall while the other half-step is ordinary
	# ground: the vertex stands on the lip, so its slope is the ground's side.
	# At a cliff's end the neighbour's surface agrees with the vertex, yet
	# 0.25 m on stands on the ramp's middle, metres lower: the plateau corner
	# leaned into the ramp and lit a dark tick at every wall end.
	var limit := WALL_LIKE * STEEPEST_SLOPE * NORMAL_STEP
	if not is_nan(plus) and not is_nan(minus):
		var plus_wall := absf(plus - centre) > limit
		var minus_wall := absf(centre - minus) > limit
		if plus_wall != minus_wall:
			if plus_wall:
				plus = NAN
			else:
				minus = NAN
	if not is_nan(plus) and not is_nan(minus):
		return (plus - minus) / (2.0 * NORMAL_STEP)
	if is_nan(plus) and is_nan(minus):
		return 0.0
	return (plus - centre) / NORMAL_STEP if not is_nan(plus) else (centre - minus) / NORMAL_STEP


## The owner surface NORMAL_STEP from v along `axis` * `sign_value`, or NAN
## where that sample crosses a wall on the owner's dual-cell border.
static func _slope_sample(region, baked_cache: Dictionary, baked: PackedFloat32Array,
		owner: Vector2i, v: Vector3, axis: Vector2i, sign_value: int, spacing: float) -> float:
	var x := v.x + float(axis.x * sign_value) * NORMAL_STEP
	var z := v.z + float(axis.y * sign_value) * NORMAL_STEP
	var along := (x - float(owner.x) * spacing) if axis.x != 0 else (z - float(owner.y) * spacing)
	if absf(along) <= spacing * 0.5:
		return TerrainTileField.sample_baked(baked, owner, x, z, region)
	var neighbour := owner + axis * sign_value
	if not baked_cache.has(neighbour):
		baked_cache[neighbour] = TerrainTileField.bake_point(region, neighbour)
	var theirs: PackedFloat32Array = baked_cache[neighbour]
	if absf(TerrainTileField.sample_baked(baked, owner, v.x, v.z, region)
			- TerrainTileField.sample_baked(theirs, neighbour, v.x, v.z, region)) >= 0.0001:
		return NAN
	return TerrainTileField.sample_baked(theirs, neighbour, x, z, region)


## The lattice point whose pinned surface holds a sheet vertex. Interior
## vertices have one candidate; a vertex on a dual-cell border (offset ±6 from
## a point) takes the candidate whose surface passes closest to it (the two
## sides of a wall differ).
static func _vertex_owner(region, baked_cache: Dictionary, v: Vector3, spacing: float) -> Vector2i:
	var xs: Array[int] = _owner_candidates(v.x, spacing)
	var zs: Array[int] = _owner_candidates(v.z, spacing)
	var best := Vector2i(xs[0], zs[0])
	var best_error := INF
	for cz in zs:
		for cx in xs:
			var key := Vector2i(cx, cz)
			if not baked_cache.has(key):
				baked_cache[key] = TerrainTileField.bake_point(region, key)
			if xs.size() == 1 and zs.size() == 1:
				return key
			var error := absf(TerrainTileField.sample_baked(baked_cache[key], key, v.x, v.z, region) - v.y)
			if error < best_error:
				best_error = error
				best = key
	return best


static func _owner_candidates(value: float, spacing: float) -> Array[int]:
	var centre := roundi(value / spacing)
	var offset := value - float(centre) * spacing
	if absf(absf(offset) - spacing * 0.5) < 0.001:
		return [centre, centre + (1 if offset > 0.0 else -1)]
	return [centre]


func _tri_tinted(st: SurfaceTool, vs: Array[Vector3], uv: Vector2, cs: Array[Color]) -> void:
	var earth := uv == _path_uv or uv == _path_spot_uv
	for i in 3:
		st.set_uv(uv)
		st.set_color(SlopeAtlas.path_tint(uv == _path_spot_uv) if earth else cs[i])
		st.add_vertex(vs[i])

const PATH_OVERLAY_DIVISIONS := 8
const PATH_SPOT_CHANCE := 0.30
const PATH_SPOT_RADIUS_MIN := 0.24
const PATH_SPOT_RADIUS_MAX := 0.72
const PATH_SPOT_JITTER := 0.26
const PATH_SPOT_LIFT := 0.030
const PATH_SPOT_DARKEN := SlopeAtlas.PATH_SPOT_DARKEN
const PATH_SPOT_SIDES := 12

# Emit one finely subdivided ground surface where a path may be present. Each
# fine triangle is partitioned at the shared path boundary; there is never a second coplanar
# path sheet. Terrain collision remains the unchanged coarse continuous sheet.
# Return 0 when the caller should emit its ordinary coarse grass quad, 1 when a
# fine all-grass quad was emitted, and 2 when at least one fine patch is path.
# The lattice is world aligned and neighbouring chunks therefore retain
# bit-identical boundary vertices. `owner` is the lattice point the quad is
# pinned to; `road` its 24 m route cell (the path field's lattice).
func _emit_path_surface(st: SurfaceTool, region: HeightfieldRegion,
		water: WaterFieldContext, features: FeatureContext, owner: Vector2i,
		road: Vector2i, x0: float, z0: float,
		quad_tints: Array[Color], baked: PackedFloat32Array,
		graded_collision: Array[Vector3] = []) -> int:
	var graded := region.has_grade_in(Rect2(Vector2(x0, z0), Vector2.ONE * STEP))
	if (features == null or water == null) and region.terrain_grades.is_empty():
		return 0
	# Most terrain quads are nowhere near a path. Centre/corner rejection avoids
	# the 8x8 subdivision there while still admitting a circular join that merely
	# clips a coarse quad's corner.
	var candidate := graded or _path_quad_candidate(features, road, x0, z0)
	if not candidate:
		# A finely divided neighbour would otherwise terminate in T-junctions
		# along this coarse edge. GPU rasterization exposed those as long white
		# hairlines at the reported path pins. A triangle fan adds the matching
		# edge vertices only on the sides that need them.
		var transition_sides := PackedByteArray([0, 0, 0, 0]) # north,east,south,west
		for side_index in 4:
			var direction: Vector2 = [Vector2.UP, Vector2.RIGHT,
				Vector2.DOWN, Vector2.LEFT][side_index]
			var nx0 := x0 + direction.x * STEP
			var nz0 := z0 + direction.y * STEP
			var neighbour_centre := Vector2(nx0 + STEP * 0.5, nz0 + STEP * 0.5)
			var neighbour_road := Vector2i(roundi(neighbour_centre.x / CELL),
				roundi(neighbour_centre.y / CELL))
			transition_sides[side_index] = 1 if _path_quad_candidate(features,
				neighbour_road, nx0, nz0) or region.has_grade_in(
					Rect2(Vector2(nx0, nz0), Vector2.ONE * STEP)) else 0
		if transition_sides.has(1):
			_emit_path_transition(st, region, owner, x0, z0, quad_tints, transition_sides)
			return 1
		return 0
	var sub_step := STEP / float(PATH_OVERLAY_DIVISIONS)
	var emitted_path := false
	var paint_cache: Dictionary = {}
	# Adjacent fine quads share their height and tint. Evaluate each lattice
	# vertex once, preserving the exact triangle order and the existing
	# surface/paint authorities.
	var vertices_started := Time.get_ticks_usec() if profile_enabled else 0
	var width := PATH_OVERLAY_DIVISIONS + 1
	var raw := PackedVector3Array()
	var colours := PackedColorArray()
	raw.resize(width*width)
	colours.resize(width*width)
	for vz in width:
		for vx in width:
			var x := x0 + float(vx)*sub_step
			var z := z0 + float(vz)*sub_step
			var index := vz*width+vx
			raw[index]=Vector3(x,TerrainTileField.sample_baked(baked,owner,x,z,region),z)
			colours[index]=_quad_tint(Vector2(x,z),x0,z0,quad_tints)
	if profile_enabled: _fine_vertices_usec += Time.get_ticks_usec()-vertices_started
	# Flat graded squares have the same physical surface at every fine-grid
	# vertex. Keep their exact outer corners and winding without submitting
	# 128 coplanar triangles to the physics server. Any height difference,
	# however small, retains the complete existing collision grid.
	var flat_collision := graded
	if flat_collision:
		for point: Vector3 in raw:
			if point.y != raw[0].y:
				flat_collision = false
				break
	if flat_collision:
		graded_collision.append_array([raw[0],raw[width-1],raw[width*width-1],
			raw[0],raw[width*width-1],raw[width*(width-1)]])
	var paint_started := Time.get_ticks_usec() if profile_enabled else 0
	var paint_bounds := Rect2(Vector2(x0,z0),Vector2.ONE*STEP)
	var possible_path := features != null and features.ground_field().may_have_path_in(paint_bounds)
	var surface_at := features.ground_field().surface_sampler_in(paint_bounds) if possible_path else Callable()
	var path_at := func(point: Vector2) -> bool:
		return possible_path and int(surface_at.call(point)) == FeatureGroundField.WORN_PATH \
			and (water == null or not water.is_wet(point))
	for sz in PATH_OVERLAY_DIVISIONS:
		for sx in PATH_OVERLAY_DIVISIONS:
			var a := sz*width+sx
			var b := a+1
			var c := b+width
			var d := a+width
			if graded and not flat_collision:
				graded_collision.append_array([raw[a],raw[b],raw[c],raw[a],raw[c],raw[d]])
			if not possible_path:
				_tri_tinted(st,[raw[a],raw[b],raw[c]],_grass_uv,[colours[a],colours[b],colours[c]])
				_tri_tinted(st,[raw[a],raw[c],raw[d]],_grass_uv,[colours[a],colours[c],colours[d]])
				continue
			var first := _emit_painted_triangle(st,[raw[a],raw[b],raw[c]],
				[colours[a],colours[b],colours[c]],_grass_uv,path_at,paint_cache)
			var second := _emit_painted_triangle(st,[raw[a],raw[c],raw[d]],
				[colours[a],colours[c],colours[d]],_grass_uv,path_at,paint_cache)
			emitted_path = emitted_path or first or second

	if profile_enabled: _fine_paint_usec += Time.get_ticks_usec()-paint_started
	return 2 if emitted_path else 1

func _emit_painted_triangle(st: SurfaceTool, vertices: Array[Vector3], colors: Array[Color],
		ground_uv: Vector2, path_at: Callable, cache: Dictionary) -> bool:
	var paint: Array[bool] = []
	for vertex: Vector3 in vertices:
		var point := Vector2(vertex.x, vertex.z)
		if not cache.has(point):
			cache[point] = bool(path_at.call(point))
		paint.append(cache[point])
	if paint[0] == paint[1] and paint[1] == paint[2]:
		_tri_tinted(st, vertices, _path_uv if paint[0] else ground_uv, colors)
	else:
		for part: Dictionary in partition_paint_triangle(vertices, colors, paint, path_at):
			for index in range(1, part.vertices.size() - 1):
				_tri_tinted(st, [part.vertices[0],part.vertices[index],part.vertices[index+1]],
					_path_uv if part.path else ground_uv,
					[part.colors[0],part.colors[index],part.colors[index+1]])
	return paint.has(true)


## Partition one existing terrain triangle, never overlay another sheet.
## Both materials receive the SAME crossing vertex. Canonical endpoint order
## makes neighbouring triangles/chunks agree even when their winding reverses.
## The predicate is the existing feature field, so world roads and house lanes
## retain one shape/corner authority instead of a second meshing approximation.
static func partition_paint_triangle(vertices: Array[Vector3], colors: Array[Color],
		paint: Array[bool], path_at: Callable) -> Array[Dictionary]:
	var parts: Array[Dictionary] = [
		{"path":false,"vertices":[] as Array[Vector3],"colors":[] as Array[Color]},
		{"path":true,"vertices":[] as Array[Vector3],"colors":[] as Array[Color]}]
	for index in 3:
		var next := (index + 1) % 3
		var side := 1 if paint[index] else 0
		parts[side].vertices.append(vertices[index])
		parts[side].colors.append(colors[index])
		if paint[index] == paint[next]:
			continue
		var a := index
		var b := next
		if vertices[b].x < vertices[a].x or (vertices[b].x == vertices[a].x and vertices[b].z < vertices[a].z):
			a = next
			b = index
		var lo := 0.0
		var hi := 1.0
		for step in 14:
			var mid := (lo + hi) * 0.5
			var p := vertices[a].lerp(vertices[b], mid)
			if bool(path_at.call(Vector2(p.x,p.z))) == paint[a]:
				lo = mid
			else:
				hi = mid
		var fraction := (lo + hi) * 0.5
		var crossing := vertices[a].lerp(vertices[b], fraction)
		var tint := colors[a].lerp(colors[b], fraction)
		for part: Dictionary in parts:
			part.vertices.append(crossing)
			part.colors.append(tint)
	return parts

func _path_quad_candidate(features: FeatureContext, road: Vector2i,
		x0: float, z0: float) -> bool:
	if features == null:
		return false
	var x1 := x0 + STEP
	var z1 := z0 + STEP
	for probe: Vector2 in [
			Vector2((x0 + x1) * 0.5, (z0 + z1) * 0.5),
			Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z1)]:
		if features.surface_at_cell(probe, road) == FeatureGroundField.WORN_PATH:
			return true
	return false

func _emit_path_transition(st: SurfaceTool, region: HeightfieldRegion,
		owner: Vector2i, x0: float, z0: float,
		quad_tints: Array[Color], sides: PackedByteArray) -> void:
	var x1 := x0 + STEP
	var z1 := z0 + STEP
	var sub_step := STEP / float(PATH_OVERLAY_DIVISIONS)
	var perimeter: Array[Vector2] = [Vector2(x0, z0)]
	# Clockwise in XZ, matching the terrain sheet's established winding.
	if sides[0] != 0:
		for index in range(1, PATH_OVERLAY_DIVISIONS + 1):
			perimeter.append(Vector2(x0 + float(index) * sub_step, z0))
	else:
		perimeter.append(Vector2(x1, z0))
	if sides[1] != 0:
		for index in range(1, PATH_OVERLAY_DIVISIONS + 1):
			perimeter.append(Vector2(x1, z0 + float(index) * sub_step))
	else:
		perimeter.append(Vector2(x1, z1))
	if sides[2] != 0:
		for index in range(PATH_OVERLAY_DIVISIONS - 1, -1, -1):
			perimeter.append(Vector2(x0 + float(index) * sub_step, z1))
	else:
		perimeter.append(Vector2(x0, z1))
	if sides[3] != 0:
		for index in range(PATH_OVERLAY_DIVISIONS - 1, 0, -1):
			perimeter.append(Vector2(x0, z0 + float(index) * sub_step))
	var centre2 := Vector2((x0 + x1) * 0.5, (z0 + z1) * 0.5)
	var centre3 := _path_surface_vertex(region, owner, centre2)
	var centre_tint := _quad_tint(centre2, x0, z0, quad_tints)
	for index in perimeter.size():
		var a2: Vector2 = perimeter[index]
		var b2: Vector2 = perimeter[(index + 1) % perimeter.size()]
		_tri_tinted(st, [centre3, _path_surface_vertex(region, owner, a2),
			_path_surface_vertex(region, owner, b2)], _grass_uv, [centre_tint,
			_quad_tint(a2, x0, z0, quad_tints),
			_quad_tint(b2, x0, z0, quad_tints)])

func _path_surface_vertex(region: HeightfieldRegion, owner: Vector2i,
		point: Vector2) -> Vector3:
	return Vector3(point.x, TerrainTileField.surface_y_on_side(region, point.x,
		point.y, owner), point.y)

# World-hashed discs make the path read as softly speckled without adding a
# material or draw call. Their broader size range stays stylized and legible at
# gameplay distance. Every rim point must remain inside the dry corridor, so no
# spot can bleed across a rounded edge, a water crossing, or a concave join.
func _emit_path_spot(st: SurfaceTool, region: HeightfieldRegion,
		water: WaterFieldContext, features: FeatureContext, quad_centre: Vector2,
		owner: Vector2i, road: Vector2i, x0: float, z0: float,
		quad_tints: Array[Color]) -> void:
	var gx := floori(quad_centre.x / STEP)
	var gz := floori(quad_centre.y / STEP)
	if Helper._cell_hash01(_water_seed + 9107, gx, gz) >= PATH_SPOT_CHANCE:
		return
	var centre := quad_centre + Vector2(
		(Helper._cell_hash01(_water_seed + 12653, gx, gz) * 2.0 - 1.0) * PATH_SPOT_JITTER,
		(Helper._cell_hash01(_water_seed + 17159, gx, gz) * 2.0 - 1.0) * PATH_SPOT_JITTER)
	var radius := lerpf(PATH_SPOT_RADIUS_MIN, PATH_SPOT_RADIUS_MAX,
		Helper._cell_hash01(_water_seed + 22273, gx, gz))
	var rim: Array[Vector2] = []
	for i in PATH_SPOT_SIDES:
		var angle := TAU * float(i) / float(PATH_SPOT_SIDES)
		var p := centre + Vector2(cos(angle), sin(angle)) * radius
		if features.surface_at_cell(p, road) \
				!= FeatureGroundField.WORN_PATH or (water != null and water.is_wet(p)):
			return
		rim.append(p)
	var lift := Vector3(0.0, PATH_SPOT_LIFT, 0.0)
	var centre3 := _path_surface_vertex(region, owner, centre) + lift
	var centre_tint := _quad_tint(centre, x0, z0, quad_tints)
	var dark := Color(PATH_SPOT_DARKEN, PATH_SPOT_DARKEN, PATH_SPOT_DARKEN, 1.0)
	for i in PATH_SPOT_SIDES:
		var a: Vector2 = rim[i]
		var b: Vector2 = rim[(i + 1) % PATH_SPOT_SIDES]
		_tri_tinted(st, [centre3, _path_surface_vertex(region, owner, a) + lift,
			_path_surface_vertex(region, owner, b) + lift], _path_spot_uv,
			[centre_tint * dark, _quad_tint(a, x0, z0, quad_tints) * dark,
			_quad_tint(b, x0, z0, quad_tints) * dark])

func _quad_tint(point: Vector2, x0: float, z0: float,
		cs: Array[Color]) -> Color:
	var dx := clampf((point.x - x0) / STEP, 0.0, 1.0)
	var dz := clampf((point.y - z0) / STEP, 0.0, 1.0)
	return cs[0].lerp(cs[1], dx).lerp(cs[3].lerp(cs[2], dx), dz)

# The biome ground tint at a world point — the ONE tint source shared with the
# sheet lattice and the dressing instances (the field's 400-750 m wavelengths
# make sub-tile variation invisible).
func _tint_at(point: Vector2) -> Color:
	if _water_seed == 0:
		return Color(1, 1, 1)   # headless geometry tests: identity, like compute_tints
	return BiomeRegistry.ground_tint_at(Vector3(point.x, 0.0, point.y), _water_seed)

# --- cliff walls --------------------------------------------------------------

## Below this a wall face is drawn as turf: a rock sliver there read as a
## dark tick where a cliff runs out.
const LOW_WALL := 1.5

## The rock skirts of every wall this chunk owns: each wall segment
## (TerrainTileField.wall_segments) whose HIGH owner is one of the chunk's
## lattice points, so every wall is emitted exactly once across chunks. Each
## 6 m half-segment is sampled at STEP, on the same world grid as the sheet:
## the top is the high owner's surface there, the bottom the low owner's, both
## exactly the sheet's own boundary vertices on either side, and the face
## stands ON the wall line. Visual and collision faces are the same planes.
func _emit_walls(st: SurfaceTool, stcol: SurfaceTool, region, chunk: Vector2i) -> bool:
	var lo := chunk * POINTS_PER_CHUNK
	var owned := Rect2i(lo, Vector2i.ONE * POINTS_PER_CHUNK)
	var spacing := TerrainTileField.spacing(region)
	var rect := Rect2(Vector2(lo) * spacing - Vector2.ONE * spacing * 0.5,
		Vector2.ONE * POINTS_PER_CHUNK * spacing)
	var emitted := false
	for wall: Dictionary in TerrainTileField.wall_segments(region, rect):
		var high: Vector2i = wall.high
		if not owned.has_point(high):
			continue
		var a: Vector2 = wall.a
		var b: Vector2 = wall.b
		var low: Vector2i = wall.low
		var tint := _tint_at((a + b) * 0.5)
		var steps := maxi(1, roundi(a.distance_to(b) / STEP))
		# Axis-aligned: the direction is exactly (±1, 0) or (0, ±1), so every
		# sample lands exactly on a sheet vertex of the 2 m grid.
		var along := (b - a).normalized()
		var top0 := TerrainTileField.surface_y_on_side(region, a.x, a.y, high)
		var bottom0 := TerrainTileField.surface_y_on_side(region, a.x, a.y, low)
		for i in steps:
			var p0 := a + along * (STEP * float(i))
			var p1 := b if i + 1 == steps else a + along * (STEP * float(i + 1))
			var top1 := TerrainTileField.surface_y_on_side(region, p1.x, p1.y, high)
			var bottom1 := TerrainTileField.surface_y_on_side(region, p1.x, p1.y, low)
			if top0 > bottom0 + 0.001 or top1 > bottom1 + 0.001:
				# Where a cliff's end has fallen below LOW_WALL the face is a turf
				# step, not rock.
				var uv := _grass_uv if maxf(top0 - bottom0, top1 - bottom1) < LOW_WALL else _skirt_uv
				_skirt_quad(st, p0, p1, top0, top1, bottom0, bottom1, tint, uv)
				_skirt_quad(stcol, p0, p1, top0, top1, bottom0, bottom1, Color.WHITE, uv)
				emitted = true
			top0 = top1
			bottom0 = bottom1
	return emitted

## One vertical double-sided quad from p0 to p1: top0/top1 down to bottom0/bottom1.
func _skirt_quad(st: SurfaceTool, p0: Vector2, p1: Vector2, top0: float, top1: float,
		bottom0: float, bottom1: float, tint: Color, uv: Vector2) -> void:
	var t0 := Vector3(p0.x, top0, p0.y)
	var t1 := Vector3(p1.x, top1, p1.y)
	var b0 := Vector3(p0.x, minf(bottom0, top0), p0.y)
	var b1 := Vector3(p1.x, minf(bottom1, top1), p1.y)
	for v in [t0, t1, b1, t0, b1, b0, t0, b1, t1, t0, b0, b1]:
		st.set_uv(uv); st.set_color(tint); st.add_vertex(v)

# --- village turf lip clipping ---------------------------------------------------
# Structural terrain (field_ground_surface) on a village lattice is dressed with
# authored grass-lip and corner pieces. The village publishes that dressing as a
# PREFILLED clip cache (SettlementFabricAssembler.maze_turf_clip_cache): per
# lattice owner {"dirs": {dir: {"lips": [..], "prof": edge profile}},
# "corners": {cdir: kind}, "sheet_edge_lift", "max_uncapped_drape"}, or null.
# World terrain has no lip pieces and is never clipped.

## The visual sheet stops this far (at the authored 3 m module scale) behind a
## lipped edge: 0.9 behind the lip line, like the old tiles' ground Center piece.
const LIP_INSET := 2.4

static func _cell_clip_info(_region, cache: Dictionary, cx: int, cz: int):
	return cache.get(Vector2i(cx, cz))

# Pointwise neighbour surface from a cached edge profile (along pdir).
static func _prof_at(prof: PackedFloat32Array, along: float, tile_size: float) -> float:
	var last := prof.size() - 1
	var a := clampf((along / tile_size + 0.5) * float(last), 0.0, float(last))
	var i := int(floorf(a))
	if i >= last:
		return prof[last]
	return lerpf(prof[i], prof[i + 1], a - float(i))

# Is slot s of this cell's `dir` edge lipped? Out-of-range slots look across the cell seam into
# the CONTINUATION cell's colinear edge — so two cells always agree about their shared corner.
static func _slot_lipped(region, cache: Dictionary, cx: int, cz: int, dir: Vector2i, s: int) -> bool:
	var tile := TerrainTileField.spacing(region)
	var slots := int(roundf(tile / minf(3.0, tile)))
	if s < 0 or s >= slots:
		var pdir := Vector2i(dir.y, dir.x)
		var step := 1 if s >= slots else -1
		cx += pdir.x * step
		cz += pdir.y * step
		s = 0 if s >= slots else slots - 1
	var info = _cell_clip_info(region, cache, cx, cz)
	if info == null or not info["dirs"].has(dir):
		return false
	var lips: Array = info["dirs"][dir]["lips"]
	return lips.size() > 0 and lips[s]

# Does a dressing corner piece sit on the cell-corner POINT toward `cdir` — placed by ANY of
# the FOUR same-height cells sharing it? A classic inner corner is owned by the DIAGONAL cell
# while the walling arms' lip runs end on the same point (owner round 4: the arm's taper draped
# a flap through the inner piece — "ground plane sticking out of inner corner lip"). The height
# gate keeps a higher cell's own corner piece (a different storey's junction) from holding this
# cell's clip open with nothing at this level to cover the band.
static func _corner_capped(region, cache: Dictionary, cx: int, cz: int, cdir: Vector2i) -> bool:
	var h: float = region.surface_height(cx, cz)
	for o in [Vector2i(0, 0), Vector2i(cdir.x, 0), Vector2i(0, cdir.y), cdir]:
		var info = _cell_clip_info(region, cache, cx + o.x, cz + o.y)
		if info == null:
			continue
		var oc := Vector2i(cdir.x - 2 * o.x, cdir.y - 2 * o.y)   # the same point, seen from that cell
		if info["corners"].has(oc) and absf(region.surface_height(cx + o.x, cz + o.y) - h) < 0.01:
			return true
	return false

# Feathered clip weight along the edge at along-position a (measured along pdir, -12..12):
# 1 inside lipped slots, tapering linearly to 0 at any slot boundary shared with an UNLIPPED
# slot — including across the cell seam. This keeps the sheet C0-continuous: a lipped cell
# never tears away from an unclipped neighbour (the owner's triangular holes), and the clip
# fades out exactly where the lip run ends.
static func _edge_w(region, cache: Dictionary, cx: int, cz: int, dir: Vector2i, a: float) -> float:
	var tile := TerrainTileField.spacing(region)
	var module_size := minf(3.0, tile)
	var slots := int(roundf(tile / module_size))
	var s := clampi(int(floorf((a + tile * 0.5) / module_size)), 0, slots - 1)
	var w_c := 1.0 if _slot_lipped(region, cache, cx, cz, dir, s) else 0.0
	var t := (a - (-tile * 0.5 + module_size * (float(s) + 0.5))) / (module_size * 0.5)
	var nb := s + 1 if t >= 0.0 else s - 1
	var nb_lipped := _slot_lipped(region, cache, cx, cz, dir, nb)
	if not nb_lipped and (nb < 0 or nb >= slots):
		# This slot boundary IS a cell corner. When a dressing corner PIECE sits on it, the lip
		# line TURNS there and keeps going — the clip must hold its weight, else the sheet
		# drapes into a steep flap through/behind the cap (owner round 4: the "slight gap" slit
		# at the lip back + a needle sliver poking from the wall at a slope-facing wrap corner).
		# Only a truly uncapped run end tapers out.
		var pdir := Vector2i(dir.y, dir.x)
		nb_lipped = _corner_capped(region, cache, cx, cz, dir + (pdir if nb >= slots else -pdir))
	var w_corner := w_c if nb_lipped else 0.0
	return lerpf(w_c, w_corner, clampf(absf(t), 0.0, 1.0))


static func _inner_corner_vertex(region, cache: Dictionary, qcx: int, qcz: int,
		v: Vector3) -> bool:
	var info = _cell_clip_info(region, cache, qcx, qcz)
	if info == null:
		return false
	var tile := TerrainTileField.spacing(region)
	var lx: float = v.x - float(qcx) * tile
	var lz: float = v.z - float(qcz) * tile
	var tuck := tile * 0.5 - 1.3 * minf(3.0, tile) / 3.0
	for cdir in info["corners"]:
		var kind: String = info["corners"][cdir]
		if kind != "inner" and kind != "pocket_cap":
			continue
		if lx * float(cdir.x) > tuck and lz * float(cdir.y) > tuck:
			return true
	return false

# Adjust a flat-top vertex for its cell's edges (visual sheet only):
#  - PULL it back LIP_INSET behind lipped edges (the KayKit lip is the visible edge there),
#    scaled by the feathered weight; the pulled edge rises by the cache's sheet_edge_lift to
#    tuck flush under the lip's raised top. Near-degenerate offsets (not zero) preserve the quad structure.
#  - BLEND it down (capped at EXPOSE_EPS) onto a neighbour that has dipped LESS than the lip
#    threshold, scaled by (1-w): sub-lip dips weld instead of opening a hairline slit at the
#    boundary (the owner's dark dashes where a slope flattens out).
static func _clip_vert(region, cache: Dictionary, qcx: int, qcz: int, v: Vector3) -> Vector3:
	var info = _cell_clip_info(region, cache, qcx, qcz)
	if info == null:
		return v
	var h: float = region.surface_height(qcx, qcz)
	var tile := TerrainTileField.spacing(region)
	var asset_scale := minf(3.0, tile) / 3.0
	var inset := LIP_INSET * asset_scale
	var top_clip := tile * 0.5 - inset
	var lx := v.x - float(qcx) * tile
	var lz := v.z - float(qcz) * tile
	var lift := 0.0
	var down := 0.0
	for dir in info["dirs"]:
		var coord := lx * float(dir.x) + lz * float(dir.y)       # distance toward this edge
		# Both clipping and draping have support only beyond top_clip. The
		# interior cannot move for any lip weight, so it needs no edge queries.
		if coord <= top_clip:
			continue
		var along := lx * float(dir.y) + lz * float(dir.x)       # signed along pdir=(dir.y,dir.x)
		var w := _edge_w(region, cache, qcx, qcz, dir, along)
		var f := clampf((coord - top_clip) / inset, 0.0, 1.0)
		if f > 0.0 and w < 1.0:
			# UNCAPPED drape: where the clip fades out, the edge follows the neighbour all the
			# way down (a hovering full-height flare read as "ground plane sticking out" at
			# lip-run ends/steps — owner round 4). The cell's own wall modules back the fold.
			var dip := maxf(h - _prof_at(info["dirs"][dir]["prof"], along, tile), 0.0)
			# Natural cliff ends have a rock wall backing the drape. Structural
			# planted decks may instead end at a facade over open air; their sealed
			# boundary forbids extending a grass curtain down into that void.
			dip = minf(dip, float(info.get("max_uncapped_drape", INF)))
			down = maxf(down, dip * f * (1.0 - w))
		if w <= 0.0:
			continue
		var target := tile * 0.5 - inset * w
		if coord > target:
			# 0.02 keeps the compressed band a few cm wide — truly degenerate slivers get
			# zero-area normals and render as dark dashes. The lift tucks the edge 1cm BELOW
			# the lip's raised top: flush to the eye, no coplanar z-fight with the lip.
			var pulled := target + (coord - target) * 0.02
			if dir.x != 0:
				lx = pulled * float(dir.x)
			else:
				lz = pulled * float(dir.y)
			lift = maxf(lift, float(info.get("sheet_edge_lift", 0.0)) * w)
	# INNER-CORNER dip: a flat cell that OWNS a classic inner corner (its diagonal is the
	# pocket) has no dressed edge of its own there, so its bare sheet ran flat to the very
	# corner point and poked out through the rounded front of the inner-corner piece as a
	# green flap over the pocket (owner round 11: "corner of plane sticking out of cliff lip
	# inner corner"). DIP the corner-point vertex well under the piece's front curve instead
	# of pulling it in XZ: the old diagonal tuck moved the
	# vertex OFF both cell boundaries while the level arms' sheets stayed ON them, and the
	# piece arms roof only 1.25 of the vacated 1.5 — two hairline slivers opened along the
	# boundaries beside the piece (owner batch 2: "tiny gaps in the ground next to inner
	# corner tiles"). The dip keeps every boundary edge welded; the down-bent corner hides
	# under the piece exactly like the flap it counters. Only the corner-point vertex dips
	# (the 1.3 box holds just it on the 2m grid) so all deformation stays under the piece;
	# build_chunk assigns its incident triangles the rock atlas texel in case a low camera
	# can still see that cliff-backing fold.
	# (Ghost corners need no dip: their diagonal cell is a HIGHER flat, already edge-clipped.)
	if _inner_corner_vertex(region, cache, qcx, qcz, v):
		down = maxf(down, 1.3 * asset_scale)
		# ("outer" one-armed flush-step corners need NO corner pull here: the dressed
		# arm's edge clip holds full weight through the corner — _slot_lipped's
		# continuation rule sees the taller cell's collinear lip run — so the boundary
		# row retracts along that axis alone and the cap's L-band covers the vacated
		# strip. A diagonal tuck abandons ground the band can't roof: a water-blue
		# wedge opened beside the cap.)
	return Vector3(float(qcx) * tile + lx, v.y + lift - down, float(qcz) * tile + lz)
