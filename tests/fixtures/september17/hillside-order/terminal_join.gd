extends "res://tests/fixtures/september17/hillside-order/terrace_order.gd"
## Investigation only: complete an admitted channel contact to the receiver's
## actual centre station before the shared terrain carver sees the trace.
var terminal_targets:Dictionary={}
func _joined_trace(sc:Vector2i,depth:int,progress_start:float,progress_end:float)->RiverTrace:
 var trace:RiverTrace=super._joined_trace(sc,depth,progress_start,progress_end)
 if trace==null or not trace.joined:return trace
 var neighbors:=_neighbour_rivers(sc,depth,progress_start,progress_end)
 var receiver:=_join_target(trace.points[-1],trace.beds[-1],_index_neighbour_rivers(neighbors))
 if receiver==null:return trace
 var nearest:=-1;var gap:=INF
 for i in receiver.points.size():
  var distance:=trace.points[-1].distance_to(receiver.points[i])
  if receiver.beds[i]>trace.beds[-1] or distance>receiver.widths[i]:continue
  if distance<gap:nearest=i;gap=distance
 if nearest<0:return trace
 var start:=trace.points[-1];var bed:=trace.beds[-1];var width:=trace.widths[-1]
 var original_count:=trace.points.size()
 var steps:=ceili(gap/3.0)
 for step in range(1,steps+1):
  var t:=float(step)/steps
  trace.points.append(start.lerp(receiver.points[nearest],t))
  trace.beds.append(lerpf(bed,receiver.beds[nearest],t))
  trace.widths.append(width)
 terminal_targets[sc]={"receiver":receiver,"station":nearest,"start":original_count-1,"gap":gap}
 return trace
