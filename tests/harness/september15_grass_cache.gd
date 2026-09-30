extends SceneTree
const FROZEN=preload("res://tests/fixtures/frozen_terrain_grade.gd")
const ORIGINAL=preload("res://tests/fixtures/september15/uncached_mesher.gd")
func _init(): call_deferred("_run")
func _run():
 var original=ORIGINAL.new()
 original.prepare_resources()
 var current:=TerrainChunkMesher.new()
 current.prepare_resources()
 var report:=[]
 for site:Array in [["P09",Vector2i(-3,-2)],["P07",Vector2i(-3,-11)],["P08",Vector2i(-4,-11)]]:
  var region:=FROZEN.region("res://docs/qa/2026-09-15-manual/01-grass/"+site[0]+"-field.txt")
  var start:=Time.get_ticks_msec()
  var before:Dictionary=original.compute_chunk(site[1],region)
  var before_ms:=Time.get_ticks_msec()-start
  start=Time.get_ticks_msec()
  var after:=current.compute_chunk(site[1],region)
  var after_ms:=Time.get_ticks_msec()-start
  var same_collision:bool=before.collision_faces==after.collision_faces
  var same_walls:bool=before.wall_collision_arrays==after.wall_collision_arrays
  assert(same_collision and same_walls)
  var entry:={"spot":site[0],"collision_identical":same_collision,"wall_collision_identical":same_walls,"before_ms":before_ms,"after_ms":after_ms,
   "original_surface_vertices":before.surface_arrays[Mesh.ARRAY_VERTEX].size(),"candidate_surface_vertices":after.surface_arrays[Mesh.ARRAY_VERTEX].size()}
  for key:String in ["surface_arrays","wall_arrays"]:
   assert(before[key]==after[key],key+" must remain exactly equal with caching")
  entry["all_terrain_visual_arrays_identical"]=true
  report.append(entry)
  print("GRASS_GEOMETRY ",entry)
 FileAccess.open("res://docs/qa/2026-09-15-manual/01-grass/cache-equality.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 quit()

func _survey(before:Node3D,after:Node3D,spot:String)->Dictionary:
 var views:Array[SubViewport]=[]
 for terrain:Node3D in [before,after]:
  var view:=SubViewport.new()
  view.own_world_3d=true
  root.add_child(view)
  view.add_child(terrain)
  views.append(view)
 await physics_frame
 await physics_frame
 var center:Vector3
 for record:Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://docs/qa/2026-09-15-manual/photo-poses.json")):
  if record.id==spot: center=Vector3(record.player[0],record.player[1],record.player[2])
 var max_delta:=0.0
 var changes:=[]
 var added:=0
 var removed:=0
 for iz in range(-36,37):
  for ix in range(-36,37):
   var point:=center+Vector3(ix*.5,0,iz*.5)
   var hits:=[]
   for view:SubViewport in views:
    hits.append(view.find_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*80,point-Vector3.UP*80,1)))
   if hits[0].is_empty() and not hits[1].is_empty(): added+=1
   if not hits[0].is_empty() and hits[1].is_empty(): removed+=1
   if not hits[0].is_empty() and not hits[1].is_empty():
    var delta:float=absf(hits[0].position.y-hits[1].position.y)
    max_delta=maxf(max_delta,delta)
    if delta>.01: changes.append({"x":point.x,"z":point.z,"before":hits[0].position.y,"after":hits[1].position.y})
 for view:SubViewport in views: view.free()
 return {"samples":73*73,"added_support":added,"removed_support":removed,"max_height_change":max_delta,"height_changes":changes}
