extends Node3D
## Art-only replay: current crags at saved production anchors, on frozen terrain.
## Does not rerun hydraulic admission, new ground seating, grass or collision.
const CRAGS=preload("res://scripts/terrain/field/CliffRockCrags.gd")
const ROCKS=preload("res://scripts/terrain/field/CliffRockDressing.gd")
const SNAPSHOT="res://docs/qa/2026-09-16-manual/10-rounded-ledges/production-01/world.scn"
func _ready()->void:
 var output:="res://docs/qa/2026-09-16-manual/11-fractured-outcrops/context-01"
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
 DirAccess.make_dir_recursive_absolute(output)
 var view:=SubViewport.new();view.size=Vector2i(1600,1000);view.own_world_3d=true
 view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;view.msaa_3d=Viewport.MSAA_4X;add_child(view)
 var world:Node3D=load(SNAPSHOT).instantiate();view.add_child(world)
 for key:StringName in world.get_meta("shader_globals",{}):RenderingServer.global_shader_parameter_set(key,world.get_meta("shader_globals")[key])
 var camera:=Camera3D.new();world.add_child(camera);camera.current=true;camera.near=.1;camera.far=500;camera.fov=65
 var generator:GDScript=preload("res://tests/fixtures/september16/crags_before_variability.gd") if "--before" in OS.get_cmdline_user_args() else CRAGS
 ROCKS.prepare()
 var forms:Array=[];var replaced:=0;var center:=Vector3(-452,32,-272)
 for node:MultiMeshInstance3D in world.find_children("*","MultiMeshInstance3D",true,false):
  if not node.has_meta("cliff_asset"):continue
  if not node.has_meta("relief_faces"):
   # Remove stale cliff plants from the close review area; current contacts follow.
   var mm:=node.multimesh.duplicate();node.multimesh=mm
   for i in mm.instance_count:
    var pose:Transform3D=node.global_transform*mm.get_instance_transform(i)
    if Vector2(pose.origin.x-center.x,pose.origin.z-center.z).length()<85:
     mm.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO),pose.origin))
   continue
  var pose:Transform3D=node.global_transform*node.multimesh.get_instance_transform(0)
  if Vector2(pose.origin.x-center.x,pose.origin.z-center.z).length()>85:continue
  var faces:PackedVector3Array=node.get_meta("relief_faces")
  var box:=AABB(faces[0],Vector3.ZERO)
  for point:Vector3 in faces:box=box.expand(point)
  var left:=-INF;var right:=-INF
  for point:Vector3 in faces:
   if absf(point.x-box.position.x)<.001:left=maxf(left,point.z)
   if absf(point.x-box.end.x)<.001:right=maxf(right,point.z)
  var current:Array=generator.make(pose,box.size.x,box.end.y,2697992464,null,left<-.49,right<-.49)
  forms.append_array(current);node.visible=false;replaced+=1
 var built:=ROCKS.build({"placements":forms+ROCKS.plants(forms,null,2697992464)},2697992464)
 var index:=0
 for node:Node in built.get_children():
  if node.has_meta("relief_faces"):
   node.multimesh.mesh=generator.mesh(forms[index]);index+=1
 world.add_child(built)
 _freeze_material_clocks(world)
 print("ART_CONTEXT replaced=",replaced," source=",SNAPSHOT)
 var shots:Array=[
  ["P12_front",Vector3(-423,40,-292),Vector3(-442,36,-298)],
  ["P12_side",Vector3(-414,42,-311),Vector3(-442,35,-298)],
  ["P17_front",Vector3(-425,39,-247),Vector3(-445,34,-250)],
  ["P20_oblique",Vector3(-482,42,-229),Vector3(-483,36,-249)],
  ["P05_vines",Vector3(-427,36,-263),Vector3(-445,36,-269)]]
 for shot:Array in shots:
  camera.position=shot[1];camera.look_at(shot[2])
  for frame in 12:await get_tree().process_frame
  await RenderingServer.frame_post_draw
  view.get_texture().get_image().save_png(output.path_join(shot[0]+".png"))
  print("ART_CONTEXT ",shot[0])
 for site:String in ["P05","P12","P17","P20"]:
  var records:Array=JSON.parse_string(FileAccess.get_file_as_string("res://docs/qa/2026-09-16-manual/10-rounded-ledges/production-01/"+site+"/poses.json"))
  for record:Dictionary in records:
   var numbers:=RegEx.new();numbers.compile("-?[0-9]+(?:\\.[0-9]+)?")
   var values:Array[float]=[]
   for match in numbers.search_all(record.camera):values.append(float(match.get_string()))
   assert(values.size()==12)
   camera.transform=Transform3D(Basis(Vector3(values[0],values[1],values[2]),Vector3(values[3],values[4],values[5]),Vector3(values[6],values[7],values[8])),Vector3(values[9],values[10],values[11]))
   camera.fov=record.fov
   for frame in 8:await get_tree().process_frame
   await RenderingServer.frame_post_draw
   var id:=site+"_reported_%d"%int(record.angle)
   view.get_texture().get_image().save_png(output.path_join(id+".png"))
   print("ART_CONTEXT ",id)
 FileAccess.open(output.path_join("scope.txt"),FileAccess.WRITE).store_string("Art-only frozen context: current crags at saved anchors, with current crevice plants. Original terrain/atmosphere/grass/collision. Hydraulic placement, native seating and traversal are not verified by this replay.\n")
 get_tree().quit()

func _freeze_material_clocks(world: Node3D) -> void:
 var materials := {}
 for node: Node in world.find_children("*","GeometryInstance3D",true,false):
  var mesh: Mesh = node.mesh if node is MeshInstance3D else node.multimesh.mesh if node is MultiMeshInstance3D and node.multimesh != null else null
  if node.material_override != null: materials[node.material_override.get_instance_id()] = node.material_override
  if mesh != null:
   for surface in mesh.get_surface_count():
    var material := mesh.surface_get_material(surface)
    if material != null: materials[material.get_instance_id()] = material
 for material: Material in materials.values():
  if material is ShaderMaterial and material.shader != null and material.shader.code.contains("TIME"):
   var shader := Shader.new()
   shader.code = material.shader.code.replace("TIME","0.0")
   material.shader = shader

