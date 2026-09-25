extends SceneTree
func _initialize()->void:
 var water:=TerrainWorldTuning.make_water(2697992464)
 var a:=Vector2i(-2,-1);var b:=Vector2i(-3,-4)
 print("PRIORITIES ",a," ",water.priority_of(a)," / ",b," ",water.priority_of(b))
 var first:RiverTrace=water.river_for(a,0);var second:RiverTrace=water.river_for(b,0)
 for source:Vector2i in [a,b]:
  for depth in 3:
   var trace:RiverTrace=water.river_for(source,depth)
   print("TRACE ",source," depth=",depth," size=",trace.points.size()," end=",trace.points[-1]," bed=",trace.beds[-1]," joined=",trace.joined)
 for i in first.points.size():
  var nearest:=INF;var station:=-1
  for j in second.points.size():
   var distance:=first.points[i].distance_to(second.points[j])
   if distance<nearest:nearest=distance;station=j
  if nearest<50:
   print("CROSSING a_i=",i," b_i=",station," distance=",nearest," a=",first.points[i]," a_bed=",first.beds[i]," b_bed=",second.beds[station]," b_width=",second.widths[station])
 quit()
