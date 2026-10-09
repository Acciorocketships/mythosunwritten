class_name RockSkirt
extends RefCounted

## Ground skirt where an embedded rock meets the ground (owner, September 27:
## rocks sat on the ground like separate objects; the ground should mesh with
## them). A ring of ground rises from the surface a short way out to a low
## mound under the rock's contact outline, so the rock emerges from the ground.
##
## The skirt is the surface it covers, swollen: every vertex takes that
## surface's own appearance inputs (material, biome tint, moss grade, rock
## exposure and lighting normal); only its height differs. Covered terrain
## is drawn with the terrain material; covered slope sheet with the slope
## material (`sheet` triangles). No outline, colour or normal seam can
## therefore appear where it meets the ground (September 27 follow-up: a
## skirt with its own normals read as a paler pad with an outline).
## It belongs to its rock (half-open rock ownership), so a chunk seam can never
## split or duplicate it. Its rim sinks just below the ground, so the surfaces
## cross cleanly instead of z-fighting. Worker-pure plain data until commit().
const SIDES := 32
## Ring offsets beyond the contact outline, as fractions of the skirt width.
## The first ring lies inside the rock (hidden), the last is the buried rim.
## The rim sinks steeply enough that the mound never lies nearly coplanar with
## the ground (which would z-fight in a comb of slivers).
const RINGS := [-0.35, 0.0, 0.3, 0.6, 0.85, 1.0]
const RIM_SINK := 0.05
## Mound height at the rock, as a fraction of the rock's exposed height,
## and the skirt width as a fraction of its mean contact radius.
const RISE := 0.2
const RISE_MAX := 0.45
const WIDTH := 0.6
const WIDTH_MIN := 0.9
const WIDTH_MAX := 2.6

## The mound's height where it meets a rock showing `exposed` metres.
static func rise_for(exposed: float) -> float:
	return minf(RISE * exposed, RISE_MAX)

## The rendered terrain: the mesher's 2 m lattice quads, each evaluated on the
## side of the lattice point owning it (so a cliff top stays flat to its wall;
## the drop is a separate skirt) and split along the same (0,0)-(1,1) diagonal.
static func terrain_ground(region: HeightfieldRegion) -> Callable:
	return _terrain_ground(region, {})

## terrain_ground reading the quad corners `prefetch_corners` gathered for a
## point (exactly the values it would sample), else sampling them itself.
static func _terrain_ground(region: HeightfieldRegion, corners: Dictionary) -> Callable:
	var step := TerrainChunkMesher.STEP
	return func(p: Vector2) -> float:
		var x0 := floorf(p.x / step) * step
		var z0 := floorf(p.y / step) * step
		var fx := p.x / step - x0 / step
		var fz := p.y / step - z0 / step
		if corners.has(p):
			var c: PackedFloat64Array = corners[p]
			if fx >= fz:
				return c[0] + fx * (c[1] - c[0]) + fz * (c[3] - c[1])
			return c[0] + fz * (c[2] - c[0]) + fx * (c[3] - c[2])
		var owner := Vector2i(TerrainTileField.point_of(p.x, region), TerrainTileField.point_of(p.y, region))
		var h00 := TerrainTileField.surface_y_on_side(region, x0, z0, owner)
		var h11 := TerrainTileField.surface_y_on_side(region, x0 + step, z0 + step, owner)
		if fx >= fz:
			var h10 := TerrainTileField.surface_y_on_side(region, x0 + step, z0, owner)
			return h00 + fx * (h10 - h00) + fz * (h11 - h10)
		var h01 := TerrainTileField.surface_y_on_side(region, x0, z0 + step, owner)
		return h00 + fz * (h01 - h00) + fx * (h11 - h01)

