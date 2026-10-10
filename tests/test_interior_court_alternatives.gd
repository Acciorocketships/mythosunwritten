extends GutTest
func test_failed_preferred_entrance_can_recover_a_broad_square():
 var plan:=WarrenMazeSitePlanner.plan(257,{},WarrenVillageScaleProfile.for_id(&'grand'),&'',false)
 assert_not_null(plan)
 if plan==null:return
 var site:Dictionary=plan.audit.get('interior_court',{})
 assert_false(site.is_empty(),'An unreachable first doorway must not discard all feasible interior squares')
 if site.is_empty():return
 var attempts:Array=plan.audit.interior_court_attempts
 assert_gt(attempts.size(),1)
 assert_false(attempts[0].accepted)
 assert_true(attempts.back().accepted)
 assert_lte(attempts.size(),WarrenMazeCarver.COURT_ENTRANCE_ATTEMPTS)
 var court:Dictionary={}
 for plot:Dictionary in plan.plots:
  if plot.id==&'plaza.00':court=plot
 assert_eq(court.cells.size(),9)
 assert_true(plan.passage_kinds.has(court.door_walk))
 assert_false(plan.excavation.flight_cells().has(court.door_walk))
 assert_eq(court.door_walk,site.entrance)
