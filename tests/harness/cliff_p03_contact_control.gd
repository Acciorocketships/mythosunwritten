extends RefCounted
func run(review:Node3D)->void:
 var view:Dictionary=review._views[0]
 await review._grass_at(view.player)
 review._camera.fov=view.fov;review._camera.look_at_from_position(view.position,view.target,Vector3.UP)
 for mode:String in ["Cliffs","CliffFaces","Surface"]:
  var hidden:Array[Node3D]=[]
  for root:Node3D in review._streamer._built.values():
   var node:Node3D=root.get_node_or_null(mode)
   if node!=null and node.visible:node.visible=false;hidden.append(node)
  for tick in 5:await review.get_tree().process_frame
  RenderingServer.force_draw();await review.get_tree().process_frame
  review.get_viewport().get_texture().get_image().save_png(review._output_dir+"/21-without-"+mode+".png")
  for node:Node3D in hidden:node.visible=true
 var target:=Vector3(517.499145507812,25.9538021087646,970.000305175781)
 var rows:=[];var space:=review.get_world_3d().direct_space_state
 for root:Node3D in review._streamer._built.values():
  for node:MultiMeshInstance3D in root.find_children("*","MultiMeshInstance3D",true,false):
   if not node.has_meta("relief_faces"):continue
   var faces:PackedVector3Array=node.get_meta("relief_faces")
   for i in range(0,faces.size(),3):
    var a:Vector3=node.global_transform*faces[i];var b:Vector3=node.global_transform*faces[i+1];var c:Vector3=node.global_transform*faces[i+2]
    var p:Vector3=(a+b+c)/3.0
    if p.distance_to(target)>.01:continue
    var cross:Vector3=(c-a).cross(b-a);var normal:=cross.normalized()
    var hits:=[]
    for distance:float in [.08,.2,.5]:
     for back:bool in [false,true]:
      var query:=PhysicsRayQueryParameters3D.create(p+normal*distance,p-normal*distance,review._character.collision_mask,[review._character.get_rid()])
      query.hit_back_faces=back
      var hit:=space.intersect_ray(query)
      hits.append({"distance":distance,"back":back,"hit":str(hit.get("position",Vector3.INF))})
    rows.append({"a":str(a),"b":str(b),"c":str(c),"area":cross.length()*.5,"hits":hits})
 FileAccess.open(review._output_dir+"/contact-control.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
 print("[p03_contact_control] ",JSON.stringify(rows))
