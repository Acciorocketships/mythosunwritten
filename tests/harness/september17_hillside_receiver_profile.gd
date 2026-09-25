extends SceneTree
func _initialize()->void:
 var water:=preload("res://tests/fixtures/september17/hillside-order/terrace_order.gd").new(2697992464,TerrainWorldTuning.HEIGHTFIELD_AMPLITUDE,TerrainWorldTuning.HEIGHTFIELD_MAX_STOREYS)
 var plan:=TerrainWorldTuning.make_heightfield(2697992464,water)
 var incoming:RiverTrace=water.river_for(Vector2i(-2,-1))
 var neighbors:=water._neighbour_rivers(incoming.source_cell,water.JOIN_DEPTH)
 var receiver:RiverTrace=water._join_target(incoming.points[-1],incoming.beds[-1],water._index_neighbour_rivers(neighbors))
 assert(receiver!=null)
 var cell:=Vector2i((incoming.points[-1]/24).floor())
 var region:=plan.compute_rect_region(Rect2i(cell-Vector2i.ONE*4,Vector2i.ONE*9))
 for river:RiverTrace in [incoming,receiver]:
  var profile:=WaterField.profile(river,region)
  var nearest:=0
  for i in river.points.size():
   if river.points[i].distance_to(incoming.points[-1])<river.points[nearest].distance_to(incoming.points[-1]):nearest=i
  print("RECEIVER_PROFILE source=",river.source_cell," station=",nearest," point=",river.points[nearest]," bed=",river.beds[nearest]," head=",profile.levels[nearest]," local_ground=",TerrainSurfaceField.surface_y(region,river.points[nearest].x,river.points[nearest].y))
  for i in range(maxi(0,nearest-4),mini(river.points.size(),nearest+3)):
   print("RECEIVER_NEAR source=",river.source_cell," station=",i," point=",river.points[i]," bed=",river.beds[i]," head=",profile.levels[i])
 quit()
