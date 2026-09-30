extends SceneTree
## Native GPU control: actual grass-root shader versus actual slope shader,
## unlit on one fixed support patch. Geometry and camera are identical.
const CRAGS=preload("res://scripts/terrain/field/CliffRockCrags.gd")
const STYLE=preload("res://scripts/terrain/field/CliffRockStyle.gd")
func _initialize()->void:_run.call_deferred()
func _run()->void:
 STYLE.apply("sheet_bedrock")
 CliffDressing.prepare(EnvironmentRenderCache.new(EnvironmentCatalog.load_default()))
 root.size=Vector2i(400,400)
 var scene:=Node3D.new();root.add_child(scene)
 var camera:=Camera3D.new();scene.add_child(camera)
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=1.8
 camera.look_at_from_position(Vector3(0,5,.001),Vector3.ZERO);camera.current=true
 var surface:=PlaneMesh.new();surface.size=Vector2(2,2)
 var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_custom_data=true;mm.use_colors=true;mm.mesh=surface;mm.instance_count=1
 mm.set_instance_transform(0,Transform3D.IDENTITY);mm.set_instance_color(0,Color.WHITE)
 var node:=MultiMeshInstance3D.new();node.multimesh=mm;scene.add_child(node)
 var baseline:=OS.get_cmdline_user_args().has("--baseline")
 var dir:="res://docs/qa/2026-09-26-manual-cliffs/colour-control"+("-before" if baseline else "")
 DirAccess.make_dir_recursive_absolute(dir)
 var rows:=[]
 for angle:float in [0,20,35,45]:
  var n:=Vector3(sin(deg_to_rad(angle)),cos(deg_to_rad(angle)),0)
  mm.set_instance_custom_data(0,Color(0,0,n.x,n.z))
  var colours:=[]
  for kind:String in ["slope","grass"]:
   var path:="res://terrain/materials/cliff_crag.gdshader" if kind=="slope" else "res://terrain/grass/grass.gdshader"
   var code:=FileAccess.get_file_as_string("/tmp/cliffs-baseline-grass.shader" if baseline and kind=="grass" else path)
   if kind=="slope":
    code=code.replace("shader_type spatial;","shader_type spatial;\nrender_mode unshaded;")
    code=code.replace("stone_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);","stone_normal=vec3(%f,%f,0.0);"%[n.x,n.y])
    code=code.replace("stone_rise=UV2;","stone_rise=vec2(%f,1.0);"%[28*(1-n.y)])
   else:code=code.replace("render_mode cull_disabled;","render_mode cull_disabled, unshaded;")
   var shader:=Shader.new();shader.code=code
   var material:=ShaderMaterial.new();material.shader=shader;CRAGS.apply_moss(material)
   material.set_shader_parameter("ground_palette_uv",CliffDressing.ground_uv())
   material.set_shader_parameter("exposure_rock",false)
   node.material_override=material
   for frame in 8:await process_frame
   await RenderingServer.frame_post_draw
   var img:=root.get_texture().get_image()
   img.save_png(dir+"/%s-%02d.png"%[kind,angle])
   var colour:=img.get_pixel(200,200);colours.append(colour)
  var delta:=Vector3(colours[0].r-colours[1].r,colours[0].g-colours[1].g,colours[0].b-colours[1].b).length()
  rows.append({"angle":angle,"slope":str(colours[0]),"grass":str(colours[1]),"delta":delta})
  if not baseline:assert(delta<.015,"Root colour must match the supporting slope")
 FileAccess.open(dir+"/results.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
 print("COLOUR_CONTROL ",JSON.stringify(rows));quit()
