extends RefCounted
const ROCKS=preload("res://scripts/terrain/field/CliffRockDressing.gd")
const FIT=preload("res://tests/fixtures/september19/bank-grass/fit.gd")
# The caller must bound the actual full grass-patch radius by this value.
# Beyond that distance omitted component borders cannot change patch fitting.
const NEIGHBOR_REACH:=4.0
static func admit(sources:Array,core:Rect2,region:HeightfieldRegion,water:WaterFieldContext)->Array[Dictionary]:
 var result:Array[Dictionary]=[]
 var domain:=core.grow(NEIGHBOR_REACH)
 for source:Dictionary in sources:
  var footprint:=ROCKS._footprint(source.bounds)
  if not footprint.intersects(domain,true):continue
  if not ROCKS._wet_formation(source,water):result.append(source);continue
  assert(water.coverage().encloses(footprint.grow(3.0)),"Shared bank support needs its complete hydraulic admission footprint")
  var bank:=FIT.fit(source,region,water)
  if not bank.is_empty():result.append(bank)
 result.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return String(a.id)<String(b.id))
 return result
static func surfaces(admitted:Array,core:Rect2)->Array[Dictionary]:
 var result:Array[Dictionary]=[]
 for rock:Dictionary in admitted:
  if not ROCKS._footprint(rock.bounds).intersects(core,true):continue
  result.append_array(ROCKS.ledge_grass_supports(rock,admitted))
 return result
