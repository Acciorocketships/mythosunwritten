extends RefCounted
## Worker-pure union of authored roof surfaces. Only intersecting pieces are
## converted to triangles; ordinary roofs retain their instanced kit meshes.
## Source UVs/normals/materials survive clipping, and collision uses the exact
## resulting triangles. No renderer resources are loaded on the worker.
const EPS := 0.0001

static func roof_volume(wing: Dictionary, kit: BuildingKit) -> Dictionary:
	var r: Rect2i = wing.rect
	var axis := int(wing.axis)
	var u0 := float(r.position[axis] - int(wing.extend_min)) * kit.module_width - 1.0
	var u1 := float(r.end[axis] + int(wing.extend_max)) * kit.module_width + 1.0
	# A branch clipped at its host's ridge ends there (see KitRoofJunctions).
	if wing.has("clip_min"): u0 = maxf(u0, float(wing.clip_min) * kit.module_width)
	if wing.has("clip_max"): u1 = minf(u1, float(wing.clip_max) * kit.module_width)
	if wing.has("verge_min"): u0 = float(r.position[axis]) * kit.module_width - float(wing.verge_min)
	if wing.has("verge_max"): u1 = float(r.end[axis]) * kit.module_width + float(wing.verge_max)
	var v0 := float(r.position[1 - axis]) * kit.module_width
	var v1 := float(r.end[1 - axis]) * kit.module_width
	var y := float(wing.eave_band) * kit.band_height()
	var rise := kit.roof_row_rise / kit.module_width
	var planes: Array[Plane] = []
	var u := Vector3.RIGHT if axis == 0 else Vector3.BACK
	var v := Vector3.BACK if axis == 0 else Vector3.RIGHT
	planes.append(Plane(u, u1))
	planes.append(Plane(-u, -u0))
	planes.append(Plane(v, v1 + 0.6))
	planes.append(Plane(-v, -v0 + 0.6))
	planes.append(Plane(Vector3.DOWN, -y + 0.2))
	# The authored roof rises 3 m per 2 m row. Its upper skin is 0.12 m
	# above that datum. This clips buried boards without eating the valley.
	var n := Vector3.UP - v * rise
	planes.append(Plane(n.normalized(), (y - v0 * rise + 0.12) / n.length()))
	n = Vector3.UP + v * rise
	planes.append(Plane(n.normalized(), (y + v1 * rise + 0.12) / n.length()))
	var lo := u * u0 + v * (v0 - 0.6) + Vector3.UP * (y - 0.2)
	var hi := u * u1 + v * (v1 + 0.6) + Vector3.UP * (y + (v1 - v0) * rise * 0.5 + 0.12)
	return {"planes": planes, "bounds": AABB(lo, hi - lo)}

## The attic a wing encloses: inside its own walls (the rectangle, not its
## verge overhang or a branch's run into its host), under its skin. Gable
## walls are trimmed only by this: a gable is removed only where another
## building's walls and roof close it in, never under a neighbour's open
## overhang (which left see-through holes).
static func enclosed_volume(wing: Dictionary, kit: BuildingKit) -> Dictionary:
	var r: Rect2i = wing.rect
	var axis := int(wing.axis)
	var w := kit.module_width
	var u0 := float(r.position[axis]) * w
	var u1 := float(r.end[axis]) * w
	var v0 := float(r.position[1 - axis]) * w
	var v1 := float(r.end[1 - axis]) * w
	var y := float(wing.eave_band) * kit.band_height()
	var rise := kit.roof_row_rise / w
	var u := Vector3.RIGHT if axis == 0 else Vector3.BACK
	var v := Vector3.BACK if axis == 0 else Vector3.RIGHT
	var planes: Array[Plane] = [Plane(u, u1), Plane(-u, -u0), Plane(v, v1), Plane(-v, -v0),
		Plane(Vector3.DOWN, -y + 0.2)]
	var n := Vector3.UP - v * rise
	planes.append(Plane(n.normalized(), (y - v0 * rise) / n.length()))
	n = Vector3.UP + v * rise
	planes.append(Plane(n.normalized(), (y + v1 * rise) / n.length()))
	var lo := u * u0 + v * v0 + Vector3.UP * (y - 0.2)
	var hi := u * u1 + v * v1 + Vector3.UP * (y + (v1 - v0) * rise * 0.5)
	return {"planes": planes, "bounds": AABB(lo, hi - lo)}


