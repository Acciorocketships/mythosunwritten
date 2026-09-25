extends GutTest
## Native rendered normals: distinguish short chipped transitions from soft noise,
## and retain unchanged shading at a zero-thickness native-wall attachment.
func _normal_image(position:Vector3,weight:float,yaw:float=0.0)->Image:
 var view:=SubViewport.new();view.size=Vector2i(512,512);view.own_world_3d=true
 view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 var world:=Node3D.new();view.add_child(world)
 var quad:=QuadMesh.new();quad.size=Vector2(16,16)
 var arrays:=quad.get_mesh_arrays()
 var colors:=PackedColorArray();colors.resize((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size());colors.fill(Color(1,1,1,weight))
 arrays[Mesh.ARRAY_COLOR]=colors
 var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 var node:=MeshInstance3D.new();node.mesh=mesh;node.position=position;node.rotation.y=yaw;world.add_child(node)
 var path:=OS.get_environment("STORY_STONE_TEST_SHADER")
 if path.is_empty():path="res://terrain/materials/cliff_crag.gdshader"
 var code:=FileAccess.get_file_as_string(path)
 code=code.replace("shader_type spatial;","shader_type spatial;\nrender_mode unshaded;")
 var last:=code.rfind("}")
 code=code.substr(0,last)+"\n ALBEDO=NORMAL*.5+.5;\n}"+code.substr(last+1)
 var shader:=Shader.new();shader.code=code
 var material:=ShaderMaterial.new();material.shader=shader;node.material_override=material
 var camera:=Camera3D.new();camera.position=position+Basis(Vector3.UP,yaw)*Vector3(0,0,20);camera.rotation.y=yaw;camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=16;camera.current=true;world.add_child(camera)
 add_child(view)
 for frame in 5:await get_tree().process_frame
 await RenderingServer.frame_post_draw
 var image:=view.get_texture().get_image()
 view.free()
 return image
func _normal(image:Image,x:int,y:int)->Vector3:
 var color:=image.get_pixel(x,y).srgb_to_linear()
 return (Vector3(color.r,color.g,color.b)*2.0-Vector3.ONE).normalized()
func test_exposed_stone_has_chipped_transitions_without_pixel_spikes()->void:
 if DisplayServer.get_name()=="headless":pending("Requires native GPU normal readback");return
 for position:Vector3 in [Vector3(-443,36,-266),Vector3(-482,36,-249),Vector3(-1262,64,-537)]:
  for yaw:float in [0.0,PI*.25,PI*.5]:
   var image:=await _normal_image(position,1.0,yaw)
   var chips:=0;var spikes:=0;var strong:=0;var maximum:=0.0
   for y in range(2,510):
    for x in range(2,510):
     var normal:=_normal(image,x,y)
     var angle:=maxf(normal.angle_to(_normal(image,x+1,y)),normal.angle_to(_normal(image,x,y+1)))
     maximum=maxf(maximum,angle)
     if angle>deg_to_rad(20):strong+=1
     if angle>deg_to_rad(5):chips+=1
     if angle>deg_to_rad(65):spikes+=1
   print("STONE_NORMAL position=",position," yaw=",rad_to_deg(yaw)," chipped_pixels=",chips," spikes=",spikes," strong=",strong," max=",rad_to_deg(maximum))
   assert_gte(strong,512,"A small but resolved fraction of the exposed stone needs sharp creases above the soft grain contrast")
   assert_eq(spikes,0,"A fracture cannot produce isolated near-flipped normals")
func test_thin_native_attachment_keeps_its_original_normal()->void:
 if DisplayServer.get_name()=="headless":pending("Requires native GPU normal readback");return
 var image:=await _normal_image(Vector3(-443,36,-266),0.0)
 print("THIN_CENTER pixel=",image.get_pixel(256,256)," normal=",_normal(image,256,256))
 var errors:=0
 for y in range(8,504,8):
  for x in range(8,504,8):
   if _normal(image,x,y).angle_to(Vector3.BACK)>deg_to_rad(1):errors+=1
 assert_eq(errors,0,"The independent material detail must vanish at the native join")
