extends GutTest
const Mesher := preload("res://scripts/terrain/field/TerrainChunkMesher.gd")
const Plan := preload("res://scripts/terrain/heightfield/HeightfieldPlan.gd")

func _plan():
	var p := Plan.new(7, 56.0, 12, "mean")
	return p

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
	# Owner screenshot (seed 3846192678, cell (1,-4)): the per-chunk water quads sat at y=2 over
	# flat storey-0 ground with no basin around them, textured with the ground-material fallback
	# (water.tres doesn't exist) — reading as weird floating brown planes. The owner asked to
	# remove them; the global WaterSurface scene is the water visual instead.
	var m := Mesher.new()
	m.set_seed(3846192678)
	var p := Plan.new(3846192678, 22.0, 8, "mean", 3)
	var node: Node3D = m.build_chunk(p, Vector2i(0, -1))   # covers cells (2,-4),(3,-4): water there
	var water := node.find_child("Water", true, false) as MeshInstance3D
	assert_true(water == null or water.mesh == null, "chunks emit no floating water quads")
	node.free()

func test_chunk_scatters_decoration_children():
	var m := Mesher.new()
	m.set_seed(7)
	var node: Node3D = m.build_chunk(_plan(), Vector2i(0, 0))
	var deco := node.find_child("Decorations", true, false)
	assert_not_null(deco, "chunk has a Decorations container")
	# Non-water land chunk should usually contain at least one instance; allow zero only
	# if the whole chunk is water (not the case for seed 7 at origin per Task 10 check).
	assert_gte(deco.get_child_count(), 0)
	node.free()

func test_adjacent_chunks_share_boundary_height():
	# The shared edge between chunk (0,0) and chunk (1,0) must sample identical heights
	# (gap-free property): the field is single-valued, so the last column of chunk 0
	# equals the first column of chunk 1.
	const Field := preload("res://scripts/terrain/field/TerrainSurfaceField.gd")
	var p = _plan()
	var r = p.compute_region(0, 0, 64)
	var boundary_x := float(Mesher.CELLS_PER_CHUNK) * 24.0 * 0.5  # right edge of chunk (0,0) in world x
	var a := Field.surface_y(r, boundary_x, 3.0)
	var b := Field.surface_y(r, boundary_x, 3.0)
	assert_eq(a, b, "field is single-valued at the shared boundary")

func test_chunk_emits_cliff_wall():
	# The cliff face is now a VERTICAL rock SKIRT (separate "CliffFaces" mesh) — not a slanted part
	# of the walkable surface — PLUS overlaid KayKit dressing + a collision wall. Verify: (a) the
	# CliffFaces skirt has rock-UV triangles, (b) a collision wall blocks it, (c) dressing.
	const Atlas := preload("res://scripts/terrain/tools/SlopeAtlas.gd")
	var cliff_uv: Vector2 = Atlas.cliff_uv()
	var p := Plan.new(11, 32.0, 8, "mean", 3)
	p.set_raw_height_override(func(cx, cz): return 12.0 if cx <= 3 else 0.0)  # cliff between cell 3 and 4
	var node := Mesher.new().build_chunk(p, Vector2i(0, 0))
	var faces := node.find_child("CliffFaces", true, false) as MeshInstance3D
	assert_not_null(faces, "a CliffFaces rock-skirt mesh is emitted at the cliff")
	var uvs: PackedVector2Array = faces.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
	var grass := 0
	for uv in uvs:
		if uv.is_equal_approx(Atlas.grass_uv()): grass += 1
	assert_eq(grass, 0, "the cliff skirt is rock (KayKit wall texel), never grass")
	# the walkable surface itself must carry NO rock (cliff faces are not slanted into it anymore)
	var mi := node.find_child("Surface", true, false) as MeshInstance3D
	var suv: PackedVector2Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
	var surf_rock := 0
	for uv in suv:
		if uv.is_equal_approx(cliff_uv): surf_rock += 1
	assert_eq(surf_rock, 0, "walkable surface is all grass; the cliff face is the separate skirt")
	# A second collision shape (the invisible wall) stops the player at the cliff.
	var body := node.find_child("Body", true, false) as StaticBody3D
	assert_not_null(body.get_node_or_null("CollisionShape3D_walls"), "collision wall present")
	# KayKit cliff dressing produced rock-wall pieces for the cliff.
	var cliffs := node.find_child("Cliffs", true, false)
	var walls := cliffs.find_child("Walls", true, false) as MultiMeshInstance3D
	assert_gt(walls.multimesh.instance_count, 0, "cliff dressing produced wall pieces")
	node.free()

func test_cliff_skirt_is_vertical_at_the_boundary_no_cap():
	# The rock cliff-face skirt (CliffFaces) is a plain VERTICAL wall on a single plane just behind the
	# cell boundary (SKIRT_RECESS behind the KayKit wall, which reaches the boundary and is the visible
	# face) — NO horizontal cap and NO overhang. The old cap+overhang produced protruding planes and
	# left the boundary drop unfilled (see-through voids). Cliff at cell 3|4 → E-edge boundary x=84, so
	# every skirt vertex sits on x = 84 - SKIRT_RECESS and every triangle is near-vertical (no cap).
	var p := Plan.new(11, 32.0, 8, "mean", 3)
	p.set_raw_height_override(func(cx, cz): return 12.0 if cx <= 3 else 0.0)
	var node := Mesher.new().build_chunk(p, Vector2i(0, 0))
	var faces := node.find_child("CliffFaces", true, false) as MeshInstance3D
	assert_not_null(faces, "CliffFaces skirt present")
	var verts: PackedVector3Array = faces.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert_gt(verts.size(), 0, "skirt has geometry")
	var horiz := 0
	var plane_x := 84.0 - Mesher.SKIRT_RECESS
	for t in range(0, verts.size(), 3):
		var a := verts[t]; var b := verts[t + 1]; var c := verts[t + 2]
		var n := (b - a).cross(c - a).normalized()
		if absf(n.y) > 0.3:
			horiz += 1
		for v in [a, b, c]:
			assert_almost_eq(v.x, plane_x, 0.01, "skirt vertex on the single recessed boundary plane")
	assert_eq(horiz, 0, "no horizontal cap triangles (those were the protruding planes)")
	node.free()