## Half-spaces beyond a wing's clip planes: its own pieces end there.
static func clip_volumes(wing: Dictionary, kit: BuildingKit) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var axis := int(wing.axis)
	const FAR := 100000.0
	for key: String in ["clip_min", "clip_max", "verge_min", "verge_max", "shed_min", "shed_max"]:
		if not wing.has(key): continue
		var cut_axis := 1-axis if key.begins_with("shed_") else axis
		var at := float(wing[key]) * kit.module_width
		if key.begins_with("verge_"):
			var rect: Rect2i = wing.rect
			at = float(rect.position[axis]) * kit.module_width - float(wing[key]) \
				if key.ends_with("min") else float(rect.end[axis]) * kit.module_width + float(wing[key])
		var lo := Vector3(-FAR, -FAR, -FAR)
		var hi := Vector3(FAR, FAR, FAR)
		if key.ends_with("min"): hi[0 if cut_axis == 0 else 2] = at
		else: lo[0 if cut_axis == 0 else 2] = at
		var volume := box_volume(AABB(lo, hi - lo))
		# Do not recover the local cut from FAR + size: float32 cancellation
		# moves a 0.157 m verge to 0.15625 and slices a flush native cap.
		var plane_index := (0 if cut_axis == 0 else 4) + (0 if key.ends_with("min") else 1)
		var plane: Plane = volume.planes[plane_index]
		plane.d = at if key.ends_with("min") else -at
		volume.planes[plane_index] = plane
		out.append(volume)
	return out


static func box_volume(box: AABB) -> Dictionary:
	return {"bounds": box, "planes": [Plane(Vector3.RIGHT, box.end.x),
		Plane(Vector3.LEFT, -box.position.x), Plane(Vector3.UP, box.end.y),
		Plane(Vector3.DOWN, -box.position.y), Plane(Vector3.BACK, box.end.z),
		Plane(Vector3.FORWARD, -box.position.z)]}

## Shared cutter context for `realize`: roof volumes, wall boxes, bake data.
static func prepare(roofs: Array[Dictionary], walls: Array[Dictionary],
		kit: BuildingKit, roof_kits: Dictionary = {}) -> Dictionary:
	var volumes: Array[Dictionary] = []
	var enclosed: Array[Dictionary] = []
	var clips: Array = []
	var gable_clips: Array = []
	var geometry: Dictionary = {}
	var loaded: Dictionary = {}
	# The base kit also supplies shared details (for example chimneys).
	_load_geometry(kit, geometry, loaded)
	for i in roofs.size():
		var roof: Dictionary = roofs[i]
		var own: BuildingKit = roof_kits.get(i, kit)
		_load_geometry(own, geometry, loaded)
		volumes.append(roof_volume(roof, own))
		enclosed.append(enclosed_volume(roof, own))
		clips.append(clip_volumes(roof, own))
		# Verge fitting shortens the roof skin, never its closing facade.
		# Native relief can stand proud of that plane; cutting it away exposes
		# the inside of the attic. Branch/host clip planes still apply.
		var gable_roof := roof.duplicate()
		gable_roof.erase("verge_min")
		gable_roof.erase("verge_max")
		gable_clips.append(clip_volumes(gable_roof, own))
	return {"data": geometry, "roof_kits": roof_kits,
		"roofs": roofs, "walls": walls, "kit": kit, "volumes": volumes,
		"enclosed": enclosed, "clips": clips, "gable_clips": gable_clips}


static func _load_geometry(kit: BuildingKit, geometry: Dictionary, loaded: Dictionary) -> void:
	var path := kit.roof_geometry_path
	assert(not path.is_empty(), "Roof union requires the kit's baked geometry")
	if not loaded.has(path):
		var file := FileAccess.open(path, FileAccess.READ)
		assert(file != null, "Missing baked roof geometry: " + path)
		geometry.merge(file.get_var(), false)
		loaded[path] = true
	for variant: StringName in kit.geometry_aliases:
		var canonical: StringName = kit.geometry_aliases[variant]
		if geometry.has(canonical): geometry[variant] = geometry[canonical]



