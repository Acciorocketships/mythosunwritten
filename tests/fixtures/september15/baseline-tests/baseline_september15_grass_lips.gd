extends GutTest
const OriginalCliff=preload("res://tests/fixtures/september15/before_cliff.gd")
const OriginalMesher=preload("res://tests/fixtures/september15/before_mesher.gd")
const FROZEN = preload("res://tests/fixtures/frozen_terrain_grade.gd")

func test_reported_amber_cliff_retains_its_grass_edge_in_a_grade_collar() -> void:
 var region := FROZEN.region("res://docs/qa/2026-09-15-manual/01-grass/P09-field.txt")
 OriginalCliff._ensure_loaded()
 var arrays := OriginalCliff.compute_graded_faces(region,-22,-13,4,2697992464)
 var green_vertices := 0
 for uv:Vector2 in arrays[Mesh.ARRAY_TEX_UV]:
  if uv.is_equal_approx(OriginalCliff.ground_uv()): green_vertices+=1
 assert_gt(green_vertices,0,"The photographed graded cliff needs an authored grass rim, not only rock and a square sheet.")
 var corner:=Vector3(-492,40,-276)
 var visible:=OriginalMesher._clip_vert(region,{},-21,-11,corner)
 assert_gt(visible.distance_to(corner),0.5,"The sheet must tuck behind the rounded native rim at the photographed corner.")

func test_original_suppression_reproduces_the_photographed_square_edge() -> void:
 var region := FROZEN.region("res://docs/qa/2026-09-15-manual/01-grass/P09-field.txt")
 var original = preload("res://tests/fixtures/september15/before_mesher.gd")
 var corner:=Vector3(-492,40,-276)
 assert_eq(original._clip_vert(region,{},-21,-11,corner),corner)
