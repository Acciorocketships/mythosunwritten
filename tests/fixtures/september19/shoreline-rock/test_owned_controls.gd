extends GutTest
func _walls()->Array:
 var result:=[]
 for x in range(-16,16):
  for y in 8:result.append(Transform3D(Basis.IDENTITY,Vector3(x*3+1.5,y*4,10.5)))
 return result
func test_removed_facade_and_more_varied_depth()->void:
 var rocks=preload("res://tests/fixtures/september19/shoreline-rock/owned_adapter.gd")
 rocks.prepare()
 var panels:=0;var depths:=[]
 for p:Dictionary in rocks.formations(_walls(),2697992464):
  if str(p.asset).trim_prefix("cliff.rock.moss_").to_int()>=10:panels+=1
  var columns:Dictionary={}
  for point:Vector3 in rocks._faces(p):
   var world:Vector3=p.transform*point
   var column:=snappedf(world.x,.001)
   columns[column]=maxf(columns.get(column,-INF),world.z-10.5)
  depths.append_array(columns.values())
 assert_eq(panels,0,"Remove backing facade entirely")
 depths.sort()
 # The later owner review rejected oversized masses. Keep meaningful lower
 # projection and variation without requiring the rejected seven-metre reach.
 assert_gt(float(depths[-1]),4.0,"Some rooted lower shoulders project noticeably from the wall")
 assert_lt(float(depths[-1]),8.0,"Lower shoulders remain restrained rather than oversized masses")
 assert_gt(float(depths[int(depths.size()*.9)])-float(depths[int(depths.size()*.1)]),2.0,"Do not replace the wall with a uniform-depth skin")
 assert_false(&"kaykit.bush.01" in rocks.PLANTS,"Owner rejected spherical cliff shrubs")

class ChannelWater extends WaterFieldContext:
 func coverage()->Rect2:return Rect2(-1000,-1000,2000,2000)
 func has_sources()->bool:return true
 func is_wet(_point:Vector2)->bool:return true
 func level_at(_point:Vector2)->float:return 20.0

class BoundedDryWater extends WaterFieldContext:
 var outside_queries:=0
 var queries:=0
 # WorldFieldBlockCache and GrassField use [0,192], not the native cell
 # boundary [-12,180]. Keep the real production query window in this test.
 func coverage()->Rect2:return Rect2(0,0,192,192).grow(26)
 func has_sources()->bool:return true
 func is_wet(point:Vector2)->bool:
  queries+=1
  if not coverage().has_point(point):outside_queries+=1
  return false

func test_halo_reservations_do_not_query_unprepared_water()->void:
 var rocks=preload("res://tests/fixtures/september19/shoreline-rock/owned_adapter.gd");rocks.prepare()
 var plan:=HeightfieldPlan.new(2697992464,128,32,"mean",4)
 plan.set_raw_height_override(func(cx:int,_cz:int)->float:return 32.0 if cx<=3 else 0.0)
 var region:=plan.compute_region(4,4,12)
 var water:=BoundedDryWater.new()
 var dry:=rocks.compute(region,0,0,8,2697992464)
 var bounded:=rocks.compute(region,0,0,8,2697992464,null,water)
 assert_gt(water.queries,0)
 assert_eq(water.outside_queries,0,"Halo reservations must not read beyond the prepared water field")
 assert_eq(bounded.placements,dry.placements,"A dry water field preserves the canonical rock and plant placement")

func test_outcrops_cannot_project_into_existing_water_channels()->void:
 var rocks=preload("res://tests/fixtures/september19/shoreline-rock/owned_adapter.gd");rocks.prepare()
 var plan:=HeightfieldPlan.new(2697992464,128,32,"mean",4)
 plan.set_raw_height_override(func(cx:int,_cz:int)->float:return 32.0 if cx<=3 else 0.0)
 var region:=plan.compute_region(4,4,12)
 var dry:=rocks.compute(region,0,0,8,2697992464)
 var wet:=rocks.compute(region,0,0,8,2697992464,null,ChannelWater.new())
 assert_gt(dry.placements.size(),0)
 assert_eq(wet.collision_faces.size(),0,"Do not add rock collision under an existing waterfall")
 for placement:Dictionary in wet.placements:
  assert_eq(placement.kind,"foliage","No decorative solid may enter the wet channel")
  assert_eq(placement.attachment,"wall_crag","Only the unchanged native wall can support remaining plants")
  assert_gt(placement.support_point.y,20.3,"Native wall ferns must remain above the water")

func test_moss_caps_use_the_canonical_terrain_uv_and_shader()->void:
 var rocks=preload("res://tests/fixtures/september19/shoreline-rock/owned_adapter.gd");rocks.prepare()
 for asset:StringName in rocks._visuals:
  if asset in rocks.PLANTS:continue
  var found:=0
  for piece:EnvironmentVisualPiece in rocks._visuals[asset].pieces:
   for i in piece.mesh.get_surface_count():
    if piece.mesh.surface_get_material(i)!=CliffDressing.shared_material():continue
    found+=1
    for uv:Vector2 in piece.mesh.surface_get_arrays(i)[Mesh.ARRAY_TEX_UV]:assert_eq(uv,CliffDressing.ground_uv())
  assert_gt(found,0,"Every moss cap shares the same turf palette, biome field and substrate shader")

func test_trailing_vine_material_keeps_authored_alpha_cutouts()->void:
 var vegetation=preload("res://scripts/terrain/field/CliffVegetation.gd");vegetation.prepare()
 for asset:StringName in vegetation._visuals:
  if not str(asset).begins_with("native.cliff.trailing_"):continue
  for piece:EnvironmentVisualPiece in vegetation._visuals[asset].pieces:
   for i in piece.mesh.get_surface_count():
    var material:=piece.mesh.surface_get_material(i) as ShaderMaterial
    assert_not_null(material)
    assert_not_null(material.get_shader_parameter("albedo_texture"))
    assert_true(material.shader.code.contains("ALPHA = texel.a"))
    assert_true(material.shader.code.contains("ALPHA_SCISSOR_THRESHOLD"),"Tinting must not turn leaf cards into solid rectangles")
