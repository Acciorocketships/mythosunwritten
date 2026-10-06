extends RefCounted
## Intersect finished roof triangles with public air; boundary contact is legal.
const UNION := preload("res://scripts/terrain/features/villages/kit/KitRoofMeshUnion.gd")
const TOLERANCE := 0.0001

static func audit(built: Dictionary, kit: BuildingKit, finished := true) -> Dictionary:
	var ctx := UNION.prepare(built.roofs,built.walls,kit,built.roof_kits)
	var out := {"triangles":0,"intrusions":0,"area":0.0,"gable_contacts":0,"gable_area":0.0,"roles":{},"examples":[]}
	for part: Dictionary in built.placements:
		if int(part.get("roof_index",-1)) < 0 or not ctx.data.has(part.asset_id): continue
		var actual := UNION.realize(part,ctx) if finished else {}
		var surfaces: Array = ctx.data[part.asset_id] if actual.is_empty() else actual.meshes
		var pose: Transform3D = part.transform if actual.is_empty() else Transform3D.IDENTITY
		for surface: Dictionary in surfaces:
			if surface.vertices.is_empty(): continue
			var vertices := PackedVector3Array()
			var bounds := AABB(pose*surface.vertices[0],Vector3.ZERO)
			for v: Vector3 in surface.vertices:
				vertices.append(pose*v)
				bounds = bounds.expand(vertices[-1])
			var volumes: Array[Dictionary] = []
			for volume: Dictionary in built.walls:
				if bool(volume.get("open",false)) and bounds.intersects(volume.bounds): volumes.append(volume)
			for i in range(0,surface.indices.size(),3):
				out.triangles += 1
				var triangle := PackedVector3Array()
				for j in 3: triangle.append(vertices[surface.indices[i+j]])
				var box := AABB(triangle[0],Vector3.ZERO).expand(triangle[1]).expand(triangle[2])
				for volume: Dictionary in volumes:
					if not box.intersects(volume.bounds): continue
					var polygon := triangle
					for plane: Plane in volume.planes:
						plane.d -= TOLERANCE
						polygon = _clip(polygon,plane)
						if polygon.size()<3: break
					var area := 0.0
					for j in range(1,polygon.size()-1):
						area += (polygon[j]-polygon[0]).cross(polygon[j+1]-polygon[0]).length()*0.5
					if area <= 0.000001: continue
					# Gables are boundary facades, not overhangs. The public floor
					# reaches the wall datum, behind the finished facade relief.
					# Report that contact without claiming character clearance.
					if String(part.role).begins_with("gable."):
						out.gable_contacts += 1
						out.gable_area += area
						break
					out.intrusions += 1
					out.area += area
					out.roles[part.role] = int(out.roles.get(part.role,0))+1
					if out.examples.size()<8: out.examples.append([String(part.stable_id),String(part.role),area])
					break
	return out

static func _clip(points: PackedVector3Array, plane: Plane) -> PackedVector3Array:
	var out := PackedVector3Array()
	if points.is_empty(): return out
	var previous := points[-1]
	var pd := plane.distance_to(previous)
	for point: Vector3 in points:
		var d := plane.distance_to(point)
		if (pd<=0.0)!=(d<=0.0): out.append(previous.lerp(point,pd/(pd-d)))
		if d<=0.0: out.append(point)
		previous = point
		pd = d
	return out
