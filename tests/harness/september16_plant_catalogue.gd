extends SceneTree
## Actual local source models under common studio lighting; no production claim.
func _initialize()->void:
 call_deferred("_run")
func _run()->void:
 var view:=SubViewport.new();view.size=Vector2i(1800,1200);view.own_world_3d=true
 view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;view.msaa_3d=Viewport.MSAA_4X;root.add_child(view)
 var stage:=Node3D.new();view.add_child(stage)
 var env:=WorldEnvironment.new();env.environment=Environment.new()
 env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.16,.19,.21)
 env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.8;stage.add_child(env)
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-50,-35,0);light.light_energy=1.2;stage.add_child(light)
 var camera:=Camera3D.new();stage.add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=27
 camera.position=Vector3(0,25,24);camera.look_at(Vector3.ZERO);camera.current=true
 var entries:=[]
 for name:String in ["Fern_1","Plant_1","Plant_7","Bush_Common","Bush_Common_Flowers"]:
  entries.append(["Stylized / "+name,"res://assets/StylizedNatureQuaternius/glTF/"+name+".gltf"])
 for i in 4:entries.append(["Fantasy / Plant_0%d"%(i+1),"res://assets/LowPolyFantasyVillage/Models/Nature/Plant_0%d.glb"%(i+1)])
 for i:int in [1,2,4,5,6,9]:entries.append(["Medieval / Vine%d"%i,"res://assets/MedievalVillageQuaternius/glTF/Prop_Vine%d.gltf"%i])
 var metadata:=[]
 for i in entries.size():
  var doc:=GLTFDocument.new();var state:=GLTFState.new();assert(doc.append_from_file(entries[i][1],state)==OK)
  var model:=doc.generate_scene(state);var meshes:=model.find_children("*","MeshInstance3D",true,false)
  var box:=AABB();var first:=true
  for node:MeshInstance3D in meshes:
   var pose:=node.transform;var parent:=node.get_parent()
   while parent!=model and parent is Node3D:pose=parent.transform*pose;parent=parent.get_parent()
   var bounds:AABB=pose*node.mesh.get_aabb();box=bounds if first else box.merge(bounds);first=false
  var scale_value:=3.2/maxf(box.size.x,maxf(box.size.y,box.size.z))
  var cell:=Vector3((i%5-2)*5.0,0,(i/5-1)*6.0)
  stage.add_child(model);model.scale=Vector3.ONE*scale_value;model.position=cell-Vector3(box.get_center().x,box.position.y,box.get_center().z)*scale_value
  var label:=Label3D.new();label.text=entries[i][0];label.font_size=32;label.pixel_size=.007
  label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.no_depth_test=true;label.position=cell+Vector3(0,-.3,2.0);stage.add_child(label)
  metadata.append({"name":entries[i][0],"source":entries[i][1],"bounds":str(box),"preview_scale":scale_value})
 for frame in 12:await process_frame
 await RenderingServer.frame_post_draw
 var output:="res://docs/qa/2026-09-16-manual/07-cliff-planting"
 view.get_texture().get_image().save_png(output.path_join("plant-catalogue.png"))
 FileAccess.open(output.path_join("plant-catalogue.json"),FileAccess.WRITE).store_string(JSON.stringify(metadata,"  "))
 quit()