## The final surfaces of one roof placement: {} when it stays an instance
## (not a roof piece, or nothing cuts it), else {surfaces, meshes} where each
## mesh is the trimmed triangle soup of the matching baked surface, in the
## placement's (native building) frame.
static func realize(placement: Dictionary, ctx: Dictionary) -> Dictionary:
	# Opt-in cache for a fixed context shared by facade fitting and emission.
	# Ordinary audit contexts stay uncached because their cutters may change.
	var index := int(placement.get("roof_index",-1))
	# Per-placement cuts (for example a newly attached turret) are not part
	# of the shared roof/asset/pose cache key. Never reuse its earlier skin.
	if not ctx.has("realized_cache") or index < 0 or not placement.get("clip_volumes", []).is_empty():
		return _realize(placement,ctx)
	var by_roof: Dictionary = ctx.realized_cache.get(index,{})
	var by_asset: Dictionary = by_roof.get(placement.asset_id,{})
	var pose: Transform3D = placement.transform
	if by_asset.has(pose): return by_asset[pose]
	var result := _realize(placement,ctx)
	by_asset[pose] = result
	by_roof[placement.asset_id] = by_asset
	ctx.realized_cache[index] = by_roof
	return result


static func _realize(placement: Dictionary, ctx: Dictionary) -> Dictionary:
	# A chimney is relocated/omitted as one complete stack before emission;
	# clipping individual courses could leave an open body or floating cap.
	if String(placement.get("role", &"")).begins_with("chimney."):
		return {}
	var roof_index := int(placement.get("roof_index", -1))
	var data: Dictionary = ctx.data
	if roof_index < 0 or not data.has(placement.asset_id):
		return {}
	var kit: BuildingKit = ctx.roof_kits.get(roof_index, ctx.kit)
	var transform: Transform3D = placement.transform
	var surfaces: Array = data[placement.asset_id]
	var bounds := AABB()
	var first := true
	for surface: Dictionary in surfaces:
		for p: Vector3 in transform * (surface.vertices as PackedVector3Array):
			bounds = AABB(p, Vector3.ZERO) if first else bounds.expand(p)
			first = false
	var cutters: Array[Dictionary] = []
	# Roof skins and their trims are trimmed by every other roof's skin
	# volume (valleys, buried boards) and by public headroom; gable walls
	# only where another building encloses them.
	var gable := String(placement.get("role", "")).begins_with("gable.")
	var volumes: Array = ctx.enclosed if gable else ctx.volumes
	for i in volumes.size():
		if i != roof_index and bounds.intersects(volumes[i].bounds): cutters.append(volumes[i])
	cutters.append_array(ctx.gable_clips[roof_index] if gable else ctx.clips[roof_index])
	cutters.append_array(placement.get("clip_volumes",[]))
	var eave := float(ctx.roofs[roof_index].eave_band) * kit.band_height()
	for wall: Dictionary in ctx.walls:
		var open := bool(wall.get("open", false))
		if gable and open: continue
		# Walls cut only roofs they rise above; open walking clearance cuts
		# whatever reaches into it.
		if (open or wall.bounds.end.y > eave + 0.2) and bounds.intersects(wall.bounds):
			cutters.append(wall)
	if cutters.is_empty():
		return {}
	var results: Array[Dictionary] = []
	var changed := false
	for surface: Dictionary in surfaces:
		var mesh := trim_surface(surface, transform, cutters)
		results.append(mesh)
		changed = changed or bool(mesh.changed)
	if not changed:
		return {}
	return {"surfaces": surfaces, "meshes": results}


static func append(placements: Array[Dictionary], roofs: Array[Dictionary],
		walls: Array[Dictionary], kit: BuildingKit, map: Transform3D,
		payload: EnvironmentInstancePayload, roof_kits: Dictionary = {}) -> Dictionary:
	var ctx := prepare(roofs, walls, kit, roof_kits)
	return append_prepared(placements,ctx,map,payload)


