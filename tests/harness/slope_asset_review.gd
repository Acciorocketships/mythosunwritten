extends SceneTree
func _initialize()->void:call_deferred("_run")
func _run()->void:
 root.size=Vector2i(1600,1000)
 var scene:=Node3D.new();root.add_child(scene)
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-45,-35,0);scene.add_child(light)
 var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.25,.3,.34);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.5;scene.add_child(env)
 var paths:Array[String]=[]
 for i in range(1,13):paths.append("res://assets/ANGRY MESH/Models/Stylized_Pack_-_Meadow_Environment/Rocks/Rocks_-_Summer/P_Rock_%02d_Summer.glb"%i)
 for i in range(1,8):paths.append("res://assets/Polyart/Models/Farmlands/Stones/PF_Farm_RockMedium_%02d.glb"%i)
 for i in range(1,4):paths.append("res://assets/Polyart/Models/Farmlands/Stones/PF_Farm_Cliff_Large_%02d.glb"%i)
 var mat:=StandardMaterial3D.new();mat.albedo_color=Color(.55,.51,.46);mat.roughness=1
 for i in paths.size():
  var asset:Node3D=load(paths[i]).instantiate()
  var instance:MeshInstance3D=asset.find_children("*","MeshInstance3D",true,false)[0]
  var pose:=Transform3D.IDENTITY;var node:Node=instance
  while node!=asset:pose=(node as Node3D).transform*pose;node=node.get_parent()
  var box:AABB=pose*instance.mesh.get_aabb()
  print(paths[i].get_file()," ",box.size)
  var sc:=3.6/maxf(box.size.x,maxf(box.size.y,box.size.z))
  var position:=Vector3((i%6)*5.5,0,(i/6)*6.)
  var mesh:=MeshInstance3D.new();mesh.mesh=instance.mesh;mesh.material_override=mat;mesh.transform=Transform3D(Basis.from_scale(Vector3.ONE*sc),position)*Transform3D(Basis(),-box.get_center()+Vector3.UP*box.size.y*.5)*pose
  scene.add_child(mesh)
  var label:=Label3D.new();label.text=paths[i].get_file().replace("P_Rock_","Meadow ").replace("_Summer.glb","").replace("PF_Farm_","Farm ").replace(".glb","");label.font_size=34;label.pixel_size=.01;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.position=position+Vector3(0,0,2.3);scene.add_child(label)
  asset.free()
 var cam:=Camera3D.new();scene.add_child(cam);cam.projection=Camera3D.PROJECTION_ORTHOGONAL;cam.size=36;cam.position=Vector3(21,29,38);cam.look_at(Vector3(13,0,9));cam.current=true
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("/tmp/cliff-flanks/assets.png");quit()
