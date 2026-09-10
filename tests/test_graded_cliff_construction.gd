extends GutTest

func _region(graded: bool) -> HeightfieldRegion:
 var storeys: Dictionary = {}
 var levels: Dictionary = {}
 for z in range(-3,4):
  for x in range(-3,4):
   storeys[Vector2i(x,z)] = 3 if x <= 0 else 0
   levels[Vector2i(x,z)] = 0
 var region := HeightfieldRegion.new(storeys,levels)
 if not graded: return region
 var claims: Dictionary = {}
 for z in range(-2,3):
  for x in range(2,7): claims[Vector2i(x,z)] = 4.0
 return region.with_terrain_grades([TerrainGradePatch.new(&"street",claims,Vector2.ZERO,3.0)])

func test_constructed_street_removes_the_natural_cliff_wall_from_its_walk() -> void:
 var region := _region(true)
 var visual := SurfaceTool.new()
 var collision := SurfaceTool.new()
 visual.begin(Mesh.PRIMITIVE_TRIANGLES)
 collision.begin(Mesh.PRIMITIVE_TRIANGLES)
 var mesher := TerrainChunkMesher.new()
 assert_true(mesher._emit_wall(visual,collision,region,0,0,Vector2i.RIGHT,12.0))
 var vertices := collision.commit_to_arrays()[Mesh.ARRAY_VERTEX] as PackedVector3Array
 var intrusions := 0
 for vertex: Vector3 in vertices:
  if absf(vertex.z) <= 4.0 and vertex.y > 4.01: intrusions += 1
 assert_eq(intrusions,0,"the old cliff cannot remain as an invisible barrier above a graded road")
 var outside := 0
 for vertex: Vector3 in vertices:
  if absf(vertex.z) > 10.0 and vertex.y > 4.01: outside += 1
 assert_gt(outside,0,"natural cliffs outside the constructed street remain")

func test_lip_dressing_and_surface_clipping_follow_the_same_graded_street() -> void:
 var region := _region(true)
 var pieces := CliffDressing.compute(region,0,0,1)
 var intrusions := 0
 for key: String in pieces:
  for transform: Transform3D in pieces[key]:
   if transform.origin.x > 9.0 and absf(transform.origin.z) < 4.0:
    intrusions += 1
 assert_eq(intrusions,0,"rigid natural cliff pieces cannot cut through the new street")
 var info: Variant = TerrainChunkMesher._cell_clip_info(region,{},0,0)
 if info != null and info.dirs.has(Vector2i.RIGHT):
  var lips: Array = info.dirs[Vector2i.RIGHT].lips
  if not lips.is_empty():
   assert_false(lips[3])
   assert_false(lips[4])
 var natural := CliffDressing.compute(_region(false),0,0,1)
 assert_gt(natural.lip.size(),0,"the natural cliff fixture genuinely carries lips")

func test_graded_banks_keep_the_authored_rock_mesh_and_uv_detail() -> void:
 var mesher := TerrainChunkMesher.new()
 mesher.prepare_resources()
 var data := mesher.compute_chunk(Vector2i.ZERO, _region(true))
 assert_true(data.has("graded_cliff_arrays"), "deformed banks need their authored rock skin")
 if not data.has("graded_cliff_arrays"): return
 var arrays := data.graded_cliff_arrays as Array
 assert_false(arrays.is_empty())
 if arrays.is_empty(): return
 var uvs := arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array
 var unique: Dictionary = {}
 for uv: Vector2 in uvs: unique[uv] = true
 assert_gt(unique.size(), 4, "rock banks retain the atlas detail, not a single flat gray texel")

func test_a_filled_cliff_has_no_coplanar_apron_across_the_street() -> void:
 var mesher := TerrainChunkMesher.new()
 mesher.prepare_resources()
 var apron := SurfaceTool.new()
 apron.begin(Mesh.PRIMITIVE_TRIANGLES)
 mesher._emit_aprons(apron,_region(true),{},1,0,Color.WHITE,null,null,{})
 var vertices := apron.commit_to_arrays()[Mesh.ARRAY_VERTEX] as PackedVector3Array
 var exposed := 0
 for vertex: Vector3 in vertices:
  if absf(vertex.z)<4.0 and vertex.x<12.01 and vertex.y>3.9: exposed+=1
 assert_eq(exposed,0,"the finished street has one ground sheet, without old apron paint over its edge")
