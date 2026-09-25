extends SceneTree
## Read-only audit of the unshipped descending-head experiment.
const CANDIDATE=preload("res://tests/fixtures/september17/hillside-order/terrace_order.gd")
func _initialize()->void:
 var cells:Array[Vector2i]=[]
 for z in range(-3,0):
  for x in range(-4,-1):cells.append(Vector2i(x,z))
 cells.append(Vector2i(-3,-4))
 var snapshots:Array=[]
 for reverse:bool in [false,true]:
  var plan=CANDIDATE.new(2697992464,TerrainWorldTuning.HEIGHTFIELD_AMPLITUDE,TerrainWorldTuning.HEIGHTFIELD_MAX_STOREYS)
  var order:=cells.duplicate()
  if reverse:order.reverse()
  var records:Dictionary={};var start:=Time.get_ticks_msec()
  for cell:Vector2i in order:
   var trace:RiverTrace=plan.river_for(cell)
   if trace==null:
    records[cell]=null
    continue
   var targets:Array=plan._neighbour_rivers(cell,plan.JOIN_DEPTH)
   var target:RiverTrace=plan._join_target(trace.points[-1],trace.beds[-1],plan._index_neighbour_rivers(targets))
   var fingerprint:=var_to_bytes([trace.points,trace.beds,trace.widths,trace.joined,trace.land_bars]).hex_encode().sha256_text()
   var depth_one:RiverTrace=plan.river_for(cell,1)
   var depth_equal:=trace.points==depth_one.points and trace.beds==depth_one.beds and trace.widths==depth_one.widths and trace.joined==depth_one.joined
   records[cell]=[fingerprint,trace.points.size(),trace.joined,target.source_cell if target!=null else null,depth_equal]
   print("ORDER_CORPUS reverse=",reverse," cell=",cell," record=",records[cell])
  snapshots.append(records)
  print("ORDER_CORPUS_RUN reverse=",reverse," elapsed_s=",(Time.get_ticks_msec()-start)/1000.0," cache=",plan._trace_cache.size()," nesting=",plan.max_dependency_nesting," edges=",plan.dependency_edges.size())
 var different:=0;var dangling:=0;var depth_different:=0;var joined:=0
 for cell:Vector2i in cells:
  if snapshots[0][cell]!=snapshots[1][cell]:different+=1
  var record=snapshots[0][cell]
  if record==null:continue
  if record[2]:
   joined+=1
   if record[3]==null:dangling+=1
  if not record[4]:depth_different+=1
 print("ORDER_CORPUS_RESULT cells=",cells.size()," order_differences=",different," joined=",joined," missing_receiver=",dangling," depth_differences=",depth_different)
 quit(0 if different==0 and dangling==0 and depth_different==0 else 1)