## The four 2 m quad corners (0,0), (1,0), (0,1), (1,1) of every point, each
## on the side of the point's owner, in one batched kernel call: exactly the
## surface_y_on_side values terrain_ground and the terrain normal read.
static func prefetch_corners(region: HeightfieldRegion, corners: Dictionary,
		points: PackedVector2Array) -> void:
	if points.is_empty():
		return
	var step := TerrainChunkMesher.STEP
	var n := points.size() * 4
	var xs := PackedFloat64Array(); xs.resize(n)
	var zs := PackedFloat64Array(); zs.resize(n)
	var oi := PackedInt32Array(); oi.resize(n)
	var oj := PackedInt32Array(); oj.resize(n)
	var lo := Vector2i(1 << 30, 1 << 30)
	var hi := Vector2i(-(1 << 30), -(1 << 30))
	for k in points.size():
		var p := points[k]
		var owner := Vector2i(TerrainTileField.point_of(p.x, region), TerrainTileField.point_of(p.y, region))
		lo = lo.min(owner); hi = hi.max(owner)
		var x0 := floorf(p.x / step) * step
		var z0 := floorf(p.y / step) * step
		for c in 4:
			xs[k * 4 + c] = x0 + step if c & 1 else x0
			zs[k * 4 + c] = z0 + step if c & 2 else z0
			oi[k * 4 + c] = owner.x
			oj[k * 4 + c] = owner.y
	var window := TerrainTileField.dense_window(region, lo - Vector2i.ONE, hi - lo + Vector2i(3, 3))
	assert(TerrainTileField._window_holds(window, lo, hi))
	var heights := TerrainTileField.sample_window(window, xs, zs, oi, oj)
	if TerrainTileField.grades(region):
		for i in n:
			heights[i] = TerrainTileField._apply_grade(region, xs[i], zs[i], heights[i])
	for k in points.size():
		corners[points[k]] = heights.slice(k * 4, k * 4 + 4)

## Contact radius in each of SIDES directions: the support function of the
## rock's world-space base outline about its centre.
static func contact_radii(outline: PackedVector2Array, centre: Vector2) -> PackedFloat32Array:
	var radii := PackedFloat32Array()
	for k in SIDES:
		var direction := Vector2.from_angle(TAU * k / SIDES)
		var reach := 0.0
		for point: Vector2 in outline:
			reach = maxf(reach, (point - centre).dot(direction))
		radii.append(reach)
	return radii

## Contact radii of an ellipse (semi-axes along `axis_u` and its normal).
static func ellipse_radii(semi: Vector2, axis_u: Vector2) -> PackedFloat32Array:
	var outline := PackedVector2Array()
	var axis_v := Vector2(-axis_u.y, axis_u.x)
	for k in 32:
		var a := TAU * k / 32.0
		outline.append(axis_u * semi.x * cos(a) + axis_v * semi.y * sin(a))
	return contact_radii(outline, Vector2.ZERO)

