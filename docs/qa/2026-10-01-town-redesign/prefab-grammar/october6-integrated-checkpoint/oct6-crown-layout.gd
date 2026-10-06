extends SceneTree
const Candidate = preload("/tmp/oct6-crown-planner.gd")
func _init():call_deferred("_run")
func _run():
 var result:={}
 for mode:String in ["baseline","candidate"]:
  var profile:=WarrenVillageScaleProfile.for_id(&"large")
  var plan:WarrenMazeSourcePlan
  if mode=="candidate":plan=Candidate.plan(31,{},profile)
  else:plan=WarrenMazeSitePlanner.plan(31,{},profile)
  if plan==null:
   result[mode]={"failure":Candidate.last_failure if mode=="candidate" else WarrenMazeSitePlanner.last_failure}
   continue
  var kinds:={}
  var natives:=[]
  var courts:=[]
  for p:Dictionary in plan.plots:
   var kind:=String(p.kind)
   kinds[kind]=int(kinds.get(kind,0))+1
   if kind==String(WarrenMazeSourcePlan.PLOT_ASSET):natives.append(p)
   if kind==String(WarrenMazeSourcePlan.PLOT_DECK):courts.append(p)
  var covered:=0
  for c in plan.excavation.covered:
   if plan.excavation.covered[c]:covered+=1
  result[mode]={"kinds":kinds,"native":natives,"courts":courts,"covered":covered,"public":plan.excavation.public_cells().size(),"bridges":plan.excavation.bridge_spans.size()}
 FileAccess.open("/tmp/oct6-crown-layout.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 print("LAYOUT ",JSON.stringify(result))
 quit()
