extends SceneTree
## Original connected cliff buttresses. Each closed solid carries its own
## descending terraces; its high rear ridge is buried in the native wall.
const SECTORS := 14
func _initialize()->void:
 DirAccess.make_dir_recursive_absolute("res://assets/CliffOutcrops")
 for variant in 6:
  var vertices:Array[Vector3]=[]
  var triangles:Array=[]
  var phase:float=variant*1.37
  var upper:float=.70+.075*sin(phase)
  var lower:float=.28+.08*cos(phase)
  var heights:Array[float]=[1.0,.83,upper+.04,upper,upper-.012,upper-.045,(upper+lower)*.5,lower+.035,lower,lower-.012,lower-.048,.08,.018]
  var radii:Array[float]=[.08,.16,.25,.30,.62,.67,.68,.70,.73,1.0,1.04,1.03,1.0]
  var widths:Array[float]=[.79,.80,.84,.87,.97,1.0,1.01,1.02,1.03,1.08,1.09,1.1,1.1]
  var count:=SECTORS+3
  for row in heights.size():
   for j in SECTORS+1:
    var angle:float=PI*float(j)/SECTORS
    # Uneven but shared contours keep every riser joined to its ledge.
    var scallop:float=1.0+.18*sin(angle*3.0+phase)+.07*cos(angle*7.0-phase)
    var x:float=cos(angle)*.5*widths[row]*scallop+.055*sin(phase+heights[row]*2.0)*sin(angle)
    var upper_strength:float=smoothstep(-.65,.65,sin(angle*2.0+phase*.7))
    var lower_strength:float=smoothstep(-.7,.65,sin(angle*2.0+phase*.7+2.6))
    if variant in [1,4]:
     upper_strength*=.12;lower_strength=maxf(lower_strength,.70)
    if variant in [2,5]:
     lower_strength*=.12;upper_strength=maxf(upper_strength,.70)
    var radius:float=radii[row]
    if row==4:radius=.30+.24*upper_strength
    if row==5:radius=.36+.24*upper_strength
    if row==6:radius=.62+.12*upper_strength
    if row==7:radius=.75+.10*upper_strength
    if row==8:radius=.78+.12*upper_strength
    if row==9:radius=.75+.25*lower_strength
    if row==10:radius=.79+.25*lower_strength
    var z:float=-.17+sin(angle)*radius*scallop
    if row in [1,2,6,7,11]:
     z+=sin(angle)*.048*sin(angle*7.0+phase+row*.8)
     x+=sin(angle)*.025*sin(angle*5.0+phase+row*.9)
    if row==1:z-=sin(angle)*.06
    # The entire buried root fits the parent wall; broad ledges fan outward
    # only after emerging. This prevents an exposed rear fin at wall ends.
    var bearing_half_width:float=lerpf(.36,.60,smoothstep(0.0,.16,z))
    if row==0:bearing_half_width=.29
    x*=bearing_half_width/.60
    if z<=0.0:x=clampf(x,-.31,.31)
    var y:float=heights[row]+sin(angle)*(.047*sin(angle*3.0+phase)+.023*cos(angle*7.0-phase))*sin(heights[row]*PI)
    # A short central walking patch survives inside an uneven larger shoulder.
    # Ends rise into the wall and grades vary between shelves, rather than
    # making every whole ledge a horizontal extrusion.
    if row in [3,4,8,9]:
     var level:float=upper if row<5 else lower
     var edge:float=maxf(0.0,absf(float(j)-7.0)-1.0)/6.0
     y=level+edge*edge*(.055+.04*sin(phase+angle))
     if j<6 or j>8:y+=.02*sin(angle*3.0+phase)*sin(angle)
     if row in [4,9]:y-=edge*.045
     if variant in [1,3,5]:y+=.085*cos(angle)+.018*sin(angle*5.0+phase)
    if row>0:
     # Nested cross-sections: no narrowed waist or curled-in side can sit
     # under a larger upper shelf. Lower rock continuously bears upper rock.
     var previous:Vector3=vertices[(row-1)*count+j]
     z=maxf(z,previous.z+.004)
     if absf(cos(angle))>.01:x=signf(x)*maxf(absf(x),absf(previous.x)+.001)
    if z<=0.0:x=clampf(x,-.31,.31)
    vertices.append(Vector3(x,y,z))
   vertices.append(Vector3(-.31,heights[row],-.48))
   vertices.append(Vector3(.31,heights[row],-.48))
  for row in heights.size()-1:
   for j in count:
    var next:=(j+1)%count
    var a:=row*count+j;var b:=row*count+next
    var c:=(row+1)*count+j;var d:=(row+1)*count+next
    # Broad near-horizontal ledges only. The two end sectors keep a gray
    # collar where the outcrop intersects the wall; steep shoulders stay rock.
    var turf:bool=row in [3,8] and j>=2 and j<SECTORS-2
    if turf:
     var min_up:=1.0
     for face:Array in [[a,b,c],[b,d,c]]:
      var aa:Vector3=vertices[face[0]]*Vector3(26,18,7)
      var bb:Vector3=vertices[face[1]]*Vector3(26,18,7)
      var cc:Vector3=vertices[face[2]]*Vector3(26,18,7)
      min_up=minf(min_up,(bb-aa).cross(cc-aa).normalized().y)
     turf=min_up>.86 and minf(vertices[a].z,minf(vertices[b].z,minf(vertices[c].z,vertices[d].z)))>.06
     if (row==3 and variant in [1,4]) or (row==8 and variant in [2,5]):turf=false
    triangles.append([a,b,c,turf]);triangles.append([b,d,c,turf])
  var top:=vertices.size();vertices.append(Vector3(0,1,-.34))
  var bottom:=vertices.size();vertices.append(Vector3(0,.018,-.34))
  for j in count:
   var next:=(j+1)%count
   triangles.append([top,next,j,false])
   triangles.append([bottom,(heights.size()-1)*count+j,(heights.size()-1)*count+next,false])
  var mesh:=ArrayMesh.new()
  for turf in [false,true]:
   var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);st.set_smooth_group(-1 if turf else 0)
   for tri in triangles:
    if tri[3]!=turf:continue
    for i in [0,2,1]:st.add_vertex(vertices[tri[i]])
   st.generate_normals()
   var arrays:=st.commit_to_arrays()
   if not turf:
    var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
    var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
    var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
    var expanded:=SurfaceTool.new();expanded.begin(Mesh.PRIMITIVE_TRIANGLES)
    for face in range(0,points.size() if indices.is_empty() else indices.size(),3):
     var ids:Array=[face,face+1,face+2] if indices.is_empty() else [indices[face],indices[face+1],indices[face+2]]
     var plane:Vector3=(points[ids[2]]-points[ids[0]]).cross(points[ids[1]]-points[ids[0]]).normalized()
     for index:int in ids:
      expanded.set_normal(plane.lerp(normals[index],.28).normalized());expanded.add_vertex(points[index])
    expanded.commit(mesh)
   else:mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
   var mat:=StandardMaterial3D.new();mat.roughness=1;mat.metallic_specular=0
   mat.albedo_color=Color(.2,.5,.15) if turf else Color(.40,.39,.42)
   mesh.surface_set_material(mesh.get_surface_count()-1,mat)
  var root:=Node3D.new();var node:=MeshInstance3D.new();node.mesh=mesh;root.add_child(node);node.owner=root
  var doc:=GLTFDocument.new();var state:=GLTFState.new();assert(doc.append_from_scene(root,state)==OK)
  assert(doc.write_to_filesystem(state,"res://assets/CliffOutcrops/boulder_%d.glb"%variant)==OK)
  root.free()
 quit()
