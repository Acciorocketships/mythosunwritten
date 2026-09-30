extends RefCounted
func run(review:Node3D)->void:
 var space:=review.get_world_3d().direct_space_state;var rows:=[]
 for view:Dictionary in review._views:
  var p:Vector3=view.position
  var query:=PhysicsRayQueryParameters3D.create(p+Vector3.UP*120,p-Vector3.UP*120,review._character.collision_mask,[review._character.get_rid()]);query.hit_back_faces=true
  var hit:=space.intersect_ray(query)
  rows.append({"view":view.id,"position":str(p),"surface":str(hit.get("position",Vector3.INF)),"clearance":p.y-hit.position.y if not hit.is_empty() else INF})
 FileAccess.open(review._output_dir+"/camera-clearance.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
 print("[camera_clearance] ",JSON.stringify(rows))
