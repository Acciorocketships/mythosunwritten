extends RefCounted
## Transactional host changes for an already supported/clear tower candidate.
## Spatial reservation is the caller's responsibility. A rejected host plan
## changes neither openings nor roof wings.
const TOWER := preload("res://scripts/terrain/features/villages/kit/KitTowerAssembly.gd")
const UNION := preload("res://scripts/terrain/features/villages/kit/KitRoofMeshUnion.gd")

static func prepare(host: BuildingMass, kit: BuildingKit, catalog: EnvironmentCatalog,
		candidate: Dictionary, audit: Dictionary = {}) -> Dictionary:
	if candidate.is_empty(): return {}
	if int(candidate.form) in [TOWER.Form.ROUND,TOWER.Form.CORBELLED_ROUND]: return _prepare_corner(host,kit,catalog,candidate,audit)
	var pose: Transform3D = candidate.pose
	var inverse := pose.affine_inverse()
	var attachment_box: AABB = candidate.bounds
	var wings := {}
	for index in host.roofs.size():
		var roof: Dictionary = host.roofs[index]
		var eave_attachment: bool = candidate.get("attachment",&"gable") == &"eave"
		var axis := 1-int(roof.axis) if eave_attachment else int(roof.axis)
		var coordinate := 0 if axis == 0 else 2
		if absf(pose.basis.z[coordinate]) < 0.999: continue
		var positive := pose.basis.z[coordinate] > 0
		if not eave_attachment and bool(roof.get("open_max" if positive else "open_min", false)): continue
		var rect: Rect2i = roof.rect
		var end := rect.end[axis] if positive else rect.position[axis]
		if absf(pose.origin[coordinate] - float(end) * kit.module_width) > 0.01: continue
		var across := pose.origin[2 if axis == 0 else 0] / kit.module_width
		if across <= rect.position[1 - axis] or across >= rect.end[1 - axis]: continue
		if not attachment_box.intersects(UNION.roof_volume(roof, kit).bounds): continue
		if eave_attachment:
			var cap_y := (pose*(candidate.parts[-1].transform as Transform3D)).origin.y
			if absf(cap_y+TOWER.ROOF_LAP-float(roof.eave_band)*kit.band_height())>0.01: continue
		wings[index] = "" if eave_attachment else ("verge_max" if positive else "verge_min")
	if wings.is_empty(): return {}
	var openings: Array[Dictionary] = []
	var designer := BuildingDesigner.new(kit)
	var box: AABB = candidate.bounds
	for index in host.storeys.size():
		var floor: Dictionary = host.storeys[index]
		var y := int(floor.floor_band) * kit.band_height()
		if y >= box.end.y or y + int(floor.get("bands", 2)) * kit.band_height() <= box.position.y: continue
		for slot: Dictionary in designer.slots_of(host, floor):
			var outward := Vector3(BuildingMass.DIRS[slot.dir].x, 0, BuildingMass.DIRS[slot.dir].y)
			if outward.dot(pose.basis.z) < 0.999: continue
			var centre: Vector2 = slot.centre * kit.module_width
			var local := inverse * Vector3(centre.x, y, centre.y)
			if absf(local.x) >= 2.1 or absf(local.z) >= 0.5: continue
			var opening: StringName = floor.openings.get(slot.edge, floor.get("default_opening", BuildingMass.OPENING_WINDOW))
			if opening in [BuildingMass.OPENING_DOOR, BuildingMass.OPENING_NONE]: return {}
			openings.append({"storey": index, "edge": slot.edge,
				"centre": slot.centre, "dir": slot.dir, "y": y})
	return {"wings": wings, "reach": TOWER.gable_reach(kit, catalog), "openings": openings}

static func apply(host: BuildingMass, plan: Dictionary) -> void:
	assert(not plan.is_empty())
	for index: int in plan.wings:
		var roof: Dictionary = host.roofs[index]
		var key: String = plan.wings[index]
		if key.is_empty(): continue # Eave joints keep the authored overhang; native cap trims the crossing.
		# Never widen a verge already shortened for a public route.
		roof[key] = minf(float(roof.get(key, plan.reach)), float(plan.reach))
	for opening: Dictionary in plan.openings:
		host.storeys[opening.storey].openings[opening.edge] = BuildingMass.OPENING_PLAIN
		# Window boxes belong to the opening, even when they sit below the
		# tower's corbel and therefore miss its measured collision envelope.
		for index in range(host.decor.size() - 1, -1, -1):
			var item: Dictionary = host.decor[index]
			if item.kind != &"window_box" or int(item.dir) != int(opening.dir): continue
			if (item.centre as Vector2).distance_to(opening.centre) > 0.01: continue
			if absf(float(item.get("y", 0.0)) - float(opening.y)) > 0.01: continue
			host.decor.remove_at(index)

