extends GutTest
const BEFORE=preload("res://tests/fixtures/september17/cliff-curved-treads/grass-field-before.gd")
const WIDTH=preload("res://tests/helpers/cliff_tread_width.gd")
func test_ordinary_ground_keeps_identical_grass_buffers()->void:
 var fixture=load("res://tests/test_grass_field.gd").new()
 var program:GrassProgram=fixture._program()
 var inputs:Dictionary=fixture._flat_inputs(program)
 for seed_value:int in [99,1234]:
  var a:=BEFORE.compute(program,seed_value,Vector2i.ZERO,inputs.region,inputs.water)
  var b:=GrassField.compute(program,seed_value,Vector2i.ZERO,inputs.region,inputs.water)
  assert_eq(var_to_bytes(a.batches),var_to_bytes(b.batches),"Refining native ledges cannot reshuffle ordinary grass")
 fixture.free()
func test_supported_ledge_refinement_only_supplies_unmet_density()->void:
 assert_eq(GrassField._support_weight(1.0,0.0),0.0)
 assert_eq(GrassField._support_weight(.5,0.0),0.0)
 assert_almost_eq(GrassField._support_weight(1.0/sqrt(6.0),0.0),.5,.00001)
 assert_eq(GrassField._support_weight(.1,0.0),1.0,"Fine ledge sampling remains bounded")
func test_tread_width_is_independent_of_mesh_subdivision()->void:
 for steps:int in [1,2,4]:
  var faces:=PackedVector3Array()
  for i in steps:
   var a:=Vector3(0,0,2.0*i/steps);var b:=a+Vector3.RIGHT*2
   var c:=a+Vector3.BACK*2.0/steps;var d:=b+Vector3.BACK*2.0/steps
   faces.append_array(PackedVector3Array([a,b,c,c,b,d]))
  var widths:=WIDTH.at_vertices(faces);var area:=0.0
  for i in range(0,faces.size(),3):
   assert_almost_eq(WIDTH.triangle(faces,i,widths),2.0,.00001,"Subdivision edges are not shelf boundaries")
   area+=(faces[i+2]-faces[i]).cross(faces[i+1]-faces[i]).length()*.5
  assert_almost_eq(area,4.0,.00001)

func test_support_index_matches_full_scan_at_boundaries_and_overlaps()->void:
 var surfaces:Array=[]
 for center:Vector2 in [Vector2(-2,-2),Vector2.ZERO,Vector2(2,2)]:
  for height:float in [1.0,1.5,1.5]:
   var a:=center-Vector2.ONE*1.75;var b:=a+Vector2(3.5,0);var c:=a+Vector2(0,3.5)
   surfaces.append({"id":"surface_%d"%surfaces.size(),"bounds":Rect2(a,Vector2.ONE*3.5),"height":height,"triangles":PackedVector2Array([a,b,c]),"border":PackedVector2Array([a,b,b,c,c,a]),"obstacles":[]})
 var index:=GrassSupportSurfaces.spatial_index(surfaces)
 var mismatch:=0;var samples:=0
 for x in range(-18,19):
  for z in range(-18,19):
   for offset:float in [-.0001,0.0,.0001]:
    var point:=Vector2(x*.25+offset,z*.25+offset)
    if GrassSupportSurfaces.at_index(index,point)!=GrassSupportSurfaces.at_point(surfaces,point):mismatch+=1
    samples+=1
 assert_eq(mismatch,0,"Spatial bins must preserve actual support, borders and coincident-face precedence")
 assert_eq(samples,4107)
