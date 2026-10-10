extends SceneTree
func _init():
 var p=WarrenMazeSitePlanner.plan(11,{},WarrenVillageScaleProfile.for_id(&"compact"),&"",false)
 for plot in p.plots:
  if plot.id!=WarrenPlotReservations.PLAZA_PLOT_ID:continue
  print("PLOT ",plot)
  for c in plot.cells:
   for d in WarrenPassageLatticeRules.DIRECTIONS:
    var v=Vector3i(c.x+d.x,plot.floor,c.y+d.y)
    if p.passage_kinds.has(v):print("ENTRY ",v," flight=",p.excavation.flight_cells().has(v))
 print("WITHDRAWN ",p.audit.get("withdrawn_terminal_public_cells"))
 quit()
