extends RefCounted
class WalkController extends CharacterController:
 var direction:=Vector2.ZERO
 func get_move_vector(_body:CharacterBody3D,_dt:float)->Vector2:return direction
func run(review:Node3D)->void:
 var body:CharacterBody3D=review._character
 var original:CharacterController=body.controller
 var position:Vector3=body.global_position
 var controller:=WalkController.new();body.controller=controller
 var streamer:FieldTerrainStreamer=review._streamer
 streamer.set_process(false);streamer._freeze_player(false)
 body.set_physics_process(false)
 var space:=review.get_world_3d().direct_space_state
 var rows:=[]
 for site:Vector2 in [Vector2(510,948),Vector2(516,948),Vector2(548,972)]:
  for direction:float in [1.0,-1.0]:
   var z:=site.y-2.5 if direction>0 else site.y+.5
   var start:=Vector3(site.x,80,z)
   var query:=PhysicsRayQueryParameters3D.create(start,start-Vector3.UP*80,body.collision_mask,[body.get_rid()]);query.hit_back_faces=true
   var hit:=space.intersect_ray(query);assert(not hit.is_empty())
   body.global_position=hit.position+Vector3.UP*.06;body.velocity=Vector3.ZERO;controller.direction=Vector2.ZERO
   for tick in 30:
    await review.get_tree().physics_frame;body._physics_process(1.0/60.0)
   start=body.global_position
   controller.direction=Vector2(0,direction)
   var trace:=[]
   for tick in 300:
    await review.get_tree().physics_frame;body._physics_process(1.0/60.0)
    if tick%15==0:trace.append([body.position.x,body.position.y,body.position.z])
    if (body.position.z-start.z)*direction>=3.0:break
   var travel:float=(body.position.z-start.z)*direction
   rows.append({"site":str(site),"direction":direction,"travel":travel,"rise":body.position.y-start.y,"passed":travel>=3.0,"on_floor":body.is_on_floor(),"trace":trace})
   controller.direction=Vector2.ZERO
 body.controller=original;body.global_position=position;body.velocity=Vector3.ZERO
 streamer.set_process(true)
 FileAccess.open(review._output_dir+"/crown-walks.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
 print("[crown_walks] ",JSON.stringify(rows))
 for row:Dictionary in rows:assert(row.passed,"The actual character must traverse the rounded crown in both directions")
