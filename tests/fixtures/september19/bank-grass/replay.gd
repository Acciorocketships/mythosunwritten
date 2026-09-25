extends SceneTree
const OUT="res://docs/qa/2026-09-19-manual/123-bank-grass"
const SOURCE="res://docs/qa/2026-09-19-manual/119-small-town/world.scn"
const ROCKS=preload("res://scripts/terrain/field/CliffRockDressing.gd")
var grass_before:Node3D
var grass_after:Node3D
func _init()->void:run.call_deferred()
func run()->void:
 Engine.max_fps=30;root.size=Vector2i(1280,800)
 var stage:Node3D=load(SOURCE).instantiate();root.add_child(stage)
 for key:StringName in stage.get_meta("shader_globals",{}):
  if key in [&"biome_ground_a",&"biome_ground_b",&"biome_ground_color",&"biome_ground_origin",&"grass_lod_origin",&"wind_direction",&"wind_idle_bend",&"wind_gust_texture",&"wind_gust_scale",&"wind_gust_speed",&"wind_gust_bend",&"grass_trample_texture",&"grass_static_trample_texture",&"grass_trample_origin",&"grass_trample_size",&"grass_trample_epoch"]:RenderingServer.global_shader_parameter_set(key,stage.get_meta("shader_globals")[key])
 ROCKS.prepare()
 var old_banks:Array=FileAccess.open("res://docs/qa/2026-09-19-manual/121-shoreline-rock/owned/banks.bin",FileAccess.READ).get_var()
 var old_plants:Array=FileAccess.open("res://docs/qa/2026-09-19-manual/122-bank-attachments/plants.bin",FileAccess.READ).get_var()
 var originals:=ROCKS.build({"placements":old_banks},2697992464);root.add_child(originals);originals.hide()
 var original_leaves:=ROCKS.build({"placements":old_plants},2697992464);root.add_child(original_leaves);original_leaves.hide()
 var bank_map:Dictionary={};var replaced:Dictionary={}
 for bank:Dictionary in old_banks:bank_map[bank.id]=bank
 for bank:Dictionary in FileAccess.open(OUT.path_join("admitted.bin"),FileAccess.READ).get_var():
  if bank.get("replay_recipe",{}).has("shore_level"):bank_map[bank.id]=bank;replaced[bank.id]=true
 var banks:Array=bank_map.values()
 var plants:Array=FileAccess.open(OUT.path_join("plants.bin"),FileAccess.READ).get_var()
 for plant:Dictionary in old_plants:
  if not replaced.has(plant.support_id):plants.append(plant)
 var stones:=ROCKS.build({"placements":banks},2697992464);root.add_child(stones)
 var leaves:=ROCKS.build({"placements":plants},2697992464);root.add_child(leaves)
 var by_id:Dictionary={}
 for rock:Dictionary in banks:
  var body:=StaticBody3D.new();body.collision_layer=64;body.collision_mask=0
  var shape:=CollisionShape3D.new();var mesh:=ConcavePolygonShape3D.new();mesh.set_faces(rock.faces);shape.shape=mesh
  body.add_child(shape);root.add_child(body);body.transform=rock.transform
  by_id[rock.id]=body
 await physics_frame;await physics_frame
 var catalog:=EnvironmentCatalog.load_default();var cache:=EnvironmentRenderCache.new(catalog)
 var program:=GrassProgram.compile(load("res://terrain/grass/settings.tres"),catalog,cache)
 var streamer:=GrassStreamer.new(program,cache)
 streamer.begin_frame(Vector2(-519.5,326.4))
 RenderingServer.global_shader_parameter_set(&"wind_idle_bend",0.0)
 RenderingServer.global_shader_parameter_set(&"wind_gust_bend",0.0)
 grass_before=Node3D.new();grass_after=Node3D.new();root.add_child(grass_before);root.add_child(grass_after)
 var payloads:Dictionary=FileAccess.open(OUT.path_join("payloads.bin"),FileAccess.READ).get_var()
 var new_roots:Array[Vector3]=[];var normals:Array[Vector3]=[]
 for tile:Vector2i in payloads:
  var original:Dictionary={}
  for variant:String in ["before","after"]:
   var batches:Dictionary=payloads[tile][variant]
   for asset:StringName in batches:
    var batch:Dictionary=batches[asset];var buffer:PackedFloat32Array=batch.buffer
    streamer._add_batch(grass_before if variant=="before" else grass_after,asset,batch)
    for i in batch.count:
     var o:int=i*20
     var pose:=Transform3D(Basis(Vector3(buffer[o],buffer[o+4],buffer[o+8]),Vector3(buffer[o+1],buffer[o+5],buffer[o+9]),Vector3(buffer[o+2],buffer[o+6],buffer[o+10])),Vector3(buffer[o+3],buffer[o+7],buffer[o+11]))
     pose=pose*(program.assets[asset].piece_transform as Transform3D).affine_inverse()
     if variant=="before":original[pose.origin]=true
     elif not original.has(pose.origin):new_roots.append(pose.origin);normals.append(pose.basis.y.normalized())
 var failures:Array=[];var max_gap:=0.0
 for i in new_roots.size():
  var point:=new_roots[i];var normal:=normals[i]
  var hit:=root.world_3d.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+normal*.2,point-normal*.2,64))
  if hit.is_empty():failures.append({"root":point,"reason":"no bank contact"})
  else:
   max_gap=maxf(max_gap,(hit.position as Vector3).distance_to(point))
   if (hit.position as Vector3).distance_to(point)>.005:failures.append({"root":point,"hit":hit.position,"reason":"unsupported"})
  if point.y<13.999:failures.append({"root":point,"reason":"below water clearance"})
 var report:={"new_grass_roots":new_roots.size(),"failures":failures,"maximum_root_contact_gap":max_gap}
 FileAccess.open(OUT.path_join("native-contact.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("BANK_GRASS_CONTACT ",report)
 var camera:=Camera3D.new();root.add_child(camera);camera.current=true;camera.fov=75
 var feet:=Vector3(-519.5,20,326.4);var aim:=Vector3(-499.7,8,306.5)
 var pivot:=feet+Vector3.UP*CameraMouseView.PIVOT_HEIGHT;var backward:=(pivot-aim).normalized()
 var eye:=ReviewCam.solve_cam(feet,aim,Vector2(backward.x,backward.z).length()*CameraMouseView.BOOM_LENGTH,CameraMouseView.PIVOT_HEIGHT+backward.y*CameraMouseView.BOOM_LENGTH,CameraMouseView.PIVOT_HEIGHT)
 for angle in [0,-10,10,-35,35]:
  camera.position=pivot+(eye-pivot).rotated(Vector3.UP,deg_to_rad(angle));camera.look_at(pivot)
  await capture_pair(camera,leaves,"photo-%d"%angle)
 var detail:=Vector3.ZERO;var closest:=INF
 for point:Vector3 in new_roots:
  var distance:=point.distance_to(Vector3(-517,15,325))
  if distance<closest:closest=distance;detail=point
 if closest<INF:
  camera.position=detail+Vector3(5,3,-2)
  camera.look_at(detail)
  await capture_pair(camera,leaves,"grass-detail")
 camera.position=eye;camera.look_at(pivot)
 for after:bool in [false,true]:
  originals.visible=not after;original_leaves.visible=not after;stones.visible=after;leaves.visible=after
  grass_before.visible=not after;grass_after.visible=after
  for i in 5:await process_frame
  RenderingServer.force_draw(false)
  root.get_texture().get_image().save_png(OUT.path_join("profile-%s.png"%["after" if after else "before"]))
 print("BANK_GRASS_RENDER done")
 quit(0 if failures.is_empty() else 1)
func capture_pair(_camera:Camera3D,leaves:Node3D,label:String)->void:
 for after:bool in [false,true]:
  grass_before.visible=not after;grass_after.visible=after
  for i in 5:await process_frame
  RenderingServer.force_draw(false)
  root.get_texture().get_image().save_png(OUT.path_join("%s-%s.png"%[label,"after" if after else "before"]))
