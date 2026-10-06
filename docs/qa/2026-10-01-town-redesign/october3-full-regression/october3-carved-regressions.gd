extends SceneTree
func _init():
 for job in [[17,&"compact"],[29,&"standard"],[43,&"large"],[71,&"grand"],[12,&"compact"],[4,&"compact"],[3,&"standard"],[9,&"standard"]]:
  var profile=WarrenVillageScaleProfile.for_id(job[1])
  var plan=WarrenMazeCarver.carve(job[0],WarrenMassifBuilder.build(job[0],{},profile),profile)
  if plan==null:
   print("LAYOUT_NULL ",job," ",WarrenMazeSitePlanner.last_failure)
   continue
  var kinds={}
  var max_walk=0
  for c in plan.passage_kinds:
   var k=String(plan.passage_kinds[c]);kinds[k]=int(kinds.get(k,0))+1;max_walk=maxi(max_walk,c.y)
  var e=plan.excavation
  for lane in e.lanes:
   if String(lane.get("feature_kind","")).contains("gate"):
    print("GATE ",job," kind=",lane.get("feature_kind")," anchor=",lane.anchor," cells=",lane.cells)
  print("LAYOUT ",job," route=",e.route," summit=",plan.summit_cell," platform=",plan.massif.is_platform(plan.massif.crown_column)," walks=",kinds," max_walk=",max_walk," plaza=",plan.audit.get("plot_outcomes",{}).get("plaza",{}))
 quit()
