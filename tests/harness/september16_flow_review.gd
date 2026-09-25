extends "res://tests/harness/september16_manual_qa.gd"
func _capture_views(world:Node3D)->void:
 var base:=_output_dir
 var samplers:=[];var seen:={}
 for owner:Node in get_tree().get_nodes_in_group("water_surface"):
  if not owner.has_meta("sampler"):continue
  var s:WaterSampler=owner.get_meta("sampler")
  if seen.has(s.get_instance_id()):continue
  seen[s.get_instance_id()]=true;samplers.append(s)
 var samples:=0;var uphill:=[]
 for s:WaterSampler in samplers:
  for j in range(2,s._nz-2):
   for i in range(2,s._nx-2):
    for offset:Vector2 in [Vector2.ZERO,Vector2(.25,.25),Vector2(.5,.5),Vector2(.75,.75)]:
     var p:=s._origin+(Vector2(i,j)+offset)*s._step
     if p.distance_to(Vector2(-1110.7,-757.5))>160:continue
     var v:=s.velocity_at(p);var h:=s.level_at(p)
     if not is_finite(h) or v.length()<.1:continue
     var a:=s.level_at(p-v.normalized()*.5);var b:=s.level_at(p+v.normalized()*.5)
     if not is_finite(a) or not is_finite(b):continue
     samples+=1
     if b-a>.025:uphill.append({"point":str(p),"rise":b-a,"velocity":str(v)})
 var report:={"samples":samples,"uphill":uphill}
 _character.global_position=Vector3(-1175.3,8,-731)
 await get_tree().physics_frame
 await get_tree().physics_frame
 _character._update_in_water()
 report["P01_in_water"]=_character.in_water
 report["P01_immersed"]=_character.immersed
 report["P01_wading"]=_character.wading
 var params:=PhysicsPointQueryParameters3D.new()
 params.position=_character.global_position+Vector3.UP*.3
 params.collide_with_areas=true;params.collide_with_bodies=false;params.collision_mask=_character.WATER_LAYER_MASK
 report["P01_trigger_hits"]=_camera.get_world_3d().direct_space_state.intersect_point(params,64).size()
 report["P01_levels"]=[]
 for s:WaterSampler in samplers:
  var h:=s.level_at(Vector2(-1175.3,-731))
  if is_finite(h):report.P01_levels.append(h)
 FileAccess.open(base.path_join("flow-report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("FLOW_REVIEW samples=",samples," uphill=",uphill.size()," P01_swim=",report.P01_in_water," hits=",report.P01_trigger_hits)
 for record:Array in _spots():
  if not record[0] in ["P01","P10","P21"]:continue
  _spot=record;_output_dir=base.path_join(record[0]);DirAccess.make_dir_recursive_absolute(_output_dir)
  await super._capture_views(world)
 _output_dir=base

func _shot(label:String)->void:
 var effect=preload("res://scripts/camera/UnderwaterView.gd").new()
 effect.camera=_camera;effect.world_seed=WORLD_SEED;add_child(effect)
 effect.update_view()
 await super._shot(label)
 effect.clear();effect.free()
