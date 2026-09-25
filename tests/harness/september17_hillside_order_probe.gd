extends SceneTree
func _initialize()->void:
 var source:GDScript=preload("res://tests/fixtures/september17/hillside-order/head_order.gd")
 if "--resolved" in OS.get_cmdline_user_args():source=preload("res://tests/fixtures/september17/hillside-order/resolved_order.gd")
 if "--certified" in OS.get_cmdline_user_args():source=preload("res://tests/fixtures/september17/hillside-order/certified_prefix.gd")
 if "--terrace" in OS.get_cmdline_user_args():source=preload("res://tests/fixtures/september17/hillside-order/terrace_order.gd")
 var plan=source.new(2697992464,TerrainWorldTuning.HEIGHTFIELD_AMPLITUDE,TerrainWorldTuning.HEIGHTFIELD_MAX_STOREYS)
 var started:=Time.get_ticks_msec()
 var cells:Array[Vector2i]=[Vector2i(-2,-1),Vector2i(-3,-4)]
 if "--reverse" in OS.get_cmdline_user_args():cells.reverse()
 for cell:Vector2i in cells:
  for depth in 4:
   var trace:RiverTrace=plan.river_for(cell,depth)
   print("HEAD_ORDER source=",cell," depth=",depth," head=",trace.beds[0]," stations=",trace.points.size()," joined=",trace.joined," end=",trace.points[-1]," end_bed=",trace.beds[-1])
  if "--receivers" in OS.get_cmdline_user_args():
   var current:RiverTrace=plan.river_for(cell)
   var others:Array=plan._neighbour_rivers(cell,plan.JOIN_DEPTH)
   var target:RiverTrace=plan._join_target(current.points[-1],current.beds[-1],plan._index_neighbour_rivers(others))
   if target!=null:
    var nearest:=0
    for i in target.points.size():
     if target.points[i].distance_to(current.points[-1])<target.points[nearest].distance_to(current.points[-1]):nearest=i
    print("ORDER_RECEIVER source=",cell," target=",target.source_cell," target_head=",target.beds[0]," target_count=",target.points.size()," station=",nearest," bed=",target.beds[nearest]," gap=",target.points[nearest].distance_to(current.points[-1])," width=",target.widths[nearest])
 print("HEAD_ORDER elapsed=",(Time.get_ticks_msec()-started)/1000.0," cache=",plan._trace_cache.size())
 if "--terrace" in OS.get_cmdline_user_args():
  print("ORDER_DEPENDENCIES nesting=",plan.max_dependency_nesting," edges=",plan.dependency_edges.size())
  for bands:Array in plan.dependency_edges.values():assert(bands[1]<bands[0])
 quit()
