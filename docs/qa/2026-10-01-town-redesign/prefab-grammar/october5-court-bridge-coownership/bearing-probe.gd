extends SceneTree
func _init():
 var source=preload("res://tests/fixtures/frozen_maze_source.gd").read("res://tests/fixtures/october5-court-bridge-bearing-source.txt")
 var volume=WarrenMazeVolumeAdapter.to_volume_plan(source)
 for e in source.excavation.walk_edges():
  if e.a.y==e.b.y:continue
  var t=WarrenVolumeTransition.new(&"probe",e.a,e.b,WarrenVolumeTransition.Kind.STAIR,[] as Array[Vector3i])
  for fine in t.clearance_air_cells():
   if Vector3i(floori(float(fine.x)/2),fine.y,floori(float(fine.z)/2))==Vector3i(-2,6,-1):
    print("FOUNDATION_FLIGHT ",e)
    break

 for plot in source.plots:
  if plot.cells.has(Vector2i(-2,-1)):print("COLUMN_PLOT ",plot)
  if plot.id!=&"bridge.01.end.0.lower":continue
  print("PLOT ",plot)
  print("FRONTAGE ",volume.has_frontage(plot.door_walk))
  print("PUBLIC_CEILING ",WarrenMazeBlockPartitioner.plot_has_public_ceiling(source,plot,volume))
  for c in plot.cells:
   for y in range(0,plot.top+1):print("MASS ",c," band=",y," ",volume.has_mass(Vector3i(c.x,y,c.y))," source=",source.solid_at(Vector3i(c.x,y,c.y))," carved=",source.excavation.carved.has(Vector3i(c.x,y,c.y)))
  print("CANDIDATES ",WarrenMazeBlockPartitioner._rectangles(plot,plot.door_walk))
 quit()
