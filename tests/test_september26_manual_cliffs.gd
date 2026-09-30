extends GutTest
## Owner correction: preserve the original surface-net art; repair holes/lips.
const FIELD=preload("res://scripts/terrain/field/CliffSlopeField.gd")
const ENVELOPE=preload("res://scripts/terrain/field/CliffSlopeEnvelope.gd")
const STYLE=preload("res://scripts/terrain/field/CliffRockStyle.gd")
const AREA=Rect2(296,768,8,8)
const SEED=2697992464

func before_each()->void:STYLE.apply("sheet_bedrock")
func after_each()->void:STYLE.apply("sheet_bedrock")

func _field():
 var saved:Dictionary=FileAccess.open("res://tests/fixtures/september26-cliffs/photo11-envelope.var",FileAccess.READ).get_var()
 var env=ENVELOPE.new()
 for key:String in saved:env.set(key,saved[key])
 var field=FIELD.new([],SEED,null,AREA)
 field._env=env
 return field

func _original()->Dictionary:
 return FileAccess.open("res://tests/fixtures/september26-cliffs/photo11-original-mesh.var",FileAccess.READ).get_var()

func _inconsistent(faces:PackedVector3Array)->int:
 var edges:={}
 for i in range(0,faces.size(),3):
  for j in 3:
   var a:=faces[i+j];var b:=faces[i+(j+1)%3]
   var key:=[a,b] if a<b else [b,a]
   if not edges.has(key):edges[key]=[]
   edges[key].append(1 if a<b else -1)
 var count:=0
 for edge:Array in edges.values():
  if edge.size()==2 and edge[0]==edge[1]:count+=1
 return count

func _hit(faces:PackedVector3Array,q:Vector2)->bool:
 for i in range(0,faces.size(),3):
  if Geometry3D.ray_intersects_triangle(Vector3(q.x,100,q.y),Vector3.DOWN,faces[i],faces[i+1],faces[i+2])!=null:return true
 return false

func test_photo11_triangle_winding_is_consistent_without_changing_the_mesher()->void:
 assert_eq(_inconsistent(_original().faces),15,"Original frozen mesh reproduces reversed shared edges")
 assert_eq(_inconsistent(_field().solid(AREA)[0].faces),0,"Surface-net neighbours agree on winding")

func test_photo11_omitted_plateau_columns_are_filled()->void:
 var old:PackedVector3Array=_original().faces
 var fixed:PackedVector3Array=_field().solid(AREA)[0].faces
 var original_missing:=0;var remaining:=0
 for x in range(300,304):
  for z in range(772,776):
   var q:=Vector2(x+.2,z+.2)
   if not _hit(old,q):original_missing+=1
   if not _hit(fixed,q):remaining+=1
 assert_eq(original_missing,16,"Original upper-cliff opening is reproduced")
 assert_eq(remaining,0,"All sixteen positions have real replacement triangles")

func test_rock_shape_and_stone_exposure_away_from_the_hole_are_unchanged()->void:
 var old:Dictionary=_original().roots
 var fixed:Dictionary=_field().solid(AREA)[0].native_roots
 var checked:=0
 for p:Vector3 in old:
  # Two metres clear of the missing-column boundary and ownership edges.
  if p.x<296.5 or p.x>=298.0 or p.z<769 or p.z>775:continue
  checked+=1
  assert_true(fixed.has(p),"Original rounded mesh vertex is retained: %s"%p)
  # Normals now use the continuous field (test_cliff_sheet_normals): the
  # old sparse-band derivative caused the owner-reported false recesses.
  if fixed.has(p):assert_eq(fixed[p][1],old[p][1],"Original stone exposure is retained")
 assert_gt(checked,80,"Covers a substantial original face, not a single control point")

# The owner subsequently requested gentler slopes. Their quantitative profile
# and crest continuity checks now live in test_p03_cliff_followup.gd.

func test_only_buried_skirt_faces_are_withdrawn_after_lip_removal()->void:
 var env=ENVELOPE.new();env.origin=Vector2(-4,-4);env.w=17;env.h=17
 env.ground.resize(17*17);env.ground.fill(4.0);env.surface.resize(17*17);env.surface.fill(4.0)
 for x in range(-8,9):
  for z in range(-8,9):env.replacement_columns[Vector2i(x,z)]=true
 var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3(-.5,4,0),Vector3(.5,4,0),Vector3(0,0,0)])
 assert_true(env.uncovered_faces(arrays).is_empty(),"Flush native skirt cannot draw a hairline through the replacement plateau")
 env.surface.fill(2.0)
 assert_false(env.uncovered_faces(arrays).is_empty(),"Exposed upper wall retains backing below its flat top")
 env.surface.fill(4.0);env.replacement_columns.erase(Vector2i(0,1))
 assert_false(env._buried_skirt_point(Vector3(0,4,0)),"A missing replacement neighbour preserves the backstop")
