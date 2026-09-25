extends SceneTree
const GEO = preload("res://tools/environment_bake/EnvironmentBakeGeometry.gd")
const OUT = "res://docs/qa/2026-09-13-manual/11-roof-joins/"
func _init() -> void: run.call_deferred()
func merge(meshes: Array[ArrayMesh]) -> ArrayMesh:
 var surface=SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 for mesh in meshes:
  for index in mesh.get_surface_count(): surface.append_from(mesh,index,Transform3D.IDENTITY)
 return surface.commit()
func run() -> void:
 root.size=Vector2i(1400,900)
 var stage=Node3D.new()
 root.add_child(stage)
 var environment=WorldEnvironment.new()
 environment.environment=Environment.new()
 environment.environment.background_mode=Environment.BG_COLOR
 environment.environment.background_color=Color("677782")
 environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 environment.environment.ambient_light_color=Color.WHITE
 environment.environment.ambient_light_energy=.65
 stage.add_child(environment)
 var sun=DirectionalLight3D.new()
 stage.add_child(sun)
 sun.rotation_degrees=Vector3(-50,-30,0)
 var catalog=EnvironmentCatalog.load_default()
 var visual=load(catalog.descriptor(&"lpfv.fabric.roof.compact.slate.03").visual_path) as EnvironmentVisual
 var source=visual.pieces[0].mesh as ArrayMesh
 # Native quarter stock and proper baked mirrors make both junction slopes
 # share the same exact section at the two diagonal boundaries.
 var quarter=GEO.clip_axis_range(GEO.clip_axis_range(source,0,0,3),2,0,3)
 var cross_symmetric=merge([quarter,GEO.mirror_axis(quarter,0)])
 var middle_half=GEO.clip_axis_range(cross_symmetric,2,0,.75)
 var middle=merge([middle_half,GEO.mirror_axis(middle_half,2)])
 var end=GEO.clip_axis_range(cross_symmetric,2,.75,3)
 var host_parts:Array[ArrayMesh]=[]
 for z in [-1.5,0.0,1.5]: host_parts.append(GEO.transform_mesh(middle,Transform3D(Basis.IDENTITY,Vector3(0,0,z))))
 host_parts.append(GEO.transform_mesh(end,Transform3D(Basis.IDENTITY,Vector3(0,0,1.5))))
 host_parts.append(GEO.transform_mesh(GEO.mirror_axis(end,2),Transform3D(Basis.IDENTITY,Vector3(0,0,-1.5))))
 var host=merge(host_parts)
 var host_negative=GEO.clip_half_space(GEO.clip_axis_range(host,2,-10,0),Plane(Vector3(1,0,1),0))
 var host_positive=GEO.clip_half_space(GEO.clip_axis_range(host,2,0,10),Plane(Vector3(1,0,-1),0))
 var branch_parts:Array[ArrayMesh]=[]
 for z in [0.0,1.5,3.0]: branch_parts.append(GEO.transform_mesh(middle,Transform3D(Basis.IDENTITY,Vector3(0,0,z))))
 branch_parts.append(GEO.transform_mesh(end,Transform3D(Basis.IDENTITY,Vector3(0,0,3))))
 var branch=GEO.transform_mesh(merge(branch_parts),Transform3D(Basis(Vector3.UP,PI/2),Vector3.ZERO))
 branch=GEO.clip_half_space(GEO.clip_half_space(branch,Plane(Vector3(-1,0,1),0)),Plane(Vector3(-1,0,-1),0))
 var total=merge([host_negative,host_positive,branch])
 for s in total.get_surface_count(): total.surface_set_material(s,visual.pieces[0].material_override if visual.pieces[0].material_override else source.surface_get_material(0))
 var instance=MeshInstance3D.new()
 instance.mesh=total
 stage.add_child(instance)
 ResourceSaver.save(total,OUT+"native-valley-prototype.res")
 var camera=Camera3D.new()
 stage.add_child(camera)
 camera.current=true
 for i in 3:
  camera.position=[Vector3(10,10,12),Vector3(10,5,-10),Vector3(2,15,1)][i]
  camera.look_at(Vector3(1,1,0))
  for frame in 10: await process_frame
  RenderingServer.force_draw(false)
  root.get_texture().get_image().save_png(OUT+"native-valley-prototype-%d.png"%i)
 print("NATIVE_VALLEY bounds=",total.get_aabb()," triangles=",GEO.triangle_faces(total).size()/3)
 quit()
