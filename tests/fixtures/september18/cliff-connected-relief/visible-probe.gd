extends SceneTree
const BASE=preload("res://tests/fixtures/september18/cliff-connected-relief/before.gd")
const NEXT=preload("res://tests/fixtures/september18/cliff-connected-relief/broad.gd")
func _initialize()->void:
 var anchors:Array=FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin",FileAccess.READ).get_var()
 var eye:=Vector3(-482,42,-229);var target:=Vector3(-483,36,-249)
 var basis:=Basis.looking_at(target-eye)
 var pixels:Array=[Vector2(400,530),Vector2(800,530),Vector2(1200,530),Vector2(1200,620)]
 for generator:GDScript in [BASE,NEXT]:
  var results:Array=[]
  for pixel:Vector2 in pixels:results.append({"distance":INF})
  for index in anchors.size():
   var a:Array=anchors[index];var pose:Transform3D=a[0]
   var rock:Dictionary=generator.make(pose,a[1],a[2],2697992464,null,a[3],a[4])[0]
   var faces:PackedVector3Array=rock.faces
   var origin:Vector3=pose.affine_inverse()*eye
   for pi in pixels.size():
    var pixel:Vector2=pixels[pi]
    var local_direction:Vector3=Vector3((pixel.x-800)/500*tan(deg_to_rad(32.5)),(500-pixel.y)/500*tan(deg_to_rad(32.5)),-1).normalized()
    var direction:Vector3=pose.basis.inverse()*basis*local_direction
    for i in range(0,faces.size(),3):
     var hit=Geometry3D.ray_intersects_triangle(origin,direction,faces[i],faces[i+1],faces[i+2])
     if hit==null:continue
     var distance:float=origin.distance_to(hit)
     if distance>=results[pi].distance:continue
     results[pi]={"distance":distance,"anchor":index,"hit":str(hit),"tri":[str(faces[i]),str(faces[i+1]),str(faces[i+2])],"normal":str((faces[i+2]-faces[i]).cross(faces[i+1]-faces[i]).normalized())}
  print("VISIBLE ",generator.resource_path," ",JSON.stringify(results))
 quit()
