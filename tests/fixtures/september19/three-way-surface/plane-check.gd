extends SceneTree
const U=preload("res://tests/fixtures/september19/three-way-surface/union.gd")
func _init()->void:
 var ps:Array[Vector3]=[];var ds:Array[float]=[]
 for p:Vector3i in U.CUBE:
  ps.append(Vector3(p));ds.append(.5-p.y+.1*p.x)
 var faces:=PackedVector3Array();var green:=PackedVector3Array()
 for tet:Array in U.TETS:U._tet(ps,ds,tet,faces,green)
 var expected:=Vector3(-.1,1,0).normalized();var error:=0.0
 for i in range(0,faces.size(),3):
  var n:Vector3=(faces[i+2]-faces[i]).cross(faces[i+1]-faces[i]).normalized()
  error=maxf(error,n.distance_to(expected))
 print("PLANE triangles=",faces.size()/3," green=",green.size()/3," maximum_normal_error=",error)
 quit(1 if error>.001 else 0)
