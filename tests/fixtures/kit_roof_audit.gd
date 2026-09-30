extends RefCounted
## Geometric roof invariants of a kit-built town, measured on the realized
## (union-trimmed) roof pieces in the native kit frame. Input: the dictionary
## returned by `KitVillageBuildings.build`.
##   tiny          roof wings one module deep (a lone ridge-top row)
##   tiny_beside   ... of them sharing an edge with a deeper roof within two
##                 bands: the "tiny roof at the edge of a big roof"
##   open_exposed  open (joined) wing ends whose end section is not buried in
##                 another roof or building: a see-through "mini gable"
##   gable_holes   closed gable ends with visible holes: parts of the gable
##                 triangle carry no gable geometry although nothing encloses
##                 them (a trimmed or missing side panel)
##   eaves_cut     eave pieces that walking clearance strips of more than
##                 half their overhang (the see-through slot under a roof)
##   air_roofs     roofs sheltering cells no storey (of any building) fills
##                 below the eave
##   air_unsupported ... of them with a free corner of that air (a vertex no
##                 wall touches) carrying no timber post up to the eave
const UNION := preload("res://scripts/terrain/features/villages/kit/KitRoofMeshUnion.gd")
const STEP := 0.4
const MARGIN := 0.35


static func audit(built: Dictionary, kit: BuildingKit) -> Dictionary:
	var roofs: Array = built.roofs
	var ctx := UNION.prepare(roofs, built.walls, kit)
	var by_roof: Dictionary = {}
	for placement: Dictionary in built.placements:
		var index := int(placement.get("roof_index", -1))
		if index < 0: continue
		if not by_roof.has(index): by_roof[index] = []
		(by_roof[index] as Array).append(placement)
	var owner: Dictionary = {}
	for mass: BuildingMass in built.masses:
		for roof: Dictionary in mass.roofs: owner[int(roof.union_index)] = mass.stable_id
	var out := {"roofs": roofs.size(), "tiny": 0, "tiny_beside": 0, "open_ends": 0, "open_exposed": 0,
		"gable_ends": 0, "gable_holes": 0, "air_roofs": 0, "air_unsupported": 0, "eaves_cut": 0, "examples": []}
	# Walking clearance alone (no other roofs, no solid walls).
	var open_ctx := ctx.duplicate()
	var none: Array[Dictionary] = []
	for i in roofs.size(): none.append({"planes": [], "bounds": AABB(Vector3.ONE * -1e6, Vector3.ZERO)})
	open_ctx.volumes = none
	open_ctx.enclosed = none
	open_ctx.clips = none.map(func(_v: Dictionary) -> Array: return [])
	open_ctx.walls = (built.walls as Array).filter(func(w: Dictionary) -> bool: return bool(w.get("open", false)))
	for placement: Dictionary in built.placements:
		if int(placement.get("roof_index", -1)) < 0 or not String(placement.role).contains(".eave"): continue
		var realized := UNION.realize(placement, open_ctx)
		if realized.is_empty(): continue
		var t: Transform3D = placement.transform
		var raw := 0.0
		for surface: Dictionary in ctx.data[placement.asset_id]:
			var soup := PackedVector3Array()
			for i: int in surface.indices: soup.append(t * surface.vertices[i])
			raw += _overhang_area(soup, t)
		var kept := 0.0
		for mesh: Dictionary in realized.meshes:
			var soup := PackedVector3Array()
			for i: int in mesh.indices: soup.append(mesh.vertices[i])
			kept += _overhang_area(soup, t)
		if raw > 0.01 and kept < raw * 0.5:
			out.eaves_cut += 1
			(out.examples as Array).append("eave_cut %s at %s" % [placement.stable_id, t.origin])
	var posts: Dictionary = {}
	for placement: Dictionary in built.placements:
		if placement.role != &"post.timber": continue
		var t: Transform3D = placement.transform
		var key := Vector2i(roundi(t.origin.x / kit.module_width), roundi(t.origin.z / kit.module_width))
		if Vector2(t.origin.x, t.origin.z).distance_to(Vector2(key) * kit.module_width) > 0.3: continue
		posts[key] = maxf(float(posts.get(key, -INF)), t.origin.y + t.basis.y.length())
	var solid_at: Dictionary = {}
	for i in roofs.size():
		var roof: Dictionary = roofs[i]
		var r: Rect2i = roof.rect
		var axis := int(roof.axis)
		var tag := "%s %s axis=%d eave=%d" % [owner.get(i, "?"), r, axis, int(roof.eave_band)]
		if r.size[1 - axis] < 2:
			out.tiny += 1
			var beside := false
			for other: Dictionary in roofs:
				var o: Rect2i = other.rect
				if absi(int(other.eave_band) - int(roof.eave_band)) > 2: continue
				if o.size[1 - int(other.axis)] < 2 or not o.grow(1).intersects(r): continue
				var dx := maxi(o.position.x, r.position.x) - mini(o.end.x, r.end.x)
				var dy := maxi(o.position.y, r.position.y) - mini(o.end.y, r.end.y)
				beside = beside or not (dx >= 0 and dy >= 0)
			if beside: out.tiny_beside += 1
			(out.examples as Array).append(("tiny_beside " if beside else "tiny ") + tag)
		var free := _free_vertices(roof, built.masses, solid_at)
		if not free.is_empty():
			out.air_roofs += 1
			var eave_y := float(int(roof.eave_band)) * kit.band_height()
			var missing := 0
			for vertex: Vector2i in free:
				if float(posts.get(vertex, -INF)) < eave_y - 0.4: missing += 1
			if missing > 0:
				out.air_unsupported += 1
				(out.examples as Array).append("air_unsupported posts=%d/%d %s" % [missing, free.size(), tag])
		for end in 2:
			if bool(roof["open_min" if end == 0 else "open_max"]):
				out.open_ends += 1
				var exposed := _open_exposed(roof, end, i, ctx)
				if exposed > 0:
					out.open_exposed += 1
					(out.examples as Array).append("open_exposed end=%d samples=%d %s" % [end, exposed, tag])
			else:
				out.gable_ends += 1
				var holes := _gable_holes(roof, end, i, by_roof.get(i, []), ctx)
				if holes > 1:
					out.gable_holes += 1
					(out.examples as Array).append("gable_hole end=%d samples=%d %s" % [end, holes, tag])
	return out


