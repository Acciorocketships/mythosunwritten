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
 var walls:=[];var lips:=[]
 for x in range(-16,16):
  for y in 4:walls.append(Transform3D(Basis.IDENTITY,Vector3(x*3+1.5,y*4,0)))
  lips.append(Transform3D(Basis.IDENTITY,Vector3(x*3+1.5,16,0)))
 _stage.add_child(CliffDressing.build_from_data({"wall":walls,"lip":lips,"outer_wall":[],"inner_wall":[],"outer_lip":[],"inner_lip":[]},2697992464))
 var rocks=preload("res://scripts/terrain/field/CliffRockDressing.gd");rocks.prepare()
 var forms:=rocks.formations(walls,2697992464)
 var plants:=rocks.plants(forms,null,2697992464)
 _stage.add_child(rocks.build({"placements":forms+plants},2697992464))
 var floor_node:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(300,220);floor_node.mesh=plane
 var mat:=StandardMaterial3D.new();mat.albedo_color=Color(.21,.3,.15);mat.roughness=1;floor_node.material_override=mat;_stage.add_child(floor_node)
 var mage:Node3D=load("res://characters/models/mage.tscn").instantiate();_stage.add_child(mage);mage.position=Vector3(0,0,14);mage.rotation.y=PI
 _camera=Camera3D.new();_stage.add_child(_camera);_camera.current=true;_camera.far=500;_camera.near=.1
 var shots:Array=[["front",Vector3(0,9,40),Vector3(0,8,0),65.0],["oblique",Vector3(32,13,28),Vector3(0,7,1),60.0],["close",Vector3(-8,8,19),Vector3(-10,7,0),65.0],["wide",Vector3(55,30,66),Vector3(0,8,0),65.0],["ledges",Vector3(-15,20,17),Vector3(-9,5,1),60.0]]
 for shot:Array in shots:
  _camera.position=shot[1];_camera.look_at(shot[2]);_camera.fov=shot[3]
  for frame in 8:await get_tree().process_frame
  await RenderingServer.frame_post_draw
  _view.get_texture().get_image().save_png(_output.path_join(shot[0]+".png"))
  print("CLIFF_STUDY ",shot[0])
 get_tree().quit()
