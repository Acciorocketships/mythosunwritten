extends SceneTree
func _init() -> void: run.call_deferred()
func run() -> void:
 root.size=Vector2i(1400,800)
 var stage=Node3D.new()
 root.add_child(stage)
 var env=WorldEnvironment.new()
 env.environment=Environment.new()
 env.environment.background_mode=Environment.BG_COLOR
 env.environment.background_color=Color("677782")
 env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 env.environment.ambient_light_color=Color.WHITE
 env.environment.ambient_light_energy=.8
 stage.add_child(env)
 var sun=DirectionalLight3D.new()
 stage.add_child(sun)
 sun.rotation_degrees=Vector3(-50,-30,0)
 var camera=Camera3D.new()
 stage.add_child(camera)
 camera.current=true
 camera.position=Vector3(15,18,28)
 camera.look_at(Vector3(10,2,3))
 var catalog=EnvironmentCatalog.load_default()
 var visual=load(catalog.descriptor(&"lpfv.fabric.roof.compact.slate.03").visual_path) as EnvironmentVisual
 var combination=CSGCombiner3D.new()
 stage.add_child(combination)
 for i in 1:
  var part=CSGMesh3D.new()
  var source_mesh=visual.pieces[0].mesh
  var explicit_mesh=ArrayMesh.new()
  for surface in source_mesh.get_surface_count():
   var arrays=source_mesh.surface_get_arrays(surface)
   print("ARRAYS ",arrays[Mesh.ARRAY_VERTEX].size())
   if arrays[Mesh.ARRAY_INDEX]==null or arrays[Mesh.ARRAY_INDEX].is_empty():
    var indices=PackedInt32Array()
    for v in arrays[Mesh.ARRAY_VERTEX].size(): indices.append(v)
    arrays[Mesh.ARRAY_INDEX]=indices
   explicit_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
   explicit_mesh.surface_set_material(surface,source_mesh.surface_get_material(surface))
  part.mesh=BoxMesh.new()
  print("SOURCE ",part.mesh.get_aabb()," local ",visual.pieces[0].local_transform," surfaces ",part.mesh.get_surface_count())
  combination.add_child(part)
  part.transform=visual.pieces[0].local_transform
  if i>0:
   part.rotate_y(PI/2)
   part.position.x=3.0 if i==2 else 0.0
  if i==1:
   var cut=CSGBox3D.new()
   cut.size=Vector3(10,10,10)
   cut.operation=CSGShape3D.OPERATION_SUBTRACTION
   cut.position=part.to_local(Vector3(-5,0,0))
   part.add_child(cut)
 camera.position=Vector3(9,9,12)
 camera.look_at(Vector3(1,1,0))
 for frame in 120: await process_frame
 RenderingServer.force_draw(false)
 root.get_texture().get_image().save_png("res://docs/qa/2026-09-13-manual/11-roof-joins/csg-prototype.png")
 print("ROOT? ",combination.is_root_shape()," visible ",combination.visible," processing ",combination.process_mode)
 var meshes=combination.get_meshes()
 print("CSG_PROTOTYPE ",meshes)
 if meshes.size()>1: print("BAKED ",meshes[1].get_aabb(), " surfaces ",meshes[1].get_surface_count())
 if meshes.size()>1: ResourceSaver.save(meshes[1],"res://docs/qa/2026-09-13-manual/11-roof-joins/csg-prototype.res")
 quit()