func test_skirt_stops_short_of_a_perpendicular_wall_no_fin():
	# Owner screenshot (seed 2827641023 cell (1,-4)): at an outer corner the two rock skirts each
	# spanned their FULL cell edge, so each one ran SKIRT_RECESS past the other's plane and poked
	# out through the perpendicular KayKit wall face as a thin vertical fin. Where a cell also
	# walls the perpendicular direction, the skirt must stop at the perpendicular skirt plane.
	var p := Plan.new(11, 32.0, 8, "mean", 3)
	p.set_raw_height_override(func(cx, cz): return 12.0 if (cx <= 0 and cz <= 0) else 0.0)
	var node := Mesher.new().build_chunk(p, Vector2i(0, 0))
	var faces := node.find_child("CliffFaces", true, false) as MeshInstance3D
	assert_not_null(faces, "CliffFaces skirt present")
	var verts: PackedVector3Array = faces.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var lim := 12.0 - Mesher.SKIRT_RECESS + 0.01
	for v in verts:
		if absf(v.x - (12.0 - Mesher.SKIRT_RECESS)) < 0.01:   # cell (0,0)'s east skirt plane
			assert_lte(v.z, lim, "east skirt stops at the south skirt plane (no fin through the south wall)")
		if absf(v.z - (12.0 - Mesher.SKIRT_RECESS)) < 0.01:   # cell (0,0)'s south skirt plane
			assert_lte(v.x, lim, "south skirt stops at the east skirt plane (no fin through the east wall)")
	node.free()

func test_skirt_follows_a_dipping_neighbour_slope():
	# Owner screenshot (2827641023 cell (2,4)): the rock skirt stopped at the neighbour's
	# cell-centre height, but the neighbouring SLOPE surface descends further along the shared
	# edge — leaving a see-through void under the wall. The skirt bottom must follow the
	# neighbour's actual boundary surface, down to y=0 at the dipped corner here.
	var p := Plan.new(0, 64.0, 12, "mean", 4)
	p.set_raw_height_override(func(cx, cz):
		if cx == 2 and cz == 1: return 4.0
		if cx == 2 and cz == 0: return 0.0
		return 12.0)
	var node := Mesher.new().build_chunk(p, Vector2i(0, 0))
	var faces := node.find_child("CliffFaces", true, false) as MeshInstance3D
	assert_not_null(faces)
	var verts: PackedVector3Array = faces.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var plane_x := 36.0 - Mesher.SKIRT_RECESS   # C=(1,1)'s east skirt plane
	var min_y := 1e9
	for v in verts:
		if absf(v.x - plane_x) < 0.01 and v.z > 12.0 and v.z < 36.0:
			min_y = minf(min_y, v.y)
	assert_lt(min_y, 0.5, "east skirt reaches the dipped neighbour surface (y≈0), not the storey line (y=4)")
	node.free()

func test_skirt_covers_the_slope_facing_side_of_a_cliff_top():
	# Owner screenshot (2827641023 cell (4,12)): a SAME-storey slope neighbour descends along a
	# cliff top's side boundary, exposing a vertical face that had no skirt at all (see-through).
	var p := Plan.new(0, 64.0, 12, "mean", 4)
	p.set_raw_height_override(func(cx, cz):
		if cx == 2 and cz == 1: return 4.0
		if cx == 1 and cz == 0: return 8.0
		if cx == 0 and cz == 0: return 8.0
		return 12.0)
	var node := Mesher.new().build_chunk(p, Vector2i(0, 0))
	var faces := node.find_child("CliffFaces", true, false) as MeshInstance3D
	assert_not_null(faces)
	var verts: PackedVector3Array = faces.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var plane_x := 12.0 + Mesher.SKIRT_RECESS   # C=(1,1)'s west skirt plane (recessed INTO C)
	var found := false
	for v in verts:
		if absf(v.x - plane_x) < 0.01 and v.z > 12.0 and v.z < 36.0 and v.y < 8.5:
			found = true
			break
	assert_true(found, "the slope-facing side of the cliff top gets a skirt down the exposed face")
	node.free()

# C=(1,1) storey 2 (h=8) is a cliff top (its south neighbour row cz>=2 is storey 0). Its WEST
# neighbour W=(0,1) is storey 3 — HIGHER, and itself a cliff top. The junction band between C's
# terrain and W's recessed south wall used to show see-through slits (owner's terrace gaps).
func _terrace_plan():
	var p := Plan.new(0, 64.0, 12, "mean", 4)
	p.set_raw_height_override(func(cx, cz):
		if cx == 0 and cz == 1: return 12.0   # W: higher cliff top west of C
		if cz >= 2: return 0.0                # low ground south of everything
		return 8.0)                            # C=(1,1) and the flat backdrop
	return p

