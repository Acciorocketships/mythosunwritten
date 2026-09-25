extends GutTest
const FROZEN = preload("res://tests/fixtures/frozen_terrain_grade.gd")

func test_reported_amber_cliff_retains_its_grass_edge_in_a_grade_collar() -> void:
 var region := FROZEN.region("res://docs/qa/2026-09-15-manual/01-grass/P09-field.txt")
 CliffDressing._ensure_loaded()
 var arrays := CliffDressing.compute_graded_faces(region,-22,-13,4,2697992464)
 var green_vertices := 0
 for uv:Vector2 in arrays[Mesh.ARRAY_TEX_UV]:
  if uv.is_equal_approx(CliffDressing.ground_uv()): green_vertices+=1
 assert_gt(green_vertices,0,"The photographed graded cliff needs an authored grass rim, not only rock and a square sheet.")
 var corner:=Vector3(-492,40,-276)
 var visible:=TerrainChunkMesher._clip_vert(region,{},-21,-11,corner)
 assert_gt(visible.distance_to(corner),0.5,"The sheet must tuck behind the rounded native rim at the photographed corner.")

func test_original_suppression_reproduces_the_photographed_square_edge() -> void:
 var region := FROZEN.region("res://docs/qa/2026-09-15-manual/01-grass/P09-field.txt")
 var original = preload("res://tests/fixtures/september15/before_mesher.gd")
 var corner:=Vector3(-492,40,-276)
 assert_eq(original._clip_vert(region,{},-21,-11,corner),corner)

func test_partly_graded_native_rim_keeps_its_original_footprint() -> void:
 var region := FROZEN.region("res://docs/qa/2026-09-15-manual/01-grass/P07-field.txt")
 var source := Vector3(-517.5,24.05,-1966.5)
 var remainder := region.graded_height(source.x,source.z,1)-region.graded_height(source.x,source.z,0)
 assert_gt(remainder,.05,"The fixture contains a surviving cliff, not a removed street wall")
 assert_lt(remainder,.95,"The fixture lies in the transition collar")
 var mapped := CliffDressing.graded_rim_point(region,source)
 assert_eq(Vector2(mapped.x,mapped.z),Vector2(source.x,source.z),
  "The surviving native rim must not pull away from its rock backing")

func test_flat_ground_without_a_native_rim_never_moves_sideways_in_a_grade() -> void:
 var heights:Dictionary={}
 var levels:Dictionary={}
 for z in range(-3,4):
  for x in range(-3,4):
   heights[Vector2i(x,z)]=2
   levels[Vector2i(x,z)]=0
 # This is the historical post-classification grading regression. Production
 # now compiles native controls first; retain the old input explicitly here.
 var region:=HeightfieldRegion.new(heights,levels)
 region.terrain_grades.assign([
  TerrainGradePatch.new(&"flat_street",{Vector2i(3,0):8.0,Vector2i(4,0):8.0},Vector2.ZERO,3.0)])
 var input:=Vector3(10,8,0)
 var previous=preload("res://tests/fixtures/september15/uncached_mesher.gd")
 assert_ne(previous._clip_vert(region,{},0,0,input),input,"Rejected candidate reproduces sideways ground compression")
 assert_eq(TerrainChunkMesher._clip_vert(region,{},0,0,input),input,
  "Grading must not compress flat ground that has no native cliff rim")