static func fit_parts(parts: Array[Dictionary], candidate: Dictionary,
		kit: BuildingKit, catalog: EnvironmentCatalog) -> int:
	var removed := 0
	var pose: Transform3D = candidate.pose
	var inverse := pose.affine_inverse()
	var tower_box: AABB = candidate.bounds
	for index in range(parts.size() - 1, -1, -1):
		var part: Dictionary = parts[index]
		var part_pose: Transform3D = part.transform
		var box: AABB = part_pose * catalog.descriptor(part.asset_id).measured_aabb
		if not box.intersects(tower_box): continue
		if part.role in [&"window_box", &"ivy.wall", &"ivy.corner", &"prop.doorstep", &"prop.pot", &"awning"]:
			parts.remove_at(index)
			removed += 1
			continue
		if part.role != &"gable.wall" or part_pose.basis.z.normalized().dot(pose.basis.z) < 0.999: continue
		var local := inverse * part_pose.origin
		if absf(local.x) >= 2.1 or absf(local.z) >= 0.5: continue
		var old_anchor := kit.anchor(part.role) * kit.asset_anchor(part.asset_id)
		part.role = &"gable.plain"
		part.asset_id = kit.asset(part.role)
		part.transform = part_pose * old_anchor.affine_inverse() * kit.anchor(part.role) * kit.asset_anchor(part.asset_id)
	return removed


## A full shaft belongs at a convex, occupied building corner. Both adjoining
## wall faces enter the stone cylinder; the cap closes the eave junction.
static func _prepare_corner(host: BuildingMass, kit: BuildingKit,
		catalog: EnvironmentCatalog, candidate: Dictionary, audit: Dictionary = {}) -> Dictionary:
	if candidate.get("attachment", &"") != &"corner": return {}
	var pose: Transform3D = candidate.pose
	var corner := Vector2i(roundi(pose.origin.x / kit.module_width), roundi(pose.origin.z / kit.module_width))
	var base_band := roundi(pose.origin.y / kit.band_height())
	var top_band := base_band + int(candidate.storeys) * 2
	var quadrant := Vector2i(2147483647,2147483647)
	for band in range(base_band,top_band):
		var cells := host.cells_at_band(band)
		var occupied: Array[Vector2i] = []
		for offset: Vector2i in [Vector2i(-1,-1),Vector2i(-1,0),Vector2i(0,-1),Vector2i.ZERO]:
			if cells.has(corner+offset): occupied.append(offset)
		if occupied.size()!=1:
			audit["corner_join_quadrants"]=int(audit.get("corner_join_quadrants",0))+1
			var counts: Dictionary = audit.get("corner_quadrant_counts",{})
			counts[occupied.size()] = int(counts.get(occupied.size(),0))+1
			audit["corner_quadrant_counts"] = counts
			var examples: Array = audit.get("corner_quadrant_examples",[])
			if examples.size()<12:
				examples.append({"host":host.stable_id,"corner":corner,"base":base_band,"top":top_band,"band":band,"occupied":occupied})
			audit["corner_quadrant_examples"] = examples
			return {}
		if band==base_band: quadrant=occupied[0]
		elif quadrant!=occupied[0]:
			audit["corner_join_shifted"]=int(audit.get("corner_join_shifted",0))+1
			return {}
	var wings := {}
	for index in host.roofs.size():
		var roof: Dictionary = host.roofs[index]
		var rect: Rect2i = roof.rect
		if int(roof.eave_band)!=top_band: continue
		if corner.x not in [rect.position.x,rect.end.x] or corner.y not in [rect.position.y,rect.end.y]: continue
		wings[index] = "" if kit.roof_edge_caps else ("verge_min" if corner[int(roof.axis)] == rect.position[int(roof.axis)] else "verge_max")
	if wings.is_empty(): return {}
	var openings: Array[Dictionary] = []
	var designer := BuildingDesigner.new(kit)
	var radius := float(candidate.get("opening_reach", 1.8)) # Native window surrounds.
	for index in host.storeys.size():
		var floor: Dictionary = host.storeys[index]
		var band := int(floor.floor_band)
		if band >= top_band: continue
		if (band+int(floor.get("bands",2)))*kit.band_height() <= (candidate.bounds as AABB).position.y: continue
		if bool(floor.get("inset",false)):
			audit["corner_join_inset"]=int(audit.get("corner_join_inset",0))+1
			return {}
		for slot: Dictionary in designer.slots_of(host,floor):
			var centre: Vector2 = slot.centre*kit.module_width
			if centre.distance_to(Vector2(pose.origin.x,pose.origin.z))>radius: continue
			var opening: StringName = floor.openings.get(slot.edge,floor.get("default_opening",BuildingMass.OPENING_WINDOW))
			if opening in [BuildingMass.OPENING_DOOR,BuildingMass.OPENING_NONE]:
				audit["corner_join_door"]=int(audit.get("corner_join_door",0))+1
				return {}
			openings.append({"storey":index,"edge":slot.edge,"centre":slot.centre,"dir":slot.dir,"y":band*kit.band_height()})
	return {"wings":wings,"reach":TOWER.gable_reach(kit,catalog),"openings":openings}
