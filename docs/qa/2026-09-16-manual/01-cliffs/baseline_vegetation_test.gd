extends GutTest
const GREEN:=preload("res://docs/qa/2026-09-16-manual/01-cliffs/baseline_vegetation.gd")

class RaisedWater extends WaterFieldContext:
 func has_sources()->bool:return true
 func is_wet(_point:Vector2)->bool:return true
 func level_at(_point:Vector2)->float:return 13.0

func _walls(turn:int=0)->Array:
 var result:=[]
 var basis:=Basis(Vector3.UP,turn*PI*.5)
 for x in range(-32,32):
  for y in 4:result.append(Transform3D(basis,basis*Vector3(x*3+1.5,y*4,10.5)))
 return result

func test_strands_have_actual_native_wall_support_and_stay_above_water()->void:
 GREEN.prepare()
 for turn in 4:
  var dry:=GREEN.vines(_walls(turn),2697992464)
  var wet:=GREEN.vines(_walls(turn),2697992464,null,RaisedWater.new())
  assert_gt(dry.size(),12,"A complete exposed wall carries visible but interrupted greenery")
  assert_lt(dry.size(),55,"The original face remains visible between vine groups")
  assert_gt(wet.size(),0,"Wet feet must retain greenery on the exposed bank")
  for p:Dictionary in wet:
   assert_gte(p.bounds.position.y,13.35-.001,"The complete leaf mesh stays above physical water")
  var occupied:Dictionary={}
  for wall:Transform3D in _walls(turn):occupied[GREEN._key(wall)]=true
  for p:Dictionary in dry:
   var top:Transform3D=p.transform
   var visual:EnvironmentVisual=GREEN._visuals[p.asset]
   var supported:=true
   for piece:EnvironmentVisualPiece in visual.pieces:
    for vertex:Vector3 in piece.mesh.get_faces():
     var point:Vector3=piece.local_transform*vertex
     var row:=top;row.origin.y+=floorf((point.y+.3)/4)*4
     if not occupied.has(GREEN._key(row)):supported=false
   assert_true(supported,"All strand vertices have an actual canonical wall row behind them")

func test_public_clearance_and_chunk_partition_are_preserved()->void:
 GREEN.prepare()
 var walls:=_walls()
 var full:=GREEN.vines(walls,42)
 var left:=[];var right:=[]
 for p:Transform3D in walls:
  if p.origin.x<0:left.append(p)
  else:right.append(p)
 var split:=GREEN.vines(left,42)+GREEN.vines(right,42)
 assert_eq(split,full,"Changing chunk partition does not change strand identity, placement or length")
 var shape:=FeatureGroundShape.axis_rect(Rect2(Vector2(-1000,-1000),Vector2(2000,2000)))
 var context:=FeatureContext.new(shape.bounds(),FeatureGroundField.new([],[shape],0.0),EnvironmentInstancePayload.new())
 assert_eq(GREEN.vines(walls,42,context).size(),0,"Leaves must not fill reserved public air")
 var thread:=Thread.new()
 assert_eq(thread.start(func()->Array:return GREEN.vines(walls,42)),OK)
 assert_eq(var_to_bytes(thread.wait_to_finish()),var_to_bytes(full),"Worker reads detached bounds and canonical transforms only")

func test_baked_leaf_geometry_matches_the_original_wall_relief()->void:
 GREEN.prepare()
 CliffDressing._ensure_loaded()
 var native:PackedVector3Array=CliffDressing._pieces.wall[0].get_faces()
 for i in native.size():native[i]=CliffDressing._pieces.wall[1]*native[i]
 var worst:=0.0;var smallest:=INF
 for asset:StringName in GREEN._visuals:
  if asset==GREEN.FERN:continue
  var visual:EnvironmentVisual=GREEN._visuals[asset]
  assert_eq(visual.collisions.size(),0,"Soft hanging leaves add no movement obstruction")
  for piece:EnvironmentVisualPiece in visual.pieces:
   for vertex:Vector3 in piece.mesh.get_faces():
    var point:=piece.local_transform*vertex
    var origin:=Vector3(point.x,fposmod(point.y+.3,4)-.3,3)
    var depth:=-INF
    for i in range(0,native.size(),3):
     var hit=Geometry3D.ray_intersects_triangle(origin,Vector3.FORWARD,native[i],native[i+1],native[i+2])
     if hit!=null:depth=maxf(depth,hit.z)
    if not is_finite(depth):fail_test("Leaf has no measured native face behind it: "+str(point));return
    var distance:=point.z-depth
    worst=maxf(worst,distance);smallest=minf(smallest,distance)
 assert_gt(smallest,.02,"Leaves do not disappear inside the wall relief")
 assert_lt(worst,.24,"Leaves follow the native relief rather than floating on a flat hanging plane")

func test_ledge_plants_have_one_owner_when_grass_support_crosses_a_chunk()->void:
 GREEN.prepare()
 var terraces=preload("res://scripts/terrain/field/CliffTerraces.gd")
 terraces.prepare()
 var plan:=HeightfieldPlan.new(17,128,32,"mean",4)
 plan.set_raw_height_override(func(cx:int,_cz:int)->float:return 24.0 if cx<=3 else 0.0)
 var region:=plan.compute_region(4,4,12)
 var full:=GREEN.compute(CliffDressing.compute(region,0,0,8),terraces.compute(region,0,0,8,99),region,99)
 var split:=[]
 for owner:Vector2i in [Vector2i(0,0),Vector2i(0,4),Vector2i(4,0),Vector2i(4,4)]:
  split.append_array(GREEN.compute(CliffDressing.compute(region,owner.x,owner.y,4),terraces.compute(region,owner.x,owner.y,4,99),region,99))
 var full_keys:=[];var split_keys:=[];var fern_count:=0
 for p:Dictionary in full:
  full_keys.append(str(p.asset)+str(p.transform))
  if p.kind=="fern":fern_count+=1
 for p:Dictionary in split:split_keys.append(str(p.asset)+str(p.transform))
 full_keys.sort();split_keys.sort()
 assert_gt(fern_count,0,"Exposed native ledge plants are exercised")
 assert_eq(split_keys,full_keys,"Grass sampling halos must not duplicate rendered plants")

func test_sampling_only_halo_cannot_emit_plants()->void:
 GREEN.prepare()
 var terraces=preload("res://scripts/terrain/field/CliffTerraces.gd")
 terraces.prepare()
 var plan:=HeightfieldPlan.new(17,128,32,"mean",4)
 plan.set_raw_height_override(func(cx:int,_cz:int)->float:return 24.0 if cx<=3 else 0.0)
 var region:=plan.compute_region(4,4,12)
 var data:=terraces.compute(region,0,0,8,99)
 data.placements=[]
 assert_eq(GREEN.compute({"wall":[]},data,region,99).size(),0,"A sampling halo has no right to render a neighbor's ferns")
