extends GutTest
## Grass on a raised support (a dry ledge whose XZ footprint is wet): the
## support's own plane owns water clearance (GrassField._qualified_surface /
## _support_clears_water); ordinary ground keeps the signed shoreline rule.
## September 19 pinned this on a bank ledge built from crag formations; the
## supports here are synthetic ({y, normal, edge_distance}), the invariants
## exact.
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

const POINT:=Vector2(-480.0,280.0)
var program:GrassProgram

func before_all()->void:
 program=GrassProgram.new();program.shore_clearance=.3;program.max_grade=1.0

## A flat ledge 0.5 m above the 13.7 m water: 0.2 m more than the clearance.
static func _flat_ledge()->Dictionary:
 return {"y":14.2,"normal":Vector3.UP,"edge_distance":1.0}

## A ledge tilted 45 degrees whose centre stands 0.35 m over the water (only
## 0.05 m above the clearance plane): its downhill roots at 0.2 m drop 0.2 m.
static func _tilted_ledge()->Dictionary:
 return {"y":13.7+.35,"normal":Vector3(1,1,0).normalized(),"edge_distance":1.0}

func _qualify(water:BankWater,support:Dictionary,edge_scale:=1.0)->Dictionary:
 return GrassField._qualified_surface(program,POINT,null,water,null,.2,{},{},edge_scale,support)

func test_dry_rock_ledge_above_water_is_eligible_for_grass()->void:
 var water:=BankWater.new();water.centre=POINT
 var support:=_flat_ledge()
 var result:=_qualify(water,support)
 assert_false(result.is_empty(),"The dry ledge is above water even though its XZ footprint is wet")
 if not result.is_empty():assert_eq(result.y,support.y)

func test_submerged_ledge_stays_bare()->void:
 var water:=BankWater.new();water.height=_flat_ledge().y+.1
 assert_true(_qualify(water,_flat_ledge()).is_empty())

func test_higher_water_at_patch_edge_stays_bare()->void:
 var water:=BankWater.new();water.centre=POINT;water.outside_height=_flat_ledge().y+.1
 assert_true(_qualify(water,_flat_ledge()).is_empty())
 assert_gt(water.queries,1,"The broad patch needs water clearance at its edge, not just its center")

func test_ordinary_wet_ground_retains_the_shoreline_rule()->void:
 assert_true(_qualify(BankWater.new(),{}).is_empty())

func test_sloping_patch_checks_its_lower_edge()->void:
 assert_true(_qualify(BankWater.new(),_tilted_ledge()).is_empty(),"The center is dry but the downhill roots lack water clearance")

func test_patch_clearance_uses_the_actual_reduced_footprint()->void:
 assert_false(_qualify(BankWater.new(),_tilted_ledge(),.1).is_empty(),"A genuinely smaller supported patch can remain entirely above water")
