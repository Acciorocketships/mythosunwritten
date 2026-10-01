extends SceneTree
func _initialize()->void:
 var control:="--control" in OS.get_cmdline_user_args()
 var script:GDScript=load("res://tests/fixtures/september17/hillside-order/terrace_order.gd" if control else "res://tests/fixtures/september17/hillside-order/terminal_join.gd")
 var water=script.new(2697992464,TerrainWorldTuning.HEIGHTFIELD_AMPLITUDE,TerrainWorldTuning.HEIGHTFIELD_MAX_STOREYS)
 if "--reverse" in OS.get_cmdline_user_args():water.river_for(Vector2i(-4,-1))
 var incoming:RiverTrace=water.river_for(Vector2i(-2,-1))
 var target:Dictionary
 if control:
  var receiver:RiverTrace=water._join_target(incoming.points[-1],incoming.beds[-1],water._index_neighbour_rivers(water._neighbour_rivers(incoming.source_cell,water.JOIN_DEPTH)))
  assert(receiver!=null)
  var nearest:=0
  for i in receiver.points.size():
   if incoming.points[-1].distance_to(receiver.points[i])<incoming.points[-1].distance_to(receiver.points[nearest]):nearest=i
  target={"receiver":receiver,"station":nearest,"start":incoming.points.size()-1,"gap":incoming.points[-1].distance_to(receiver.points[nearest])}
 else:
  assert(water.terminal_targets.has(incoming.source_cell))
  target=water.terminal_targets[incoming.source_cell]
 var receiver:RiverTrace=target.receiver
 var station:int=target.station
 var plan:=TerrainWorldTuning.make_heightfield(2697992464,water)
 var cell:=Vector2i((incoming.points[-1]/24).floor())
 var region:=plan.compute_rect_region(Rect2i(cell-Vector2i.ONE*4,Vector2i.ONE*9))
 var receiving:=WaterField.profile(receiver,region)
 var profile:=WaterField.profile(incoming,region)
 var max_rise:=0.0
 for i in range(1,incoming.points.size()):max_rise=maxf(max_rise,profile.levels[i]-profile.levels[i-1])
 print("CARVED_TERMINAL source=",incoming.source_cell," receiver=",receiver.source_cell," incoming_count=",incoming.points.size()," receiver_count=",receiver.points.size()," station=",station," connector_gap=",target.gap," head_gap=",profile.levels[-1]-receiving.levels[station]," spatial_gap=",incoming.points[-1].distance_to(receiver.points[station])," max_rise=",max_rise)
 var discovered:=false
 for trace:RiverTrace in water._region_for(Vector2i((incoming.points[-1]/water.SUPER).floor())).rivers:
  if trace==incoming:discovered=true
 print("TERMINAL_DISCOVERED endpoint_owner=",discovered)
 for i in range(maxi(0,target.start-2),incoming.points.size()):
  print("CARVED_STATION i=",i," p=",incoming.points[i]," bed=",incoming.beds[i]," head=",profile.levels[i]," native_ground=",TerrainTileField.surface_y(region,incoming.points[i].x,incoming.points[i].y))
 if "--fill" in OS.get_cmdline_user_args():
  var centre:Vector2=receiver.points[station]
  var start:Vector2=incoming.points[target.start]
  var context:=WaterFieldContext.build(water,Rect2(centre,Vector2.ZERO).expand(start).grow(4.0),region,0.0)
  var wet:=0;var samples:=0;var rise:=0.0;var previous:=NAN
  # Identical spatial probes in control and candidate, including the endpoint.
  var steps:=maxi(1,ceili(start.distance_to(centre)/.75))
  for step in steps+1:
   var point:Vector2=start.lerp(centre,float(step)/steps)
   var level:=context.level_at(point)
   if is_finite(level):
    wet+=1
    if is_finite(previous):rise=maxf(rise,level-previous)
   samples+=1;previous=level
   print("TERMINAL_FILL_SAMPLE p=",point," level=",level," ground=",TerrainTileField.surface_y(region,point.x,point.y))
  print("TERMINAL_FILL wet=",wet," total=",samples," maximum_rise=",rise," end_level=",context.level_at(centre)," receiver_profile=",receiving.levels[station])
 print("CARVED_DEPENDENCIES nesting=",water.max_dependency_nesting," edges=",water.dependency_edges.size())
 quit()
