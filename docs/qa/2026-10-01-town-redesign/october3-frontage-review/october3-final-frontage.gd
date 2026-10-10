extends SceneTree
func _init():
 var world_seed=6046713720826375059
 var profile=WarrenVillageScaleProfile.select(world_seed)
 for stage in [&"carve",&"reserve",&""]:
  var plan=WarrenMazeSitePlanner.plan(world_seed,{},profile,stage,true)
  if plan==null:
   print("NULL ",stage," ",WarrenMazeSitePlanner.last_failure)
   continue
  var doors={}
  for plot in plan.plots:
   doors[plot.door_walk]=plot.id
  print("STAGE ",stage," passages=",plan.passage_cells().size()," plots=",plan.plots.size()," frontage=",plan.audit.get("frontage_ratio",-1)," withdrawn=",plan.audit.get("withdrawn_terminal_public_cells",[]))
  for lane in plan.excavation.lanes:
   if lane.get("feature_kind",&"")==&"perimeter":
    var addressed=[]
    for c in lane.cells:
     if doors.has(c):addressed.append([c,doors[c]])
    print("PERIMETER ",lane.cells," doors=",addressed)
 quit()
