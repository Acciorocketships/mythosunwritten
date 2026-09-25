extends SceneTree
const SOURCE="res://docs/qa/2026-09-19-manual/96-inner-shelf-tips/candidate3/after-forms.bin"
func _init()->void:
 var forms:Array=FileAccess.open(SOURCE,FileAccess.READ).get_var()
 inspect(forms,"before")
 preload("res://tests/fixtures/september19/inner-ledge-levels/warp.gd").apply(forms)
 inspect(forms,"candidate")
 quit()
func inspect(forms:Array,label:String)->void:
 var corner:=Vector3(-445.5,32,-301.5)
 var pair:Array=[]
 for f:Dictionary in forms:
  if corner in f.replay_recipe.get("inner_connections",[]):pair.append(f)
 var count:=0;var max_gap:=0.0;var sum:=0.0
 for ix in 17:
  for iz in 17:
   var at:Vector3=corner+Vector3(1.0+float(ix)*.25,6,1.0+float(iz)*.25)
   var hits:Array=[]
   for f:Dictionary in pair:
    var start:Vector3=f.transform.affine_inverse()*at
    var top:=-INF
    for i in range(0,f.green.size(),3):
     var hit=Geometry3D.ray_intersects_triangle(start,Vector3.DOWN,f.green[i],f.green[i+1],f.green[i+2])
     if hit!=null and hit.y>2.0 and hit.y<3.6:top=maxf(top,hit.y)
    if is_finite(top):hits.append(top)
   if hits.size()!=2:continue
   var delta:float=absf(hits[0]-hits[1]);count+=1;sum+=delta;max_gap=maxf(delta,max_gap)
   if ix==5 and iz==5:print("SEAM_POINT ",label," world=",at," heights=",hits)
 print("SEAM ",label," overlaps=",count," max=",max_gap," mean=",sum/maxi(1,count))
