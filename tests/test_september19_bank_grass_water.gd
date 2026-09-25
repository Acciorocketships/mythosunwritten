extends GutTest
class BankWater extends WaterFieldContext:
 var height:=13.7
 var outside_height:=-INF
 var centre:=Vector2.ZERO
 var queries:=0
 func covers(_p:Vector2)->bool:return true
 func has_sources()->bool:return true
 func shore_distance_at(_p:Vector2)->float:return -.5
 func level_at(p:Vector2)->float:
  queries+=1
  return outside_height if outside_height>0 and p.distance_to(centre)>.1 else height
var program:GrassProgram
var support:Dictionary
var point:Vector2
func before_all()->void:
 program=GrassProgram.new();program.shore_clearance=.3;program.max_grade=1.0
 var banks:Array=FileAccess.open("res://docs/qa/2026-09-19-manual/121-shoreline-rock/owned/banks.bin",FileAccess.READ).get_var()
 var caps:=preload("res://tests/fixtures/september19/bank-grass/supports.gd").surfaces(banks,Rect2(-576,192,192,192))
 var index:=GrassSupportSurfaces.spatial_index(caps)
 for cap:Dictionary in caps:
  var p:Vector3=(cap.face[0]+cap.face[1]+cap.face[2])/3
  var candidate:=GrassSupportSurfaces.at_index(index,Vector2(p.x,p.z))
  if candidate.is_empty() or candidate.normal.y<.99 or candidate.y<14.1:continue
  if support.is_empty() or candidate.edge_distance>support.edge_distance:
   support=candidate;point=Vector2(p.x,p.z)
 assert(not support.is_empty())
func test_dry_rock_ledge_above_water_is_eligible_for_grass()->void:
 var water:=BankWater.new();water.centre=point
 var result:=GrassField._qualified_surface(program,point,null,water,null,.2,{}, {},1.0,support)
 assert_false(result.is_empty(),"The reported dry bank ledge is above water even though its XZ footprint is wet")
 if not result.is_empty():assert_eq(result.y,support.y)
func test_submerged_ledge_stays_bare()->void:
 var water:=BankWater.new();water.height=support.y+.1
 assert_true(GrassField._qualified_surface(program,point,null,water,null,.2,{}, {},1.0,support).is_empty())
func test_higher_water_at_patch_edge_stays_bare()->void:
 var water:=BankWater.new();water.centre=point;water.outside_height=support.y+.1
 assert_true(GrassField._qualified_surface(program,point,null,water,null,.2,{}, {},1.0,support).is_empty())
 assert_gt(water.queries,1,"The broad patch needs water clearance at its edge, not just its center")
func test_ordinary_wet_ground_retains_the_shoreline_rule()->void:
 var water:=BankWater.new()
 assert_true(GrassField._qualified_surface(program,point,null,water,null,.2,{}, {},1.0,{}).is_empty())
func test_sloping_patch_checks_its_lower_edge()->void:
 var water:=BankWater.new()
 var tilted:=support.duplicate();tilted.y=water.height+.35;tilted.normal=Vector3(1,1,0).normalized()
 assert_true(GrassField._qualified_surface(program,point,null,water,null,.2,{}, {},1.0,tilted).is_empty(),"The center is dry but the downhill roots lack water clearance")
func test_patch_clearance_uses_the_actual_reduced_footprint()->void:
 var water:=BankWater.new()
 var tilted:=support.duplicate();tilted.y=water.height+.35;tilted.normal=Vector3(1,1,0).normalized()
 assert_false(GrassField._qualified_surface(program,point,null,water,null,.2,{}, {},.1,tilted).is_empty(),"A genuinely smaller supported patch can remain entirely above water")
