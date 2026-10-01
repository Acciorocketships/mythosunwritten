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

func _roots(f:Dictionary,seed_value:int=99)->Array[Vector3]:
 var roots:Array[Vector3]=[]
 for z in 8:
  var payload:=GrassField.compute(f.program,seed_value,Vector2i(3,z),f.region,f.water,null,f.data.grass_supports)
  for asset_id:StringName in payload.batches:
   var batch:Dictionary=payload.batches[asset_id]
   for i in batch.count:
    var k:int=i*GrassPayload.FLOATS_PER_INSTANCE
    var p:=Vector3(batch.buffer[k+3],batch.buffer[k+7],batch.buffer[k+11])
    if p.y>TerrainTileField.surface_y(f.region,p.x,p.z)+.5:roots.append(p)
 return roots
func test_paired_grass_density()->void:
 ROCKS=load("res://scripts/terrain/field/CliffRockDressing.gd")
 var f:=_fixture();var before:Array=FileAccess.open("/tmp/cliff42-before-supports.bin",FileAccess.READ).get_var()
 var after:Array=FileAccess.open("/tmp/cliff42-after-supports.bin",FileAccess.READ).get_var()
 var total_before:=0;var total_after:=0
 for seed_value in range(99,115):
  f.data.grass_supports=before
  var a:=_roots(f,seed_value)
  f.data.grass_supports=after
  var b:=_roots(f,seed_value)
  total_before+=a.size();total_after+=b.size()
  print("PAIRED_GRASS seed=",seed_value," before=",a.size()," after=",b.size())
 print("PAIRED_GRASS_TOTAL before=",total_before," after=",total_after)
 assert_gt(total_after,0)
