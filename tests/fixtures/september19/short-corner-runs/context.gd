extends Node3D
## Art-only replay: current crags at saved production anchors, on frozen terrain.
## Does not rerun hydraulic admission, new ground seating, grass or collision.
const CRAGS=preload("res://scripts/terrain/field/CliffRockCrags.gd")
const ROCKS=preload("res://scripts/terrain/field/CliffRockDressing.gd")
const REPLAY=preload("res://tests/fixtures/cliff_snapshot_replay.gd")
const SNAPSHOT="res://docs/qa/2026-09-16-manual/10-rounded-ledges/production-01/world.scn"
func _ready()->void:
 var output:="res://docs/qa/2026-09-16-manual/12-cliff-transition/context-01"
 var snapshot:=SNAPSHOT
 var center:=Vector3(-452,32,-272)
 var single_site:=""
 var poses_root:=""
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
  if arg.begins_with("--snapshot="):snapshot=arg.trim_prefix("--snapshot=")
  if arg.begins_with("--site="):single_site=arg.trim_prefix("--site=")
  if arg.begins_with("--poses-root="):poses_root=arg.trim_prefix("--poses-root=")
  if arg.begins_with("--center="):
   var coordinates:=arg.trim_prefix("--center=").split(",")
   assert(coordinates.size()==3)
   center=Vector3(float(coordinates[0]),float(coordinates[1]),float(coordinates[2]))
 DirAccess.make_dir_recursive_absolute(output)
 var benchmark:="--benchmark-stone" in OS.get_cmdline_user_args()
 if benchmark:
  Engine.max_fps=0
  DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 var view:=SubViewport.new();view.size=Vector2i(1600,1000);view.own_world_3d=true
 view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;view.msaa_3d=Viewport.MSAA_4X;add_child(view)
 var world:Node3D=load(snapshot).instantiate();view.add_child(world)
 for key:StringName in world.get_meta("shader_globals",{}):RenderingServer.global_shader_parameter_set(key,world.get_meta("shader_globals")[key])
 var camera:=Camera3D.new();world.add_child(camera);camera.current=true;camera.near=.1;camera.far=500;camera.fov=65
 var generator:GDScript=preload("res://tests/fixtures/september16/crags_before_wall_transition.gd") if "--before" in OS.get_cmdline_user_args() else CRAGS
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with("--generator="):generator=load(arg.trim_prefix("--generator="))
 var corner_generator:GDScript=preload("res://scripts/terrain/field/CliffCornerCrags.gd")
 var custom_corner:=false
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with("--corner-generator="):
   corner_generator=load(arg.trim_prefix("--corner-generator="));custom_corner=true
 ROCKS.prepare()
 var forms:Array=[];var replaced:=0;var corner_poses:Dictionary={}
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
  var current:Dictionary={"faces":faces,"green":node.get_meta("relief_green"),"transform":pose,"anchor":pose.origin,"id":str(pose),"replay_recipe":node.get_meta("relief_recipe"),"kind":"rock","asset":&"cliff.native_crag","native_crag":true}
  var box:=AABB(faces[0],Vector3.ZERO)
  for p:Vector3 in faces:box=box.expand(p)
  current.bounds=pose*box;current.top=current.bounds.end.y;current.base=current.bounds.position.y
  if current.replay_recipe.kind in ["corner","inner_corner"]:
   current=REPLAY.rebuild(pose,faces,current.replay_recipe,generator,corner_generator)
   assert(current.faces==faces,"Frozen corner must keep exact native geometry")
  if current.has("native_roots"):
   if generator!=CRAGS and not custom_corner:
    push_error("A custom wall generator needs its matching --corner-generator for a faithful corner comparison")
    get_tree().quit(1);return
   corner_poses[pose]=true
  forms.append(current);node.visible=false;replaced+=1
 if "--corner-study" in OS.get_cmdline_user_args():
  var corner_rows:Array=[]
  for node:MultiMeshInstance3D in world.find_children("*OuterWalls*","MultiMeshInstance3D",true,false):
   for i in node.multimesh.instance_count:
    var pose:Transform3D=node.global_transform*node.multimesh.get_instance_transform(i)
    if Vector2(pose.origin.x-center.x,pose.origin.z-center.z).length()<85:corner_rows.append(pose)
  print("CORNER_CONTEXT rows=",corner_rows.size())
  assert(not corner_rows.is_empty())
  FileAccess.open(output.path_join("corner-rows.bin"),FileAccess.WRITE).store_var(corner_rows)
  var corners:GDScript=preload("res://scripts/terrain/field/CliffCornerCrags.gd")
  for arg:String in OS.get_cmdline_user_args():
   if arg.begins_with("--corner-generator="):corners=load(arg.trim_prefix("--corner-generator="))
  for corner:Dictionary in corners.formations(corner_rows,2697992464):
   if not corner_poses.has(corner.transform):forms.append(corner)
 if "--inner-study" in OS.get_cmdline_user_args():
  var rows:Array=[]
  for node:MultiMeshInstance3D in world.find_children("*InnerWalls*","MultiMeshInstance3D",true,false):
   for i in node.multimesh.instance_count:
    var pose:Transform3D=node.global_transform*node.multimesh.get_instance_transform(i)
    if Vector2(pose.origin.x-center.x,pose.origin.z-center.z).length()<85:rows.append(pose)
  FileAccess.open(output.path_join("inner-rows.bin"),FileAccess.WRITE).store_var(rows)
  var additions:Array=corner_generator.formations(rows,2697992464,null,null,true)
  for form:Dictionary in additions:
   if not corner_poses.has(form.transform):forms.append(form)
  print("INNER_CONTEXT rows=",rows.size()," formations=",additions.size())
 FileAccess.open(output.path_join("before-forms.bin"),FileAccess.WRITE).store_var(forms)
 if "--shared-edges" in OS.get_cmdline_user_args():
  var edges:GDScript=preload("res://tests/fixtures/september19/corner-edge-profiles/blend.gd")
  if "--sample-field" in OS.get_cmdline_user_args():edges=preload("res://tests/fixtures/september19/corner-edge-profiles/blend-field.gd")
  if "--compress-section" in OS.get_cmdline_user_args():edges=preload("res://tests/fixtures/september19/corner-edge-profiles/blend-section.gd")
  if "--repair-caps" in OS.get_cmdline_user_args():edges=preload("res://tests/fixtures/september19/corner-edge-profiles/blend-section-caps.gd")
  edges.apply(forms)
 if "--run-study" in OS.get_cmdline_user_args():
  if not preload("res://tests/fixtures/september19/short-corner-runs/study.gd").apply(forms):
   get_tree().quit(1);return
 FileAccess.open(output.path_join("after-forms.bin"),FileAccess.WRITE).store_var(forms)
 var built:=ROCKS.build({"placements":forms+ROCKS.plants(forms,null,2697992464)},2697992464)
 var index:=0
 for node:Node in built.get_children():
  if node.has_meta("relief_faces"):
   node.multimesh.mesh=generator.mesh(forms[index])
   for arg:String in OS.get_cmdline_user_args():
    if arg.begins_with("--stone-shader="):
     var material:=ShaderMaterial.new();material.shader=load(arg.trim_prefix("--stone-shader="))
     for texture_arg:String in OS.get_cmdline_user_args():
      if texture_arg.begins_with("--stone-normal="):material.set_shader_parameter("rock_normal",load(texture_arg.trim_prefix("--stone-normal=")))
     node.multimesh.mesh.surface_set_material(0,material)
   index+=1
 world.add_child(built)
 _freeze_material_clocks(world)
 var heights:Dictionary={}
 for form:Dictionary in forms:
  var height:float=form.top-form.transform.origin.y
  heights[height]=heights.get(height,0)+1
 print("ART_CONTEXT replaced=",replaced," corners=",corner_poses.size()," source=",snapshot," heights=",heights)
 var shots:Array=[
  ["P12_front",Vector3(-423,40,-292),Vector3(-442,36,-298)],
  ["P12_side",Vector3(-414,42,-311),Vector3(-442,35,-298)],
  ["P17_front",Vector3(-425,39,-247),Vector3(-445,34,-250)],
  ["P20_oblique",Vector3(-482,42,-229),Vector3(-483,36,-249)],
  ["P05_vines",Vector3(-427,36,-263),Vector3(-445,36,-269)]]
 if not single_site.is_empty():shots=[]
 var only_shot:=""
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with("--shot="):only_shot=arg.trim_prefix("--shot=")
 if not only_shot.is_empty():shots=shots.filter(func(shot:Array)->bool:return shot[0]==only_shot)
 # Supplemental native-join diagnostics; these do not replace any reported
 # ReviewCam pose. Derive the camera from the pinned formation's own transform.
 if "--cut-detail" in OS.get_cmdline_user_args():
  var anchor:Array=FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin",FileAccess.READ).get_var()[20]
  var pose:Transform3D=anchor[0]
  shots=[["P20_cut_front",pose*Vector3(3.5,6.6,7.0),pose*Vector3(3.5,6.6,.4)],
   ["P20_cut_oblique",pose*Vector3(7.5,7.0,7.0),pose*Vector3(3.5,6.6,.4)]]
 if "--short-detail" in OS.get_cmdline_user_args():
  shots=[["short_inner",Vector3(-409,35,-338),Vector3(-421,30,-349)],
   ["short_above",Vector3(-410,42,-338),Vector3(-421,30,-349)],
   ["short_side",Vector3(-413,33,-340),Vector3(-421,31,-348)]]
 if "--join-detail" in OS.get_cmdline_user_args():
  shots=[["lower_inner_front",Vector3(-434,35,-266),Vector3(-445,30,-277)],
   ["lower_inner_above",Vector3(-435,43,-267),Vector3(-444,29,-276)],
   ["inner_front",Vector3(-434,38,-291),Vector3(-444,35,-300)],
   ["inner_above",Vector3(-437,44,-294),Vector3(-443,34,-299)],
   ["outer_oblique",Vector3(-437,41,-242),Vector3(-445,35,-252)]]
 for shot:Array in shots:
  camera.position=shot[1];camera.look_at(shot[2])
  if benchmark and shot[0] in ["P12_front","P20_oblique"]:
   var old_shader:Shader=load("res://tests/fixtures/september17/cliff-weathering/before.gdshader")
   var new_shader:Shader=load("res://terrain/materials/cliff_crag.gdshader")
   var materials:Array[ShaderMaterial]=[]
   for node:MultiMeshInstance3D in built.get_children():
    if node.has_meta("relief_faces"):materials.append(node.multimesh.mesh.surface_get_material(0))
   for variant:int in [0,1,1,0]:
    for material:ShaderMaterial in materials:material.shader=old_shader if variant==0 else new_shader
    for frame in 40:await RenderingServer.frame_post_draw
    var start:=Time.get_ticks_usec()
    for frame in 120:await RenderingServer.frame_post_draw
    print("STONE_FRAME view=",shot[0]," variant=",variant," mean_ms=",(Time.get_ticks_usec()-start)/120000.0)
   for material:ShaderMaterial in materials:material.shader=new_shader
  for frame in 12:await get_tree().process_frame
  RenderingServer.force_draw()
  view.get_texture().get_image().save_png(output.path_join(shot[0]+".png"))
  print("ART_CONTEXT ",shot[0])
 var sites:Array=["P05","P12","P17","P20"] if single_site.is_empty() else [single_site]
 if "--short-detail" in OS.get_cmdline_user_args() or "--cut-detail" in OS.get_cmdline_user_args() or "--join-detail" in OS.get_cmdline_user_args() or not only_shot.is_empty():sites=[]
 for site:String in sites:
  var path:="res://docs/qa/2026-09-16-manual/10-rounded-ledges/production-01/"+site
  if not poses_root.is_empty():path=poses_root
  var records:Array=JSON.parse_string(FileAccess.get_file_as_string(path.path_join("poses.json")))
  for record:Dictionary in records:
   var numbers:=RegEx.new();numbers.compile("-?[0-9]+(?:\\.[0-9]+)?")
   var values:Array[float]=[]
   for match in numbers.search_all(record.camera):values.append(float(match.get_string()))
   assert(values.size()==12)
   camera.transform=Transform3D(Basis(Vector3(values[0],values[1],values[2]),Vector3(values[3],values[4],values[5]),Vector3(values[6],values[7],values[8])),Vector3(values[9],values[10],values[11]))
   camera.fov=record.fov
   for frame in 8:await get_tree().process_frame
   RenderingServer.force_draw()
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
