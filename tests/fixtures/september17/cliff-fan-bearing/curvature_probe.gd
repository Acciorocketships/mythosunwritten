extends SceneTree
func _initialize()->void:call_deferred("_run")
func _run()->void:
 var generator:GDScript=load(OS.get_environment("STORY_DETAIL_GENERATOR"))
 var anchors:Array=FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin",FileAccess.READ).get_var()
 var scores:Array[float]=[];var highs:=0
 for anchor:Array in anchors:
  var form:Dictionary=generator.make(anchor[0],anchor[1],anchor[2],2697992464,null,anchor[3],anchor[4])[0]
  var heights:Dictionary={}
  for point:Vector3 in form.faces:
   if point.z<-.4 or point.y<1.0 or point.y>anchor[2]-1.0:continue
   var grid:=Vector2i(roundi(point.x*4),roundi(point.y*5))
   if absf(point.x-grid.x*.25)>.001 or absf(point.y-grid.y*.2)>.001:continue
   heights[grid]=maxf(heights.get(grid,-INF),point.z)
  for grid:Vector2i in heights:
   if heights[grid]<2.0:continue
   var neighbors:Array=[grid+Vector2i.LEFT,grid+Vector2i.RIGHT,grid+Vector2i.UP,grid+Vector2i.DOWN]
   if not neighbors.all(func(g:Vector2i)->bool:return heights.has(g)):continue
   var curvature:float=absf(heights[neighbors[0]]+heights[neighbors[1]]-2.0*heights[grid])+absf(heights[neighbors[2]]+heights[neighbors[3]]-2.0*heights[grid])
   scores.append(curvature)
   if curvature>.25:highs+=1
 scores.sort()
 print("CURVATURE samples=",scores.size()," median=",scores[scores.size()/2]," q75=",scores[scores.size()*3/4]," q95=",scores[scores.size()*95/100]," high_ratio=",float(highs)/scores.size())
 quit()