static func append_prepared(placements: Array[Dictionary], ctx: Dictionary,
		map: Transform3D, payload: EnvironmentInstancePayload) -> Dictionary:
	var details := fit_chimneys(placements, ctx)
	fit_ridge_contacts(placements, ctx)
	var clipped := 0
	var removed := 0
	for placement: Dictionary in placements:
		var realized := realize(placement, ctx)
		if realized.is_empty():
			BuildingKitAssembler.append_to_payload([placement], map, payload)
			continue
		var surfaces: Array = realized.surfaces
		var results: Array = realized.meshes
		var transform: Transform3D = placement.transform
		clipped += 1
		for surface_index in surfaces.size():
			var surface: Dictionary = surfaces[surface_index]
			# The cached mesh remains in native coordinates for other readers.
			var mesh: Dictionary = (results[surface_index] as Dictionary).duplicate(true)
			if mesh.vertices.is_empty():
				removed += 1
				continue
			var normal_map := map.basis.inverse().transposed()
			for i in mesh.vertices.size():
				mesh.vertices[i] = map * mesh.vertices[i]
				mesh.normals[i] = (normal_map * mesh.normals[i]).normalized()
			mesh.tangents = _tangents(mesh)
			for index: int in mesh.indices: mesh.collision_faces.append(mesh.vertices[index])
			mesh.stable_id = StringName("%s.union.%d.%d" % [placement.stable_id, surface.piece, surface.surface])
			mesh.anchor = map * transform.origin
			mesh.material_asset_id = placement.asset_id
			mesh.material_piece = surface.piece
			mesh.material_surface = surface.surface
			payload.add_surface_mesh(mesh)
	return {"clipped": clipped, "removed": removed, "chimneys": details}


static func fit_ridge_contacts(placements: Array[Dictionary], ctx: Dictionary) -> void:
	# A curved native eave can cover a cap's bearing below the analytic roof
	# plane. End the ornament there, instead of leaving its tip through the eave.
	var eaves: Array[Dictionary] = []
	for part: Dictionary in placements:
		var role := String(part.get("role", ""))
		if role.begins_with("roof.") and role.contains(".eave") and ctx.data.has(part.asset_id):
			eaves.append({"part": part, "bounds": _part_bounds(part, ctx.data)})
	for part: Dictionary in placements:
		if not String(part.get("role", "")).begins_with("trim.ridge") or not ctx.data.has(part.asset_id): continue
		var bounds := _part_bounds(part, ctx.data)
		var cuts: Array[Dictionary] = []
		for eave: Dictionary in eaves:
			if eave.part.roof_index == part.roof_index or not bounds.intersects(eave.bounds): continue
			if not eave.has("meshes"):
				var fitted := realize(eave.part, ctx)
				eave.meshes = fitted.meshes if not fitted.is_empty() else []
				if fitted.is_empty():
					for surface: Dictionary in ctx.data[eave.part.asset_id]:
						eave.meshes.append(trim_surface(surface, eave.part.transform, []))
			for mesh: Dictionary in eave.meshes:
				var eave_kit: BuildingKit = ctx.roof_kits.get(eave.part.roof_index, ctx.kit)
				var rim_top := float(ctx.roofs[eave.part.roof_index].eave_band) * eave_kit.band_height() + 0.2
				cuts.append_array(_ridge_eave_cutters(mesh, bounds, int(ctx.roofs[part.roof_index].axis), rim_top))
		if not cuts.is_empty():
			var existing: Array = part.get("clip_volumes", []).duplicate()
			existing.append_array(cuts)
			part.clip_volumes = existing


static func _part_bounds(part: Dictionary, data: Dictionary) -> AABB:
	var bounds := AABB()
	var first := true
	for surface: Dictionary in data[part.asset_id]:
		for point: Vector3 in part.transform * (surface.vertices as PackedVector3Array):
			bounds = AABB(point, Vector3.ZERO) if first else bounds.expand(point)
			first = false
	return bounds


