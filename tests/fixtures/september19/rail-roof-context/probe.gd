extends SceneTree
func _init() -> void: call_deferred("_run")
func _run() -> void:
 root.size=Vector2i(1920,1080)
 var camera:=Camera3D.new()
 root.add_child(camera)
 var data:Dictionary=FileAccess.open("res://docs/qa/2026-09-19-manual/108-rail-roof-context/payload.bin",FileAccess.READ).get_var()
 var town:Transform3D=data.transform
 var poses:Array=JSON.parse_string(FileAccess.get_file_as_string("res://docs/qa/2026-09-16-manual/05-town-rails/baseline/P15/poses.json"))
 for pose:Dictionary in poses:
  if int(pose.angle)!=0: continue
  var pattern:=RegEx.new()
  pattern.compile("-?[0-9]+(?:\\.[0-9]+)?")
  var v:Array[float]=[]
  for found in pattern.search_all(pose.camera):v.append(float(found.get_string()))
  camera.transform=Transform3D(Basis(Vector3(v[0],v[1],v[2]),Vector3(v[3],v[4],v[5]),Vector3(v[6],v[7],v[8])),Vector3(v[9],v[10],v[11]))
  camera.fov=pose.fov
 await process_frame
 var hit_meshes:Dictionary={}
 for pixel:Vector2 in [Vector2(1150,650),Vector2(1160,692),Vector2(1140,670),Vector2(1100,620)]:
  var origin:=town.affine_inverse()*camera.project_ray_origin(pixel)
  var direction:Vector3=town.basis.inverse()*camera.project_ray_normal(pixel)
  var nearest:=INF
  var hit:Dictionary={}
  for mesh:Dictionary in data.surface_meshes:
   var vertices:PackedVector3Array=mesh.vertices
   var indices:PackedInt32Array=mesh.indices
   for i in range(0,indices.size(),3):
    var point:Variant=Geometry3D.ray_intersects_triangle(origin,direction,vertices[indices[i]],vertices[indices[i+1]],vertices[indices[i+2]])
    if point!=null and origin.distance_squared_to(point)<nearest:
     nearest=origin.distance_squared_to(point)
     hit={"mesh":str(mesh.stable_id),"point":str(point),"triangle":i/3}
  print("HIT ",pixel," ",hit)
  if not hit.is_empty():hit_meshes[hit.mesh]=true
 var program:=SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
 var frozen:=preload("res://tests/fixtures/frozen_maze_source.gd")
 var spatial:=frozen.spatial(frozen.read("res://docs/qa/2026-09-16-manual/05-town-rails/current-source.txt"),program)
 var fabric:=spatial.compiled_fabric_cache()
 for placement:Dictionary in fabric.expanded_placements():
  if "landmark.01.component.00" in String(placement.stable_id):print("NATIVE ",placement.asset_id," ",placement.bounds)
 var skin:=SettlementFabricAssembler.maze_ground_skin_transaction(fabric)
 for cell:Vector3i in [Vector3i(4,5,7),Vector3i(4,6,7)]:
  print("CELL ",cell," original-retained ",fabric.retained_terrace_cells.has(cell)," final-retained ",skin.retained.has(cell)," solid ",skin.solids.has(cell))
  for unit:FabricUnit in fabric.units:
   var recipe:=fabric.recipe(unit.recipe_id)
   for local:Vector3i in recipe.solid_cells:
    if FabricRecipe.transform_cell(local,unit.lattice_origin,unit.yaw_quarters)==cell:print("OWNER ",unit.stable_id," recipe ",unit.recipe_id," roof-tag ",recipe.has_tag(&"roof")," origin ",unit.lattice_origin," yaw ",unit.yaw_quarters," bounds ",recipe.placement_bounds)
 for transition:WarrenVolumeTransition in spatial.source_volume.transitions:
  if not hit_meshes.has("public-transition/%s.mesh"%transition.stable_id):continue
  var span:=WarrenTransitionSurfaceBuilder._span_endpoints(transition)
  print("TRANSITION ",transition.stable_id," ",span)
  var lateral:=Vector3(-transition.direction.y,0,transition.direction.x)
  var barriers:Array[AABB]=fabric.surface_plan._guard_wall_boxes.duplicate()
  span["lateral"]=lateral
  barriers.append_array(fabric.surface_plan._raised_stair_side_barriers(span))
  for side in [-1.0,1.0]:
   var offset:Vector3=lateral*1.5*side
   for fraction in [0.52,1.0]:
    var a:Vector3=span.start+offset+Vector3.UP*WarrenTransitionSurfaceBuilder.GUARD_HEIGHT*fraction
    var b:Vector3=span.end+offset+Vector3.UP*WarrenTransitionSurfaceBuilder.GUARD_HEIGHT*fraction
    for box:AABB in barriers:
     if WarrenTransitionSurfaceBuilder._line_box_interval(a,b,box)!=Vector2.ZERO:print("RAIL_CUT ",box)
    print("RAIL ",side," ",fraction," ",a," to ",b," exposed ",WarrenTransitionSurfaceBuilder._exposed_guard_spans(a,b,barriers))
   for endpoint:Vector3 in [span.start,(span.start+span.end)*.5,span.end]:
    var foot:=endpoint+offset
    print("POST ",foot," spans ",WarrenTransitionSurfaceBuilder._exposed_guard_spans(foot,foot+Vector3.UP*1.4,barriers))
    for box:AABB in barriers:
     if box.grow(.3).has_point(foot): print("BOX ",box)
 quit()
