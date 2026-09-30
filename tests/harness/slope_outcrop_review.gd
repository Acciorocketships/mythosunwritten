extends SceneTree
## Small native geometry review; no road-planning wait. Seed matches massif.
const FIELD=preload("res://scripts/terrain/field/CliffSlopeField.gd")
const ROCKS=preload("res://scripts/terrain/field/CliffSlopeRocks.gd")
func _initialize()->void:
 call_deferred("_run")
func _run()->void:
 preload("res://scripts/terrain/field/CliffRockStyle.gd").apply("sheet")
 root.size=Vector2i(1400,900)
 var scene:=Node3D.new();root.add_child(scene)
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-45,-35,0);light.light_energy=1.5;scene.add_child(light)
 var world:=WorldEnvironment.new();world.environment=Environment.new()
 world.environment.background_mode=Environment.BG_COLOR;world.environment.background_color=Color(.65,.76,.8)
 world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;world.environment.ambient_light_color=Color.WHITE;world.environment.ambient_light_energy=.6
 scene.add_child(world)
 var field=FIELD.new([FIELD.straight_wall(Vector2(-30,0),Vector2(30,0),Vector2(0,1),8.)],2697992464)
 var material:=StandardMaterial3D.new();material.albedo_color=Color(.3,.44,.22);material.roughness=1.0
 for placement:Dictionary in field.solid(Rect2(-33,-5,66,22)):
  var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=placement.faces
  var normals:=PackedVector3Array()
  for v:Vector3 in placement.faces:normals.append(placement.native_roots[v][0])
  arrays[Mesh.ARRAY_NORMAL]=normals
  var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  var node:=MeshInstance3D.new();node.mesh=mesh;node.material_override=material;scene.add_child(node)
 var entries:={}
 for rock:Dictionary in field.rock_list:entries[rock.piece]=entries.get(rock.piece,[])+[rock]
 scene.add_child(ROCKS.build(entries,2697992464))
 var exposed_ends:=0;var ends:=0
 for rock:Dictionary in field.rock_list:
  if rock.kind!="face":continue
  var piece:Array=ROCKS._pieces[rock.piece]
  var bounds:Vector3=ROCKS.PIECES[rock.piece][1]
  for v:Vector3 in piece[0].get_faces():
   var local:Vector3=piece[1]*v
   if absf(local.y)<bounds.y*.42:continue
   ends+=1
   var p:Vector3=rock.transform*local
   if p.y>field.envelope().sample(Vector2(p.x,p.z)):exposed_ends+=1
 print("[outcrop_review] exposed end vertices=",exposed_ends,"/",ends)
 var cam:=Camera3D.new();scene.add_child(cam);cam.position=Vector3(21,16,29);cam.look_at(Vector3(2,4,3));cam.current=true
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("/tmp/slope-outcrop-review.png")
 print("[outcrop_review] rocks=",field.rock_list.size())
 quit()