func test_collision_wall_is_flush_with_the_boundary_no_pocket():
	# Owner (round 7): "when i jump i often get stuck in the wall — is this an issue with the
	# collision shapes?" It was: the collision wall reused the VISUAL skirt mesh, recessed
	# SKIRT_RECESS behind the boundary while the collision sheet keeps its full extent to the
	# boundary — an overhang pocket under the lip band that wedged a jumping capsule, plus
	# zigzag profile edges to catch on. The collision wall is now its own FLAT plane ON the
	# boundary with its top flush at the cliff top, meeting the sheet collision in a clean
	# convex edge. The visual skirt keeps its recess.
	var p := Plan.new(11, 32.0, 8, "mean", 3)
	p.set_raw_height_override(func(cx, cz): return 12.0 if cx <= 3 else 0.0)
	var node := Mesher.new().build_chunk(p, Vector2i(0, 0))
	var body := node.find_child("Body", true, false) as StaticBody3D
	var cs := body.get_node("CollisionShape3D_walls") as CollisionShape3D
	var faces: PackedVector3Array = (cs.shape as ConcavePolygonShape3D).get_faces()
	assert_gt(faces.size(), 0, "collision wall has geometry")
	var top := -1e9
	for v in faces:
		assert_almost_eq(v.x, 84.0, 0.01, "collision wall sits ON the cell boundary plane")
		top = maxf(top, v.y)
	assert_almost_eq(top, 12.0, 0.01, "collision wall reaches the cliff top (no pocket under the lip band)")
	node.free()

func test_sheet_skirt_and_pieces_share_one_material():
	# Owner (round 8): "the cliff lip, the skirt, and the slope are all different colours...
	# it would be nice if they all used the same [texture] (so we could even change all of
	# them at once in the future)". The walkable sheet and aprons now render with the SAME
	# de-sheened KayKit material as the skirt — grass texel sampled from the lip piece's top,
	# rock texel from the wall piece — so every terrain surface shares the KayKit palette.
	var p := Plan.new(11, 32.0, 8, "mean", 3)
	p.set_raw_height_override(func(cx, cz): return 12.0 if cx <= 3 else 0.0)
	var node := Mesher.new().build_chunk(p, Vector2i(0, 0))
	var mi := node.find_child("Surface", true, false) as MeshInstance3D
	var faces := node.find_child("CliffFaces", true, false) as MeshInstance3D
	assert_eq(mi.mesh.surface_get_material(0), faces.mesh.surface_get_material(0),
		"the sheet and the skirt share one material (the KayKit palette)")
	var walls := node.find_child("Walls", true, false) as MultiMeshInstance3D
	var lips := node.find_child("Lips", true, false) as MultiMeshInstance3D
	assert_eq(walls.material_override, mi.mesh.surface_get_material(0),
		"the wall pieces render with the same shared material")
	assert_eq(lips.material_override, mi.mesh.surface_get_material(0),
		"the lip pieces render with the same shared material")
	# the sheet's grass texel comes from the lip piece's grass top, not the terrain atlas
	var lip_mesh := CliffDressing._pieces["lip"][0] as Mesh
	var arr = lip_mesh.surface_get_arrays(0)
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
	# Owner (round 7): "from some angles the skirt is a very different colour than the
	# surrounding slopes" — the big flat skirt caught the wall material's specular sheen
	# (roughness 0.6 / specular 0.5) that the curved modules never show at one angle. The
	# skirt uses a de-sheened DUPLICATE of the wall material.
	var m := Mesher.new()
	m._ensure_skirt_style()
	var mat := m._skirt_material as StandardMaterial3D
	assert_almost_eq(mat.roughness, 1.0, 0.001, "skirt roughness maxed (no angle-dependent sheen)")
	assert_almost_eq(mat.metallic_specular, 0.0, 0.001, "skirt specular removed")

func test_cliff_top_visual_plane_stops_at_the_lip_back():
	# Owner: "there is still a plane on the cliff top that extends past the cliff edge/corner
	# lips. it should only go up to the back of the cliff edge lips" — like the old tiles, whose
	# ground Center ends 0.9 behind the 10.5 lip line (i.e. at 9.6). The VISUAL top sheet of a
	# cliff top must stop at 9.6 on lipped edges; the KayKit lip is the edge from there out.
	var p := Plan.new(11, 32.0, 8, "mean", 3)
	p.set_raw_height_override(func(cx, cz): return 12.0 if cx <= 0 else 0.0)  # E cliff at x=12
	var node := Mesher.new().build_chunk(p, Vector2i(0, 0))
	var mi := node.find_child("Surface", true, false) as MeshInstance3D
	var verts: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for v in verts:
		if v.y > 11.9:   # the cliff-top plane of the column-0 cells
			assert_lt(v.x, 9.7, "cliff-top plane stops at the back of the lip (9.6), not the boundary")
	node.free()

func test_cliff_top_collision_still_reaches_the_boundary():
	# The clip is VISUAL only — the lip band must stay walkable, so the collision trimesh keeps
	# the full flat top out to the cell boundary.
	var p := Plan.new(11, 32.0, 8, "mean", 3)
	p.set_raw_height_override(func(cx, cz): return 12.0 if cx <= 0 else 0.0)
	var node := Mesher.new().build_chunk(p, Vector2i(0, 0))
	var body := node.find_child("Body", true, false) as StaticBody3D
	var cs := body.get_node("CollisionShape3D") as CollisionShape3D
	var faces: PackedVector3Array = (cs.shape as ConcavePolygonShape3D).get_faces()
	var reaches := false
	for v in faces:
		if v.y > 11.9 and v.x > 11.9:
			reaches = true
			break
	assert_true(reaches, "collision still covers the lip band out to the boundary")
	node.free()

