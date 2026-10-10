extends SceneTree
func _init():
 var data=FileAccess.open('res://terrain/environment/geometry/pure_village_roof_turret.bin',FileAccess.READ).get_var()
 var pose=Transform3D(Basis(Vector3(.8320503,0,.5547002),Vector3.UP,Vector3(-.5547002,0,.8320503)),Vector3(-8,19.25,-4))
 var surfaces=[]
 for mesh in data[&'pure_village.roof_turret.roof']:
  var vs=[]
  for v in mesh.vertices:vs.append([ (pose*v).x,(pose*v).y,(pose*v).z])
  surfaces.append({'vertices':vs,'indices':Array(mesh.indices)})
 var report=JSON.parse_string(FileAccess.get_file_as_string('/tmp/turret-fragments.json'))
 report.append({'role':'native.cap','asset':'native.cap','surfaces':surfaces})
 FileAccess.open('/tmp/cap-ray.json',FileAccess.WRITE).store_string(JSON.stringify(report))
 quit()
