extends SceneTree

## Focused, resource-free diagnostic for the 2026-09-04 production village.
## It reports only committed entries and surfaces near the exact annotated
## points, keeping visual debugging tied to the final world-space payload.
const WORLD_SEED := 2697992464
const SUPER_CELL := Vector2i(0, 0)
const POINTS := {
	"terrain_handoff_wedge": Vector3(238.1, 4.0, 316.6),
	"orphan_stone_cell": Vector3(253.4, 9.9, 289.5),
	"diagonal_gap_facade_planes": Vector3(286.3, 5.1, 291.4),
	"elevated_turf_supports": Vector3(237.5, 17.0, 294.2),
	"planters_in_walkway": Vector3(247.3, 17.0, 299.1),
	"door_behind_railing": Vector3(258.8, 11.0, 315.3),
	"double_ground_sheet": Vector3(251.0, 4.0, 278.7),
	"facade_plane_jut": Vector3(262.8, 5.0, 336.0),
	"turf_lip_corner": Vector3(282.3, 8.1, 345.2),
	"sep5_joints": Vector3(259.8, 5, 299.5),
	"sep5_entrance": Vector3(298.5, 5.08, 291.5),
	"sep5_room": Vector3(239, 17.1, 295.4),
}


func _init() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var feature_program := FeatureProgram.compile(catalog)
	assert(feature_program != null)
	var water := TerrainWorldTuning.make_water(WORLD_SEED)
	var heightfield := TerrainWorldTuning.make_heightfield(WORLD_SEED, water)
	var fields := WorldFieldBlockCache.new(heightfield, water,
		feature_program.query_margin, feature_program.shore_distance_limit,
		feature_program.field_cache_cap)
	var settlements := SettlementPlan.new(WORLD_SEED, water)
	var world := WorldFeaturePlan.new(WORLD_SEED, water, fields,
		feature_program, settlements)
	var frame := world.frame_for(SUPER_CELL)
	assert(frame != null)
	var record := world.village_plan().record_for(frame)
	if record == null or record.is_empty():
		push_error("Village probe failed: %s" % WarrenSpatialFabricCompiler.last_failure)
		quit(1)
		return
	var report := {
		"settlement": String(record.stable_id),
		"centre": [record.centre.x, record.centre.y],
		"world_transform": str(record.urban_fabric.world_transform),
		"terrain_relief_m": record.urban_fabric.terrain_relief_m,
		"outskirts_audit": record.outskirts.audit if record.outskirts != null else {},
		"points": {},
	}
	var fabric := record.urban_fabric.fabric_plan
	var grade := record.urban_fabric.terrain_grade
	report["grade_claims"] = []
	for key: Vector2i in grade._claims:
		var p: Vector2 = grade._origin + Vector2(key) * grade._targets.pitch
		if p.distance_to(Vector2(309,275)) < 60:
			report.grade_claims.append([p.x,p.y,grade._claims[key]])
	report["grade_samples"] = []
	for z in range(305, 326):
		for x in range(310, 331):
			var p := Vector2(x,z)
			var natural := TerrainSurfaceField.surface_y(fields.region_at(p), x, z)
			report.grade_samples.append([x,z,natural,grade.surface_y(p,natural)])
	var spatial := record.urban_fabric.volumetric_spatial
	report["room_bearings"] = []
	for building: WarrenBuildingVolume in spatial.buildings:
		for room: WarrenRoomStamp in building.room_records:
			if not String(room.stable_id).contains("house.009"):
				continue
			var below: Array = []
			for cell: Vector3i in room.private_cells:
				if cell.y == room.lattice_origin.y:
					below.append({"cell":str(cell + Vector3i.DOWN),
						"use": spatial.grid.use_at(cell + Vector3i.DOWN),
						"owner": spatial.grid.owner_name_at(cell + Vector3i.DOWN)})
			report.room_bearings.append({"id":room.stable_id,"origin":str(room.lattice_origin),
				"terrain":room.terrain_bearing,"audit":room.audit,"below":below})
	report["retained"] = fabric.retained_terrace_cells.keys().map(func(c: Vector3i) -> Array: return [c.x,c.y,c.z])
	report["solid"] = fabric.transformed_cells(&"solid").keys().map(func(c: Vector3i) -> Array: return [c.x,c.y,c.z])
	report["units"] = []
	for unit: FabricUnit in fabric.units:
		report.units.append({"id": String(unit.stable_id), "recipe": String(unit.recipe_id),
			"parents": unit.parent_ids,
			"transform": str(unit.transform()), "world_transform": str(record.urban_fabric.world_transform * unit.transform())})
	report["entrances"] = fabric.surface_plan.entrance_records
	report["guards"] = fabric.surface_plan.guard_segments
	report["transitions"] = fabric.surface_plan._transition_mesh_payloads.map(func(p: Dictionary) -> Dictionary:
		return {"id": p.get("stable_id"), "cells": p.get("claim_cells"), "guards": p.get("guard_segments")})
	var plaza_supports: Array = []
	for cell: Vector3i in fabric.planned_plaza_cells:
		plaza_supports.append({"cell": str(cell),
			"retained": fabric.retained_terrace_cells.has(cell),
			"below": fabric.retained_terrace_cells.has(cell + Vector3i.DOWN)})
	report["plaza_supports"] = plaza_supports
	report["turf_seams"] = _turf_seam_probe(record.urban_fabric, catalog)
	for label: String in POINTS:
		report.points[label] = _near_point(record.urban_fabric, catalog,
			POINTS[label] as Vector3)
	var json := JSON.stringify(report, "  ")
	var output := FileAccess.open("/tmp/village-manual-probe.json",
		FileAccess.WRITE)
	assert(output != null)
	output.store_string(json)
	output.close()
	print("[village_manual_probe] wrote /tmp/village-manual-probe.json")
	quit()


