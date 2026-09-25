extends SceneTree
func _initialize()->void:
 call_deferred("_run")
func _run()->void:
 var generator: GDScript=load(OS.get_environment("STORY_COLUMN_GENERATOR"))
 var anchors:Array=FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin",FileAccess.READ).get_var()
 var camera:=Transform3D.IDENTITY
 camera.origin=Vector3(-423,40,-292)
 camera=camera.looking_at(Vector3(-442,36,-298))
 var samples:Array=[]
 for sx in [1170,1200,1220]:
  for sy in [520,540,560,580,600]:samples.append(Vector2(sx,sy))
 var hits:Array=[]
 for screen:Vector2 in samples:
  var scale:=tan(deg_to_rad(65.0)*.5)
  var direction:=camera.basis*Vector3((screen.x/800.0-1.0)*1.6*scale,(1.0-screen.y/500.0)*scale,-1).normalized()
  var closest:=INF;var record:Dictionary={}
  for index in anchors.size():
   var a:Array=anchors[index]
   var form:Dictionary=generator.make(a[0],a[1],a[2],2697992464,null,a[3],a[4])[0]
   var origin:Vector3=a[0].affine_inverse()*camera.origin
   var ray:Vector3=a[0].basis.inverse()*direction
   var faces:PackedVector3Array=form.faces
   for i in range(0,faces.size(),3):
    var hit=Geometry3D.ray_intersects_triangle(origin,ray,faces[i],faces[i+1],faces[i+2])
    if hit==null:continue
    var distance:float=hit.distance_to(origin)
    if distance<closest:
     closest=distance
     record={"screen":str(screen),"anchor":index,"local":str(hit),"triangle":[str(faces[i]),str(faces[i+1]),str(faces[i+2])],"normal":str((faces[i+2]-faces[i]).cross(faces[i+1]-faces[i]).normalized())}
  hits.append(record)
 print(JSON.stringify(hits,"  "))
 quit()
