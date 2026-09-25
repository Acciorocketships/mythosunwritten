extends SceneTree
func _init() -> void:
 var data: Dictionary = FileAccess.open("res://docs/qa/2026-09-13-manual/40-rail-ends/before-payload.bin",FileAccess.READ).get_var()
 var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
 var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
 var spatial := frozen.spatial(frozen.read("res://docs/qa/2026-09-13-manual/09-upper-wall/current-source.txt"),program)
 var fabric := spatial.compiled_fabric_cache()
 var town: Transform3D = data.transform
 print("TOWN ",town)
 var area := AABB(Vector3(980,22,-420),Vector3(36,10,24))
 var report := {"transitions":[],"guards":[],"claims":[],"native_rails":[],"wall_boxes":[]}
 for transition: WarrenVolumeTransition in spatial.source_volume.transitions:
  if not transition.is_vertical(): continue
  var ends := WarrenTransitionSurfaceBuilder._span_endpoints(transition)
  if area.has_point(town*ends.start) or area.has_point(town*ends.end):
   report.transitions.append({"id":str(transition.stable_id),"start":str(town*ends.start),"end":str(town*ends.end),"local_start":str(ends.start),"local_end":str(ends.end)})
 for segment: Dictionary in fabric.surface_plan.guard_segments:
  if area.has_point(town*segment.a) or area.has_point(town*segment.b): report.guards.append({"key":str(segment.stable_key),"a":str(town*segment.a),"b":str(town*segment.b)})
 for claim: Dictionary in fabric.surface_plan._claims.values():
  var p: Vector3 = town*(Vector3(claim.cell)*FabricRecipe.CELL_SIZE)
  if area.has_point(p): report.claims.append({"cell":str(claim.cell),"kind":claim.kind,"world":str(p)})
 for box: AABB in fabric.surface_plan._guard_wall_boxes:
  if area.intersects(town*box): report.wall_boxes.append(str(town*box))
 for cell: Vector3i in [Vector3i(4,2,6),Vector3i(4,2,7),Vector3i(7,2,4),Vector3i(7,2,5),Vector3i(7,2,6),Vector3i(7,2,7)]:
  for direction: Vector3i in [Vector3i.LEFT,Vector3i.RIGHT]:
   var neighbor := cell+direction
   var segment := PublicRealmSurfacePlan._guard_segment(cell,direction,&"probe")
   print("EDGE ",cell," ",direction," transition=",fabric.surface_plan._has_public_transition(cell,direction)," solid=",fabric.surface_plan._structural_solid_cells.has(PublicRealmSurfacePlan._cell_key(neighbor))," solid_above=",fabric.surface_plan._structural_solid_cells.has(PublicRealmSurfacePlan._cell_key(neighbor+Vector3i.UP))," backed=",fabric.surface_plan._guard_is_backed_by_wall(segment))
 print("OPENINGS ",fabric.surface_plan._public_openings)
 print("GREEN ",fabric.surface_plan._green_threshold_openings)
 var catalog := EnvironmentCatalog.load_default()
 for asset: StringName in data.batches:
  if not "railing" in String(asset): continue
  var batch: Dictionary = data.batches[asset]
  for index in batch.transforms.size():
   var frame: Transform3D = town*batch.transforms[index]
   var bounds: AABB = frame*catalog.descriptor(asset).measured_aabb
   if area.intersects(bounds): report.native_rails.append({"id":str(batch.ids[index]),"asset":str(asset),"frame":str(frame),"bounds":str(bounds)})
 FileAccess.open("res://docs/qa/2026-09-13-manual/40-rail-ends/owners.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 quit()
