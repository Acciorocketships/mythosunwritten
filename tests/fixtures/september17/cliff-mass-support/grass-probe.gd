extends GutTest
var ROCKS:GDScript=load("res://scripts/terrain/field/CliffRockDressing.gd" if OS.get_environment("STORY_GRASS_BASELINE").is_empty() else "res://tests/fixtures/september17/cliff-mass-support/before-dressing.gd")
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

func test_root_survey()->void:
 var f:=_fixture()
 var roots:Array=[]
 var q:=Vector2(85.45217,38.24749)
 print("MISSING_ROOT_SUPPORT ",GrassSupportSurfaces.at_point(f.data.grass_supports,q))
 for surface:Dictionary in f.data.grass_supports:
  if (surface.bounds as Rect2).has_point(q):print("MISSING_ROOT_FACE ",surface)
 for x in range(2,6):
  for z in 8:
   var payload:=GrassField.compute(f.program,99,Vector2i(x,z),f.region,f.water,null,f.data.grass_supports)
   for id:StringName in payload.batches:
    var b:Dictionary=payload.batches[id]
    for i in b.count:
     var k:int=i*GrassPayload.FLOATS_PER_INSTANCE
     var p:=Vector3(b.buffer[k+3],b.buffer[k+7],b.buffer[k+11])
     if p.y>TerrainSurfaceField.surface_y(f.region,p.x,p.z)+.5:roots.append([x,z,str(p)])
 print("ROOT_SURVEY ",JSON.stringify(roots))
 assert_gt(roots.size(),0)
