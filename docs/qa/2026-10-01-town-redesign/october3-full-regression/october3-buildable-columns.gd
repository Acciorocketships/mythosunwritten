extends SceneTree
func longest(source,column,start):
 var run=0
 var best=0
 for band in range(start,source.massif.top_at(column)):
  run=0 if source.excavation.carved.has(Vector3i(column.x,band,column.y)) else run+1
  best=maxi(best,run)
 return best
func _init():
 var totals=[0,0,0,0]
 for job in [[12,&"compact"],[4,&"compact"],[3,&"standard"],[9,&"standard"]]:
  var p=WarrenVillageScaleProfile.for_id(job[1])
  var plan=WarrenMazeSitePlanner.plan(job[0],{},p,&"",false)
  var raw=WarrenMazeCarver.carve(job[0],WarrenMassifBuilder.build(job[0],{},p),p)
  var owned={}
  for plot in plan.plots:
   for c in plot.cells:owned[c]=true
  for r in plan.audit.get("plot_outcomes",{}).get("asset_clearance_reservations",[]):
   for c in r.get("columns",[]):owned[c]=true
  for c in raw.massif.columns:
   if raw.massif.is_reserved_ground(c):continue
   var before=longest(raw,c,raw.massif.base_at(c))>=WarrenMazeSourcePlan.MIN_HOUSE_BANDS
   var after=longest(raw,c,raw.massif.bearing_at(c))>=WarrenMazeSourcePlan.MIN_HOUSE_BANDS
   totals[0]+=int(before);totals[1]+=int(before and owned.has(c));totals[2]+=int(after);totals[3]+=int(after and owned.has(c))
   if before and not after:print("PLINTH ",job," ",c," base=",raw.massif.base_at(c)," bearing=",raw.massif.bearing_at(c)," top=",raw.massif.top_at(c)," owned=",owned.has(c))
 print("TOTALS ",totals)
 quit()