## Area of the triangles of `soup` lying outside the wall line of the eave
## piece placed at `t` (its native +Z points out of the wall).
static func _overhang_area(soup: PackedVector3Array, t: Transform3D) -> float:
	var inverse := t.affine_inverse()
	var area := 0.0
	for k in range(0, soup.size(), 3):
		var a := soup[k]
		var b := soup[k + 1]
		var c := soup[k + 2]
		if (inverse * ((a + b + c) / 3.0)).z > 0.05:
			area += (b - a).cross(c - a).length() * 0.5
	return area


## Vertices of the air a roof shelters (its cells no building fills in the
## band below the eave) that no such building cell touches.
static func _free_vertices(roof: Dictionary, masses: Array, solid_at: Dictionary) -> Array[Vector2i]:
	var band := int(roof.eave_band) - 1
	if not solid_at.has(band):
		var cells: Dictionary = {}
		for mass: BuildingMass in masses: cells.merge(mass.cells_at_band(band))
		solid_at[band] = cells
	var solid: Dictionary = solid_at[band]
	var seen: Dictionary = {}
	var out: Array[Vector2i] = []
	for cell: Vector2i in BuildingMass.rect_cells(roof.rect):
		if solid.has(cell): continue
		for corner: Vector2i in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.ONE, Vector2i.DOWN]:
			var vertex := cell + corner
			if seen.has(vertex): continue
			seen[vertex] = true
			var walled := false
			for near: Vector2i in [vertex, vertex - Vector2i.RIGHT, vertex - Vector2i.DOWN, vertex - Vector2i.ONE]:
				walled = walled or solid.has(near)
			if not walled: out.append(vertex)
	return out


