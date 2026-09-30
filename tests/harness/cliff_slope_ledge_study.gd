extends SceneTree
## Neutral-material study renders (September 27 slope/ledge review) of the
## frozen P03 native inputs and a synthetic 20 m wall at 30 degrees to the
## grid, meshed by the production surface nets, for any envelope source.
##   Godot --path . -s res://tests/harness/cliff_slope_ledge_study.gd -- /abs/envelope.gd OUTDIR
const FIELD=preload("res://scripts/terrain/field/CliffSlopeField.gd")
const CRAGS=preload("res://scripts/terrain/field/CliffRockCrags.gd")
func _initialize()->void:run.call_deferred()
func _mesh(scene:Node3D,env,ground:Callable,area:Rect2,textured:bool)->void:
 var field=FIELD.new([],2697992464);field._env=env;field.ground_at=ground
 for rock:Dictionary in field.solid(area):
  rock.render_arrays=CRAGS.mesh_arrays(rock,null,2697992464)
  var node:=MeshInstance3D.new();node.mesh=CRAGS.mesh(rock);scene.add_child(node)
  if not textured:
   var m:=StandardMaterial3D.new();m.albedo_color=Color(.55,.55,.55);m.roughness=1.0;node.material_override=m
func run()->void:
 var args:=OS.get_cmdline_user_args()
 # Swap the envelope revision in place: the field's typed envelope slot
 # only accepts the production script resource.
 var script:=load("res://scripts/terrain/field/CliffSlopeEnvelope.gd") as GDScript
 script.source_code=FileAccess.get_file_as_string(args[0]);assert(script.reload(false)==OK)
 var out:String=args[1]
 load("res://scripts/terrain/field/CliffRockStyle.gd").apply("sheet_bedrock")
 var d:Dictionary=bytes_to_var(FileAccess.get_file_as_bytes("res://tests/fixtures/september26-cliffs/p03-constrained-inputs.var.gz").decompress_dynamic(4000000,FileAccess.COMPRESSION_GZIP))
 var index:=func(q:Vector2)->int:
  var p:=Vector2i(((q-d.origin)/.5).round()).clamp(Vector2i.ZERO,Vector2i(d.w-1,d.h-1));return p.y*d.w+p.x
 var ground:=func(q:Vector2)->float:return d.ground[index.call(q)]
 var env=script.build(Rect2(476,924,92,96),ground,func(q:Vector2)->bool:return d.excluded[index.call(q)]!=0,2697992464,func(q:Vector2)->float:return d.wet[index.call(q)])
 var n:=Vector2(cos(.52),sin(.52))
 var wall_ground:=func(q:Vector2)->float:return 20.0 if (q-Vector2(2000,0)).dot(n)<0.0 else 0.0
 var wall=script.build(Rect2(1970,-30,60,60),wall_ground,Callable(),2697992464)
 root.size=Vector2i(1600,900)
 var views:={"p03-front":[Vector3(508,50,934),Vector3(497,40,955)],"p03-side":[Vector3(516,49,963),Vector3(497,40,955)],
  "p03-rockface":[Vector3(541,44,958),Vector3(542,36,973)],"p03-close":[Vector3(500,44,944),Vector3(505,37,958)],
  "wall-oblique":[Vector3(2000,26,30),Vector3(2000,10,0)],"wall-along":[Vector3(1985,24,-22),Vector3(2008,8,8)]}
 for textured:bool in [false,true]:
  var scene:=Node3D.new();root.add_child(scene)
  var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-50,-35,0);scene.add_child(light)
  var world:=WorldEnvironment.new();world.environment=Environment.new();world.environment.background_mode=Environment.BG_COLOR;world.environment.background_color=Color(.6,.65,.7);world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;world.environment.ambient_light_color=Color.WHITE;world.environment.ambient_light_energy=.7;scene.add_child(world)
  _mesh(scene,env,ground,Rect2(478,926,86,86),textured)
  _mesh(scene,wall,wall_ground,Rect2(1975,-25,50,50),textured)
  var cam:=Camera3D.new();scene.add_child(cam);cam.current=true;cam.fov=60
  for i in 5:await process_frame
  for view:String in views:
   cam.look_at_from_position(views[view][0],views[view][1])
   for frame in 3:await process_frame
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("%s/%s-%s.png"%[out,view,"textured" if textured else "neutral"])
  scene.queue_free();await process_frame
 quit()
