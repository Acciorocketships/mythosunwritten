extends GutTest

func _sample(path:String,position:Vector3)->Image:
 var view:=SubViewport.new();view.size=Vector2i(256,256);view.own_world_3d=true
 view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 var world:=Node3D.new();view.add_child(world)
 var plane:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2(20,20)
 var arrays:=quad.get_mesh_arrays();var colors:=PackedColorArray()
 colors.resize((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size());colors.fill(Color(1,1,1,0))
 arrays[Mesh.ARRAY_COLOR]=colors
 var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 plane.mesh=mesh;plane.position=position;world.add_child(plane)
 var code:=FileAccess.get_file_as_string(path).replace("shader_type spatial;","shader_type spatial;\nrender_mode unshaded;")
 var shader:=Shader.new();shader.code=code
 var material:=ShaderMaterial.new();material.shader=shader
 material.set_shader_parameter("use_texture",false);material.set_shader_parameter("instance_variation",false)
 plane.material_override=material
 var camera:=Camera3D.new();camera.position=position+Vector3(0,0,20);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=20;camera.current=true;world.add_child(camera)
 add_child(view)
 for frame in 5:await get_tree().process_frame
 await RenderingServer.frame_post_draw
 var image:=view.get_texture().get_image();view.free();return image

func test_stone_has_restrained_spatial_colour_without_stripes_or_join_mismatch()->void:
 if DisplayServer.get_name()=="headless":pending("Requires native GPU colour readback");return
 for position:Vector3 in [Vector3(-443,36,-266),Vector3(-1262,64,-537),Vector3(10,12,30)]:
  var crag:=await _sample("res://terrain/materials/cliff_crag.gdshader",position)
  var native:=await _sample("res://terrain/materials/field_rock.gdshader",position)
  var values:Array[float]=[];var max_step:=0.0;var max_seam:=0.0
  for y in range(8,248):
   for x in range(8,248):
    var c:=crag.get_pixel(x,y).srgb_to_linear();var n:=native.get_pixel(x,y).srgb_to_linear()
    values.append(c.get_luminance())
    var next:=crag.get_pixel(x+1,y).srgb_to_linear()
    max_step=maxf(max_step,absf(c.get_luminance()-next.get_luminance()))
    max_seam=maxf(max_seam,maxf(absf(c.r-n.r),maxf(absf(c.g-n.g),absf(c.b-n.b))))
  values.sort();var middle:float=values[values.size()/2]
  var contrast:float=(values[int(values.size()*.95)]-values[int(values.size()*.05)])/middle
  print("STONE_COLOUR position=",position," contrast=",contrast," step=",max_step/middle," seam=",max_seam)
  assert_gt(contrast,.07,"Broad stone areas need visible colour variation even at native joins")
  assert_lt(contrast,.40,"Keep grey stone restrained rather than high-contrast streaks")
  assert_lt(max_step/middle,.03,"Colour must vary smoothly rather than make sharp pixel bands")
  assert_lt(max_seam,.003,"Native stone and added rock share the same colour field at their join")
