extends SceneTree
## Investigational comparison; neither plan mutates production configuration.
func _initialize()->void:
 var original:=TerrainWorldTuning.make_water(2697992464)
 var trial=preload("res://tests/fixtures/september17/hillside-order/terrace_order.gd").new(2697992464,TerrainWorldTuning.HEIGHTFIELD_AMPLITUDE,TerrainWorldTuning.HEIGHTFIELD_MAX_STOREYS)
 var cells:Array[Vector2i]=[]
 for z in range(-3,0):
  for x in range(-4,-1):cells.append(Vector2i(x,z))
 cells.append(Vector2i(-3,-4))
 var rows:=[]
 for cell:Vector2i in cells:
  var before:RiverTrace=original.river_for(cell)
  var after:RiverTrace=trial.river_for(cell)
  if before==null:
   assert(after==null)
   continue
  var receiver:RiverTrace=original._join_target(before.points[-1],before.beds[-1],original._index_neighbour_rivers(original._neighbour_rivers(cell,original.JOIN_DEPTH))) if before.joined else null
  var same_band:=false
  if receiver!=null:same_band=floori(before.beds[0]/4.0)==floori(receiver.beds[0]/4.0)
  var prefix:=true
  var raw:RiverTrace=trial.river_for(cell,0)
  for i in after.points.size():
   if after.points[i]!=raw.points[i] or after.beds[i]!=raw.beds[i] or after.widths[i]!=raw.widths[i]:prefix=false
  var row:Dictionary={"source":str(cell),"source_head":before.beds[0],"before_count":before.points.size(),"after_count":after.points.size(),"before_joined":before.joined,"after_joined":after.joined,"old_receiver":str(receiver.source_cell) if receiver!=null else "none","same_source_band":same_band,"trial_is_raw_prefix":prefix,"before_end":str(before.points[-1]),"after_end":str(after.points[-1])}
  rows.append(row)
  print("ROUTE_DELTA ",JSON.stringify(row))
 var path:="res://docs/qa/2026-09-18-manual/53-hillside-native/route-delta.json"
 FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
 quit()
