extends RefCounted
func run(review:Node3D)->void:
 var envs:=[]
 var FIELD=load("res://scripts/terrain/field/CliffSlopeField.gd")
 for chunk:Vector2i in [Vector2i(2,4),Vector2i(2,5)]:
  var input:Dictionary=review._inputs[chunk]
  var owned:=Rect2(Vector2(chunk*8)*24.0-Vector2(12,12),Vector2.ONE*192.0)
  var field=FIELD.new([],2697992464,input.region,owned,input.features,input.water)
  envs.append(field.envelope())
 var max_error:=0.0;var samples:=0;var examples:=[]
 for x in range(960,1121):
  for z in range(1892,1901):
   var q:=Vector2(x,z)*.5
   var error:float=absf(envs[0].at(q)-envs[1].at(q))
   max_error=maxf(max_error,error);samples+=1
   if error>.001 and examples.size()<10:examples.append({"q":str(q),"difference":error})
 var view:Dictionary=review._views[0]
 review._camera.fov=view.fov;review._camera.look_at_from_position(view.position,view.target,Vector3.UP)
 var contacts:=[];var space:=review.get_world_3d().direct_space_state
 for pixel:Vector2 in [Vector2(360,500),Vector2(380,580),Vector2(430,680)]:
  var a:Vector3=review._camera.project_ray_origin(pixel);var d:Vector3=review._camera.project_ray_normal(pixel)
  var query:=PhysicsRayQueryParameters3D.create(a,a+d*100,review._character.collision_mask,[review._character.get_rid()])
  query.hit_back_faces=true
  var hit:=space.intersect_ray(query)
  contacts.append({"pixel":str(pixel),"point":str(hit.get("position",Vector3.INF)),"distance":a.distance_to(hit.position) if not hit.is_empty() else INF})
 var result:={"shared_samples":samples,"maximum_height_disagreement":max_error,"examples":examples,"opening_rays":contacts}
 FileAccess.open(review._output_dir+"/seam-after.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 print("[p03_verify] ",JSON.stringify(result))
 assert(max_error<.000001,"Adjacent cliff chunks must share a continuous surface")
 for contact:Dictionary in contacts:assert(float(contact.distance)<20.0,"The formerly open foreground wall must intercept the ray")
