extends SceneTree
const GEO = preload("res://tools/environment_bake/EnvironmentBakeGeometry.gd")
const CUT = preload("res://tests/harness/september13_roof_prism_cut.gd")
const OUT = "res://docs/qa/2026-09-13-manual/11-roof-joins/"
var prepared=OS.get_cmdline_user_args().has("--prepared")
var tight=OS.get_cmdline_user_args().has("--tight")
var orange=OS.get_cmdline_user_args().has("--orange")
var label="offset"
func _init() -> void: run.call_deferred()
func prepared_stock(catalog:EnvironmentCatalog, role:String, narrow:bool)->ArrayMesh:
 var base="lpfv.fabric.roof.compact.orange.03" if orange else "lpfv.fabric.roof.compact.slate.03"
 var mirror=role=="middle_mirror"
 var id=StringName(base+".run."+("middle" if mirror else role)+(".tight" if narrow else "")+(".mirror_z" if mirror else ""))
 var descriptor=catalog.descriptor(id)
 assert(descriptor!=null,str(id))
 var visual=load(descriptor.visual_path) as EnvironmentVisual
 var parts:Array[ArrayMesh]=[]
 for piece:EnvironmentVisualPiece in visual.pieces:
  parts.append(GEO.transform_mesh(piece.mesh,Transform3D(Basis.IDENTITY,Vector3(0,-descriptor.measured_aabb.position.y,0))*piece.local_transform))
 return merge(parts)
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
 var visual=load(catalog.descriptor(&"lpfv.fabric.roof.compact.orange.03" if orange else &"lpfv.fabric.roof.compact.slate.03").visual_path) as EnvironmentVisual
 var source=visual.pieces[0].mesh as ArrayMesh
 var middle=GEO.clip_axis_range(source,2,-.75,.75)
 var end=GEO.clip_axis_range(source,2,.75,3)
 var start=GEO.clip_axis_range(source,2,-3,-.75)
 var mirrored_middle=GEO.mirror_axis(middle,2)
 if prepared:
  label="prepared-"+("orange" if orange else "blue")+("-tight" if tight else "-ordinary")
  middle=prepared_stock(catalog,"middle",tight)
  mirrored_middle=prepared_stock(catalog,"middle_mirror",tight)
  end=prepared_stock(catalog,"end",tight)
  start=prepared_stock(catalog,"start",tight)
 var host_parts:Array[ArrayMesh]=[]
 for i in 3:
  var z=-1.5+1.5*i
  host_parts.append(GEO.transform_mesh(middle if i%2==0 else mirrored_middle,Transform3D(Basis.IDENTITY,Vector3(0,0,z))))
 host_parts.append(GEO.transform_mesh(end,Transform3D(Basis.IDENTITY,Vector3(0,0,1.5))))
 host_parts.append(GEO.transform_mesh(start,Transform3D(Basis.IDENTITY,Vector3(0,0,-1.5))))
 var host=merge(host_parts)
 if prepared:
  middle=prepared_stock(catalog,"middle",false)
  mirrored_middle=prepared_stock(catalog,"middle_mirror",false)
  end=prepared_stock(catalog,"end",false)
 var branch_parts:Array[ArrayMesh]=[]
 for i in 3:
  branch_parts.append(GEO.transform_mesh(middle if i%2==0 else mirrored_middle,Transform3D(Basis.IDENTITY,Vector3(0,0,1.5*i))))
 branch_parts.append(GEO.transform_mesh(end,Transform3D(Basis.IDENTITY,Vector3(0,0,3))))
 var branch=GEO.transform_mesh(GEO.clip_axis_range(merge(branch_parts),2,0,10),Transform3D(Basis(Vector3.UP,PI/2),Vector3(0,0,1.5)))
 var total=merge([CUT.subtract(host,branch,true),CUT.subtract(branch,host)])
 var coverage={}
 for key in ["host","branch","joined"]:
  var mesh=host if key=="host" else branch if key=="branch" else total
  var coords=[]
  for v:Vector3 in GEO.triangle_faces(mesh): coords.append_array([v.x,v.y,v.z])
  coverage[key]=coords
 FileAccess.open(OUT+label+"-native-triangles.json",FileAccess.WRITE).store_string(JSON.stringify(coverage))
 for s in total.get_surface_count(): total.surface_set_material(s,visual.pieces[0].material_override if visual.pieces[0].material_override else source.surface_get_material(0))
 var instance=MeshInstance3D.new()
 instance.mesh=total
 stage.add_child(instance)
 ResourceSaver.save(total,OUT+"native-"+label+"-valley-prototype.res")
 var camera=Camera3D.new()
 stage.add_child(camera)
 camera.current=true
 for i in 3:
  camera.position=[Vector3(6,6,7),Vector3(6,3,-6),Vector3(2,9,1)][i]
  camera.look_at(Vector3(1,1,0))
  for frame in 10: await process_frame
  RenderingServer.force_draw(false)
  root.get_texture().get_image().save_png(OUT+"native-"+label+"-valley-prototype-%d.png"%i)
 print("NATIVE_VALLEY bounds=",total.get_aabb()," triangles=",GEO.triangle_faces(total).size()/3)
 quit()
