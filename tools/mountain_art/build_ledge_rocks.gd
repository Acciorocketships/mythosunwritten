extends SceneTree
## Original solid rock ribs: broad planes and irregular recessed green shelves.
## Reference direction: Ultimate Nature moss rocks; no source geometry is copied.
func _initialize()->void:
 DirAccess.make_dir_recursive_absolute("res://assets/CliffMossRocks")
 for variant in range(10,18):
  var rng:=RandomNumberGenerator.new();rng.seed=variant*9817
  var count:=1+variant%3
  var outline:=[Vector2(-.5,-.3),Vector2(-.32,-.5),Vector2(.30,-.5),Vector2(.5,-.27),Vector2(.50,.19),Vector2(.37,.5),Vector2(-.36,.50),Vector2(-.5,.23)]
  for j in outline.size():outline[j]+=Vector2(rng.randf_range(-.025,.025),rng.randf_range(-.025,.025))
  var rings:Array=[]
  var y:=0.0
  var front:=.82
  var centre:=0.0
  for level in count+1:
   var next_y:=1.0 if level==count else float(level+1)/float(count+1)+rng.randf_range(-.065,.065)
   var width:=lerpf(1.0,.82,float(level)/float(count))
   var lean:=rng.randf_range(-.055,.055)
   if level==0:rings.append(_ring(outline,0,width,front,centre))
   rings.append(_ring(outline,next_y-.018,width+rng.randf_range(-.04,.02),front,centre+lean))
   if level<count:
    front-=.40/float(count)
    centre+=rng.randf_range(-.07,.07)
    rings.append(_ring(outline,next_y,width-.015,front,centre))
  var top:Array=rings.back()
  for j in top.size():top[j].y=1.0
  var warp:=PackedFloat32Array()
  for j in outline.size():warp.append(rng.randf_range(-.055,.055))
  for k in range(1,rings.size()-1):
   for j in outline.size():rings[k][j].y+=warp[j]
  var polygons:Array=[]
  for k in rings.size()-1:
   for j in outline.size():
    var n:=(j+1)%outline.size()
    polygons.append([rings[k][j],rings[k+1][j],rings[k][n]])
    polygons.append([rings[k][n],rings[k+1][j],rings[k+1][n]])
  for j in range(1,outline.size()-1):
   polygons.append([rings[0][0],rings[0][j],rings[0][j+1]])
   polygons.append([top[0],top[j+1],top[j]])
  for tri:Array in polygons:
   var swap:Vector3=tri[1];tri[1]=tri[2];tri[2]=swap
  var volume:=0.0
  for tri:Array in polygons:volume+=(tri[0] as Vector3).dot((tri[2] as Vector3).cross(tri[1]))/6.0
  assert(volume>0,"Closed rock faces must point outward")
  var mesh:=ArrayMesh.new()
  for moss in [false,true]:
   var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES);surface.set_smooth_group(-1)
   for tri:Array in polygons:
    var normal:Vector3=(tri[2]-tri[0]).cross(tri[1]-tri[0]).normalized()
    var is_green:=normal.y>.65
    if is_green!=moss:continue
    for p:Vector3 in tri:surface.add_vertex(p)
   surface.generate_normals();surface.commit(mesh)
   var mat:=StandardMaterial3D.new();mat.roughness=1;mat.metallic_specular=0
   mat.albedo_color=Color(.19,.32,.10) if moss else Color(.40,.39,.42)
   mesh.surface_set_material(mesh.get_surface_count()-1,mat)
  var root:=Node3D.new();var node:=MeshInstance3D.new();node.mesh=mesh;root.add_child(node);node.owner=root
  var doc:=GLTFDocument.new();var state:=GLTFState.new();assert(doc.append_from_scene(root,state)==OK)
  assert(doc.write_to_filesystem(state,"res://assets/CliffMossRocks/moss_%d.glb"%variant)==OK)
  root.free()
 quit()

func _ring(outline:Array,y:float,width:float,front:float,centre:float)->Array:
 var out:=[]
 for p:Vector2 in outline:
  var z:=lerpf(-.5,front,p.y+.5)
  out.append(Vector3(p.x*width+centre,y,z))
 return out