## The rendered terrain surface: height (`terrain_ground`), the mesher's
## field-gradient lattice normal and its bilinear 24 m tint-lattice biome tint.
## `corner_tint(pos, seed)` is the lattice tint (BiomeRegistry.ground_tint_at;
## tests count its calls).
static func terrain_surface(region: HeightfieldRegion, world_seed: int,
		corner_tint: Callable = BiomeRegistry.ground_tint_at) -> Dictionary:
	var corners := {}
	var ground := _terrain_ground(region, corners)
	var step := TerrainChunkMesher.STEP
	var tile := TerrainChunkMesher.CELL
	# The sheet lights each vertex of its 2 m lattice with the exact field
	# gradient there (TerrainChunkMesher.field_normals), interpolated across
	# the quad. The quad's corners lie on the side of the lattice point owning
	# the point being shaded (a cliff's upper and lower quads never weld).
	var baked := {}
	# Lattice corner tints and node normals, read once each (one surface is
	# built and read by one thread: a skirt's or a candidate's own).
	var tints := {}
	var node_normals := {}
	var lattice_tint := func(x: float, z: float) -> Color:
		var key := Vector2(x, z)
		if not tints.has(key):
			tints[key] = corner_tint.call(Vector3(x, 0, z), world_seed)
		return tints[key]
	return {
		"height": ground,
		"prefetch": func(points: PackedVector2Array) -> void:
			prefetch_corners(region, corners, points),
		"normal": func(p: Vector2) -> Vector3:
			var owner := Vector2i(TerrainTileField.point_of(p.x, region), TerrainTileField.point_of(p.y, region))
			var x0 := floorf(p.x / step) * step
			var z0 := floorf(p.y / step) * step
			var fx := (p.x - x0) / step
			var fz := (p.y - z0) / step
			var nodes := PackedVector3Array()
			var known: PackedFloat64Array = corners.get(p, PackedFloat64Array())
			var missing := PackedVector3Array()
			for k in 4:
				var x := x0 + (step if k & 1 else 0.0)
				var z := z0 + (step if k & 2 else 0.0)
				var node := Vector3(x, known[k] if not known.is_empty()
					else TerrainTileField.surface_y_on_side(region, x, z, owner), z)
				nodes.append(node)
				if not node_normals.has(node):
					missing.append(node)
			# field_normals is per node (a pure function of the node), so a
			# node shared by neighbouring vertices is lit once.
			if not missing.is_empty():
				var fresh := TerrainChunkMesher.field_normals(missing, region, baked)
				for k in missing.size():
					node_normals[missing[k]] = fresh[k]
			var n := Vector3.ZERO
			for k in 4:
				n += (node_normals[nodes[k]] as Vector3) * (fx if k & 1 else 1.0 - fx) * (fz if k & 2 else 1.0 - fz)
			return n.normalized(),
		"tint": func(p: Vector2) -> Color:
			var x0 := floorf(p.x / tile) * tile
			var z0 := floorf(p.y / tile) * tile
			var fx := (p.x - x0) / tile
			var fz := (p.y - z0) / tile
			var a: Color = lattice_tint.call(x0, z0).lerp(lattice_tint.call(x0 + tile, z0), fx)
			var b: Color = lattice_tint.call(x0, z0 + tile).lerp(lattice_tint.call(x0 + tile, z0 + tile), fx)
			return a.lerp(b, fz),
	}

