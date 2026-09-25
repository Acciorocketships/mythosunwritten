extends GutTest

# Pins the full-projection ("current") rock shape this test was written for.
# The owner-selected September 23 default compresses projection (subtle),
# which narrows ledges by design; test_september23_cliff_directions.gd
# covers that style, including its retained wall turf.
const _STYLE=preload("res://scripts/terrain/field/CliffRockStyle.gd")
func before_all()->void:_STYLE.apply("current")
func after_all()->void:_STYLE.apply("chosen")
const CRAGS=preload("res://scripts/terrain/field/CliffRockCrags.gd")

func _edge_normal_jumps(generator:GDScript,entry_index:int=0)->Vector2i:
 generator.prepare()
 # First formation in the photographed native anchor fixture (stable saved order).
 var entry:Array=FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin",FileAccess.READ).get_var()[entry_index]
 var rock:Dictionary=generator.make(entry[0],entry[1],entry[2],2697992464,null,entry[3],entry[4])[0]
 var arrays:Array=generator.mesh(rock).surface_get_arrays(0)
 var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
 var edges:Dictionary={}
 var coordinate:float=rock.transform.origin.dot(rock.transform.basis.x)
 for i in range(0,vertices.size(),3):
  var geometric:Vector3=(vertices[i+2]-vertices[i]).cross(vertices[i+1]-vertices[i]).normalized()
  for j in 3:
   var a:Vector3=vertices[i+j];var b:Vector3=vertices[i+(j+1)%3]
   if minf(a.z-generator._native_depth(coordinate+a.x,a.y),b.z-generator._native_depth(coordinate+b.x,b.y))<2.0:continue
   var key:Array=[a,b] if a<b else [b,a]
   var ns:Array=[normals[i+j],normals[i+(j+1)%3]] if a<b else [normals[i+(j+1)%3],normals[i+j]]
   if not edges.has(key):edges[key]=[]
   edges[key].append([geometric,ns])
 var tested:=0;var broken:=0
 for pair:Array in edges.values():
  if pair.size()!=2 or pair[0][0].dot(pair[1][0])<cos(deg_to_rad(30)):continue
  tested+=1
  if pair[0][1][0].angle_to(pair[1][1][0])>.015 or pair[0][1][1].angle_to(pair[1][1][1])>.015:broken+=1
 return Vector2i(tested,broken)

func test_continuous_stone_faces_share_the_same_normals_across_gentle_edges()->void:
 var metric:=_edge_normal_jumps(CRAGS)
 print("CRAG_GENTLE_EDGES tested=",metric.x," discontinuous=",metric.y)
 assert_gt(metric.x,100,"Exercise the actual reconstructed formation")
 assert_eq(metric.y,0,"Gentle connected surfaces must not expose triangle boundaries through shading")

func test_nearby_photographed_formations_keep_continuous_normals()->void:
  # These three controls have exposed stone thicker than the native blend.
 # Anchor 30 is wholly thin and belongs to the attachment-normal control.
 for index:int in [4,12,20]:
  var metric:=_edge_normal_jumps(CRAGS,index)
  print("CRAG_NEIGHBOR ",index," tested=",metric.x," discontinuous=",metric.y)
  assert_gt(metric.x,100)
  assert_eq(metric.y,0,"Neighboring formations must also retain smooth connected faces")
