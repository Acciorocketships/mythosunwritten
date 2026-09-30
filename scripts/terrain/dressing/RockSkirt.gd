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
	var step := TerrainChunkMesher.STEP
	return func(p: Vector2) -> float:
		var owner := Vector2i(TerrainTileField.point_of(p.x, region), TerrainTileField.point_of(p.y, region))
		var x0 := floorf(p.x / step) * step
		var z0 := floorf(p.y / step) * step
		var fx := p.x / step - x0 / step
		var fz := p.y / step - z0 / step
		var h00 := TerrainTileField.surface_y_on_side(region, x0, z0, owner)
		var h11 := TerrainTileField.surface_y_on_side(region, x0 + step, z0 + step, owner)
		if fx >= fz:
			var h10 := TerrainTileField.surface_y_on_side(region, x0 + step, z0, owner)
			return h00 + fx * (h10 - h00) + fz * (h11 - h10)
		var h01 := TerrainTileField.surface_y_on_side(region, x0, z0 + step, owner)
		return h00 + fz * (h01 - h00) + fx * (h11 - h01)

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
## smooth lattice normal and its bilinear 24 m tint-lattice biome tint.
static func terrain_surface(region: HeightfieldRegion, world_seed: int) -> Dictionary:
	var ground := terrain_ground(region)
	var step := TerrainChunkMesher.STEP
	var tile := TerrainChunkMesher.CELL
	# generate_normals() on the welded 2 m lattice averages its incident faces:
	# a central difference at each node, interpolated across the quad. Welding
	# never joins a cliff's upper and lower quads, so every node is taken on
	# the side of the lattice point owning the point being shaded.
	return {
		"height": ground,
		"normal": func(p: Vector2) -> Vector3:
			var owner := Vector2i(TerrainTileField.point_of(p.x, region), TerrainTileField.point_of(p.y, region))
			var h := func(x: float, z: float) -> float:
				return TerrainTileField.surface_y_on_side(region, x, z, owner)
			var x0 := floorf(p.x / step) * step
			var z0 := floorf(p.y / step) * step
			var fx := (p.x - x0) / step
			var fz := (p.y - z0) / step
			var n := Vector3.ZERO
			for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
				var x := x0 + corner.x * step
				var z := z0 + corner.y * step
				var w := (fx if corner.x > 0 else 1.0 - fx) * (fz if corner.y > 0 else 1.0 - fz)
				n += Vector3(float(h.call(x - step, z)) - float(h.call(x + step, z)), 2.0 * step,
					float(h.call(x, z - step)) - float(h.call(x, z + step))) * w
			return n.normalized(),
		"tint": func(p: Vector2) -> Color:
			var x0 := floorf(p.x / tile) * tile
			var z0 := floorf(p.y / tile) * tile
			var fx := (p.x - x0) / tile
			var fz := (p.y - z0) / tile
			var a := BiomeRegistry.ground_tint_at(Vector3(x0, 0, z0), world_seed).lerp(
				BiomeRegistry.ground_tint_at(Vector3(x0 + tile, 0, z0), world_seed), fx)
			var b := BiomeRegistry.ground_tint_at(Vector3(x0, 0, z0 + tile), world_seed).lerp(
				BiomeRegistry.ground_tint_at(Vector3(x0 + tile, 0, z0 + tile), world_seed), fx)
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
	# The mound meets the rock where it shows: in each direction it rises in
	# proportion to the rock's visible height at that contact. On a slope the
	# uphill contact can lie at or above the rock's top (the rock is buried
	# there); no mound rises over it (September 27 integration: uphill of
	# every slope rock the ground bulged up to 0.45 m over nothing).
	var top: float = float(ground.call(centre)) + exposed
	var rises := PackedFloat32Array()
	for k in SIDES:
		var contact_point := centre + Vector2.from_angle(TAU * k / SIDES) * radii[k]
		rises.append(rise_for(maxf(0.0, top - float(ground.call(contact_point)))))
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
		var s: float = RINGS[j]
		for k in SIDES:
			var p := centre + Vector2.from_angle(TAU * k / SIDES) \
				* (radii[k] * (1.0 + minf(s, 0.0)) + maxf(s, 0.0) * width)
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
## mesh and one collision shape.
static func commit(parent: Node3D, skirts: Array) -> void:
	assert(OS.get_thread_caller_id() == OS.get_main_thread_id())
	if skirts.is_empty():
		return
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var faces := PackedVector3Array()
	for skirt: Dictionary in skirts:
		var base := vertices.size()
		vertices.append_array(skirt.vertices)
		normals.append_array(skirt.normals)
		colors.append_array(skirt.colors)
		for index: int in skirt.indices:
			indices.append(base + index)
			faces.append((skirt.vertices as PackedVector3Array)[index])
	# The terrain-covering triangles; slope-covering ones render in the sheet.
	if indices.is_empty():
		return
	var uvs := PackedVector2Array()
	uvs.resize(vertices.size())
	uvs.fill(CliffDressing.ground_uv())
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
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
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var collision := CollisionShape3D.new()
	collision.name = &"RockSkirts"
	collision.shape = shape
	var body := StaticBody3D.new()
	body.name = &"RockSkirtCollision"
	body.add_child(collision)
	parent.add_child(body)