static func _ridge_eave_cutters(mesh: Dictionary, cap: AABB, ridge_axis: int = -1,
		rim_top: float = INF) -> Array[Dictionary]:
	var cuts: Array[Dictionary] = []
	# Higher roof junctions are handled by the ordinary solid union. A cap
	# admitted at the low rim must still end through the entire covering pitch.
	if cap.position.y > rim_top: return cuts
	for t in range(0, mesh.indices.size(), 3):
		var polygon: Array = []
		var normal := Vector3.ZERO
		for k in 3:
			var i: int = mesh.indices[t+k]
			normal += mesh.normals[i]
			polygon.append({"p": mesh.vertices[i], "n": mesh.normals[i], "uv": mesh.uvs[i]})
		if normal.y <= EPS: continue
		polygon = split(polygon, Plane(Vector3.UP, cap.position.y + EPS), false)
		# Only the contact over this ornament contributes to its termination.
		for axis in [0, 2]:
			var direction := Vector3.ZERO
			direction[axis] = 1.0
			polygon = split(polygon, Plane(direction, cap.end[axis]), true)
			polygon = split(polygon, Plane(-direction, -cap.position[axis]), true)
		if polygon.size() < 3: continue
		var projected_area := 0.0
		for i in polygon.size():
			var a: Vector3 = polygon[i].p
			var b: Vector3 = polygon[(i+1)%polygon.size()].p
			projected_area += a.x*b.z - b.x*a.z
		if absf(projected_area) < EPS * EPS: continue
		var center := Vector3.ZERO
		for vertex: Dictionary in polygon: center += vertex.p
		center /= polygon.size()
		var planes: Array[Plane] = [Plane(Vector3.UP, cap.end.y + EPS * 4.0),
			Plane(Vector3.DOWN, -cap.position.y + EPS * 4.0)]
		var bounds := AABB(Vector3(center.x, cap.position.y, center.z), Vector3(0, cap.size.y, 0))
		for i in polygon.size():
			var a: Vector3 = polygon[i].p
			var b: Vector3 = polygon[(i+1)%polygon.size()].p
			var n := Vector3(b.z-a.z, 0, a.x-b.x)
			if n.length_squared() < EPS * EPS: continue
			n = n.normalized()
			var plane := Plane(n, n.dot(a))
			if plane.distance_to(center) > 0: plane = Plane(-n, -n.dot(a))
			planes.append(plane)
			bounds = bounds.expand(Vector3(a.x, cap.position.y, a.z))
			bounds = bounds.expand(Vector3(a.x, cap.end.y, a.z))
		if planes.size() >= 5 and bounds.size.x > EPS and bounds.size.z > EPS and bounds.intersects(cap):
			if ridge_axis >= 0:
				# The cap is one ornament across its width. Cutting each flute
				# separately leaves detached tips beside the covering eave.
				var cross_axis := 2 if ridge_axis == 0 else 0
				bounds.position[cross_axis] = cap.position[cross_axis]
				bounds.size[cross_axis] = cap.size[cross_axis]
				bounds = bounds.grow(EPS * 4.0)
				planes.clear()
				for axis in 3:
					var direction := Vector3.ZERO
					direction[axis] = 1.0
					planes.append(Plane(direction, bounds.end[axis]))
					planes.append(Plane(-direction, -bounds.position[axis]))
			cuts.append({"planes": planes, "bounds": bounds.grow(EPS * 4.0)})
	return cuts


static func fit_chimneys(placements: Array[Dictionary], ctx: Dictionary) -> Dictionary:
	## Measured rigid stacks keep their complete render/collision instances.
	## Try the nearest clear ridge position before omitting a crowded stack.
	var groups: Dictionary = {}
	for placement: Dictionary in placements:
		if not String(placement.get("role", &"")).begins_with("chimney."):
			continue
		var index := int(placement.get("roof_index", -1))
		if index < 0: continue
		if not groups.has(index): groups[index] = []
		groups[index].append(placement)
	var removed: Dictionary = {}
	var moved := 0
	var omitted := 0
	for index: int in groups:
		var kit: BuildingKit = ctx.roof_kits.get(index, ctx.kit)
		var stack: Array = groups[index]
		var wing: Dictionary = ctx.roofs[index]
		var axis := int(wing.axis)
		var rect: Rect2i = wing.rect
		var original := float((stack[0].transform as Transform3D).origin[axis * 2]) / kit.module_width
		var positions: Array[float] = [original]
		for u in range(rect.position[axis] + 1, rect.end[axis]):
			if is_equal_approx(float(u),original): continue
			positions.append(float(u))
		positions.sort_custom(func(a: float,b: float) -> bool:
			return absf(a-original) < absf(b-original) if not is_equal_approx(absf(a-original),absf(b-original)) else a < b)
		var found := false
		for u: float in positions:
			if u < float(wing.get("clip_min",-INF)) + 0.5 \
					or u > float(wing.get("clip_max",INF)) - 0.5:
				continue
			var offset := Vector3.RIGHT * (u-original) * kit.module_width if axis == 0 \
				else Vector3.BACK * (u-original) * kit.module_width
			if not _chimney_is_clear(stack,offset,ctx): continue
			for placement: Dictionary in stack:
				var pose: Transform3D = placement.transform
				pose.origin += offset
				placement.transform = pose
			wing.chimney_u = u
			moved += int(not is_equal_approx(u,original))
			found = true
			break
		if found: continue
		wing.chimney = false
		omitted += 1
		for placement: Dictionary in stack: removed[placement.stable_id] = true
	if not removed.is_empty():
		placements.assign(placements.filter(func(p: Dictionary) -> bool: return not removed.has(p.stable_id)))
	return {"moved":moved,"omitted":omitted,"checked":groups.size()}