static func _turf_seam_probe(urban: VillageUrbanFabricPlan, catalog: EnvironmentCatalog) -> Array:
	var player := Vector3(239.4,17.1,300.1)
	var camera := ReviewCam.solve_cam(player,Vector3(239.6,17.3,300.4))
	var basis := Basis.looking_at(player-camera,Vector3.UP)
	var report: Array = []
	var transaction := SettlementFabricAssembler.maze_ground_skin_transaction(urban.fabric_plan)
	var controls := SettlementFabricAssembler.maze_terrain_control_surface_cells(urban.fabric_plan)
	var region := SettlementFabricAssembler.maze_terrain_surface_region(transaction.capped_ground, controls)
	var local_inverse := urban.world_transform.affine_inverse()
	for pixel: Vector2 in [Vector2(370,650),Vector2(440,600),Vector2(1060,720),Vector2(1090,650)]:
		var screen := Vector2(pixel.x/960.0-1.0,1.0-pixel.y/540.0)
		var ray := basis * Vector3(screen.x*(16.0/9.0)*tan(deg_to_rad(37.5)),
			screen.y*tan(deg_to_rad(37.5)),-1.0)
		var point := camera + ray * ((17.08-camera.y)/ray.y)
		var local := local_inverse * point
		var cell := Vector3i(roundi(local.x/1.5),4,roundi(local.z/1.5))
		var neighbors: Array = []
		for z in range(cell.z-1,cell.z+2):
			for x in range(cell.x-1,cell.x+2):
				neighbors.append({"cell":str(Vector3i(x,3,z)),"height":region.surface_height(x,z),
					"turf":transaction.capped_ground.has(Vector3i(x,3,z)),
					"control":controls.has(Vector3i(x,4,z))})
		var layers: Array = []
		for mesh: Dictionary in urban.surface_meshes:
			var vertices: PackedVector3Array = mesh.vertices
			var indices: PackedInt32Array = mesh.get("indices",PackedInt32Array())
			for i in range(0,indices.size() if not indices.is_empty() else vertices.size(),3):
				var a := vertices[indices[i] if not indices.is_empty() else i]
				var b := vertices[indices[i+1] if not indices.is_empty() else i+1]
				var c := vertices[indices[i+2] if not indices.is_empty() else i+2]
				var hit: Variant = Geometry3D.ray_intersects_triangle(point+Vector3.UP*2,Vector3.DOWN,a,b,c)
				if hit != null and (hit as Vector3).y > 16:
					layers.append({"id":str(mesh.get("stable_id","")),"y":(hit as Vector3).y})
		var entries: Array = []
		for entry: Dictionary in urban.entries:
			var descriptor := catalog.descriptor(entry.asset_id)
			var box: AABB = entry.transform * descriptor.measured_aabb
			if Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z)).has_point(Vector2(point.x,point.z)) \
					and box.position.y < 17.2 and box.end.y > 16.0:
				entries.append({"id":str(entry.stable_id),"asset":str(entry.asset_id),"box":str(box)})
		report.append({"pixel":str(pixel),"world":str(point),"local":str(local),
			"neighbors":neighbors,"layers":layers,"entries":entries})
	return report


static func _near_point(urban: VillageUrbanFabricPlan,
		catalog: EnvironmentCatalog, point: Vector3) -> Dictionary:
	var entries: Array[Dictionary] = []
	for entry: Dictionary in urban.entries:
		var transform := entry.transform as Transform3D
		if Vector2(transform.origin.x, transform.origin.z).distance_to(
				Vector2(point.x, point.z)) > 12.0:
			continue
		var descriptor := catalog.descriptor(StringName(entry.asset_id))
		var bounds := transform * descriptor.measured_aabb \
			if descriptor != null else AABB(transform.origin, Vector3.ZERO)
		entries.append({
			"id": String(entry.stable_id),
			"asset": String(entry.asset_id),
			"origin": _v3(transform.origin),
			"transform": str(transform),
			"bounds": _aabb(bounds),
		})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.id) < String(b.id))
	var meshes: Array[Dictionary] = []
	for mesh: Dictionary in urban.surface_meshes:
		var bounds := _vertex_bounds(mesh.vertices as PackedVector3Array)
		if not bounds.grow(1.0).has_point(point) \
				and Vector2(bounds.get_center().x, bounds.get_center().z).distance_to(
					Vector2(point.x, point.z)) > 12.0:
			continue
		meshes.append({
			"id": String(mesh.get("stable_id", "")),
			"kind": int(mesh.get("kind", -1)),
			"terrain_ground": bool(mesh.get("terrain_ground", false)),
			"terrain_path": bool(mesh.get("terrain_path", false)),
			"terrain_rock": bool(mesh.get("terrain_rock", false)),
			"bounds": _aabb(bounds),
		})
	return {"world": _v3(point), "entries": entries, "meshes": meshes}


static func _vertex_bounds(vertices: PackedVector3Array) -> AABB:
	if vertices.is_empty():
		return AABB()
	var bounds := AABB(vertices[0], Vector3.ZERO)
	for index in range(1, vertices.size()):
		bounds = bounds.expand(vertices[index])
	return bounds


static func _v3(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


static func _aabb(value: AABB) -> Dictionary:
	return {"position": _v3(value.position), "size": _v3(value.size)}
