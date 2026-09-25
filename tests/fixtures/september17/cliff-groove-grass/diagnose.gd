extends GutTest
var ROCKS:GDScript
func _fixture()->Dictionary:
 ROCKS.prepare()
 var plan:=HeightfieldPlan.new(17,64,12,"mean",4)
 plan.set_raw_height_override(func(x:int,_z:int)->float:return 16.0 if x<=3 else 0.0)
 var region:=plan.compute_region(4,4,12)
 var water:=WaterFieldContext.new()
 water._region=region;water._coverage=Rect2(-48,-48,288,288)
 water._ctx={"ponds":[],"rivers":[],"buckets":{},"region":region}
 water._shore_curves_ready=true;water._shore_limit=.3
 var data:Dictionary=ROCKS.compute(region,0,0,8,99,null,water)
 var catalog:=EnvironmentCatalog.load_default()
 var program:=GrassProgram.compile(load("res://terrain/grass/settings.tres"),catalog,EnvironmentRenderCache.new(catalog))
 return {"region":region,"water":water,"data":data,"program":program}

func _roots(f:Dictionary)->Array[Vector3]:
 var roots:Array[Vector3]=[]
 for z in 8:
  var payload:=GrassField.compute(f.program,99,Vector2i(3,z),f.region,f.water,null,f.data.grass_supports)
  for asset_id:StringName in payload.batches:
   var batch:Dictionary=payload.batches[asset_id]
   for i in batch.count:
    var k:int=i*GrassPayload.FLOATS_PER_INSTANCE
    var p:=Vector3(batch.buffer[k+3],batch.buffer[k+7],batch.buffer[k+11])
    if p.y>TerrainSurfaceField.surface_y(f.region,p.x,p.z)+.5:roots.append(p)
 return roots
func test_compare_ledge_supports()->void:
 ROCKS=load("res://scripts/terrain/field/CliffRockDressing.gd")
 var before:=_fixture();var roots_before:=_roots(before)
 ROCKS=load("res://tests/fixtures/september17/cliff-groove-grass/dressing.gd")
 var after:=_fixture();var roots_after:=_roots(after)
 print("ROOTS before=",roots_before," after=",roots_after)
 for p:Vector3 in roots_before:
  var a:=GrassSupportSurfaces.at_point(before.data.grass_supports,Vector2(p.x,p.z))
  var b:=GrassSupportSurfaces.at_point(after.data.grass_supports,Vector2(p.x,p.z))
  print("ROOT_SUPPORT ",p," BEFORE ",a," AFTER ",b)
 FileAccess.open("/tmp/cliff42-before-supports.bin",FileAccess.WRITE).store_var(before.data.grass_supports)
 FileAccess.open("/tmp/cliff42-after-supports.bin",FileAccess.WRITE).store_var(after.data.grass_supports)
 assert_gt(roots_before.size(),0)
