extends RefCounted
## Measured Pure Village tower grammar, in native kit metres.
## A half tower is an attachment: its open rear MUST be backed by its host
## through host_height(). A corbel also needs that host below the first floor.
## This describes geometry; the town planner still owns support and clearance.

enum Form { ROUND, GROUNDED_HALF, CORBELLED_HALF, CORBELLED_ROUND }
const COURSE := 3.0
const ROOF_LAP := 0.5
const PREFIX := "pure_village.tower."
const ROOF_GEOMETRY := "res://terrain/environment/geometry/pure_village_tower_roof.bin"
const ROOF_CORE := "res://terrain/environment/geometry/pure_village_tower_core.bin"


static func asset_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for form: Form in [Form.ROUND, Form.GROUNDED_HALF, Form.CORBELLED_HALF]:
		for part: Dictionary in parts(4, form):
			if not out.has(part.asset_id): out.append(part.asset_id)
	for suffix: String in ["middle","window","roof"]:
		out.append(StringName("pure_village.roof_turret."+suffix))
	out.append(&"pure_village.roof_turret.support")
	for prefix: String in ["pure_village.tower.roof", "pure_village.roof_turret.roof"]:
		for suffix: String in ["wood_red", "wood_blue", "sage"]:
			out.append(StringName(prefix + "." + suffix))
	return out


## A tower-attached roof seats over the complete native gable frame, not
## merely the nominal plaster plane. Pure Village's timber relief is deeper.
static func gable_reach(kit: BuildingKit, catalog: EnvironmentCatalog) -> float:
	var reach := kit.wall_face
	for role: StringName in [&"gable.left", &"gable.right", &"gable.small", &"gable.plain"]:
		if not kit.has_role(role): continue
		var anchor: Transform3D = kit.anchors.get(role, Transform3D.IDENTITY)
		for id: StringName in kit.roles[role]:
			var descriptor := catalog.descriptor(id)
			assert(descriptor != null)
			reach = maxf(reach, (anchor * descriptor.measured_aabb).end.z)
	return reach + 0.01


static func placed_cutters(local: Array, pose: Transform3D) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for cutter: Dictionary in local:
		var planes: Array[Plane] = []
		for plane: Plane in cutter.planes: planes.append(pose * plane)
		out.append({"planes": planes, "bounds": pose * (cutter.bounds as AABB)})
	return out


## The cap is a leaning, curved native mesh, not a straight mathematical cone.
## Each projected source triangle bounds a vertical prism under its own skin.
## Their union is the exact upper envelope of the authored roof. This avoids
## convex-hull cuts across its concave taper and preserves the original asset.
## Cut only above the cap's base; the shaft/backing governs the lower junction.
static func roof_cutters(surfaces: Array, pose: Transform3D) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for surface: Dictionary in surfaces:
		var vertices: PackedVector3Array = surface.vertices
		var indices: PackedInt32Array = surface.indices
		for i in range(0, indices.size(), 3):
			var a := vertices[indices[i]]
			var b := vertices[indices[i + 1]]
			var c := vertices[indices[i + 2]]
			var normal := (b - a).cross(c - a)
			if absf(normal.y) < 0.000001: continue
			if normal.y < 0.0: normal = -normal
			normal = normal.normalized()
			var planes: Array[Plane] = [Plane(normal, normal.dot(a)), Plane(Vector3.DOWN, 0.0)]
			var centre := (a + b + c) / 3.0
			var triangle := [a, b, c]
			for j in 3:
				var p: Vector3 = triangle[j]
				var q: Vector3 = triangle[(j + 1) % 3]
				var side := Vector3(q.z - p.z, 0, p.x - q.x).normalized()
				if side.dot(centre - p) > 0: side = -side
				planes.append(Plane(side, side.dot(p)))
			var box := AABB(Vector3(a.x, 0, a.z), Vector3.ZERO)
			for p: Vector3 in triangle: box = box.expand(p).expand(Vector3(p.x, 0, p.z))
			var mapped: Array[Plane] = []
			for plane: Plane in planes: mapped.append(pose * plane)
			out.append({"planes": mapped, "bounds": pose * box})
	return out


