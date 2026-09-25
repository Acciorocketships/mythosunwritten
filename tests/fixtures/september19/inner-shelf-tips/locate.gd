extends SceneTree
const SOURCE="res://docs/qa/2026-09-19-manual/94-stepped-inner-join/candidate/after-forms.bin"
func _initialize()->void:call_deferred("run")
func run()->void:
 var view:=SubViewport.new();view.size=Vector2i(1600,1000);root.add_child(view)
 var camera:=Camera3D.new();view.add_child(camera);camera.position=Vector3(-435,43,-267);camera.look_at(Vector3(-444,29,-276));camera.fov=65
 var forms:Array=FileAccess.open(SOURCE,FileAccess.READ).get_var()
 for pixel:Vector2 in [Vector2(728,402),Vector2(765,468),Vector2(938,605),Vector2(949,671),Vector2(857,422),Vector2(815,513)]:
  var origin:=camera.project_ray_origin(pixel);var direction:=camera.project_ray_normal(pixel)
  var nearest:=INF;var result:Dictionary={}
  for form:Dictionary in forms:
   var local:Transform3D=(form.transform as Transform3D).affine_inverse()
   var start:Vector3=local*origin;var ray:Vector3=local.basis*direction
   for i in range(0,form.faces.size(),3):
    var a:Vector3=form.faces[i];var b:Vector3=form.faces[i+1];var c:Vector3=form.faces[i+2]
    var hit:Variant=Geometry3D.ray_intersects_triangle(start,ray,a,b,c)
    if hit==null:continue
    var distance:float=start.distance_to(hit)
    if distance>=nearest:continue
    nearest=distance
    result={"pixel":str(pixel),"point":str(form.transform*hit),"local":str(hit),"id":form.id,"pose":str(form.transform),"recipe":str(form.replay_recipe),"triangle":[str(a),str(b),str(c)],"index":i}
  print("TIP ",JSON.stringify(result))
 quit()
