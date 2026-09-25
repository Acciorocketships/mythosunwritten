extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var source=preload("res://tests/fixtures/september18/cliff-widening-shoulders/fan.gd")
 var anchors:Array=FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin",FileAccess.READ).get_var()
 var forms:Array=[]
 for a:Array in anchors:forms.append_array(source.make(a[0],a[1],a[2],2697992464,null,a[3],a[4]))
 var corner=preload("res://tests/fixtures/september18/cliff-widening-shoulders/fan-corner.gd")
 var rows:Array=FileAccess.open("res://docs/qa/2026-09-18-manual/45-cliff-widening-shoulders/fan-context/corner-rows.bin",FileAccess.READ).get_var()
 forms.append_array(corner.formations(rows,2697992464))
 var eye:=Vector3(-423,40,-292);var target:=Vector3(-442,36,-298)
 var basis:=Basis.looking_at(target-eye,Vector3.UP)
 var extent:=tan(deg_to_rad(65*.5))
 for pixel:Vector2 in [Vector2(1380,600),Vector2(1460,750),Vector2(1100,650),Vector2(1300,900),Vector2(500,550)]:
  var direction:Vector3=basis*Vector3((pixel.x/800.0-1)*extent*1.6,(1-pixel.y/500.0)*extent,-1).normalized()
  var distance:=INF;var hit_info:Dictionary={}
  for index in forms.size():
   var form:Dictionary=forms[index]
   var inverse:Transform3D=form.transform.affine_inverse()
   var origin:Vector3=inverse*eye;var ray:Vector3=inverse.basis*direction
   var faces:PackedVector3Array=form.faces
   for i in range(0,faces.size(),3):
    var hit=Geometry3D.ray_intersects_triangle(origin,ray,faces[i],faces[i+1],faces[i+2])
    if hit==null:continue
    var depth:float=origin.distance_to(hit)
    if depth>=distance:continue
    distance=depth
    var normal:Vector3=(faces[i+2]-faces[i]).cross(faces[i+1]-faces[i]).normalized()
    hit_info={"form":index,"anchor":form.anchor,"hit":hit,"world":form.transform*hit,"normal":normal,"triangle":[faces[i],faces[i+1],faces[i+2]],"end":anchors[index].slice(3) if index<anchors.size() else []}
  print("SURFACE_RAY pixel=",pixel," distance=",distance," info=",hit_info)
 quit()
