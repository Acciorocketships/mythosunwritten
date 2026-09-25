extends GutTest
const ROCKS=preload("res://tests/fixtures/september18/cliff-local-bearing/shallow-cover-dressing.gd")
func _fixture(generator:GDScript=ROCKS)->Dictionary:
 generator.prepare()
 var plan:=HeightfieldPlan.new(17,64,12,"mean",4)
 plan.set_raw_height_override(func(x:int,_z:int)->float:return 16.0 if x<=3 else 0.0)
 var region:=plan.compute_region(4,4,12)
 var water:=WaterFieldContext.new()
 water._region=region;water._coverage=Rect2(-48,-48,288,288)
 water._ctx={"ponds":[],"rivers":[],"buckets":{},"region":region}
 water._shore_curves_ready=true;water._shore_limit=.3
 var data:Dictionary=generator.compute(region,0,0,8,99,null,water)
 var catalog:=EnvironmentCatalog.load_default()
 var program:=GrassProgram.compile(load("res://terrain/grass/settings.tres"),catalog,EnvironmentRenderCache.new(catalog))
 return {"region":region,"water":water,"data":data,"program":program}

func test_real_grass_worker_roots_whole_patches_on_exposed_turf_ledges()->void:
 var f:=_fixture();var rooted:=0;var escaped:=0;var buried:=0;var rooted_surfaces:Dictionary={}
 # Curved rim edits move small patches relative to the fixed world lattice.
 # Judge coverage over a fixed seed corpus, while checking every whole patch.
 for seed_value in range(99,115):
  for z in 8:
   var payload:=GrassField.compute(f.program,seed_value,Vector2i(3,z),f.region,f.water,null,f.data.grass_supports)
   for asset_id:StringName in payload.batches:
    var batch:Dictionary=payload.batches[asset_id]
    for i in batch.count:
     var k:int=i*GrassPayload.FLOATS_PER_INSTANCE
     var p:=Vector3(batch.buffer[k+3],batch.buffer[k+7],batch.buffer[k+11])
     if p.y<=TerrainSurfaceField.surface_y(f.region,p.x,p.z)+.5:continue
     rooted+=1
     var asset:Dictionary=f.program.assets[asset_id]
     var radius:float=asset.footprint_radius*Vector3(batch.buffer[k],batch.buffer[k+4],batch.buffer[k+8]).length()/(asset.piece_transform as Transform3D).basis.x.length()
     var centre:=GrassSupportSurfaces.at_point(f.data.grass_supports,Vector2(p.x,p.z))
     rooted_surfaces[centre.support_id]=true
     var normal:Vector3=centre.get("normal",Vector3.UP)
     for angle in 16:
      var q:=p+Vector3(cos(angle*TAU/16),0,sin(angle*TAU/16))*radius
      var hit:=GrassSupportSurfaces.at_point(f.data.grass_supports,Vector2(q.x,q.z))
      if hit.is_empty() or absf(hit.y-p.y+(normal.x*(q.x-p.x)+normal.z*(q.z-p.z))/normal.y)>.002:escaped+=1
     for rock:Dictionary in f.data.placements:
      if rock.kind!="rock" or not (rock.bounds as AABB).has_point(p+Vector3.UP*.1):continue
      if ROCKS._covered(rock,p+Vector3.UP*.1):buried+=1
 print("CLIFF_GRASS rooted=",rooted," escaped=",escaped," buried=",buried)
 assert_gt(rooted_surfaces.size(),16,"Actual ordinary grass must reach many distinct exposed shoulders across the seed corpus")
 assert_gte(rooted,16*6,"Average visible ledge coverage must retain at least six whole patches per seed")
 assert_eq(escaped,0,"Complete patches remain on the actual exposed turf triangles")
 assert_eq(buried,0,"Risers and overlapping rocks cannot contain grass roots")

func test_ledge_grass_is_identical_on_either_side_of_chunk_ownership()->void:
 var f:=_fixture()
 for z in [3,4]:
  for x in [3,4]:
   var tile:=Vector2i(x,z);var owner:=Vector2i(0 if x<4 else 4,0 if z<4 else 4)
   var split:=ROCKS.compute(f.region,owner.x,owner.y,4,99,null,f.water)
   var a:=GrassField.compute(f.program,99,tile,f.region,f.water,null,f.data.grass_supports)
   var b:=GrassField.compute(f.program,99,tile,f.region,f.water,null,split.grass_supports)
   if var_to_bytes(a.batches)!=var_to_bytes(b.batches):
    FileAccess.open("/tmp/cliff-grass-full.bin",FileAccess.WRITE).store_var(f.data.grass_supports)
    FileAccess.open("/tmp/cliff-grass-split.bin",FileAccess.WRITE).store_var(split.grass_supports)
    print("GRASS_OWNER_MISMATCH ",tile," full_surfaces=",f.data.grass_supports.size()," split_surfaces=",split.grass_supports.size())
   assert_true(var_to_bytes(a.batches)==var_to_bytes(b.batches),"Full and split owners produce identical actual grass buffers")

func test_new_grass_does_not_add_a_second_foliage_family_to_outcrop_ledges()->void:
 var f:=_fixture()
 var vegetation=preload("res://scripts/terrain/field/CliffVegetation.gd");vegetation.prepare()
 var cliffs:=CliffDressing.compute(f.region,0,0,8)
 var plants:=vegetation.compute(cliffs,f.data,f.region,99,null,f.water)
 var ferns:=0
 for plant:Dictionary in plants:
  if plant.kind=="fern":ferns+=1
 assert_eq(ferns,0,"The dedicated outcrop plant owner retains ledge dressing when grass is enabled")

func test_ledge_detail_change_preserves_paired_grass_coverage()->void:
 var baseline:GDScript=load("res://tests/fixtures/september17/cliff-detail-options/before-dressing.gd")
 var old:=_fixture(baseline);var current:=_fixture()
 var counts:Array[int]=[0,0]
 for index in 2:
  var f:Dictionary=old if index==0 else current
  for seed_value in range(99,115):
   for z in 8:
    var payload:=GrassField.compute(f.program,seed_value,Vector2i(3,z),f.region,f.water,null,f.data.grass_supports)
    for asset_id:StringName in payload.batches:
     var batch:Dictionary=payload.batches[asset_id]
     for i in batch.count:
      var k:int=i*GrassPayload.FLOATS_PER_INSTANCE
      var p:=Vector3(batch.buffer[k+3],batch.buffer[k+7],batch.buffer[k+11])
      if p.y>TerrainSurfaceField.surface_y(f.region,p.x,p.z)+.5:counts[index]+=1
 print("PAIRED_LEDGE_COVERAGE before=",counts[0]," current=",counts[1])
 assert_gt(counts[0],16*6,"The comparison fixture must itself provide substantial coverage")
 assert_gte(float(counts[1])/counts[0],.90,"Detail changes must preserve paired seed-corpus grass coverage within ten percent")
