extends "res://tests/harness/september15_mountain_study.gd"
## Native catalogue/wall construction under fixed studio light for rapid art rejection.
func _ready()->void:
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with("--output="):_output=arg.trim_prefix("--output=")
 DirAccess.make_dir_recursive_absolute(_output)
 _view=SubViewport.new();_view.size=Vector2i(1600,1000);_view.own_world_3d=true
 _view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;_view.msaa_3d=Viewport.MSAA_4X;add_child(_view)
 _stage=Node3D.new();_view.add_child(_stage);_lighting()
 var cache:=EnvironmentRenderCache.new(EnvironmentCatalog.load_default())
 var ids:Array[StringName]=[]
 for id:StringName in CliffDressing.ASSETS.values():ids.append(id)
 assert(cache.prepare(ids));CliffDressing.prepare(cache)
 var height:=16
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with("--height="):height=int(arg.trim_prefix("--height="))
 var walls:=[];var lips:=[];var corners:=[];var corner_lips:=[]
 var corner_pose:=Transform3D(Basis.IDENTITY,Vector3(10.5,0,10.5))
 for y in height/4:corners.append(Transform3D(Basis.IDENTITY,corner_pose.origin+Vector3.UP*y*4))
 corner_lips.append(Transform3D(Basis.IDENTITY,corner_pose.origin+Vector3.UP*height))
 for side:int in [0,1]:
  var basis:=Basis(Vector3.UP,side*PI*.5)
  for x in range(1,17):
   var base:=corner_pose.origin+basis*Vector3(-x*3 if side==0 else x*3,0,0)
   for y in height/4:walls.append(Transform3D(basis,base+Vector3.UP*y*4))
   lips.append(Transform3D(basis,base+Vector3.UP*height))
 _stage.add_child(CliffDressing.build_from_data({"wall":walls,"lip":lips,"outer_wall":corners,"inner_wall":[],"outer_lip":corner_lips,"inner_lip":[]},2697992464))
 var rocks=preload("res://scripts/terrain/field/CliffRockDressing.gd");rocks.prepare()
 var generator:GDScript=rocks.CRAGS
 var corner_generator:GDScript=rocks.CORNERS
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with("--generator="):generator=load(arg.trim_prefix("--generator="))
  if arg.begins_with("--corner-generator="):corner_generator=load(arg.trim_prefix("--corner-generator="))
 var forms:Array[Dictionary]=[]
 for record:Dictionary in rocks.RELIEF.panels(walls):
  if record.width>=6:forms.append_array(generator.make(record.pose,record.width,record.height,2697992464,null,record.left_end,record.right_end))
 forms.append_array(corner_generator.formations(corners,2697992464))
 var plants:=rocks.plants(forms,null,2697992464)
 _stage.add_child(rocks.build({"placements":forms+plants},2697992464))
 var floor_node:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(300,220);floor_node.mesh=plane
 var mat:=StandardMaterial3D.new();mat.albedo_color=Color(.21,.3,.15);mat.roughness=1;floor_node.material_override=mat;_stage.add_child(floor_node)
 var mage:Node3D=load("res://characters/models/mage.tscn").instantiate();_stage.add_child(mage);mage.position=Vector3(0,0,14);mage.rotation.y=PI
 _camera=Camera3D.new();_stage.add_child(_camera);_camera.current=true;_camera.far=500;_camera.near=.1
 var shots:Array=[["front",Vector3(37,9,37),Vector3(10.5,8,10.5),65.0],["oblique",Vector3(45,13,19),Vector3(10.5,7,10.5),60.0],["close",Vector3(20,8,24),Vector3(10.5,7,10.5),65.0],["wide",Vector3(55,30,66),Vector3(10.5,8,10.5),65.0],["ledges",Vector3(19,20,24),Vector3(10.5,5,10.5),60.0]]
 var scale_y:=float(height)/16.0
 var diagnostics:="--diagnose" in OS.get_cmdline_user_args()
 var sun:DirectionalLight3D=_stage.find_children("*","DirectionalLight3D",true,false)[0]
 sun.rotation_degrees=Vector3(-43,40,0)
 var environment:Environment=_stage.find_children("*","WorldEnvironment",true,false)[0].environment
 var stone_materials:Array[ShaderMaterial]=[]
 var original_shader:Shader=load("res://terrain/materials/cliff_crag.gdshader")
 var plain_shader:=Shader.new()
 var relief_line:=RegEx.new();relief_line.compile("float relief\\s*=.*?;")
 plain_shader.code=relief_line.sub(original_shader.code,"float relief = 0.0;")
 var facet_shader:=Shader.new()
 facet_shader.code="shader_type spatial; void fragment(){vec3 n=normalize(cross(dFdx(VERTEX),dFdy(VERTEX))); NORMAL=n*sign(dot(n,NORMAL)); ALBEDO=vec3(.25); ROUGHNESS=1.0; SPECULAR=0.0;}"
 var unlit_shader:=Shader.new()
 unlit_shader.code="shader_type spatial; render_mode unshaded; void fragment(){ALBEDO=vec3(.4);}"
 for node:MultiMeshInstance3D in _stage.find_children("*","MultiMeshInstance3D",true,false):
  if not node.has_meta("relief_faces"):continue
  stone_materials.append(node.multimesh.mesh.surface_get_material(0))
 for shot:Array in shots:
  shot[1].y*=scale_y;shot[2].y*=scale_y
  shot[1].x=10.5+(shot[1].x-10.5)*sqrt(scale_y)
  shot[1].z=10.5+(shot[1].z-10.5)*sqrt(scale_y)
  _camera.position=shot[1];_camera.look_at(shot[2]);_camera.fov=shot[3]
  var variants:Array=["base","no_shadow","no_bump","neither","no_ssao","facets","unlit"] if diagnostics else ["base"]
  for variant:String in variants:
   sun.shadow_enabled=not variant in ["no_shadow","neither"]
   environment.ssao_enabled=variant!="no_ssao"
   for material:ShaderMaterial in stone_materials:
    material.shader=facet_shader if variant=="facets" else unlit_shader if variant=="unlit" else plain_shader if variant in ["no_bump","neither"] else original_shader
   for frame in 8:await get_tree().process_frame
   await RenderingServer.frame_post_draw
   var suffix:="_"+variant if diagnostics else ""
   _view.get_texture().get_image().save_png(_output.path_join(shot[0]+suffix+".png"))
   print("CLIFF_STUDY ",shot[0],suffix)
 get_tree().quit()
