extends SceneTree
func _init(): call_deferred('run')
func run():
 var out := {}
 for seed_value in [19,29,47,61,73,97,109,139,163,181,223,283]:
  var start := Time.get_ticks_msec()
  var p := WarrenMazeSitePlanner.plan(seed_value,{},WarrenVillageScaleProfile.for_id(&'grand'),&'',false)
  var row := {'ms':Time.get_ticks_msec()-start}
  if p == null:
   row['failure']=WarrenMazeSitePlanner.last_failure
  else:
   row['court']=p.audit.get('interior_court',{})
   row['visits']=p.audit.get('interior_court_visits',0)
   row['attempts']=p.audit.get('interior_court_attempts',[])
   row['squares']=[]
   for plot:Dictionary in p.plots:
    if plot.kind==WarrenMazeSourcePlan.PLOT_DECK:row.squares.append({'id':plot.id,'cells':plot.cells.size(),'floor':plot.floor})
  out[str(seed_value)]=row
  FileAccess.open('/tmp/oct5-court-holdout-source.json',FileAccess.WRITE).store_string(JSON.stringify(out,'\t'))
  print('COURT_HOLDOUT ',seed_value,' ms=',row.ms,' attempts=',row.get('attempts',[]).size(),' accepted=',not row.get('court',{}).is_empty())
 quit()