static func parts(storeys: int, form: Form) -> Array[Dictionary]:
	assert(storeys <= 4 and (storeys >= 2 or storeys == 1 and form == Form.CORBELLED_HALF))
	var out: Array[Dictionary] = []
	if form == Form.CORBELLED_HALF:
		out.append(_part("half_support", 0.0))
	for floor_index in storeys:
		var y := float(floor_index) * COURSE
		var suffix := "window"
		if floor_index == 0 and form != Form.CORBELLED_HALF:
			suffix = "base" if form == Form.ROUND else "half_base"
			# Source half-base origin differs from the full-round base.
			if form == Form.GROUNDED_HALF: y += 0.125
		elif form != Form.ROUND and floor_index < storeys - 1:
			suffix = "half_window"
		out.append(_part(suffix, y))
	# Native roof overlaps the final stone course by half a metre.
	out.append(_part("roof", float(storeys) * COURSE - ROOF_LAP))
	return out


static func _part(suffix: String, y: float) -> Dictionary:
	return {"asset_id": StringName(PREFIX + suffix),
		"role": StringName("tower." + suffix),
		"transform": Transform3D(Basis.IDENTITY, Vector3(0, y, 0))}


static func host_height(storeys: int, form: Form) -> float:
	return 0.0 if form == Form.ROUND else float(storeys - 1) * COURSE


static func bounds(assembly: Array[Dictionary], catalog: EnvironmentCatalog) -> AABB:
	var result := AABB()
	var first := true
	for part: Dictionary in assembly:
		var descriptor := catalog.descriptor(part.asset_id)
		assert(descriptor != null, "Tower modules must be baked before placement.")
		var box: AABB = part.transform * descriptor.measured_aabb
		result = box if first else result.merge(box)
		first = false
	return result


## Prove one proposed attachment before changing a host's walls or roofs.
## Pose is native-metre space. `blocked` includes public air and other owners;
## `bearing` proves the actual ground/structure beneath a grounded base.
## Return an empty record on failure; no partial tower may be emitted.
## This is attachment admission, not final roof acceptance: a surviving
## candidate still needs native roof junctions and gable-opening arbitration.
static func fit(host: BuildingMass, kit: BuildingKit, catalog: EnvironmentCatalog,
		pose: Transform3D, storeys: int, form: Form,
		blocked: Callable, bearing: Callable = Callable(),
		assembly_override: Array[Dictionary] = [], audit: Dictionary = {}) -> Dictionary:
	var assembly := parts(storeys, form) if assembly_override.is_empty() else assembly_override
	var local_bounds := bounds(assembly, catalog)
	var world_bounds := pose * local_bounds
	var base_band := roundi(pose.origin.y / kit.band_height())
	if not is_equal_approx(float(base_band) * kit.band_height(), pose.origin.y): return {}
	if form == Form.CORBELLED_ROUND:
		if not _corbel_corner_supported(host,kit,pose,storeys): return {}
	elif form != Form.ROUND:
		# The host must carry the rear half of the round transition, as well
		# as close the lower half tower. A single paper-thin wall is not enough.
		var low := -1.5 if form == Form.CORBELLED_HALF else 0.0
		var host_box := pose * AABB(Vector3(-1.71, low, -1.71),
			Vector3(3.42, host_height(storeys, form) - low, 1.66))
		for cell: Vector3i in _cells(host_box, kit):
			if not host.cells_at_band(cell.y).has(Vector2i(cell.x, cell.z)): return {}
		for floor: Dictionary in host.storeys:
			var y0 := int(floor.floor_band) * kit.band_height()
			var y1 := y0 + int(floor.get("bands", 2)) * kit.band_height()
			if y1 <= host_box.position.y or y0 >= host_box.end.y: continue
			if bool(floor.get("inset", false)): return {}
			for edge: Vector3i in floor.openings:
				if floor.openings[edge] not in [BuildingMass.OPENING_DOOR, BuildingMass.OPENING_NONE]: continue
				var direction := Vector2(BuildingMass.DIRS[edge.z])
				var centre := (Vector2(edge.x, edge.y) + Vector2(0.5, 0.5) + direction * 0.5) * kit.module_width
				var point := pose.affine_inverse() * Vector3(centre.x, y0, centre.y)
				if absf(point.x) < 2.1 and absf(point.z) < 0.5: return {}
		# A tower on a wall face must project outside its host, not be buried
		# in a neighbouring wing of that same compound.
		for band in range(base_band, base_band + (storeys - 1) * 2):
			var front := pose * Vector3(0, float(band - base_band) * kit.band_height() + 0.1, 1.0)
			if host.cells_at_band(band).has(Vector2i(floori(front.x / kit.module_width), floori(front.z / kit.module_width))): return {}
	if form not in [Form.CORBELLED_HALF,Form.CORBELLED_ROUND]:
		if not bearing.is_valid(): return {}
		var first: Dictionary = assembly[0]
		var foot: AABB = pose * first.transform * catalog.descriptor(first.asset_id).measured_aabb
		foot.size.y = 0.01
		for cell: Vector3i in _cells(foot, kit):
			if not bool(bearing.call(Vector2i(cell.x, cell.z), base_band)):
				audit["corner_bearing_rejected"] = int(audit.get("corner_bearing_rejected",0))+1
				audit["corner_bearing_example"] = str(host.stable_id, " / ", cell, " / base ", base_band)
				return {}
	for cell: Vector3i in _cells(world_bounds, kit):
		if host.cells_at_band(cell.y).has(Vector2i(cell.x, cell.z)): continue
		# Native footing relief can sit slightly below its datum, inside the
		# very stone course already proved to bear the complete footprint.
		if form not in [Form.CORBELLED_HALF,Form.CORBELLED_ROUND] and cell.y < base_band \
				and bearing.is_valid() and bool(bearing.call(Vector2i(cell.x,cell.z),base_band)): continue
		if blocked.is_valid() and bool(blocked.call(Vector2i(cell.x, cell.z), cell.y)):
			audit["corner_reservation_rejected"] = int(audit.get("corner_reservation_rejected",0))+1
			audit["corner_reservation_example"] = str(host.stable_id, " / ", cell, " / base ", base_band)
			return {}
	return {"parts": assembly, "pose": pose, "bounds": world_bounds,
		"local_bounds": local_bounds, "storeys": storeys, "form": form}


