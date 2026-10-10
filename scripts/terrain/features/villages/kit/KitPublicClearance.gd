extends RefCounted
## Finished public walking air in native kit metres. Flat floors, ramps,
## stair treads and exterior gate approaches share this geometry authority.
## Guard tops and stair undersides are not walking surfaces.

static func build(spatial: WarrenSpatialPlan, fabric: SettlementFabricPlan,
		kit: BuildingKit) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if fabric.surface_plan == null: return out
	var map := KitVillageBuildings.native_to_lattice(kit).affine_inverse()
	var height := TraversalEnvelope.MIN_HEADROOM / VillageWorldScale.VERTICAL_SCALE
	for mesh: Dictionary in floor_meshes(spatial, fabric):
		out.append_array(from_mesh(mesh, map, height))
	# Reachable construction crowns are real walking floors even though the
	# sealed public-floor union predates their bridge connections.
	var crowns := SettlementFabricAssembler.maze_terrace_deck_cells(fabric)
	var union_script := preload("res://scripts/terrain/features/villages/kit/KitRoofMeshUnion.gd")
	for cell: Vector3i in crowns:
		if fabric.surface_plan.has_cell(cell):
			continue
		var center := Vector3(cell) * FabricRecipe.CELL_SIZE
		var box := AABB(center - Vector3(.5, 0, .5) * FabricRecipe.CELL_SIZE,
			Vector3(FabricRecipe.CELL_SIZE, height, FabricRecipe.CELL_SIZE))
		var volume := union_script.box_volume(map * box)
		volume["open"] = true
		out.append(volume)
	return out


## Late skywalks are not in the earlier public-floor mesh. Their whole
## crossing, including each landing, must still stay free of optional wall
## hoods and other facade ornaments. Keep these volumes out of roof/wall
## cutting: enclosed spans intentionally have an inhabited shell. Protect
## their full room height, so ornaments cannot hang between headroom and the
## ceiling; open spans reserve only their required walking clearance.
static func skywalk_ornament_air(spans: Array[Dictionary], kit: BuildingKit) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var union_script := preload("res://scripts/terrain/features/villages/kit/KitRoofMeshUnion.gd")
	var height := TraversalEnvelope.MIN_HEADROOM / VillageWorldScale.VERTICAL_SCALE
	var occupied := {}
	for span: Dictionary in spans:
		var step: Vector3i = span.step
		var cross: Vector3i = span.get("cross", Vector3i(step.z, 0, step.x))
		for k in range(int(span.gap) + 2):
			for lane in int(span.get("width", 1)):
				var at: Vector3i = span.cell + step * k + cross * lane
				var room_height := kit.storey_height if bool(span.get("enclosed", false)) else height
				occupied[at] = maxf(float(occupied.get(at, 0.0)), room_height)
	for cell: Vector3i in occupied:
		var volume := union_script.box_volume(AABB(Vector3(cell.x * kit.module_width,
			cell.y * kit.band_height(), cell.z * kit.module_width),
			Vector3(kit.module_width, float(occupied[cell]), kit.module_width)))
		volume["open"] = true
		out.append(volume)
	return out


## These rooms carry a route through a bridge and both of its abutments.
## They are PRIVATE_VOLUME, so the exterior floor mesh cannot protect them.
## Reserve their full floor at bridge level against optional internal shafts;
## never use these volumes to cut walls / roofs around the inhabited passage.
static func inhabited_bridge_rooms(spatial: WarrenSpatialPlan,
		kit: BuildingKit) -> Array[Dictionary]:
	var rooms := {}
	for building: WarrenBuildingVolume in spatial.buildings:
		for room: WarrenRoomStamp in building.room_records:
			rooms[room.stable_id] = room
	var occupied := {}
	for id: StringName in KitVillageBuildings.sorted_ids(rooms.keys()):
		var bridge: WarrenRoomStamp = rooms[id]
		var supports: Array = bridge.audit.get("bridge_support_room_ids", [])
		if supports.size() != 2 or bridge.private_cells.is_empty():
			continue
		var floor := 1 << 20
		for cell: Vector3i in bridge.private_cells:
			floor = mini(floor, cell.y)
		var group: Array = supports.duplicate()
		group.append(id)
		for member: StringName in group:
			if not rooms.has(member):
				continue
			for cell: Vector3i in rooms[member].private_cells:
				if cell.y == floor:
					occupied[cell] = true
	var out: Array[Dictionary] = []
	var height := TraversalEnvelope.MIN_HEADROOM / VillageWorldScale.VERTICAL_SCALE
	for cell: Vector3i in occupied:
		var box := AABB(Vector3(cell.x * kit.module_width, cell.y * kit.band_height(),
			cell.z * kit.module_width), Vector3(kit.module_width, height, kit.module_width))
		out.append({"bounds": box, "room_route": true})
	return out


