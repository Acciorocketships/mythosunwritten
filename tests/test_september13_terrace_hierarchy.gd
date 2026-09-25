extends GutTest
const Terraces=preload("res://scripts/terrain/field/CliffTerraces.gd")

func test_tall_cliffs_build_broad_benches_with_borne_upper_shelves() -> void:
 Terraces.prepare()
 var plan:=HeightfieldPlan.new(17,128,32,"mean",4)
 plan.set_raw_height_override(func(cx:int,_cz:int)->float:return 32.0 if cx<=3 else 0.0)
 var region:=plan.compute_region(4,4,12)
 var data:=Terraces.compute(region,0,0,8,99)
 var hosts:Dictionary={}
 for p:Dictionary in data.placements:
  if p.kind!="rock":hosts[p.id]=p
 var supported:=0
 for p:Dictionary in hosts.values():
  if not p.has("support_id"):continue
  supported+=1
  assert_true(hosts.has(p.support_id),"Upper stock retains its exact lower owner")
  if not hosts.has(p.support_id):continue
  var host:Dictionary=hosts[p.support_id]
  assert_almost_eq(p.base,host.top,.0001)
  assert_gt(p.top,host.top+1.5)
  assert_lte(p.top-host.top,4.0,"Each tier retains an ordinary jumpable rise")
  var cap:=GrassSupportSurfaces.from_native(host,Terraces._definitions[host.asset].faces)
  var upper:=GrassSupportSurfaces.from_native(p,Terraces._definitions[p.asset].faces)
  for point:Vector2 in upper.border:
   if TerrainSurfaceField.surface_y(region,point.x,point.y)>=p.base+.3:continue
   assert_false(GrassSupportSurfaces.at_point([cap],point).is_empty(),"Entire exposed upper physical column bears on native lower stock")
 var broad:=0
 for p:Dictionary in hosts.values():
  var box:AABB=p.bounds
  if maxf(box.size.x,box.size.z)>=12:broad+=1
 assert_gt(broad,0,"Tall faces need broad native benches rather than isolated small columns")
 assert_gt(supported,0,"A lower bench must carry subordinate native shelves")

func test_complete_stack_keeps_chunk_ownership_and_public_water_exclusions() -> void:
 Terraces.prepare()
 var plan:=HeightfieldPlan.new(17,128,32,"mean",4)
 plan.set_raw_height_override(func(cx:int,cz:int)->float:return 32.0 if cx<=3 and cz<=3 else 0.0)
 var region:=plan.compute_region(4,4,12)
 var full:=Terraces.compute(region,0,0,8,19)
 var split:Array=[]
 for owner:Vector2i in [Vector2i(0,0),Vector2i(0,4),Vector2i(4,0),Vector2i(4,4)]:
  split.append_array(Terraces.compute(region,owner.x,owner.y,4,19).placements)
 assert_eq(full.placements.size(),split.size())
 for p:Dictionary in full.placements:assert_true(split.has(p))
 var clear:=FeatureGroundShape.axis_rect(Rect2(Vector2(-1000,-1000),Vector2(2000,2000)))
 var ground:=FeatureGroundField.new([],[clear],0.0)
 var features:=FeatureContext.new(clear.bounds(),ground,EnvironmentInstancePayload.new())
 assert_eq(Terraces.compute(region,0,0,8,19,features).placements.size(),0)
 var flooded:=preload("res://tests/test_september11_cliff_terraces.gd").FloodedCliff.new()
 assert_eq(Terraces.compute(region,0,0,8,19,null,flooded).placements.size(),0)

func test_all_stack_stock_choices_retain_jump_heights_and_exposed_approaches() -> void:
 Terraces.prepare()
 var plan:=HeightfieldPlan.new(17,128,32,"mean",4)
 plan.set_raw_height_override(func(cx:int,_cz:int)->float:return 32.0 if cx<=3 else 0.0)
 var region:=plan.compute_region(4,4,12)
 var checked:=0
 for seed_value in 32:
  for base:Dictionary in Terraces.compute(region,0,0,8,seed_value).placements:
   if base.get("layers",[]).is_empty():continue
   checked+=1
   var columns:Array=[base]+base.layers
   for p:Dictionary in columns:assert_lte(p.top-p.base,4.0,"Native tier is no taller than the measured ordinary jump")
   var outward:Vector2=base.outward
   var tangent:=Vector2(-outward.y,outward.x)
   var anchor:=Vector2(base.transform.origin.x,base.transform.origin.z)-outward*.5
   for i in range(1,columns.size()):
    var parent:Dictionary=columns[i-1]
    var child:Dictionary=columns[i]
    var support:=GrassSupportSurfaces.from_native(parent,Terraces._definitions[parent.asset].faces)
    for side:float in [-1,1]:
     # The owner replaced concentric pyramids with offset shoulders. Survey
     # both real child sides instead of the old fixed, centred stack stations.
     var local:AABB=Terraces._definitions[child.asset].bounds
     var centre:=Vector2(child.transform.origin.x,child.transform.origin.z)
     var point:=centre+tangent*(local.size.x*.5+.45)*side
     var found:=GrassSupportSurfaces.at_point([support],point)
     assert_false(found.is_empty(),"Both side approaches have real native support")
     if not found.is_empty():assert_gte(found.edge_distance,.39,"A standing capsule fits on each exposed side approach")
 assert_gt(checked,50,"Many independently selected native stacks are exercised")
