extends SceneTree
const OUT="res://docs/qa/2026-09-19-manual/129-bank-corridor"
const SOURCE="res://docs/qa/2026-09-19-manual/119-small-town/world.scn"
const ROCKS=preload("res://scripts/terrain/field/CliffRockDressing.gd")
func _init()->void:run.call_deferred()
func run()->void:
 Engine.max_fps=30;root.size=Vector2i(1280,800)
 var stage:Node3D=load(SOURCE).instantiate();root.add_child(stage)
 for key:StringName in stage.get_meta("shader_globals",{}):
  if key in [&"biome_ground_a",&"biome_ground_b",&"biome_ground_color",&"biome_ground_origin",&"grass_lod_origin",&"wind_direction",&"wind_idle_bend",&"wind_gust_texture",&"wind_gust_scale",&"wind_gust_speed",&"wind_gust_bend",&"grass_trample_texture",&"grass_static_trample_texture",&"grass_trample_origin",&"grass_trample_size",&"grass_trample_epoch"]:RenderingServer.global_shader_parameter_set(key,stage.get_meta("shader_globals")[key])
 preload("res://tests/fixtures/september19/bank-water/grass.gd").add_to(root)
 ROCKS.prepare()
 var banks:Array=FileAccess.open(OUT.path_join("validated-banks.bin"),FileAccess.READ).get_var()
 var plants:Array=FileAccess.open(OUT.path_join("plants.bin"),FileAccess.READ).get_var()
 var stones:=ROCKS.build({"placements":banks},2697992464);root.add_child(stones)
 var leaves:=ROCKS.build({"placements":plants},2697992464);root.add_child(leaves)
 var by_id:Dictionary={}
 for rock:Dictionary in banks:
  var body:=StaticBody3D.new();body.collision_layer=64;body.collision_mask=0
  var shape:=CollisionShape3D.new();var mesh:=ConcavePolygonShape3D.new();mesh.set_faces(rock.faces);shape.shape=mesh
  body.add_child(shape);root.add_child(body);body.transform=rock.transform
  by_id[rock.id]=body
 await physics_frame;await physics_frame
 var failures:Array=[];var max_gap:=0.0
 for plant:Dictionary in plants:
  var point:Vector3=plant.support_point;var normal:Vector3=plant.support_normal
  var ray:=PhysicsRayQueryParameters3D.create(point+normal*.2,point-normal*.2,64)
  var hit:=root.world_3d.direct_space_state.intersect_ray(ray)
  if hit.is_empty():failures.append({"root":point,"reason":"no contact"})
  else:
   max_gap=maxf(max_gap,(hit.position as Vector3).distance_to(point))
   if hit.collider!=by_id[plant.support_id] or (hit.position as Vector3).distance_to(point)>.005:failures.append({"root":point,"hit":hit.position,"reason":"wrong support"})
 var report:={"plants":plants.size(),"failures":failures,"maximum_root_contact_gap":max_gap}
 FileAccess.open(OUT.path_join("native-plants.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("BANK_PLANT_CONTACT ",report)
 var camera:=Camera3D.new();root.add_child(camera);camera.current=true;camera.fov=75
 var feet:=Vector3(-519.5,20,326.4);var aim:=Vector3(-499.7,8,306.5)
 var pivot:=feet+Vector3.UP*CameraMouseView.PIVOT_HEIGHT;var backward:=(pivot-aim).normalized()
 var eye:=ReviewCam.solve_cam(feet,aim,Vector2(backward.x,backward.z).length()*CameraMouseView.BOOM_LENGTH,CameraMouseView.PIVOT_HEIGHT+backward.y*CameraMouseView.BOOM_LENGTH,CameraMouseView.PIVOT_HEIGHT)
 for angle in [0,-10,10,-35,35]:
  camera.position=pivot+(eye-pivot).rotated(Vector3.UP,deg_to_rad(angle));camera.look_at(pivot)
  await capture_pair(camera,leaves,"photo-%d"%angle)
 var detail:Dictionary={};var closest:=INF
 for plant:Dictionary in plants:
  var distance:float=plant.support_point.distance_to(Vector3(-517,15,325))
  if distance<closest:closest=distance;detail=plant
 if not detail.is_empty():
  camera.position=detail.support_point+detail.support_normal*6+Vector3.UP*2
  camera.look_at(detail.support_point)
  await capture_pair(camera,leaves,"attachment-detail")
 print("BANK_PLANT_RENDER done")
 quit(0 if failures.is_empty() else 1)
func capture_pair(_camera:Camera3D,leaves:Node3D,label:String)->void:
 for after:bool in [false,true]:
  leaves.visible=after
  for i in 5:await process_frame
  RenderingServer.force_draw(false)
  root.get_texture().get_image().save_png(OUT.path_join("%s-%s.png"%[label,"after" if after else "before"]))
