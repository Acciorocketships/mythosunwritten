extends SceneTree
const OUT="res://docs/qa/2026-09-19-manual/124-bank-water"
func _init()->void:run.call_deferred()
func run()->void:
 Engine.max_fps=30;root.size=Vector2i(1280,800)
 var stage:Node3D=load("res://docs/qa/2026-09-19-manual/119-small-town/world.scn").instantiate();root.add_child(stage)
 for key:StringName in stage.get_meta("shader_globals",{}):
  if key in [&"biome_ground_a",&"biome_ground_b",&"biome_ground_color",&"biome_ground_origin",&"grass_lod_origin",&"wind_direction",&"wind_idle_bend",&"wind_gust_texture",&"wind_gust_scale",&"wind_gust_speed",&"wind_gust_bend",&"grass_trample_texture",&"grass_static_trample_texture",&"grass_trample_origin",&"grass_trample_size",&"grass_trample_epoch"]:RenderingServer.global_shader_parameter_set(key,stage.get_meta("shader_globals")[key])
 RenderingServer.global_shader_parameter_set(&"grass_lod_origin",Vector2(-519.5,326.4))
 preload("res://tests/fixtures/september19/bank-water/grass.gd").add_to(root)
 var sheets:Array[MeshInstance3D]=[];var originals:Array=[];var records:Array=[]
 for node:Node in stage.find_children("*","MeshInstance3D",true,false):
  var material:Material=node.get_active_material(0)
  if not material is ShaderMaterial:continue
  if material.shader==null or not material.shader.resource_path.ends_with("water_unified.gdshader"):continue
  sheets.append(node);originals.append(node.material_override)
  var box:AABB=node.global_transform*node.get_aabb();records.append({"name":node.name,"bounds":box})
  var body:=StaticBody3D.new();body.collision_layer=64;body.collision_mask=0
  var shape:=CollisionShape3D.new();var mesh:=ConcavePolygonShape3D.new();mesh.set_faces(node.mesh.get_faces());mesh.backface_collision=true;shape.shape=mesh
  body.add_child(shape);root.add_child(body);body.global_transform=node.global_transform
 await physics_frame;await physics_frame
 var probes:Array=[]
 for x:float in [-530,-520,-510,-500,-490,-480]:
  for z in range(288,337):
   var hit:=root.world_3d.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x,80,z),Vector3(x,-20,z),64))
   if not hit.is_empty():probes.append({"position":hit.position,"normal":hit.normal})
 FileAccess.open(OUT.path_join("mesh-probes.json"),FileAccess.WRITE).store_string(JSON.stringify({"sheets":records,"probes":probes},"  "))
 var camera:=Camera3D.new();root.add_child(camera);camera.current=true;camera.fov=75
 var feet:=Vector3(-519.5,20,326.4);var aim:=Vector3(-499.7,8,306.5)
 var pivot:=feet+Vector3.UP*CameraMouseView.PIVOT_HEIGHT;var backward:=(pivot-aim).normalized()
 var eye:=ReviewCam.solve_cam(feet,aim,Vector2(backward.x,backward.z).length()*CameraMouseView.BOOM_LENGTH,CameraMouseView.PIVOT_HEIGHT+backward.y*CameraMouseView.BOOM_LENGTH,CameraMouseView.PIVOT_HEIGHT)
 var opaque:=StandardMaterial3D.new();opaque.albedo_color=Color(.08,.35,.6);opaque.roughness=.85;opaque.cull_mode=BaseMaterial3D.CULL_DISABLED
 for angle:int in [0,-35,35]:
  camera.position=pivot+(eye-pivot).rotated(Vector3.UP,deg_to_rad(angle));camera.look_at(pivot)
  for mode:String in ["original","opaque","hidden"]:
   for i in sheets.size():
    sheets[i].visible=mode!="hidden";sheets[i].material_override=opaque if mode=="opaque" else originals[i]
   for i in 5:await process_frame
   RenderingServer.force_draw(false);root.get_texture().get_image().save_png(OUT.path_join("%s-%d.png"%[mode,angle]))
 print("BANK_WATER_REPLAY sheets=",sheets.size()," probes=",probes.size())
 quit()
