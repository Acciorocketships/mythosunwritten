extends "res://tests/harness/september16_moss_review.gd"
func _capture_views(world:Node3D)->void:
 var base:=_output_dir
 var shared:=base.path_join("seated-poses.json")
 var args:=OS.get_cmdline_user_args()
 if "--seated-poses" in args:shared=args[args.find("--seated-poses")+1]
 var saved:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(shared)) if FileAccess.file_exists(shared) else {}
 var space:=_camera.get_world_3d().direct_space_state
 var report:=saved.duplicate(true)
 for record:Array in _spots():
  if not record[0] in ["P05","P12","P17","P20"]:continue
  var original:Vector3=record[2]
  if saved.has(record[0]):
   var v:Array=saved[record[0]].feet;record[2]=Vector3(v[0],v[1],v[2])
  else:
   var away:=Vector3(original.x-record[3].x,0,original.z-record[3].z).normalized()
   var best:=INF;var selected:=original
   for distance in range(0,13):
    var p:Vector3=original+away*distance
    var query:=PhysicsRayQueryParameters3D.create(p+Vector3.UP*12,p-Vector3.UP*12,_character.collision_mask,[_character.get_rid()])
    var hit:=space.intersect_ray(query)
    if hit.is_empty() or hit.normal.y<.72:continue
    var score:float=distance+absf(hit.position.y-original.y)*.5
    if score<best:best=score;selected=hit.position+Vector3.UP*.05
   assert(is_finite(best),"A nearby supported photo stance must exist")
   record[2]=selected
   report[record[0]]={"original_feet":[original.x,original.y,original.z],"feet":[selected.x,selected.y,selected.z],"reason":"Native ray-supported stance after outcrop widening"}
  record[3]+=Vector3.UP*(record[2].y-original.y)
  report[record[0]]["crosshair_height_offset"]=record[2].y-original.y
  _spot=record;_output_dir=base.path_join(record[0]);DirAccess.make_dir_recursive_absolute(_output_dir)
  await super._capture_views(world)
 FileAccess.open(base.path_join("seated-poses.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 _output_dir=base
