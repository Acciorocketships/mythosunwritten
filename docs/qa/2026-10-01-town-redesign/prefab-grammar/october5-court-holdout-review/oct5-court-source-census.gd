extends SceneTree
func _init():call_deferred('run')
func run():
 var out:={}
 for seed_value in [43,83,211,257]:
  var p:=WarrenMazeSitePlanner.plan(seed_value,{},WarrenVillageScaleProfile.for_id(&'grand'),&'',false)
  if p==null:out[seed_value]={'failure':WarrenMazeSitePlanner.last_failure};continue
  var squares:=[]
  for plot:Dictionary in p.plots:
   if plot.kind==WarrenMazeSourcePlan.PLOT_DECK:squares.append({'id':plot.id,'cells':plot.cells.size(),'floor':plot.floor})
  out[seed_value]={'proposal':p.audit.get('interior_court',{}),'visits':p.audit.get('interior_court_visits',0),'squares':squares}
  print('SOURCE ',seed_value,' ',out[seed_value])
 FileAccess.open('/tmp/oct5-court-source-census.json',FileAccess.WRITE).store_string(JSON.stringify(out,'\t'))
 quit()