static func _frame(roof: Dictionary, kit: BuildingKit) -> Dictionary:
	var r: Rect2i = roof.rect
	var axis := int(roof.axis)
	var w := kit.module_width
	var depth := r.size[1 - axis]
	return {"axis": axis, "u0": float(r.position[axis]) * w, "u1": float(r.end[axis]) * w,
		"v0": float(r.position[1 - axis]) * w, "v1": float(r.end[1 - axis]) * w,
		"eave": float(int(roof.eave_band)) * kit.band_height(),
		"rise": kit.roof_row_rise / w, "height": float(kit.roof_profile(depth).height)}


static func _point(f: Dictionary, u: float, v: float, y: float) -> Vector3:
	return Vector3(u, y, v) if int(f.axis) == 0 else Vector3(v, y, u)


## (v, y) samples strictly inside a roof's section triangle.
static func _section(f: Dictionary) -> Array[Vector2]:
	var out: Array[Vector2] = []
	# Odd offsets keep samples off module and band boundaries.
	var v := float(f.v0) + MARGIN + 0.017
	while v <= float(f.v1) - MARGIN:
		var top := float(f.eave) + minf(float(f.rise) * minf(v - float(f.v0), float(f.v1) - v), float(f.height))
		var y := float(f.eave) + 0.313
		while y <= top - MARGIN:
			out.append(Vector2(v, y))
			y += STEP
		v += STEP
	return out


static func _inside(volume: Dictionary, p: Vector3) -> bool:
	for plane: Plane in volume.planes:
		if plane.distance_to(p) > -0.01: return false
	return true


static func _buried(p: Vector3, own: int, ctx: Dictionary, skins: bool) -> bool:
	var roofs: Array = ctx.roofs
	for j in roofs.size():
		if j == own: continue
		if _inside(ctx.volumes[j] if skins else _enclosed(roofs[j], ctx.kit), p): return true
	for wall: Dictionary in ctx.walls:
		# Public headroom is open air: it hides nothing.
		if not bool(wall.get("open", false)) and _inside(wall, p): return true
	return false


## The attic a roof encloses: inside its walls' footprint, under its skin.
static func _enclosed(roof: Dictionary, kit: BuildingKit) -> Dictionary:
	var f := _frame(roof, kit)
	var axis := int(f.axis)
	var u := Vector3.RIGHT if axis == 0 else Vector3.BACK
	var v := Vector3.BACK if axis == 0 else Vector3.RIGHT
	var rise := float(f.rise)
	var planes: Array[Plane] = [Plane(u, float(f.u1)), Plane(-u, -float(f.u0)),
		Plane(v, float(f.v1)), Plane(-v, -float(f.v0)),
		Plane(Vector3.DOWN, -float(f.eave) + 0.2)]
	var n := (Vector3.UP - v * rise)
	planes.append(Plane(n.normalized(), (float(f.eave) - float(f.v0) * rise) / n.length()))
	n = Vector3.UP + v * rise
	planes.append(Plane(n.normalized(), (float(f.eave) + float(f.v1) * rise) / n.length()))
	return {"planes": planes}


static func _open_exposed(roof: Dictionary, end: int, index: int, ctx: Dictionary) -> int:
	var kit: BuildingKit = ctx.kit
	var f := _frame(roof, kit)
	var w := kit.module_width
	var r: Rect2i = roof.rect
	var axis := int(roof.axis)
	var u: float
	if end == 1:
		u = (float(r.end[axis] + int(roof.extend_max)) + 0.5) * w
		if roof.has("clip_max"): u = minf(u, float(roof.clip_max) * w)
		u -= 0.05
	else:
		u = (float(r.position[axis] - int(roof.extend_min)) - 0.5) * w
		if roof.has("clip_min"): u = maxf(u, float(roof.clip_min) * w)
		u += 0.05
	var exposed := 0
	for s: Vector2 in _section(f):
		if not _buried(_point(f, u, s.x, s.y), index, ctx, true): exposed += 1
	return exposed