static func _chimney_is_clear(stack: Array, offset: Vector3, ctx: Dictionary) -> bool:
	for placement: Dictionary in stack:
		assert(ctx.data.has(placement.asset_id), "Bake measured roof-detail geometry for this kit")
		var pose: Transform3D = placement.transform
		pose.origin += offset
		for surface: Dictionary in ctx.data[placement.asset_id]:
			var bounds := AABB(pose * surface.vertices[0],Vector3.ZERO)
			for vertex: Vector3 in surface.vertices: bounds = bounds.expand(pose * vertex)
			var cuts: Array[Dictionary] = []
			for volume: Dictionary in ctx.walls:
				if bool(volume.get("open",false)) and bounds.intersects(volume.bounds): cuts.append(volume)
			if not cuts.is_empty() and bool(trim_surface(surface,pose,cuts).changed): return false
	return true

static func trim_surface(surface: Dictionary, transform: Transform3D,
		cutters: Array[Dictionary]) -> Dictionary:
	var out := {"vertices": PackedVector3Array(), "normals": PackedVector3Array(),
		"uvs": PackedVector2Array(), "indices": PackedInt32Array(),
		"collision_faces": PackedVector3Array(), "changed": false}
	var normal_map := transform.basis.inverse().transposed()
	var ids: PackedInt32Array = surface.indices
	# Indexed triangles share corners. Transform each source corner once;
	# clipping only creates new dictionaries and never mutates these records.
	var transformed: Array[Dictionary] = []
	var positions: PackedVector3Array = transform * (surface.vertices as PackedVector3Array)
	for i in positions.size():
		transformed.append({"p":positions[i],
			"n":(normal_map * surface.normals[i]).normalized(),"uv":surface.uvs[i]})
	for t in range(0, ids.size(), 3):
		var polygon: Array = []
		for k in 3:
			polygon.append(transformed[ids[t+k]])
		var pieces: Array = [polygon]
		var triangle_changed := false
		# Every fragment remains inside its original triangle's box. Reject
		# distant cutters before allocating fragment arrays; ordinary roof
		# volumes still need the separating-plane proof below.
		var triangle_bounds := AABB()
		if not cutters.is_empty():
			triangle_bounds = AABB(polygon[0].p, Vector3.ZERO)
			for vertex: Dictionary in polygon: triangle_bounds = triangle_bounds.expand(vertex.p)
			triangle_bounds = triangle_bounds.grow(EPS * 4.0)
		for cutter: Dictionary in cutters:
			if cutter.has("bounds") and not triangle_bounds.intersects(cutter.bounds):
				if cutters.size() > 16: continue
				# Preserve the clipper's exact triangulation: a disjoint box alone
				# need not imply one separating plane of a sloped roof volume.
				var separated := false
				for plane: Plane in cutter.planes:
					if plane.distance_to(polygon[0].p) >= -EPS and plane.distance_to(polygon[1].p) >= -EPS and plane.distance_to(polygon[2].p) >= -EPS:
						separated = true
						break
				if separated: continue
			var remaining: Array = []
			for piece: Array in pieces:
				var fragments := subtract(piece, cutter.planes)
				if fragments.size() != 1 or not is_same(fragments[0], piece):
					out.changed = true
					triangle_changed = true
				remaining.append_array(fragments)
			pieces = remaining
			if pieces.is_empty(): break
		for piece: Array in pieces:
			for k in range(1, piece.size() - 1):
				var triangle: Array = [piece[0], piece[k], piece[k + 1]]
				var ab: Vector3 = triangle[1].p - triangle[0].p
				var ac: Vector3 = triangle[2].p - triangle[0].p
				var bc: Vector3 = triangle[2].p - triangle[1].p
				var cross_squared := ab.cross(ac).length_squared()
				if cross_squared < 1e-12: continue
				# A long numerical strip can pass an area-only degeneracy test,
				# then act as an invisible fence in concave collision. Its minimum
				# altitude must exceed the precision of the clipping operation.
				# Apply this only to generated fragments, preserving authored detail.
				var edge_squared := maxf(ab.length_squared(),maxf(ac.length_squared(),bc.length_squared()))
				if triangle_changed and cross_squared <= EPS*EPS*edge_squared: continue
				for vertex: Dictionary in triangle:
					out.indices.append(out.vertices.size())
					out.vertices.append(vertex.p)
					out.normals.append(vertex.n)
					out.uvs.append(vertex.uv)
	return out

