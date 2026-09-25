extends "res://tests/harness/september16_manual_qa.gd"
class WalkController extends CharacterController:
 var direction:=Vector2.ZERO
 func get_move_vector(_body:CharacterBody3D,_delta:float)->Vector2:return direction
func _capture_views(world:Node3D)->void:
 var rocks=preload("res://scripts/terrain/field/CliffRockDressing.gd");rocks.prepare()
 var space:=_camera.get_world_3d().direct_space_state
 var controller:=WalkController.new();_character.controller=controller
 var capsule_node:CollisionShape3D=_character.get_node("CollisionShape3D")
 var rows:=[];var seen:Dictionary={}
 for node:MultiMeshInstance3D in world.find_children("*","MultiMeshInstance3D",true,false):
  if not node.has_meta("cliff_asset"):continue
  if not node.has_meta("relief_green"):continue
  var asset:StringName=node.get_meta("cliff_asset")
  for index in node.multimesh.instance_count:
   var pose:Transform3D=node.global_transform*node.multimesh.get_instance_transform(index)
   if pose.origin.distance_to(_spot[2])>70:continue
   var tangent:=pose.basis.x.normalized();var outward:=pose.basis.z.normalized()
   var green:PackedVector3Array=node.get_meta("relief_green")
   for i in range(0,green.size(),3):
    var point:Vector3=pose*((green[i]+green[i+1]+green[i+2])/3)
    var key:=[pose.origin,snappedf(point.y,2.0)]
    var start_points:Dictionary={}
    if seen.has(key):continue
    var clear:=true
    for offset:float in [-1.2,-1.0,-.6,0,.6,1.0,1.2]:
     var p:=point+tangent*offset
     var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*1.6,p-Vector3.UP*1.6,_character.collision_mask,[_character.get_rid()]))
     if hit.is_empty() or hit.normal.y<cos(_character.floor_max_angle) or absf(hit.position.y-point.y)>1.3:clear=false;break
     var body:=hit.collider as StaticBody3D
     if body==null:clear=false;break
     var shape_node:Node=body.shape_owner_get_owner(body.shape_find_owner(hit.shape))
     if shape_node.name!=&"CliffRocks":clear=false;break
     p=hit.position
     start_points[offset]=p
     var capsule:=PhysicsShapeQueryParameters3D.new();capsule.shape=capsule_node.shape
     capsule.transform=Transform3D(_character.global_basis,p+Vector3.UP*.06)*capsule_node.transform
     capsule.collision_mask=_character.collision_mask;capsule.exclude=[_character.get_rid()]
     if not space.intersect_shape(capsule,1).is_empty():clear=false;break
    if not clear:continue
    seen[key]=true
    for side:float in [-1,1]:
     _character.global_position=start_points[-side]+Vector3.UP*.06
     _character.velocity=Vector3.ZERO;controller.direction=Vector2.ZERO
     for tick in 20:
      await get_tree().physics_frame;_character._physics_process(1.0/60)
     var start:=_character.global_position;var bad_contacts:=0;var contacts:Dictionary={}
     controller.direction=Vector2(tangent.x,tangent.z)*side
     for tick in 90:
      await get_tree().physics_frame;_character._physics_process(1.0/60)
      for contact in _character.get_slide_collision_count():
       var collision:=_character.get_slide_collision(contact)
       if collision.get_normal().y<-.1:bad_contacts+=1
       var collider:CollisionObject3D=collision.get_collider()
       var shape:Node=collider.shape_owner_get_owner(collider.shape_find_owner(collision.get_collider_shape_index()))
       contacts[str(shape.get_path())+str(collision.get_normal().snapped(Vector3.ONE*.01))]=true
      if (_character.global_position-start).dot(tangent*side)>=1.7:break
     var end:=_character.global_position
     var final_hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(end+Vector3.UP*.15,end-Vector3.UP*.2,_character.collision_mask,[_character.get_rid()]))
     var bearing:bool=not final_hit.is_empty() and absf(final_hit.position.y-end.y)<.1
     var passed:bool=_character.is_on_floor() and bearing and (end-start).dot(tangent*side)>=1.7 and bad_contacts==0
     rows.append({"asset":asset,"origin":str(pose.origin),"ledge_y":point.y,"side":side,"start":str(start),"end":str(end),"floor":_character.is_on_floor(),"underside_contacts":bad_contacts,"contacts":contacts.keys(),"passed":passed})
     controller.direction=Vector2.ZERO
     _camera.global_position=point+outward*13+tangent*7+Vector3.UP*7;_camera.look_at(point+Vector3.UP)
     await _shot("ledge_%02d"%rows.size())
    if rows.size()>=12:break
   if rows.size()>=12:break
  if rows.size()>=12:break
 FileAccess.open(_output_dir.path_join("walks.json"),FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
 assert(rows.size()>=6,"Need multiple actual ledges and both traversal directions")
 for row:Dictionary in rows:assert(row.passed,JSON.stringify(row))
 print("CLIFF_WALKS ",rows.size())