## `surface` is the covered surface: {height(p)->float, normal(p)->Vector3,
## tint(p)->Color, optional sheet(p)->bool (slope sheet rather than terrain)}.
## `exposed` is the rock's visible height above it.
static func build(id: String, centre: Vector2, radii: PackedFloat32Array,
		exposed: float, surface: Dictionary) -> Dictionary:
	assert(radii.size() == SIDES)
	var mean := 0.0
	for r: float in radii:
		mean += r / SIDES
	var rise := rise_for(exposed)
	var width := clampf(WIDTH * mean, WIDTH_MIN, WIDTH_MAX)
	var ground: Callable = surface.height
	# Every point the skirt samples: the centre, the contacts, the rings.
	var contacts := PackedVector2Array()
	for k in SIDES:
		contacts.append(centre + Vector2.from_angle(TAU * k / SIDES) * radii[k])
	var ring_points := PackedVector2Array()
	for j in RINGS.size():
		var s: float = RINGS[j]
		for k in SIDES:
			ring_points.append(centre + Vector2.from_angle(TAU * k / SIDES) \
				* (radii[k] * (1.0 + minf(s, 0.0)) + maxf(s, 0.0) * width))
	# A surface that can sample its terrain in one batch gathers them all
	# first; its height/normal/sheet then read exactly those values.
	if surface.has("prefetch"):
		var points := PackedVector2Array([centre])
		points.append_array(contacts)
		points.append_array(ring_points)
		surface.prefetch.call(points)
	# The mound meets the rock where it shows: in each direction it rises in
	# proportion to the rock's visible height at that contact. On a slope the
	# uphill contact can lie at or above the rock's top (the rock is buried
	# there); no mound rises over it (September 27 integration: uphill of
	# every slope rock the ground bulged up to 0.45 m over nothing).
	var top: float = float(ground.call(centre)) + exposed
	var rises := PackedFloat32Array()
	for k in SIDES:
		rises.append(rise_for(maxf(0.0, top - float(ground.call(contacts[k])))))
	# The mound over the covered surface, continuous in the plane.
	var bump := func(p: Vector2) -> float:
		var offset := p - centre
		var f := fposmod(offset.angle() / TAU, 1.0) * SIDES
		var t := f - floorf(f)
		var contact := lerpf(radii[int(f) % SIDES], radii[(int(f) + 1) % SIDES], t)
		var height := lerpf(rises[int(f) % SIDES], rises[(int(f) + 1) % SIDES], t)
		return height * (1.0 - smoothstep(0.0, 1.0, maxf(offset.length() - contact, 0.0) / width))
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var on_sheet := PackedByteArray()
	for j in RINGS.size():
		for k in SIDES:
			var p := ring_points[j * SIDES + k]
			var rim := j == RINGS.size() - 1
			vertices.append(Vector3(p.x, float(ground.call(p)) + (-RIM_SINK if rim else float(bump.call(p))), p.y))
			# Lighting is the covered surface's own: a tilt by the mound's
			# gradient read as a lighter or darker pad (September 27 review).
			normals.append(surface.normal.call(p))
			colors.append(surface.tint.call(p))
			on_sheet.append(1 if surface.has("sheet") and bool(surface.sheet.call(p)) else 0)
	var indices := PackedInt32Array()
	var sheet_indices := PackedInt32Array()
	var collision := PackedVector3Array()
	for j in RINGS.size() - 1:
		for k in SIDES:
			var a := j * SIDES + k
			var b := j * SIDES + (k + 1) % SIDES
			var c := a + SIDES
			var d := b + SIDES
			for tri: Array in [[a, c, b], [b, c, d]]:
				# Godot front faces: (v2 - v0) x (v1 - v0) points out (up).
				if (vertices[tri[2]] - vertices[tri[0]]).cross(vertices[tri[1]] - vertices[tri[0]]).y < 0.0:
					tri = [tri[0], tri[2], tri[1]]
				# Each triangle draws with the surface most of its corners cover.
				var sheet: bool = on_sheet[tri[0]] + on_sheet[tri[1]] + on_sheet[tri[2]] >= 2
				for index: int in tri:
					(sheet_indices if sheet else indices).append(index)
					collision.append(vertices[index])
	return {"id": id, "anchor": Vector3(centre.x, float(ground.call(centre)), centre.y),
		"top": float(ground.call(centre)) + rise,
		"vertices": vertices, "normals": normals, "colors": colors,
		"indices": indices, "sheet_indices": sheet_indices, "on_sheet": on_sheet,
		"collision_faces": collision,
		"grass_support": _grass_support(id, centre, radii, width, collision,
			float(ground.call(centre)) + rise)}

## Grass grows on the skirt, not on the terrain buried beneath it, and never
## under the rock: a mesh-backed GrassSupportSurfaces grid whose nodes inside
## the contact outline block blades (flag 2) and whose skirt nodes claim the
## point for the skirt triangles (flag 1).
const GRASS_STEP := 0.5
static func _grass_support(id: String, centre: Vector2, radii: PackedFloat32Array,
		width: float, faces: PackedVector3Array, top: float) -> Dictionary:
	var reach := width
	for r: float in radii:
		reach = maxf(reach, r + width)
	var origin := ((centre - Vector2.ONE * reach) / GRASS_STEP).floor() * GRASS_STEP
	var w := ceili(2.0 * reach / GRASS_STEP) + 2
	var flags := PackedByteArray()
	var heights := PackedFloat32Array()
	for k in w:
		for i in w:
			var offset := origin + Vector2(i, k) * GRASS_STEP - centre
			var f := fposmod(offset.angle() / TAU, 1.0) * SIDES
			var contact := lerpf(radii[int(f) % SIDES], radii[(int(f) + 1) % SIDES], f - floorf(f))
			var r := offset.length()
			flags.append(2 if r < contact else (1 if r < contact + width else 0))
			heights.append(top)
	return {"grid": true, "id": "rock_skirt/" + id, "origin": origin, "step": GRASS_STEP,
		"w": w, "h": w, "flags": flags, "heights": heights, "mesh_faces": faces,
		"mesh_cells": GrassSupportSurfaces.index_mesh(faces, origin, GRASS_STEP),
		"mesh_bounds": Rect2(origin, Vector2.ONE * (w - 1) * GRASS_STEP)}

