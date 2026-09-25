extends SceneTree
func _initialize()->void:
 preload("res://tests/fixtures/september17/cliff-corners/rooted-study.gd").prepare()
 var mesh:Mesh=load("res://terrain/environment/meshes/kaykit/kaykit_cliff_outer_wall_piece_00.res")
 var faces:=mesh.get_faces()
 print("CORNER_BOUNDS ",mesh.get_aabb())
 for y:float in [.3,1.0,2.0,3.5]:
  for angle:float in [0,22.5,45,67.5,90]:
   var outward:=Vector3(sin(deg_to_rad(angle)),0,cos(deg_to_rad(angle)))
   var center:=Vector3(-1.5,y,-1.5)
   var depth:=-INF
   for i in range(0,faces.size(),3):
    var hit=Geometry3D.ray_intersects_triangle(center+outward*20,-outward,faces[i],faces[i+1],faces[i+2])
    if hit!=null:depth=maxf(depth,(hit-center).dot(outward)-1.5)
   print("CORNER_RADIUS y=",y," angle=",angle," depth=",depth)
 quit()