## Optional facade dressing cannot occupy the finished walking envelope.
## Test the complete authored box in its own frame, including rotated props;
## remove a conflicting ornament whole rather than slicing its geometry.
static func fit_decor(placements: Array[Dictionary], volumes: Array[Dictionary],
		catalog: EnvironmentCatalog) -> Dictionary:
	var omitted := {}
	var blocked := {}
	var blocked_groups := {}
	for i in placements.size():
		var part: Dictionary = placements[i]
		# Native fortification trim can cross a newly bored stair opening.
		if part.role not in [&"window_box", &"prop.doorstep", &"fort.block"]: continue
		var descriptor := catalog.descriptor(part.asset_id)
		assert(descriptor != null, "Facade dressing requires measured asset bounds")
		if not intersects_air(descriptor.measured_aabb,part.transform,volumes): continue
		blocked[i] = true
		if part.has("clearance_group"): blocked_groups[part.clearance_group] = true
	for i in range(placements.size()-1,-1,-1):
		var part: Dictionary = placements[i]
		if not blocked.has(i) and not blocked_groups.has(part.get("clearance_group",&"")): continue
		omitted[part.role] = int(omitted.get(part.role,0))+1
		placements.remove_at(i)
	return omitted


static func intersects_air(box: AABB, pose: Transform3D,
		volumes: Array[Dictionary]) -> bool:
	var world_box := pose*box
	var inverse := pose.affine_inverse()
	var union_script := preload("res://scripts/terrain/features/villages/kit/KitRoofMeshUnion.gd")
	for volume: Dictionary in volumes:
		if not bool(volume.get("open",false)) or not world_box.intersects(volume.bounds): continue
		var planes: Array[Plane] = []
		planes.assign(union_script.box_volume(box).planes)
		for plane: Plane in volume.planes:
			var local: Plane = inverse*plane
			local.d -= 0.001
			planes.append(local)
		if not Geometry3D.compute_convex_mesh_points(planes).is_empty(): return true
	return false


static func floor_meshes(spatial: WarrenSpatialPlan, fabric: SettlementFabricPlan) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if fabric.surface_plan == null: return out
	out.append_array(fabric.surface_plan.mesh_payloads)
	for spec: Dictionary in VillageWarrenFabricSolver.terrain_contact_specs(spatial, fabric):
		var geometry := VillageWarrenFabricSolver.terrain_contact_local_geometry(spec)
		if bool(geometry.has_stairs):
			out.append(WarrenTransitionSurfaceBuilder.build_gate_approach(&"clearance.gate", geometry))
	return out


static func from_mesh(mesh: Dictionary, map: Transform3D,
		height: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var vertices: PackedVector3Array = mesh.vertices
	var normals: PackedVector3Array = mesh.normals
	var indices: PackedInt32Array = mesh.indices
	var lift := map.basis * Vector3.UP * height
	for i in range(0, indices.size(), 3):
		var guard := false
		for span: Vector2i in mesh.get("guard_index_ranges", []):
			guard = guard or (i >= span.x and i < span.y)
		if guard or normals[indices[i]].y <= 0.01: continue
		var points: Array[Vector3] = [map * vertices[indices[i]],
			map * vertices[indices[i + 1]], map * vertices[indices[i + 2]]]
		var normal := (points[1] - points[0]).cross(points[2] - points[0]).normalized()
		if absf(normal.y) < 0.0001: continue
		if normal.y < 0.0: normal = -normal
		var planes: Array[Plane] = [Plane(-normal, -normal.dot(points[0])),
			Plane(normal, normal.dot(points[0] + lift))]
		var centre := (points[0] + points[1] + points[2]) / 3.0
		var bounds := AABB(points[0], Vector3.ZERO)
		for j in 3:
			var edge := (points[(j + 1) % 3] - points[j]).cross(Vector3.UP).normalized()
			if edge.dot(centre - points[j]) > 0.0: edge = -edge
			planes.append(Plane(edge, edge.dot(points[j])))
			bounds = bounds.expand(points[j]).expand(points[j] + lift)
		out.append({"bounds": bounds, "planes": planes, "open": true})
	return out
