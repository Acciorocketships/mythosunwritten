extends RefCounted
func run(review:Node3D)->void:
 var view:Dictionary=review._views.filter(func(v:Dictionary)->bool:return v.id=="ledges-side-exterior")[0]
 review._camera.fov=view.fov;review._camera.look_at_from_position(view.position,view.target,Vector3.UP)
 for mode:String in ["none","Cliffs","CliffFaces","CliffRockFormations"]:
  var hidden:Array[Node3D]=[]
  for root:Node3D in review._streamer._built.values():
   var node:Node3D=root.get_node_or_null(mode)
   if node!=null and node.visible:node.visible=false;hidden.append(node)
  for tick in 5:await review.get_tree().process_frame
  RenderingServer.force_draw();await review.get_tree().process_frame
  review.get_viewport().get_texture().get_image().save_png(review._output_dir+"/ledge-without-"+mode+".png")
  for node:Node3D in hidden:node.visible=true
 print("[ledge_layers] captured")