## Main thread: the terrain-covering triangles as one merged ground-material
## mesh and bounded collision pieces on one body.
static func commit(parent: Node3D, skirts: Array) -> void:
	for step: Callable in commit_steps(parent, skirts):
		step.call()


## Skirts gathered per step on the main thread (the per-index loop was most of
## a 9-19 ms integration step on rocky chunks).
const SKIRTS_PER_STEP := 4
## Bound each physics BVH build; a whole rocky chunk can exceed 25 ms.
const COLLISION_TRIANGLES_PER_STEP := 1000

## commit as main-thread steps: gather SKIRTS_PER_STEP skirts a step, then the
## mesh, then bounded collision pieces. Running them in order builds exactly
## commit's nodes (the same arrays, mesh, shapes and child order).
static func commit_steps(parent: Node3D, skirts: Array) -> Array[Callable]:
	var steps: Array[Callable] = []
	if skirts.is_empty():
		return steps
	var acc := {"vertices": PackedVector3Array(), "normals": PackedVector3Array(),
		"colors": PackedColorArray(), "indices": PackedInt32Array(), "faces": PackedVector3Array()}
	for first in range(0, skirts.size(), SKIRTS_PER_STEP):
		steps.append(func() -> void: _gather(acc, skirts, first, mini(first + SKIRTS_PER_STEP, skirts.size())))
	steps.append(func() -> void: _commit_mesh(parent, acc))
	var face_count := 0
	for skirt: Dictionary in skirts:
		face_count += (skirt.indices as PackedInt32Array).size()
	var piece_size := COLLISION_TRIANGLES_PER_STEP * 3
	for first in range(0, face_count, piece_size):
		steps.append(func() -> void: _commit_collision(parent, acc, first, piece_size))
	return steps


static func _gather(acc: Dictionary, skirts: Array, from: int, to: int) -> void:
	assert(OS.get_thread_caller_id() == OS.get_main_thread_id())
	# Taken out of the dictionary while appending, so no copy is made.
	var vertices: PackedVector3Array = acc.vertices
	var normals: PackedVector3Array = acc.normals
	var colors: PackedColorArray = acc.colors
	var indices: PackedInt32Array = acc.indices
	var faces: PackedVector3Array = acc.faces
	acc.clear()
	for k in range(from, to):
		var skirt: Dictionary = skirts[k]
		var base := vertices.size()
		vertices.append_array(skirt.vertices)
		normals.append_array(skirt.normals)
		colors.append_array(skirt.colors)
		for index: int in skirt.indices:
			indices.append(base + index)
			faces.append((skirt.vertices as PackedVector3Array)[index])
	acc.merge({"vertices": vertices, "normals": normals, "colors": colors, "indices": indices, "faces": faces})


static func _commit_mesh(parent: Node3D, acc: Dictionary) -> void:
	var indices: PackedInt32Array = acc.indices
	# The terrain-covering triangles; slope-covering ones render in the sheet.
	if indices.is_empty():
		return
	var vertices: PackedVector3Array = acc.vertices
	var uvs := PackedVector2Array()
	uvs.resize(vertices.size())
	uvs.fill(CliffDressing.ground_uv())
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = acc.normals
	arrays[Mesh.ARRAY_COLOR] = acc.colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, CliffDressing.shared_material())
	var instance := MeshInstance3D.new()
	instance.name = &"RockSkirts"
	instance.mesh = mesh
	instance.add_to_group("tactical_solid_earth", true)
	parent.add_child(instance)


static func _commit_collision(parent: Node3D, acc: Dictionary, first: int, count: int) -> void:
	var faces: PackedVector3Array = acc.faces
	if (acc.indices as PackedInt32Array).is_empty():
		return
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces.slice(first, first + count))
	var collision := CollisionShape3D.new()
	collision.name = "RockSkirts" if first == 0 else "RockSkirts%d" % (first / count + 1)
	collision.shape = shape
	var body := parent.get_node_or_null("RockSkirtCollision") as StaticBody3D
	if body == null:
		body = StaticBody3D.new()
		body.name = &"RockSkirtCollision"
		parent.add_child(body)
	body.add_child(collision)
