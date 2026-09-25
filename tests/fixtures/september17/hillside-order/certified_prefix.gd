extends "res://scripts/terrain/water/WaterPlan.gd"
## Investigation only. A receiver always retains the raw prefix preceding any
## possible raw confluence. Admit contacts only inside that immutable prefix.
## Two finite neighborhood scans replace recursively resolved receiver tails.
var _certified:Dictionary={}
var _candidate_cache:Dictionary={}

func _raw_candidates(sc:Vector2i)->Array:
 if _candidate_cache.has(sc):return _candidate_cache[sc]
 var mine:=river_for(sc,0)
 var bounds:=_bounds_for(mine).grow(SENSE_RADIUS+W_MAX)
 var result:Array=[]
 for dz in range(-REACH_SUPERS*2,REACH_SUPERS*2+1):
  for dx in range(-REACH_SUPERS*2,REACH_SUPERS*2+1):
   var cell:=sc+Vector2i(dx,dz)
   if cell==sc:continue
   var raw:=river_for(cell,0)
   if raw==null or not _bounds_for(raw).intersects(bounds):continue
   if raw.beds[0]>mine.beds[0]:continue
   if raw.beds[0]==mine.beds[0] and raw.priority<=mine.priority:continue
   var index:=_index_neighbour_rivers([raw])
   for i in mine.points.size():
    if _join_target(mine.points[i],mine.beds[i],index)!=null:
     result.append(raw);break
 _candidate_cache[sc]=result
 return result

func _certified_prefix(sc:Vector2i)->RiverTrace:
 if _certified.has(sc):return _certified[sc]
 var raw:=river_for(sc,0)
 var index:=_index_neighbour_rivers(_raw_candidates(sc))
 for i in raw.points.size():
  if _join_target(raw.points[i],raw.beds[i],index)==null:continue
  var result:=RiverTrace.new()
  result.source_cell=raw.source_cell;result.priority=raw.priority
  result.source_pool=raw.source_pool
  result.points=raw.points.slice(0,i+1)
  result.beds=raw.beds.slice(0,i+1)
  result.widths=raw.widths.slice(0,i+1)
  result.joined=true
  _certified[sc]=result
  return result
 _certified[sc]=raw
 return raw

func _neighbour_rivers(sc:Vector2i,depth:int,_progress_start:float=-1.0,_progress_end:float=-1.0)->Array:
 if depth<=0:return []
 var result:Array=[]
 for raw:RiverTrace in _raw_candidates(sc):result.append(_certified_prefix(raw.source_cell))
 return result
