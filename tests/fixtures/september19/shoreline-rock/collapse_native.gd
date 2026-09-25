extends SceneTree
const OUT="res://docs/qa/2026-09-19-manual/121-shoreline-rock"
func _init()->void:run.call_deferred()
func run()->void:
 root.size=Vector2i(960,720);Engine.max_fps=30
 var rocks=preload("res://scripts/terrain/field/CliffRockDressing.gd");rocks.prepare()
 var forms:Array=FileAccess.open(OUT.path_join("owned/banks.bin"),FileAccess.READ).get_var()
 var form:Dictionary={}
 for f:Dictionary in forms:
  if (f.anchor as Vector3).distance_to(Vector3(-517.5,8,337.5))<.01:form=f.duplicate(true)
 form.faces=form.shore_source_faces;form.green=PackedVector3Array();form.erase("render_arrays");form.erase("native_roots")
 var fixed:=form.duplicate(true)
 preload("res://scripts/terrain/field/CliffLedgeJoin.gd").apply(fixed,[])
 var a:=MeshInstance3D.new();a.mesh=rocks.CRAGS.mesh(form);a.transform=form.transform;root.add_child(a)
 var b:=MeshInstance3D.new();b.mesh=rocks.CRAGS.mesh(fixed);b.transform=fixed.transform;root.add_child(b)
 var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("c9dfe1");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.5;root.add_child(env)
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-45,-30,0);root.add_child(light)
 var camera:=Camera3D.new();root.add_child(camera);camera.current=true;camera.fov=60
 var center:Vector3=form.transform.origin+Vector3.UP*5
 camera.position=center+form.transform.basis.z*28+form.transform.basis.x*9+Vector3.UP*7;camera.look_at(center)
 var before:Image
 for after:bool in [false,true]:
  a.visible=not after;b.visible=after
  for i in 5:await process_frame
  RenderingServer.force_draw(false)
  var captured:=root.get_texture().get_image()
  captured.save_png(OUT.path_join("collapse-%s.png"%["after" if after else "before"]))
  if not after:before=captured
  else:
   var changed:=0
   for y in captured.get_height():
    for x in captured.get_width():
     if captured.get_pixel(x,y)!=before.get_pixel(x,y):changed+=1
   print("COLLAPSE_NATIVE changed_pixels=",changed)
   FileAccess.open(OUT.path_join("collapse-native.json"),FileAccess.WRITE).store_string(JSON.stringify({"changed_pixels":changed,"pixels":captured.get_width()*captured.get_height()}))
   assert(changed==0,"Removing zero-area join triangles must retain the native rendered shape and shading")
 quit()