## The native circular corbel embeds its rear quarter into BOTH corner walls.
## Require the same convex corner for a full host storey below its seat and
## throughout the shaft; neither a one-face cantilever nor an inset wall bears it.
static func _corbel_corner_supported(host: BuildingMass,kit: BuildingKit,
		pose: Transform3D,storeys: int) -> bool:
	if storeys<2: return false
	var base := roundi(pose.origin.y/kit.band_height())
	var corner := Vector2i(roundi(pose.origin.x/kit.module_width),roundi(pose.origin.z/kit.module_width))
	var quadrant := Vector2i(99999,99999)
	for band in range(base-2,base+storeys*2):
		var occupied: Array[Vector2i] = []
		var cells := host.cells_at_band(band)
		for offset: Vector2i in [Vector2i(-1,-1),Vector2i(-1,0),Vector2i(0,-1),Vector2i.ZERO]:
			if cells.has(corner+offset): occupied.append(offset)
		if occupied.size()!=1: return false
		if band==base-2: quadrant=occupied[0]
		elif quadrant!=occupied[0]: return false
	for floor: Dictionary in host.storeys:
		var y := int(floor.floor_band)
		if y>=base+storeys*2 or y+int(floor.get("bands",2))<=base-2: continue
		if bool(floor.get("inset",false)) and floor.cells.has(corner+quadrant): return false
	return true


static func _cells(box: AABB, kit: BuildingKit) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	# Only exact face contacts are excluded. The full measured roof and
	# support overhangs must participate, even above/below the window floors.
	box = box.grow(-0.0001)
	for x in range(floori(box.position.x / kit.module_width), ceili(box.end.x / kit.module_width)):
		for y in range(floori(box.position.y / kit.band_height()), ceili(box.end.y / kit.band_height())):
			for z in range(floori(box.position.z / kit.module_width), ceili(box.end.z / kit.module_width)):
				out.append(Vector3i(x, y, z))
	return out
