extends GutTest
const CORNER=preload("res://scripts/terrain/field/CliffCornerCrags.gd")
const SEED:=2697992464
const STYLE=preload("res://scripts/terrain/field/CliffRockStyle.gd")

func test_reported_single_storey_corner_is_dressed()->void:
 var native:Dictionary=FileAccess.open("res://docs/qa/2026-09-19-manual/120-corner-shore/native.bin",FileAccess.READ).get_var()
 var target:=Vector3(-445.5,20,490.5)
 var rows:Array=native.N03.outer_wall.filter(func(p:Transform3D)->bool:return p.origin==target)
 assert_eq(rows.size(),1,"The reported corner is one native storey")
 var forms:=CORNER.formations(rows,SEED)
 assert_eq(forms.size(),1,"Short corners must join the dressed straight faces")

func test_short_corner_is_closed_below_crown_in_every_orientation()->void:
 for turn in 4:
  var pose:=Transform3D(Basis(Vector3.UP,turn*PI*.5),Vector3(-445.5,20,490.5))
  var forms:=CORNER.formations([pose],SEED)
  assert_eq(forms.size(),1)
  if forms.is_empty():continue
  var form:Dictionary=forms[0];var edges:Dictionary={};var degenerate:=0
  for i in range(0,form.faces.size(),3):
   var a:Vector3=form.faces[i];var b:Vector3=form.faces[i+1];var c:Vector3=form.faces[i+2]
   if (b-a).cross(c-a).length_squared()<1e-14:degenerate+=1
   for j in 3:
    a=form.faces[i+j];b=form.faces[i+(j+1)%3]
    var key:Array=[a,b] if a<b else [b,a]
    edges[key]=edges.get(key,0)+1
  var open:=0
  for count:int in edges.values():
   if count!=2:open+=1
  assert_eq(open,0,"One-storey corners retain a closed physical shell")
  assert_eq(degenerate,0)
  assert_lte(form.top,24.001,"Keep rock beneath the original crown")
  assert_lt(form.base,20.0,"The closed foot remains below supporting ground")

func test_short_radial_shoulders_do_not_form_oversized_pedestals()->void:
 var pose:=Transform3D(Basis.IDENTITY,Vector3(-445.5,20,490.5))
 var form:=CORNER.make(pose,4,SEED)
 var largest:=0.0
 for degrees:float in [15,30,45,60,75]:
  var direction:=Vector3(sin(deg_to_rad(degrees)),0,cos(deg_to_rad(degrees)))
  for y:float in [.25,.75,1.25,1.75]:
   var center:=Vector3(-1.5,y,-1.5);var depth:=-INF
   for i in range(0,form.faces.size(),3):
    var hit=Geometry3D.ray_intersects_triangle(center+direction*20,-direction,form.faces[i],form.faces[i+1],form.faces[i+2])
    if hit!=null:depth=maxf(depth,(hit-center).dot(direction)-1.5)
   var added:float=depth-float(CORNER._native(degrees/90.0*3.0-1.5,y,pose)[0])
   largest=maxf(largest,added)
 print("SHORT_CORNER_MAX_SHOULDER ",largest)
 assert_gt(largest,.1,"The corner still has an actual rock shoulder")
 assert_lt(largest,2.0,"A low corner must not carry a tall wall's radial pedestal")

func test_short_corner_still_respects_public_clearance()->void:
 var rock:=CORNER.make(Transform3D.IDENTITY,4,SEED)
 var box:AABB=rock.bounds
 var strip:=Rect2(Vector2(box.end.x-.1,box.position.z),Vector2(.2,box.size.z))
 var ground:=FeatureGroundField.new([], [FeatureGroundShape.axis_rect(strip)],0)
 var context:=FeatureContext.new(Rect2(-1000,-1000,2000,2000),ground,EnvironmentInstancePayload.new())
 assert_eq(CORNER.formations([Transform3D.IDENTITY],SEED,null,context).size(),0)

func test_existing_taller_corner_geometry_is_unchanged()->void:
 # September 22 (owner): taller convex corners intentionally compress their
 # pooled feet and facet thick bodies. They may only shrink, never grow, and
 # keep their turf; the byte-identical pass-120 pin no longer applies.
 # The fixture reuses the live wall source, so compare in the full-projection
 # style; subtle turf is covered in test_september23_cliff_directions.gd.
 STYLE.apply("current")
 var before=preload("res://tests/fixtures/september19/corner-shore/before_corner.gd")
 var pose:=Transform3D(Basis.IDENTITY,Vector3(-445.5,20,490.5))
 for height:float in [8,16,64]:
  var old:Dictionary=before.make(pose,height,SEED)
  var current:=CORNER.make(pose,height,SEED)
  assert_lte(current.bounds.size.x,old.bounds.size.x+.001,"A corner never widens")
  assert_lte(current.bounds.size.z,old.bounds.size.z+.001,"A corner never widens")
  assert_gt(current.green.size(),old.green.size()*.8,"Corner turf survives the reshaping")
 STYLE.apply("chosen")