## Disjoint outside fragments of a polygon minus one convex volume.
static func subtract(polygon: Array, planes: Array) -> Array:
	var entirely_inside := true
	for plane: Plane in planes:
		var entirely_outside := true
		for vertex: Dictionary in polygon:
			var distance := plane.distance_to(vertex.p)
			if distance < -EPS: entirely_outside = false
			if distance > 0.0: entirely_inside = false
		if entirely_outside: return [polygon]
	# All vertices inside a convex volume imply the whole polygon is inside.
	# Keep the outside/tolerance checks first, including coplanar faces.
	if entirely_inside: return []
	var outside: Array = []
	var inside := polygon
	for plane: Plane in planes:
		var keep := split(inside, plane, false)
		if keep.size() >= 3: outside.append(keep)
		inside = split(inside, plane, true)
		if inside.size() < 3: break
	return outside

static func split(polygon: Array, plane: Plane, negative: bool) -> Array:
	var out: Array = []
	if polygon.is_empty(): return out
	var previous: Dictionary = polygon.back()
	var pd := plane.distance_to(previous.p)
	for current: Dictionary in polygon:
		var cd := plane.distance_to(current.p)
		var pin := pd <= 0.0 if negative else pd >= 0.0
		var cin := cd <= 0.0 if negative else cd >= 0.0
		if pin != cin:
			var t := pd / (pd - cd)
			out.append({"p": previous.p.lerp(current.p, t),
				"n": previous.n.lerp(current.n, t).normalized(), "uv": previous.uv.lerp(current.uv, t)})
		if cin: out.append(current)
		previous = current
		pd = cd
	return out


## Reconstruct UV tangents after clipping/affine mapping so normal-mapped wood
## retains its board detail. The output is deindexed, so each corner has the
## exact tangent of its source UV triangle, orthogonalized to its smooth normal.
static func _tangents(mesh: Dictionary) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(mesh.vertices.size() * 4)
	for i in range(0, mesh.indices.size(), 3):
		var a: int = mesh.indices[i]
		var b: int = mesh.indices[i + 1]
		var c: int = mesh.indices[i + 2]
		var e1: Vector3 = mesh.vertices[b] - mesh.vertices[a]
		var e2: Vector3 = mesh.vertices[c] - mesh.vertices[a]
		var d1: Vector2 = mesh.uvs[b] - mesh.uvs[a]
		var d2: Vector2 = mesh.uvs[c] - mesh.uvs[a]
		var determinant := d1.x * d2.y - d1.y * d2.x
		var tangent := e1
		var bitangent := e2
		if absf(determinant) > 0.0000001:
			tangent = (e1 * d2.y - e2 * d1.y) / determinant
			bitangent = (e2 * d1.x - e1 * d2.x) / determinant
		for index: int in [a, b, c]:
			var normal: Vector3 = mesh.normals[index]
			var t := (tangent - normal * tangent.dot(normal)).normalized()
			if t.length_squared() < 0.5:
				t = normal.cross(Vector3.UP).normalized()
				if t.length_squared() < 0.5: t = normal.cross(Vector3.RIGHT).normalized()
			out[index * 4] = t.x
			out[index * 4 + 1] = t.y
			out[index * 4 + 2] = t.z
			out[index * 4 + 3] = -1.0 if normal.cross(t).dot(bitangent) < 0.0 else 1.0
	return out
