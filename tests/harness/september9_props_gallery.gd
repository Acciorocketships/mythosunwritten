extends SceneTree

# Supplementary native town study. Frozen source through the current compiler;
# no surrounding natural terrain or avatar. Production streamed views are separate.
func _init() -> void:
 _run.call_deferred()

func _run() -> void:
 Engine.max_fps=30
 root.size=Vector2i(1280,720)
 var output:=OS.get_cmdline_user_args()[0]
 DirAccess.make_dir_recursive_absolute(output)
 var stage:=Node3D.new()
 root.add_child(stage)
 var env:=WorldEnvironment.new()
 env.environment=Environment.new()
 env.environment.background_mode=Environment.BG_SKY
 env.environment.sky=Sky.new()
 env.environment.sky.sky_material=ProceduralSkyMaterial.new()
 stage.add_child(env)
 var sun:=DirectionalLight3D.new()
 stage.add_child(sun)
 var camera:=Camera3D.new()
 stage.add_child(camera)
 camera.current=true
 var director:=AtmosphereDirector.new()
 director.environment_node=env
 director.sun=sun
 director.camera=camera
 director._apply_grade()
 director._apply_mood(BiomeRegistry.blend_atmosphere({&"deep_forest":1.0}))
 var catalog:=EnvironmentCatalog.load_default()
 var program:=SettlementFabricProgram.compile(catalog)
 var frozen:=preload("res://tests/fixtures/frozen_maze_source.gd")
 var fabric:=frozen.spatial(frozen.read("res://tests/fixtures/september9-offset-source.txt"),program).compiled_fabric_cache()
 var payload:=SettlementFabricAssembler.payload(fabric)
 payload.append_from(SettlementFabricAssembler.structural_support_payload(fabric))
 payload.append_from(SettlementFabricAssembler.surface_visual_payload(fabric.surface_plan,
  SettlementFabricAssembler.maze_module_footprints(fabric),SettlementFabricAssembler.maze_skin_panel_boxes_for(fabric),fabric.planned_plaza_cells))
 var town:=Node3D.new()
 stage.add_child(town)
 town.transform=Transform3D(Basis(Vector3.UP,-PI/2)*2.0,Vector3(289.5,6.08,-1157.5))
 var map:=BiomeGroundMap.new()
 map.update(town.position,2697992464)
 var cache:=EnvironmentRenderCache.new(catalog)
 cache.prepare(payload.asset_ids())
 CliffDressing.prepare(cache)
 var queue:=EnvironmentCommitQueue.new(cache,&"Town")
 queue.register_chunk(Vector2i.ZERO,1)
 queue.enqueue(Vector2i.ZERO,1,town,payload)
 queue.drain(100000)
 var mesh_commit:=FeatureCommitQueue.new(cache)
 for mesh: Dictionary in payload.surface_meshes:mesh_commit.commit_mesh_visual(town,mesh)
 var rows:Array=[]
 for view in [
  ["overview",Vector3(-14,18,-18),Vector3(-7,6,-8)],
  ["bench_close",Vector3(-14,9,-15),Vector3(-10.8,6.5,-10.5)],
  ["bench_across",Vector3(-7,9,-15),Vector3(-10.8,6.5,-10.5)],
  ["stores_close",Vector3(-0.5,9,-12),Vector3(-3.2815,6.4,-9)],
  ["stores_other",Vector3(-1,9,-3),Vector3(-4.2185,6.4,-4.5)]]:
  camera.global_position=town.to_global(view[1])
  camera.look_at(town.to_global(view[2]))
  camera.force_update_transform()
  await create_timer(0.5).timeout
  RenderingServer.force_draw()
  await process_frame
  root.get_texture().get_image().save_png(output+"/garden_%s.png"%view[0])
  DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
  Engine.max_fps=0
  var times: Array[float]=[]
  var last:=Time.get_ticks_usec()
  for frame in 90:
   await process_frame
   var now:=Time.get_ticks_usec()
   if frame>=30:times.append(float(now-last)/1000.0)
   last=now
  times.sort()
  Engine.max_fps=30
  rows.append({"frame_median_ms":times[30],"frame_p95_ms":times[57],"view":view[0],"camera":str(camera.global_transform),"lights":town.find_children("*","OmniLight3D",true,false).size()})
 FileAccess.open(output+"/gallery.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
 director.free()
 stage.free()
 await process_frame
 quit()