static func _gable_holes(roof: Dictionary, end: int, index: int, pieces: Array,
		ctx: Dictionary) -> int:
	var kit: BuildingKit = ctx.kit
	var f := _frame(roof, kit)
	var axis := int(f.axis)
	var u_g := float(f.u1) if end == 1 else float(f.u0)
	var triangles: Array[PackedVector2Array] = []
	for placement: Dictionary in pieces:
		if not String(placement.role).begins_with("gable."): continue
		var origin: Vector3 = (placement.transform as Transform3D).origin
		if absf((origin.x if axis == 0 else origin.z) - u_g) > 0.1: continue
		# Triangle soups with their smooth normals, in the native frame.
		var soups: Array = []
		var realized := UNION.realize(placement, ctx)
		var t: Transform3D = placement.transform
		var normal_map := t.basis.inverse().transposed()
		if realized.is_empty():
			for surface: Dictionary in ctx.data[placement.asset_id]:
				var vertices := PackedVector3Array()
				var normals := PackedVector3Array()
				for i: int in surface.indices:
					vertices.append(t * surface.vertices[i])
					normals.append((normal_map * surface.normals[i]).normalized())
				soups.append([vertices, normals])
		else:
			for mesh: Dictionary in realized.meshes:
				var vertices := PackedVector3Array()
				var normals := PackedVector3Array()
				for i: int in mesh.indices:
					vertices.append(mesh.vertices[i])
					normals.append(mesh.normals[i])
				soups.append([vertices, normals])
		# Only outward-facing triangles close the gable: with its outer face
		# trimmed away a panel shows its inside (back faces) and rafters.
		var outward := Vector3.ZERO
		outward[0 if axis == 0 else 2] = 1.0 if end == 1 else -1.0
		for soup: Array in soups:
			var vertices: PackedVector3Array = soup[0]
			var normals: PackedVector3Array = soup[1]
			for k0 in range(0, vertices.size(), 3):
				if (normals[k0] + normals[k0 + 1] + normals[k0 + 2]).dot(outward) < 0.6: continue
				var tri := PackedVector2Array()
				var near := true
				for k in 3:
					var p := vertices[k0 + k]
					near = near and absf((p.x if axis == 0 else p.z) - u_g) < 0.7
					tri.append(Vector2(p.z if axis == 0 else p.x, p.y))
				if near: triangles.append(tri)
	var holes := 0
	for s: Vector2 in _section(f):
		var covered := false
		for tri: PackedVector2Array in triangles:
			if Geometry2D.point_is_inside_triangle(s, tri[0], tri[1], tri[2]):
				covered = true
				break
		if covered: continue
		var probe := 0.05 if end == 1 else -0.05
		if _buried(_point(f, u_g + probe, s.x, s.y), index, ctx, false) \
				or _buried(_point(f, u_g - probe, s.x, s.y), index, ctx, false):
			continue
		holes += 1
	return holes


## Joins and assembles free-standing masses the way `KitVillageBuildings`
## does (without a warren grid): the same `build` dictionary shape.
static func assemble(masses: Array[BuildingMass], kit: BuildingKit) -> Dictionary:
	preload("res://scripts/terrain/features/villages/kit/KitRoofJunctions.gd").join(masses)
	var roofs: Array[Dictionary] = []
	var walls: Array[Dictionary] = []
	var placements: Array[Dictionary] = []
	for mass: BuildingMass in masses:
		for roof: Dictionary in mass.roofs:
			roof.union_index = roofs.size()
			roofs.append(roof)
		for storey: Dictionary in mass.storeys:
			for rect: Rect2i in BuildingDesigner.decompose(storey.cells):
				walls.append(UNION.box_volume(AABB(Vector3(rect.position.x * kit.module_width,
					storey.floor_band * kit.band_height(), rect.position.y * kit.module_width),
					Vector3(rect.size.x * kit.module_width, int(storey.get("bands", 2)) * kit.band_height(),
					rect.size.y * kit.module_width))))
	for mass: BuildingMass in masses:
		placements.append_array(BuildingKitAssembler.new(kit).assemble(mass))
	return {"masses": masses, "roofs": roofs, "walls": walls, "placements": placements}
