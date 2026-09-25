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
 var mesher := TerrainChunkMesher.new()
 mesher.prepare_resources()
 var data:=mesher.compute_chunk(Vector2i.ZERO,region)
 var vertices := data.wall_collision_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
 var intrusions := 0
 for vertex: Vector3 in vertices:
  if absf(vertex.x-12)<.01 and absf(vertex.z) <= 4.0 and vertex.y > 4.01: intrusions += 1
 assert_eq(intrusions,0,"the old cliff cannot remain as an invisible barrier above a graded road")
 var outside := 0
 for vertex: Vector3 in vertices:
  if vertex.z > 24.0 and vertex.y > 4.01: outside += 1
 assert_gt(outside,0,"native cliffs beyond the regraded whole tile remain")

func test_lip_dressing_and_surface_clipping_follow_the_same_graded_street() -> void:
 var region := _region(true)
 var pieces := CliffDressing.compute(region,0,0,1)
 var intrusions := 0
 for key: String in pieces:
  for transform: Transform3D in pieces[key]:
   if transform.origin.x > 9.0 and absf(transform.origin.z) < 4.0:
    intrusions += 1
 assert_eq(intrusions,0,"rigid natural cliff pieces cannot cut through the new street")
 # A removed cliff has no recess even though the source topology has lips.
 # Judge the resulting street edge rather than the internal source flags.
 for z:float in [-1.5,1.5]:
  var edge:=TerrainChunkMesher._clip_vert(region,{},0,0,Vector3(12,4,z))
  assert_almost_eq(edge,Vector3(12,4,z),Vector3.ONE*.001,
   "a fully graded street keeps its complete level ground across the former cliff")
 var natural := CliffDressing.compute(_region(false),0,0,1)
 assert_gt(natural.lip.size(),0,"the natural cliff fixture genuinely carries lips")

func test_graded_banks_keep_the_authored_rock_mesh_and_uv_detail() -> void:
 var mesher := TerrainChunkMesher.new()
 mesher.prepare_resources()
 var data := mesher.compute_chunk(Vector2i.ZERO, _region(true))
 assert_true(data.graded_cliff_arrays.is_empty(),"native tile construction must not bend the rock skin afterward")
 var placements:=0
 for key:String in data.cliffs: placements+=data.cliffs[key].size()
 assert_gt(placements,0,"surviving banks use ordinary authored native rock pieces")
 var uvs:=PackedVector2Array()
 for key:String in CliffDressing._pieces:
  var mesh:Mesh=CliffDressing._pieces[key][0]
  for surface in mesh.get_surface_count(): uvs.append_array(mesh.surface_get_arrays(surface)[Mesh.ARRAY_TEX_UV])
 var unique: Dictionary = {}
 for uv: Vector2 in uvs: unique[uv] = true
 assert_gt(unique.size(), 4, "rock banks retain the atlas detail, not a single flat gray texel")

func test_a_filled_cliff_has_no_coplanar_apron_across_the_street() -> void:
 var mesher := TerrainChunkMesher.new()
 mesher.prepare_resources()
 var apron := SurfaceTool.new()
 apron.begin(Mesh.PRIMITIVE_TRIANGLES)
 mesher._emit_aprons(apron,_region(true),{},1,0,Color.WHITE,null,null,{})
 var arrays:=apron.commit_to_arrays()
 var vertices:=PackedVector3Array() if arrays[Mesh.ARRAY_VERTEX]==null else arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
 var exposed := 0
 for vertex: Vector3 in vertices:
  if absf(vertex.z)<4.0 and vertex.x<12.01 and vertex.y>3.9: exposed+=1
 assert_eq(exposed,0,"the finished street has one ground sheet, without old apron paint over its edge")
