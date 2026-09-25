extends "res://tests/harness/september15_mountain_study.gd"
func _ready()->void:
 _output="res://docs/qa/2026-09-17-manual/26-cliff-curved-treads/grass-native"
 DirAccess.make_dir_recursive_absolute(_output)
 _view=SubViewport.new();_view.size=Vector2i(1600,1000);_view.own_world_3d=true
 _view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;_view.msaa_3d=Viewport.MSAA_4X;add_child(_view)
 _stage=Node3D.new();_view.add_child(_stage);_lighting()
 _stage.find_children("*","DirectionalLight3D",true,false)[0].rotation_degrees=Vector3(-43,60,0)
 var fixture=load("res://tests/test_september16_cliff_grass.gd").new()
 var f:Dictionary=fixture._fixture();fixture.free()
 var rocks=load("res://scripts/terrain/field/CliffRockDressing.gd")
 var cache:=EnvironmentRenderCache.new(EnvironmentCatalog.load_default())
 var ids:Array[StringName]=[]
 for id:StringName in CliffDressing.ASSETS.values():ids.append(id)
 assert(cache.prepare(ids));CliffDressing.prepare(cache)
 _stage.add_child(CliffDressing.build_from_data(CliffDressing.compute(f.region,0,0,8),99))
 _stage.add_child(rocks.build(f.data,99))
 assert(cache.prepare(f.program.referenced_asset_ids))
 var streamer:=GrassStreamer.new(f.program,cache)
 var groups:Array[Node3D]=[]
 var times:Array=[];var roots:Array[Vector3]=[]
 for before:bool in [true,false]:
  var group:=Node3D.new();_stage.add_child(group);groups.append(group)
  var start:=Time.get_ticks_msec()
  var generator:GDScript=load("res://tests/fixtures/september17/cliff-curved-treads/grass-field-before.gd") if before else load("res://scripts/terrain/grass/GrassField.gd")
  for z in range(0,3):
   var payload:GrassPayload=generator.compute(f.program,99,Vector2i(3,z),f.region,f.water,null,f.data.grass_supports)
   for id:StringName in payload.batches:
    var batch:Dictionary=payload.batches[id]
    streamer._add_batch(group,id,batch)
    if not before:
     for i in batch.count:
      var k:int=i*GrassPayload.FLOATS_PER_INSTANCE
      var root:=Vector3(batch.buffer[k+3],batch.buffer[k+7],batch.buffer[k+11])
      if root.y>TerrainSurfaceField.surface_y(f.region,root.x,root.z)+.5:roots.append(root)
  times.append(Time.get_ticks_msec()-start)
  group.visible=false
 print("CURVED_GRASS elapsed_ms before_current=",times)
 _camera=Camera3D.new();_stage.add_child(_camera);_camera.current=true;_camera.near=.1;_camera.far=300
 var shots:Array=[['oblique',Vector3(107,14,31),Vector3(86,6,39)],['tread',Vector3(93,9,38),Vector3(85.5,6.1,39)],['upper',Vector3(99,15,6),Vector3(86,10,5)]]
 RenderingServer.global_shader_parameter_set(&"wind_idle_bend",0.0)
 RenderingServer.global_shader_parameter_set(&"wind_gust_bend",0.0)
 for i in mini(3,roots.size()):shots.append(["root_%d"%i,roots[i]+Vector3(2,1.4,1.7),roots[i]+Vector3.UP*.15])
 print("CURVED_GRASS roots=",roots)
 for shot:Array in shots:
  _camera.position=shot[1];_camera.look_at(shot[2]);_camera.fov=58
  streamer.begin_frame(Vector2(shot[2].x,shot[2].z))
  for index in groups.size():
   groups[index].visible=true
   for frame in 12:await get_tree().process_frame
   await RenderingServer.frame_post_draw
   _view.get_texture().get_image().save_png(_output.path_join(shot[0]+('_before' if index==0 else '_current')+'.png'))
   groups[index].visible=false
 print("CURVED_GRASS complete")
 get_tree().quit()
