extends SceneTree
## Repeatable source-stage survey; no seed-specific production rules.
## Run headless with --log-file and this script via -s.
func _init() -> void: call_deferred("run")
func run() -> void:
 var totals := {}
 var bridge_reasons := {}
 var seeded := 0
 var composed := 0
 var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default()) if "--compose" in OS.get_cmdline_user_args() else null
 for size_id: StringName in [&"compact",&"standard",&"large"]:
  for seed_value: int in [3,5,6,7,9,10,12,1260018864828801968]:
   var source := WarrenMazeSitePlanner.plan(seed_value,{},WarrenVillageScaleProfile.for_id(size_id),&"",false)
   if source == null:
    print("FAIL ",seed_value," ",size_id)
    continue
   seeded += source.excavation.bridge_span_audit.get("seeded",[]).size()
   for record: Dictionary in source.excavation.bridge_span_audit.get("refused",[]):
    var reason := String(record.get("reason","unknown")).get_slice(" at ",0).get_slice(" (",0)
    bridge_reasons[reason] = int(bridge_reasons.get(reason,0))+1
   var outcomes: Dictionary = source.audit.get("plot_outcomes",{})
   var reasons := {}
   var covers := 0
   for record: Dictionary in outcomes.get("tunnel_roofs",[]):
    var reason := String(record.get("reason",""))
    if reason == "": reason = "accepted"
    reasons[reason] = int(reasons.get(reason,0))+1
    totals[reason] = int(totals.get(reason,0))+1
   for plot: Dictionary in source.plots:
    if plot.kind == WarrenMazeSourcePlan.PLOT_OVER: covers += 1
   if program != null:
    var spatial := preload("res://tests/fixtures/frozen_maze_source.gd").spatial(source,program)
    if spatial == null:
     print("COMPOSE FAIL ",seed_value,"/",size_id)
     continue
    var built := KitVillageBuildings.build(spatial,spatial.compiled_fabric_cache(),SuntailBuildingKit.create())
    var floating := KitFloatingMassAudit.audit(spatial,spatial.compiled_fabric_cache(),built.masses)
    var stamped := 0
    for record: Dictionary in spatial.audit.get("maze_bridge_outcomes",[]):
     stamped += int(record.outcome == "stamped")
    composed += stamped
    print("BUILT ",seed_value,"/",size_id," bridges=",stamped," floating=",floating.count," outcomes=",spatial.audit.get("maze_bridge_outcomes",[]))
   print("SKY ",seed_value,"/",size_id," tunnels=",source.excavation.tunnel_cells.size()," covers=",covers," reasons=",reasons)
 print("COMPOSED ",composed)
 print("TOTAL ",totals)
 print("BRIDGE SEEDED ",seeded," REFUSED ",bridge_reasons)
 quit()
