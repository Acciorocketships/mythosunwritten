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
 var walls:=[];var lips:=[]
 for x in range(-16,16):
  for y in height/4:walls.append(Transform3D(Basis.IDENTITY,Vector3(x*3+1.5,y*4,0)))
  lips.append(Transform3D(Basis.IDENTITY,Vector3(x*3+1.5,height,0)))
 _stage.add_child(CliffDressing.build_from_data({"wall":walls,"lip":lips,"outer_wall":[],"inner_wall":[],"outer_lip":[],"inner_lip":[]},2697992464))
 var rocks=preload("res://tests/fixtures/september18/cliff-continuous-bodies/authored-dressing.gd");rocks.prepare()
 var forms:=rocks.formations(walls,2697992464)
 var plants:=rocks.plants(forms,null,2697992464)
 _stage.add_child(rocks.build({"placements":forms+plants},2697992464))
 var floor_node:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(300,220);floor_node.mesh=plane
 var mat:=StandardMaterial3D.new();mat.albedo_color=Color(.21,.3,.15);mat.roughness=1;floor_node.material_override=mat;_stage.add_child(floor_node)
 var mage:Node3D=load("res://characters/models/mage.tscn").instantiate();_stage.add_child(mage);mage.position=Vector3(0,0,14);mage.rotation.y=PI
 _camera=Camera3D.new();_stage.add_child(_camera);_camera.current=true;_camera.far=500;_camera.near=.1
 var shots:Array=[["front",Vector3(0,9,40),Vector3(0,8,0),65.0],["oblique",Vector3(32,13,28),Vector3(0,7,1),60.0],["close",Vector3(-8,8,19),Vector3(-10,7,0),65.0],["wide",Vector3(55,30,66),Vector3(0,8,0),65.0],["ledges",Vector3(-15,20,17),Vector3(-9,5,1),60.0]]
 var scale_y:=float(height)/16.0
 var diagnostics:="--diagnose" in OS.get_cmdline_user_args()
 var sun:DirectionalLight3D=_stage.find_children("*","DirectionalLight3D",true,false)[0]
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
 var requested:=""
 for arg:String in OS.get_cmdline_user_args():
  if arg.begins_with("--shot="):requested=arg.trim_prefix("--shot=")
 for shot:Array in shots:
  if not requested.is_empty() and shot[0]!=requested:continue
  shot[1].y*=scale_y;shot[2].y*=scale_y;shot[1].z*=sqrt(scale_y)
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
