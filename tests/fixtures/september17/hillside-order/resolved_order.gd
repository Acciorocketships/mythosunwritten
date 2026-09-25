extends "res://scripts/terrain/water/WaterPlan.gd"
# Investigation only: use an acyclic physical head ordering instead of a
# pairwise lower-at-crossing rule, which allowed reciprocal disappearing tails.
func _neighbour_rivers(sc:Vector2i,depth:int,progress_start:float=-1.0,progress_end:float=-1.0)->Array:
 if depth<=0:return []
 var mine:=river_for(sc,0)
 var bounds:=_bounds_for(mine).grow(SENSE_RADIUS+W_MAX)
 var others:Array=[]
 for dz in range(-REACH_SUPERS*2,REACH_SUPERS*2+1):
  for dx in range(-REACH_SUPERS*2,REACH_SUPERS*2+1):
   var cell:=sc+Vector2i(dx,dz)
   if cell==sc:continue
   var raw:=river_for(cell,0)
   if raw==null or not _bounds_for(raw).intersects(bounds):continue
   if raw.beds[0]>mine.beds[0]:continue
   if raw.beds[0]==mine.beds[0] and raw.priority<=mine.priority:continue
   var index:=_index_neighbour_rivers([raw]);var touches:=false
   for i in mine.points.size():
    if _join_target(mine.points[i],mine.beds[i],index)!=null:touches=true;break
   if not touches:continue
   var resolved:=river_for(cell,JOIN_DEPTH,progress_start,progress_end)
   others.append(resolved)
 return others
