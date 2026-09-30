extends RefCounted
func run(review:Node3D)->void:
 var view:Dictionary=review._views[0]
 await review._grass_at(view.player)
 review._camera.fov=view.fov
 review._camera.look_at_from_position(view.position,view.target,Vector3.UP)
 var space:=review.get_world_3d().direct_space_state
 var rows:=[]
 for point:Vector2 in [Vector2(360,500),Vector2(380,580),Vector2(430,680),Vector2(570,630),Vector2(500,250),Vector2(620,230),Vector2(1390,235),Vector2(1400,630),Vector2(1360,590),Vector2(1490,750)]:
  var start:Vector3=review._camera.project_ray_origin(point)
  var direction:Vector3=review._camera.project_ray_normal(point)
  var query:=PhysicsRayQueryParameters3D.create(start,start+direction*500,review._character.collision_mask,[review._character.get_rid()])
  query.hit_back_faces=true
  var hit:=space.intersect_ray(query)
  rows.append({"pixel":str(point),"position":str(hit.get("position",Vector3.INF)),"normal":str(hit.get("normal",Vector3.ZERO)),"collider":str(hit.get("collider","none")),"ray_start":str(start),"ray_direction":str(direction)})
 var nodes:=[]
 for chunk:Vector2i in review._streamer._built:
  var root:Node3D=review._streamer._built[chunk]
  nodes.append({"chunk":str(chunk),"children":root.get_children().map(func(n:Node)->String:return n.name)})
 FileAccess.open(review._output_dir+"/diagnosis.json",FileAccess.WRITE).store_string(JSON.stringify({"rays":rows,"nodes":nodes},"  "))
 for mode:String in ["Cliffs","CliffFaces","Surface","GradedCliffs","Water","CliffRockFormations"]:
  var hidden:Array[Node3D]=[]
  for root:Node3D in review._streamer._built.values():
   var node:Node3D=root.get_node_or_null(mode)
   if node!=null and node.visible:node.visible=false;hidden.append(node)
  for tick in 5:await review.get_tree().process_frame
  RenderingServer.force_draw()
  await review.get_tree().process_frame
  review.get_viewport().get_texture().get_image().save_png(review._output_dir+"/without-"+mode+".png")
  for node:Node3D in hidden:node.visible=true
 var tints:=[]
 for root:Node3D in review._streamer._built.values():
  for node:MultiMeshInstance3D in root.find_children("*","MultiMeshInstance3D",true,false):
   if not node.has_meta("relief_faces"):continue
   tints.append([node.multimesh,node.multimesh.get_instance_color(0)])
   node.multimesh.set_instance_color(0,Color.WHITE)
 for tick in 5:await review.get_tree().process_frame
 RenderingServer.force_draw()
 await review.get_tree().process_frame
 review.get_viewport().get_texture().get_image().save_png(review._output_dir+"/single-tint-control.png")
 for pair:Array in tints:pair[0].set_instance_color(0,pair[1])
 FileAccess.open(review._output_dir+"/runtime-envelope-source.gd",FileAccess.WRITE).store_string(load("res://scripts/terrain/field/CliffSlopeEnvelope.gd").source_code)
 # Freeze the actual terrain envelope around the marked foreground for fast tests.
 var cells:=TerrainChunkMesher.CELLS_PER_CHUNK
 for chunk:Vector2i in review._inputs:
  var input:Dictionary=review._inputs[chunk]
  var owned:=Rect2(Vector2(chunk*cells)*24.0-Vector2(12,12),Vector2.ONE*cells*24.0)
  var field=load("res://scripts/terrain/field/CliffSlopeField.gd").new([],2697992464,input.region,owned,input.features,input.water)
  var env=field.envelope()
  var data:={"origin":env.origin,"w":env.w,"h":env.h,"ground":env.ground,"surface":env.surface,"rock":env.rock}
  FileAccess.open(review._output_dir+"/envelope-%s-%s.var"%[chunk.x,chunk.y],FileAccess.WRITE).store_var(data)
 await load("res://tests/harness/cliff_p03_audit.gd").new().run(review)
 print("[p03_diagnose] ",JSON.stringify(rows))
