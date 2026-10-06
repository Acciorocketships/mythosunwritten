extends SceneTree
func count_sites(p):
 var streets=WarrenPlotPlanner.street_bands(p)
 var landings=WarrenPlotPlanner.street_bands(p,true)
 var blocked=WarrenPlotPlanner.blocked_columns(p)
 for c in p.massif.columns:
  if p.massif.columns[c].has("house_site"):blocked[c]=true
 var counts={"footprints":0,"fronted":0,"landing":0,"support":0,"budget":0}
 var feasible=[]
 for shape in WarrenPlotReservations._plaza_shapes(p.scale_profile.scaled(WarrenPlotReservations.DECK_MAX)):
  for anchor in p.massif.columns:
   var cells=WarrenPlotReservations._plaza_footprint(p,anchor,shape,blocked)
   if cells.is_empty():continue
   counts.footprints+=1
   if not WarrenPlotReservations._fronting_doors(cells,streets).is_empty():counts.fronted+=1
   var doors=WarrenPlotReservations._fronting_doors(cells,landings)
   if not doors.is_empty():counts.landing+=1
   for datum in doors:
    var cost=0
    var fits=true
    for c in cells:
     if not WarrenPlotReservations._deck_column_ok(p,c,datum,streets,blocked,WarrenPlotReservations.PLAZA_LEVEL_BANDS):fits=false
     cost+=absi(p.massif.top_at(c)-datum)
    if not fits:continue
    counts.support+=1
    if cost>cells.size()*WarrenPlotReservations.PLAZA_CUT_BUDGET_BANDS:continue
    counts.budget+=1
    feasible.append({"cells":cells,"floor":datum,"cost":cost})
 print("SITES ",counts," feasible=",feasible)
func _init():
 for job in [[12,&"compact"],[4,&"compact"],[3,&"standard"],[9,&"standard"]]:
  var profile=WarrenVillageScaleProfile.for_id(job[1])
  for stage in [&"carve",&"reserve",&""]:
   var p=WarrenMazeSitePlanner.plan(job[0],{},profile,stage,false)
   print("TOWN ",job," stage=",stage," held=",p.audit.get("preselected_plaza",{})," plaza=",p.audit.get("plot_outcomes",{}).get("plaza",{}))
   if stage==&"carve":count_sites(p)
   for plot in p.plots:
    if plot.kind==WarrenMazeSourcePlan.PLOT_DECK:print("DECK ",plot)
 quit()
