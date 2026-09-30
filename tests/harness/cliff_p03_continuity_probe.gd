extends RefCounted
func run(review:Node3D)->void:
 var view:Dictionary=review._views[0]
 await review._grass_at(view.player)
 review._camera.fov=view.fov;review._camera.look_at_from_position(view.position,view.target,Vector3.UP)
 var rows:=[];var space:=review.get_world_3d().direct_space_state
 for point:Vector2 in [Vector2(320,590),Vector2(300,480),Vector2(580,235),Vector2(610,270),Vector2(1290,420),Vector2(1100,780),Vector2(1420,560)]:
  var start:Vector3=review._camera.project_ray_origin(point);var dir:Vector3=review._camera.project_ray_normal(point)
  var query:=PhysicsRayQueryParameters3D.create(start,start+dir*150,review._character.collision_mask,[review._character.get_rid()]);query.hit_back_faces=true
  var hit:=space.intersect_ray(query)
  rows.append({"pixel":str(point),"point":str(hit.get("position",Vector3.INF)),"normal":str(hit.get("normal",Vector3.ZERO)),"collider":str(hit.get("collider","none"))})
 FileAccess.open(review._output_dir+"/marked-rays.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
 for mode:String in ["Water","Cliffs","CliffFaces"]:
  var hidden:Array[Node3D]=[]
  for root:Node3D in review._streamer._built.values():
   var node:Node3D=root.get_node_or_null(mode)
   if node!=null and node.visible:node.visible=false;hidden.append(node)
  for tick in 5:await review.get_tree().process_frame
  RenderingServer.force_draw();await review.get_tree().process_frame
  review.get_viewport().get_texture().get_image().save_png(review._output_dir+"/before-without-"+mode+".png")
  for node:Node3D in hidden:node.visible=true
 var source:=load("res://scripts/terrain/field/CliffSlopeEnvelope.gd").source_code as String
 source=source.replace("var caps:=PackedFloat64Array()","env.set_meta(\"uncut\",env.surface.duplicate())\n var caps:=PackedFloat64Array()")
 source=source.replace("var uncut:=env.surface.duplicate()","env.set_meta(\"wet\",wet_level)\n env.set_meta(\"excluded\",excluded)\n var uncut:=env.surface.duplicate()")
 var script:=GDScript.new();script.source_code=source;assert(script.reload()==OK)
 var input:Dictionary=review._inputs[Vector2i(2,5)]
 var area:=Rect2(476,924,92,96)
 var field=load("res://scripts/terrain/field/CliffSlopeField.gd").new([],2697992464,input.region,area,input.features,input.water)
 var env=script.build(area,field._ground_sampler(),field._exclusion(area.grow(33)),2697992464,field._water_level())
 var data:={"origin":env.origin,"w":env.w,"h":env.h,"ground":env.ground,"surface":env.surface,"rock":env.rock,"uncut":env.get_meta("uncut"),"wet":env.get_meta("wet"),"excluded":env.get_meta("excluded")}
 FileAccess.open(review._output_dir+"/native-inputs.var",FileAccess.WRITE).store_var(data)
 print("[continuity_probe] ",JSON.stringify(rows))
