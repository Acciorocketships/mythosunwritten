extends GutTest

func test_original_cliff_faces_and_caps_remain_the_native_family() -> void:
 for key:String in ["wall","outer_wall","inner_wall","lip","outer_lip","inner_lip"]:
  assert_eq(String(CliffDressing.ASSETS[key]),"kaykit.cliff."+key,"Owner rejected changing the native face texture")

func test_production_cliffs_receive_attached_vegetation() -> void:
 var plan:=HeightfieldPlan.new(2697992464,128,32,"mean",4)
 plan.set_raw_height_override(func(cx:int,_cz:int)->float:return 16.0 if cx<=3 else 0.0)
 var mesher:=TerrainChunkMesher.new()
 mesher.prepare_resources()
 mesher.set_seed(2697992464)
 var region:=plan.compute_region(4,4,12)
 var data:=mesher.compute_chunk(Vector2i.ZERO,region)
 assert_gt((data.get("cliff_vegetation",[]) as Array).size(),0,"Real chunk output must include foliage attached to the native face")
 assert_eq(data.cliffs,CliffDressing.compute(region,0,0,8),"Dressing does not move or replace native wall/cap ownership")

func test_tall_terraces_are_not_always_concentric_pyramids() -> void:
 var terraces=preload("res://scripts/terrain/field/CliffTerraces.gd")
 terraces.prepare()
 var plan:=HeightfieldPlan.new(17,128,32,"mean",4)
 plan.set_raw_height_override(func(cx:int,_cz:int)->float:return 24.0 if cx<=3 else 0.0)
 var region:=plan.compute_region(4,4,12)
 var offset_count:=0
 var widths:Dictionary={}
 for seed_value in 8:
  for base:Dictionary in terraces.compute(region,0,0,8,seed_value).placements:
   for child:Dictionary in base.get("layers",[]):
    var tangent:=Vector3(-base.outward.y,0,base.outward.x)
    if absf((child.transform.origin-base.transform.origin).dot(tangent))>.5:offset_count+=1
    widths[child.asset]=true
 assert_gt(offset_count,8,"Upper ledges must shift along the face, instead of every tier sharing one centre")
 assert_gt(widths.size(),1,"Varied native ledge stock remains in use")
