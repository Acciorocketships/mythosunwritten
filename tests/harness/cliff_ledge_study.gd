extends SceneTree
const ENV=preload("res://scripts/terrain/field/CliffSlopeEnvelope.gd")
const FIELD=preload("res://scripts/terrain/field/CliffSlopeField.gd")
const CRAGS=preload("res://scripts/terrain/field/CliffRockCrags.gd")
func _initialize()->void:run.call_deferred()
func run()->void:
 load("res://scripts/terrain/field/CliffRockStyle.gd").apply("sheet_bedrock")
 var d:Dictionary=bytes_to_var(FileAccess.get_file_as_bytes("res://tests/fixtures/september26-cliffs/p03-constrained-inputs.var.gz").decompress_dynamic(4000000,FileAccess.COMPRESSION_GZIP))
 var index:=func(q:Vector2)->int:
  var p:=Vector2i(((q-d.origin)/.5).round()).clamp(Vector2i.ZERO,Vector2i(d.w-1,d.h-1));return p.y*d.w+p.x
 var ground:=func(q:Vector2)->float:return d.ground[index.call(q)]
 var env=ENV.build(Rect2(476,924,92,96),ground,func(q:Vector2)->bool:return d.excluded[index.call(q)]!=0,2697992464,func(q:Vector2)->float:return d.wet[index.call(q)])
 var field=FIELD.new([],2697992464);field._env=env;field.ground_at=ground
 root.size=Vector2i(1600,900)
 var scene:=Node3D.new();root.add_child(scene)
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-50,-35,0);light.light_energy=1.0;scene.add_child(light)
 var world:=WorldEnvironment.new();world.environment=Environment.new();world.environment.background_mode=Environment.BG_COLOR;world.environment.background_color=Color(.6,.65,.7);world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;world.environment.ambient_light_color=Color.WHITE;world.environment.ambient_light_energy=.7;scene.add_child(world)
 var nodes:Array[MeshInstance3D]=[]
 for rock:Dictionary in field.solid(Rect2(478,926,86,86)):
  rock.render_arrays=CRAGS.mesh_arrays(rock,null,2697992464)
  var node:=MeshInstance3D.new();node.mesh=CRAGS.mesh(rock);scene.add_child(node);nodes.append(node)
  ResourceSaver.save(node.mesh,"res://docs/qa/2026-09-26-rock-ledge-restoration/study-mesh.res")
 var cam:=Camera3D.new();scene.add_child(cam);cam.current=true;cam.fov=60;cam.look_at_from_position(Vector3(508,50,934),Vector3(497,40,955))
 var shader:Shader=load("res://terrain/materials/cliff_crag.gdshader");var original:=shader.code
 var dir:="res://docs/qa/2026-09-26-rock-ledge-restoration"
 var suffix:="" if OS.get_cmdline_user_args().is_empty() else "-"+OS.get_cmdline_user_args()[0]
 for mode:String in ["baseline","neutral"]:
  if mode=="neutral":
   var material:=StandardMaterial3D.new();material.albedo_color=Color(.55,.55,.55);material.roughness=1.0
   for node in nodes:node.material_override=material
  else:
   for node in nodes:node.material_override=null
   shader.code=original if mode=="baseline" else original.replace("ALBEDO=mix(stone,green,cover);","ALBEDO=mix(stone,ground_style(stone_position.xz,texture(ground_palette_texture,grass_uv).rgb*COLOR.rgb),cover);")
  for i in 5:await process_frame
  await RenderingServer.frame_post_draw
  for view in ["front","side"]:
   cam.look_at_from_position(Vector3(508,50,934) if view=="front" else Vector3(516,49,963),Vector3(497,40,955))
   for frame in 3:await process_frame
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(dir+"/study-"+mode+suffix+"-"+view+".png")
 shader.code=original
 quit()
