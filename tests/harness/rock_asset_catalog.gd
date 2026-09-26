extends SceneTree
## Original asset contact sheets; no terrain deformation or game rock shader.
const OUT="res://docs/qa/2026-09-25-rock-catalog/"
func _initialize()->void:call_deferred("_run")
func label(parent:Node,text:String,pos:Vector2,size:int,color:=Color(.88,.91,.95))->void:
 var l:=Label.new();l.text=text;l.position=pos;l.add_theme_font_size_override("font_size",size);l.add_theme_color_override("font_color",color);parent.add_child(l)
func asset_bounds(node:Node3D)->AABB:
 var result:=AABB();var first:=true
 for child in node.find_children("*","MeshInstance3D",true,false):
  var mesh:=child as MeshInstance3D
  if mesh.mesh==null:continue
  var pose:=Transform3D.IDENTITY;var current:Node=mesh
  while current!=node:pose=(current as Node3D).transform*pose;current=current.get_parent()
  var box:AABB=pose*mesh.mesh.get_aabb()
  if first:result=box;first=false
  else:result=result.merge(box)
 return result
func view(parent:Node,source:Node3D,box:AABB,pos:Vector2,reverse:bool)->void:
 var container:=SubViewportContainer.new();container.position=pos;parent.add_child(container)
 var vp:=SubViewport.new();vp.size=Vector2i(248,260);vp.own_world_3d=true;vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;vp.msaa_3d=Viewport.MSAA_4X;container.add_child(vp)
 var world:=Node3D.new();vp.add_child(world)
 var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.23,.27,.31);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color(.96,.97,1);env.environment.ambient_light_energy=.65;world.add_child(env)
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-45,-25,0);light.light_energy=1.;world.add_child(light)
 var fill:=DirectionalLight3D.new();fill.rotation_degrees=Vector3(-20,145,0);fill.light_energy=.35;world.add_child(fill)
 var pivot:=Node3D.new();world.add_child(pivot)
 var rock:Node3D=source.duplicate();pivot.add_child(rock)
 var extent:=maxf(box.size.x,maxf(box.size.y,box.size.z));var scale_value:=3.5/maxf(.001,extent)
 pivot.scale=Vector3.ONE*scale_value;rock.position-=box.get_center()
 var cam:=Camera3D.new();world.add_child(cam);cam.projection=Camera3D.PROJECTION_ORTHOGONAL;cam.size=4.6;cam.position=Vector3(-5,2.7,-6) if reverse else Vector3(5,2.7,6);cam.look_at(Vector3.ZERO);cam.current=true
func _run()->void:
 var pages:Array=JSON.parse_string(FileAccess.get_file_as_string(OUT+"manifest.json"))
 var only:=""
 var restored:=OS.get_cmdline_user_args().has("--meadow-material")
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with("--page="):only=arg.trim_prefix("--page=")
 for page:Dictionary in pages:
  if not only.is_empty() and not String(page.file).begins_with(only):continue
  var vp:=SubViewport.new();vp.size=Vector2i(2048,1140);vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(vp)
  var panel:=ColorRect.new();panel.size=Vector2(2048,1140);panel.color=Color(.105,.13,.16);vp.add_child(panel)
  label(panel,page.title+(" · restored grass layer" if restored else ""),Vector2(24,15),34)
  label(panel,("Original geometry / restored Meadow shader" if restored else "Original geometry / imported materials")+"   •   Two opposite angles   •   Scaled to fit, not to common world size",Vector2(26,60),20,Color(.64,.72,.78))
  for i in page.items.size():
   var item:Dictionary=page.items[i];var pos:=Vector2(24+(i%4)*506,100+(i/4)*342)
   label(panel,item.id+"   "+item.name, pos,20)
   var resource=load(item.path) if ResourceLoader.exists(item.path) else null
   if resource==null and String(item.path).get_extension()=="gltf":
    var doc:=GLTFDocument.new();var state:=GLTFState.new()
    if doc.append_from_file(item.path,state)==OK:
     var imported:=doc.generate_scene(state);var packed:=PackedScene.new();packed.pack(imported);imported.free();resource=packed
   if resource==null:label(panel,"Unable to load source",pos+Vector2(0,80),20);push_error(item.path);continue
   var source:Node3D
   if resource is PackedScene:source=resource.instantiate()
   elif resource is Mesh:
    source=Node3D.new();var mesh:=MeshInstance3D.new();mesh.mesh=resource;source.add_child(mesh)
   else:continue
   if restored:
    var number:=int(String(item.id).trim_prefix("M"))
    for mesh:MeshInstance3D in source.find_children("*","MeshInstance3D",true,false):
     mesh.material_override=preload("res://scripts/terrain/field/MeadowRockMaterial.gd").make(number)
   var box:=asset_bounds(source)
   view(panel,source,box,pos+Vector2(0,34),false);view(panel,source,box,pos+Vector2(250,34),true)
   label(panel,"%.1f × %.1f × %.1f m  "%[box.size.x,box.size.y,box.size.z],pos+Vector2(0,298),18,Color(.65,.74,.79))
   source.free()
  await process_frame;await process_frame;await process_frame;await RenderingServer.frame_post_draw
  var path:String=("res://docs/qa/2026-09-25-meadow-world/" if restored else OUT)+page.file
  vp.get_texture().get_image().save_png(path);print("CATALOG ",path)
  vp.queue_free();await process_frame
 quit()