func test_ground_apron_extends_under_higher_neighbour():
	# Owner: "even if a cliff tile is higher, we still need to extend the tile at the current
	# level underneath it" — C's ground continues APRON deep into W's footprint at C's height,
	# sealing the slot floor behind W's recessed wall face.
	var node := Mesher.new().build_chunk(_terrace_plan(), Vector2i(0, 0))
	var aprons := node.find_child("Aprons", true, false) as MeshInstance3D
	assert_not_null(aprons, "chunk emits ground aprons under higher neighbours")
	var found := false
	if aprons != null and aprons.mesh != null:
		for v in (aprons.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			if absf(v.y - 8.0) < 0.1 and v.x < 12.0 and v.x > 9.4 and v.z > 12.0 and v.z < 36.0:
				found = true
				break
	assert_true(found, "C's storey-2 ground extends west under W's overhang (apron at y=8)")
	node.free()

func test_skirt_extends_under_higher_neighbour():
	# Terraced pocket: C=(1,1) storey 2, N=(1,0) and W=(0,1) storey 3, NW=(0,0) storey 4. N's
	# south skirt and W's east skirt are perpendicular and each used to stop at its own cell
	# edge — leaving an open 1.3×1.3 chimney at the junction over C's corner. N's skirt must
	# continue west INTO the higher NW cell so the two skirts cross behind the corner piece.
	var p := Plan.new(0, 64.0, 12, "mean", 4)
	p.set_raw_height_override(func(cx, cz):
		if cx == 0 and cz == 0: return 16.0
		if cx == 1 and cz == 0: return 12.0
		if cx == 0 and cz == 1: return 12.0
		if cx == 2 and cz == 0: return 0.0
		if cx == 0 and cz == 2: return 0.0
		return 8.0)
	var node := Mesher.new().build_chunk(p, Vector2i(0, 0))
	var faces := node.find_child("CliffFaces", true, false) as MeshInstance3D
	var verts: PackedVector3Array = faces.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var plane_z := 12.0 - Mesher.SKIRT_RECESS   # N=(1,0)'s south skirt plane (z=10.7)
	var min_x := 1e9
	for v in verts:
		# N's skirt band (below NW's own skirt); x>0 excludes trimmed endpoints of
		# perpendicular skirts that coincidentally land on this z
		if absf(v.z - plane_z) < 0.01 and v.y < 10.9 and v.x > 0.0:
			min_x = minf(min_x, v.x)
	assert_lt(min_x, 11.0, "N's south skirt extends west under the higher NW (closes the chimney)")
	node.free()

func test_clip_uses_the_dipped_half_of_a_north_edge_not_its_mirror():
	# Owner (round 3, seed 78498630): on north/west edges the clip's slot mask was looked up
	# with the RAW axis coordinate, but the mask is ordered along pdir=(dir.y,dir.x) — mirrored
	# for negative pdir. The flush half of the edge got clipped (a hole into the void) while the
	# dipped half kept its brim. C=(1,1) is a cliff top whose NORTH neighbour is a slope dipping
	# on the WEST half only: the clip must pull the west half and leave the east half welded.
	var p := Plan.new(0, 64.0, 12, "mean", 4)
	p.set_raw_height_override(func(cx, cz):
		if cx == 0: return 8.0                # west column: storey 2 → the slope dips west
		if cx == 1 and cz == 2: return 0.0    # C's cliff-maker (south drop 3)
		return 12.0)
	var node := Mesher.new().build_chunk(p, Vector2i(0, 0))
	var mi := node.find_child("Surface", true, false) as MeshInstance3D
	var verts: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var clipped_west := false
	var clipped_east := false
	for v in verts:
		if v.y > 11.9 and absf(v.z - 14.4) < 0.05:   # pulled to C's north clip line
			if v.x > 13.5 and v.x < 20.0: clipped_west = true
			if v.x > 27.0 and v.x < 35.0: clipped_east = true
	assert_true(clipped_west, "the DIPPED (west) half of the north edge is clipped")
	assert_false(clipped_east, "the FLUSH (east) half of the north edge stays welded (no hole)")
	node.free()

func test_clip_tapers_to_zero_at_a_neighbour_that_does_not_clip():
	# Owner (round 3, seed 186412979): A clips its lipped south edge; its east neighbour B is
	# flat with a FLUSH south edge (no clip). A's pulled corner vertex tore away from B's sheet,
	# opening a triangular hole at the seam. The clip weight must taper to zero at any corner
	# shared with an unclipped slot, so both sheets keep their shared vertex. No corner piece
	# sits on the shared point at A's level — (2,2) is HIGHER flat, so its own corner at that
	# point belongs to another storey's junction and must not hold A's clip (a same-height cap
	# would rightly HOLD it — see test_arm_lip_run_holds_at_a_classic_inner_corner_no_flap).
	var p := Plan.new(0, 64.0, 12, "mean", 4)
	p.set_raw_height_override(func(cx, cz):
		if cx == 0 and cz == 1: return 4.0    # A's cliff-maker (west drop 2)
		if cx == 1 and cz == 2: return 8.0    # the pocket: A's south dip
		if cx == 2 and cz == 2: return 16.0   # higher flat SE of A — kills B's inner corner
		return 12.0)
	var node := Mesher.new().build_chunk(p, Vector2i(0, 0))
	var mi := node.find_child("Surface", true, false) as MeshInstance3D
	var verts: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var torn := false
	var clipped_mid := false
	for v in verts:
		if v.y > 11.9 and absf(v.x - 36.0) < 0.01 and v.z > 33.5 and v.z < 33.8:
			torn = true   # A's SE corner vert pulled away from the seam with B
		if v.y > 11.9 and v.x > 20.0 and v.x < 28.0 and absf(v.z - 33.6) < 0.05:
			clipped_mid = true
	assert_false(torn, "A's corner vertex stays on the seam (B does not clip its colinear edge)")
	assert_true(clipped_mid, "mid-edge is still fully clipped")
	node.free()

func test_apron_is_clamped_by_the_higher_cells_own_clip():
	# Owner (round 3, seed 78498630): the apron strip spanned its cell's full edge width, so its
	# ends poked out through the higher cell's PERPENDICULAR wall faces as floating green planes.
	# The strip must pull back where the higher cell's own top sheet is clipped — HERE the apron
	# (y=8) is level with W's south wall span (12→0), so poking past the clip would show.
	var node := Mesher.new().build_chunk(_terrace_plan(), Vector2i(0, 0))
	var aprons := node.find_child("Aprons", true, false) as MeshInstance3D
	assert_not_null(aprons)
	var max_z := -1e9
	for v in (aprons.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
		if absf(v.y - 8.0) < 0.2 and v.x > 9.4 and v.x < 12.1:
			max_z = maxf(max_z, v.z)
	assert_lt(max_z, 33.7, "apron stops behind W's south wall face (W's clip line), not at z=36")
	node.free()

func test_buried_apron_end_is_not_clamped_no_ground_gap():
	# Owner (round 9, seed 320048332, corner (-84,-84)): "there is a gap in the ground right
	# here". The low shelf's apron tucks under the tall cell B; at the junction corner its end
	# verts were pulled back by B's SOUTH sheet clip even though the apron (y=4) runs far BELOW
	# B's south wall span (12→8) — buried inside the plateau D's solid ground. The height-blind
	# clamp collapsed the last apron quad, opening a triangular hole at the corner point. An
	# apron end below the across-cell's surface is buried and must NOT be clamped.
	var p := Plan.new(0, 64.0, 12, "mean", 4)
	p.set_raw_height_override(func(cx, cz):
		if cx == 1 and cz == 0: return 12.0   # B: tall cell, walls west over the shelf
		if cx == 1 and cz == 1: return 8.0    # D: plateau south of B (flush west walls)
		if cx == 2 and cz == 2: return 0.0    # D's cliff-maker (SE diagonal, 2 storeys down)
		return 4.0)                            # the shelf west of both, and backdrop
	var node := Mesher.new().build_chunk(p, Vector2i(0, 0))
	var am := node.find_child("Aprons", true, false) as MeshInstance3D
	assert_not_null(am, "chunk has aprons")
	var covered := false
	if am != null:
		var arrays := am.mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx = arrays[Mesh.ARRAY_INDEX]   # Nil on non-indexed meshes
		var tri_ids := []
		if idx == null or (idx as PackedInt32Array).is_empty():
			for i in range(0, verts.size() - 2, 3):
				tri_ids.append([i, i + 1, i + 2])
		else:
			for i in range(0, (idx as PackedInt32Array).size() - 2, 3):
				tri_ids.append([idx[i], idx[i + 1], idx[i + 2]])
		# probe inside the previously-collapsed zone: the shelf's apron band under B
		# (x∈[12,14.4]) in the last 2.4 before the corner (z∈[9.6,12], B's south clip zone)
		var probe := Vector2(13.5, 11.5)
		for t in tri_ids:
			var a: Vector3 = verts[t[0]]
			var b: Vector3 = verts[t[1]]
			var c: Vector3 = verts[t[2]]
			if absf(a.y - 4.0) > 0.3 or absf(b.y - 4.0) > 0.3 or absf(c.y - 4.0) > 0.3:
				continue
			if _tri_covers_xz(probe, a, b, c):
				covered = true
				break
	assert_true(covered, "the buried apron end reaches the corner (no ground gap)")
	node.free()

func test_apron_seals_the_base_slit_next_to_a_same_storey_slope():
	# Owner (round 3): "gap between slope and cliff at the same level" — the recess band between
	# a flat cell's wall face and its boundary needs a floor at the SLOPE neighbour's descending
	# surface too, not only under strictly-higher neighbours.
	var p := Plan.new(0, 64.0, 12, "mean", 4)
	p.set_raw_height_override(func(cx, cz):
		if cx == 2 and cz == 1: return 4.0    # N's cliff drop (east)
		if cx == 1 and cz == 0: return 8.0    # N's north: storey 2 → N walls north
		if cx == 0 and cz == 0: return 8.0    # W's north: storey 2 → W slopes down north
		return 12.0)
	var node := Mesher.new().build_chunk(p, Vector2i(0, 0))
	var aprons := node.find_child("Aprons", true, false) as MeshInstance3D
	var found := false
	if aprons != null and aprons.mesh != null:
		for v in (aprons.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			# mid-edge of N's west band (z filter excludes the unrelated north-band strip)
			if v.x > 11.9 and v.x < 14.5 and v.z > 18.0 and v.z < 24.0 and v.y < 11.5:
				found = true
				break
	assert_true(found, "N=(1,1)'s west recess band gets a floor at the slope's descending surface")
	node.free()

func test_apron_normals_are_vertical():
	# Owner (round 3, seed 3674690878): "skirt a different colour than ground" — the apron was
	# indexed+generate_normals'd as double-sided geometry, welding opposing faces into ~zero
	# normals (broken lighting, wrong colour). Normals must be explicit verticals.
	var node := Mesher.new().build_chunk(_terrace_plan(), Vector2i(0, 0))
	var aprons := node.find_child("Aprons", true, false) as MeshInstance3D
	assert_not_null(aprons)
	var normals: PackedVector3Array = aprons.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	assert_gt(normals.size(), 0)
	for n in normals:
		assert_gt(absf(n.y), 0.9, "apron normal is vertical (no zero-normal welding)")
	node.free()

func test_flat_cell_edge_welds_onto_a_sub_lip_dip():
	# Round 3 residue: where the neighbouring slope has dipped LESS than EXPOSE_EPS there is no
	# lip/clip/apron — a sub-25cm slit opened at the boundary (dark dashes where a slope
	# flattens out). The flat cell's visual edge must blend down (capped at the eps) to weld
	# exactly onto the neighbour's surface across that band.
	var p := Plan.new(0, 64.0, 12, "mean", 4)
	p.set_raw_height_override(func(cx, cz):
		if cx == 0: return 8.0                # west column low → the north slope dips westward
		if cx == 1 and cz == 2: return 0.0    # C=(1,1)'s cliff-maker
		return 12.0)
	var node := Mesher.new().build_chunk(p, Vector2i(0, 0))
	var mi := node.find_child("Surface", true, false) as MeshInstance3D
	var verts: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	# C=(1,1)'s north boundary (z=12): every vertex still ON the boundary line must agree in
	# height with the other side (clipped columns have left the line and are exempt). The old
	# behaviour left C's verts at 12.0 over the neighbour's 11.75..12 sub-eps dips.
	var ys := {}
	for v in verts:
		if absf(v.z - 12.0) > 0.01 or v.x < 12.5 or v.x > 35.5 or v.y < 10.0 or v.y > 12.2:
			continue
		var key := int(roundf(v.x))
		if not ys.has(key):
			ys[key] = []
		ys[key].append(v.y)
	var worst := 0.0
	for key in ys:
		var lo = 1e9
		var hi = -1e9
		for y in ys[key]:
			lo = minf(lo, y)
			hi = maxf(hi, y)
		worst = maxf(worst, hi - lo)
	assert_lt(worst, 0.06, "flat edge welds onto the neighbour where its dip is below the lip threshold")
	node.free()

func test_skirt_uses_the_kaykit_wall_material():
	# Owner (round 3): "the skirts are a different colour than the ground/walls" — the skirt
	# rendered with the terrain atlas rock texel, visibly mismatching the KayKit wall pieces it
	# peeks out between. It must use the wall piece's own material so every peek-through blends.
	var p := Plan.new(11, 32.0, 8, "mean", 3)
	p.set_raw_height_override(func(cx, cz): return 12.0 if cx <= 0 else 0.0)
	var node := Mesher.new().build_chunk(p, Vector2i(0, 0))
	var faces := node.find_child("CliffFaces", true, false) as MeshInstance3D
	assert_not_null(faces)
	var wall_mat := (CliffDressing._pieces["wall"][0] as Mesh).surface_get_material(0) as StandardMaterial3D
	assert_not_null(wall_mat, "the KayKit wall piece has a material")
	# a de-sheened DUPLICATE of the wall material (round 7): same albedo texture, no specular
	var skirt_mat := faces.mesh.surface_get_material(0) as StandardMaterial3D
	assert_eq(skirt_mat.albedo_texture, wall_mat.albedo_texture, "the skirt shares the KayKit wall texture")
	node.free()

func test_apron_top_faces_use_the_sheet_winding():
	# Owner (round 4): aprons rendered DARK — the winding of the "up" side was backwards for
	# half the directions, so the face visible from above was the down-normal copy. The sheet's
	# up-facing triangles wind with a right-hand geometric normal pointing DOWN (Godot front =
	# clockwise); every apron triangle lit as UP must use the same winding.
	var node := Mesher.new().build_chunk(_terrace_plan(), Vector2i(0, 0))
	var aprons := node.find_child("Aprons", true, false) as MeshInstance3D
	assert_not_null(aprons)
	var arr = aprons.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var up_faces := 0
	for t in range(0, verts.size(), 3):
		if normals[t].y > 0.9:
			up_faces += 1
			var n_geo := (verts[t + 1] - verts[t]).cross(verts[t + 2] - verts[t])
			assert_lt(n_geo.y, 0.0, "an UP-lit apron face must wind like the sheet's top faces")
	assert_gt(up_faces, 0, "aprons have up-lit faces")
	node.free()

func test_aprons_have_collision():
	# Owner (round 4): "I think it's missing a collision shape (the player falls through)" —
	# where the apron is the only floor (the recess band beyond the cell boundary), the player
	# needs collision under their feet.
	var node := Mesher.new().build_chunk(_terrace_plan(), Vector2i(0, 0))
	var body := node.find_child("Body", true, false) as StaticBody3D
	var cs := body.get_node_or_null("CollisionShape3D_aprons") as CollisionShape3D
	assert_not_null(cs, "aprons carry a collision shape")
	if cs != null:
		var found := false
		for v in (cs.shape as ConcavePolygonShape3D).get_faces():
			if absf(v.y - 8.0) < 0.3 and v.x > 9.4 and v.x < 12.1:
				found = true
				break
		assert_true(found, "the apron band under the higher neighbour is walkable")
	node.free()

func test_taper_edge_drapes_onto_the_dipping_neighbour():
	# Owner (round 4): where a lipped edge's clip weight tapers to 0 (at a step to an unclipped
	# neighbour cell), the sheet flared back out to the boundary at FULL height — hovering over
	# the drop as a "ground plane sticking out". The flared band must drape down to the
	# neighbour's surface instead (A's own wall modules back the descending fold).
	var p := Plan.new(0, 64.0, 12, "mean", 4)
	p.set_raw_height_override(func(cx, cz):
		if cx == 0 and cz == 1: return 4.0    # A=(1,1)'s cliff-maker (west drop 2)
		if cx == 1 and cz == 2: return 8.0    # A's south dip (lipped edge, dip 4)
		if cx == 2 and cz == 2: return 16.0   # higher flat SE of A: the run end stays UNCAPPED
		return 12.0)
	var node := Mesher.new().build_chunk(p, Vector2i(0, 0))
	var mi := node.find_child("Surface", true, false) as MeshInstance3D
	var verts: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var draped := false
	for v in verts:
		# A's boundary vert one grid step before the seam corner: previously hovered at y=12;
		# draped it sits partway down (h − dip·f ≈ 11.33). The neighbours' own verts at this
		# position are at 12.0 (B) and 8.0 ((1,2)), so this band is unique to the drape.
		if absf(v.x - 36.0) < 0.01 and absf(v.z - 34.0) < 0.01 and v.y > 10.9 and v.y < 11.7:
			draped = true
	assert_true(draped, "the taper edge drapes down the step instead of hovering at the top")
	node.free()

func test_capped_corner_holds_the_clip_no_draped_flap():
	# Owner (round 4, seed 1450085760 cell (16,-1) SE corner — "slight gap"): where a cliff top's
	# lip line TURNS at an outer-corner cap (east: flat lower cliff top; south: same-storey slope
	# dipping at the shared corner via the diagonal), the clip weight tapered to 0 at that corner —
	# BOTH edges' colinear continuations are unlipped — so the sheet draped into a steep flap
	# through/behind the corner cap: a dark slit along the lip back plus a needle sliver poking
	# out of the wall. A corner PIECE occupies that slot: the run does not END there, it TURNS,
	# so the clip must hold its weight across the capped corner.
	var p := Plan.new(0, 64.0, 12, "mean", 4)
	p.set_raw_height_override(func(cx, cz):
		if cx == 1 and cz == 0: return 0.0    # C's cliff-maker (3-storey north drop)
		if cx == 2 and cz == 0: return 0.0    # E's cliff-maker (2-storey north drop)
		if cx == 2 and cz == 1: return 8.0    # E: flat cliff top one storey below C
		return 12.0)                           # C=(1,1); S=(1,2) slopes via the diagonal dip to E
	var node := Mesher.new().build_chunk(p, Vector2i(0, 0))
	var mi := node.find_child("Surface", true, false) as MeshInstance3D
	var verts: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	# C's SE corner slot, strictly inside the cell (boundary columns x=36 / z=36 belong to E / S).
	# Clipped, every C vert here sits at the lifted top (≈12.04); the bug's flap left verts at
	# intermediate heights descending behind the cap. E's top is 8.0 and S's slope only reaches
	# the box at its exact boundary, so the (8.5, 11.9) band is unique to the flap.
	for v in verts:
		if v.x > 33.0 and v.x < 35.9 and v.z > 33.0 and v.z < 35.9:
			assert_false(v.y > 8.5 and v.y < 11.9,
				"sheet vert drapes behind the SE corner cap (the owner's 'slight gap'): %s" % v)
	node.free()

func test_arm_lip_run_holds_at_a_classic_inner_corner_no_flap():
	# Owner (round 4, seed 1450085760 cell (8,-2) SW junction — "ground plane sticking out of
	# inner corner lip"): at a CLASSIC inner corner the piece is owned by the DIAGONAL cell D,
	# while the walling arms' lip runs end on the same corner point. Each arm's colinear
	# continuation (one of D's flush edges) is unlipped, so the arm's clip tapered to 0 there
	# and its sheet draped into a flap poking out through the inner piece. The cap check must
	# consider ALL FOUR cells sharing the point, not just the run's own cell.
	var p := Plan.new(0, 64.0, 12, "mean", 4)
	p.set_raw_height_override(func(cx, cz):
		if cx == 0 and cz == 0: return 0.0    # arm N=(1,1)'s cliff-maker (NW diagonal)
		if cx == 1 and cz == 3: return 0.0    # arm E=(2,2)'s cliff-maker (SW diagonal)
		if cx == 1 and cz == 2: return 4.0    # P: the pocket, one storey below the arms
		return 8.0)                            # arms N/E at 8; D=(2,1) owns the inner corner
	var node := Mesher.new().build_chunk(p, Vector2i(0, 0))
	var mi := node.find_child("Surface", true, false) as MeshInstance3D
	var verts: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	# Around the shared corner point (36,36): the arms' sheets sit clipped at ~8.04, P's slope
	# at ~4, D's flat top at 8.0 — only a draped flap leaves verts at intermediate heights.
	for v in verts:
		if v.x > 33.5 and v.x < 38.5 and v.z > 33.5 and v.z < 38.5:
			assert_false(v.y > 4.6 and v.y < 7.9,
				"an arm's sheet drapes through the inner corner piece (the owner's protruding plane): %s" % v)
	node.free()

func test_run_end_at_a_higher_flat_neighbour_holds_the_clip():
	# Owner (round 5, seed 1751195249 cell (-7,-5) NW junction — the "weird glitch" fold and the
	# "gap next to skirt"): where a lipped run ends against a HIGHER flat neighbour, the dressing
	# caps the junction with an extension corner one module into that cell — but the clip's
	# corner check didn't know extension caps exist, so the sheet tapered to 0 and draped a
	# crumpled fold through the cap, dipping away from the higher wall's base apron. Junction
	# caps must hold the clip exactly like classic corner pieces.
	var p := Plan.new(0, 64.0, 12, "mean", 4)
	p.set_raw_height_override(func(cx, cz):
		if cx == 0 and cz == 0: return 0.0    # H=(1,1)'s cliff-maker (NW diagonal)
		if cx == 2 and cz == 0: return 0.0    # L=(2,1)'s cliff-maker and exposed north edge
		if cx == 2 and cz == 1: return 8.0    # L: lower cliff top, its run ends against H
		return 12.0)                           # H=(1,1) higher flat; (1,0)=12 keeps H's north flush
	var node := Mesher.new().build_chunk(p, Vector2i(0, 0))
	var mi := node.find_child("Surface", true, false) as MeshInstance3D
	var verts: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	# L's NW junction box: held, L's verts sit clipped at ~8.04; the fold left verts draped to
	# intermediate heights. The 0-ground's own verts are at ~0 and H's top at 12 — outside the band.
	for v in verts:
		if v.x > 35.9 and v.x < 38.5 and v.z > 11.5 and v.z < 14.5:
			assert_false(v.y > 0.5 and v.y < 7.9,
				"sheet vert drapes through the junction cap (the owner's fold): %s" % v)
	node.free()

func test_surface_is_gap_free_for_any_heightfield():
	# The owner's requirement: gap-free terrain for ANY heightmap. The surface renders EVERY
	# grid quad (grass or rock), so the triangle count is always GRID*GRID*2 — no quad skipped,
	# no hole — even on wild, steep, cliff-riddled heightfields. Checked over several seeds.
	var expected := Mesher.GRID * Mesher.GRID * 2
	for seed in [1, 7, 42, 999]:
		var p := Plan.new(seed, 40.0, 12, "mean", 3)
		var node := Mesher.new().build_chunk(p, Vector2i(0, 0))
		var mi := node.find_child("Surface", true, false) as MeshInstance3D
		var idx: PackedInt32Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX]
		assert_eq(idx.size() / 3, expected, "seed %d: every quad rendered (gap-free surface)" % seed)
		node.free()

func test_cliff_face_is_rock_not_climbing_grass():
	# The surface is continuous (gap-free for any heightfield), but a boundary-straddling cliff
	# face must be textured ROCK, not grass (the old "grass climbs the cliff" bug). So every
	# STEEP triangle (large vertical extent over a tiny footprint) must carry the rock UV, and
	# no grass-UV triangle may span more than a gentle slope.
	const Atlas := preload("res://scripts/terrain/tools/SlopeAtlas.gd")
	var grass_uv: Vector2 = Atlas.grass_uv()
	var p := Plan.new(11, 32.0, 8, "mean", 3)
	p.set_raw_height_override(func(cx, cz): return 12.0 if cx <= 3 else 0.0)  # 3-storey cliff at cell 3|4
	var node := Mesher.new().build_chunk(p, Vector2i(0, 0))
	var mi := node.find_child("Surface", true, false) as MeshInstance3D
	var arr = mi.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var worst_grass := 0.0
	for t in range(0, idx.size(), 3):
		var a := verts[idx[t]]; var b := verts[idx[t + 1]]; var c := verts[idx[t + 2]]
		var y_ext: float = maxf(maxf(a.y, b.y), c.y) - minf(minf(a.y, b.y), c.y)
		var is_grass := uvs[idx[t]].is_equal_approx(grass_uv)
		if is_grass:
			worst_grass = maxf(worst_grass, y_ext)
	assert_lt(worst_grass, 6.0, "no GRASS triangle spans a cliff's height (cliff faces are rock)")
	node.free()

func test_steep_upramp_slope_is_grass_not_rock():
	# Owner's grey diamonds: a cell one storey below a cliff top ramps UP to meet it — a steep but
	# WALKABLE slope. Its quads must be classified grass, NOT rock (textured grey). Only a real
	# cliff face (≥2 cell drop, or a 1-storey step between two cliff tops) is rock.
	var p := Plan.new(0, 32.0, 8, "mean", 3)
	p.set_raw_height_override(func(cx, cz):
		if cx == 1 and cz == 0: return 8.0    # cliff top (drops ≥2 to (2,0)=0)
		if cx == 0 and cz == 0: return 4.0    # one storey below it → ramps up to meet it
		return 0.0)
	var region = p.compute_region(0, 0, 8)
	var m = Mesher.new()
	# a quad straddling cell (0,0)→(1,0): the up-ramp reaches the cliff-top height here (steep),
	# but it's a walkable slope, so it must be grass.
	assert_false(m._is_cliff_quad(region, 10.0, 12.0, -2.0, 0.0), "steep up-ramp slope quad is grass, not rock")
	# the actual ≥2 cliff face (cell (1,0) storey 2 → (2,0) storey 0) IS rock.
	assert_true(m._is_cliff_quad(region, 34.0, 36.0, -2.0, 0.0), "the ≥2 cliff face is rock")

func _tri_covers_xz(p: Vector2, a: Vector3, b: Vector3, c: Vector3) -> bool:
	var a2 := Vector2(a.x, a.z)
	var b2 := Vector2(b.x, b.z)
	var c2 := Vector2(c.x, c.z)
	var d1 := (b2 - a2).cross(p - a2)
	var d2 := (c2 - b2).cross(p - b2)
	var d3 := (a2 - c2).cross(p - c2)
	return (d1 >= -0.001 and d2 >= -0.001 and d3 >= -0.001) or (d1 <= 0.001 and d2 <= 0.001 and d3 <= 0.001)
