extends GutTest
const ROCKS=preload("res://scripts/terrain/field/CliffRockDressing.gd")
func _forms()->Array:
 ROCKS.prepare()
 var walls:=[]
 for x in range(-16,16):
  for y in 4:walls.append(Transform3D(Basis.IDENTITY,Vector3(x*3+1.5,y*4,0)))
 return ROCKS.formations(walls,2697992464)
func _front(forms:Array,x:float,y:float)->float:
 var front:=-INF
 for rock:Dictionary in forms:
  var faces:PackedVector3Array=rock.faces if rock.has("faces") else ROCKS._definitions[rock.asset].faces
  var inverse:Transform3D=rock.transform.affine_inverse()
  var origin:Vector3=inverse*Vector3(x,y,30);var direction:Vector3=inverse.basis*Vector3.FORWARD
  for i in range(0,faces.size(),3):
   var hit=Geometry3D.ray_intersects_triangle(origin,direction,faces[i],faces[i+1],faces[i+2])
   if hit!=null:front=maxf(front,(rock.transform*hit).z)
 return front
func test_native_cell_seams_do_not_become_regular_pod_ends()->void:
 var forms:=_forms()
 for x:float in [-12,12]:
  for y:float in [2,5,8]:
   var left:=_front(forms,x-.01,y);var right:=_front(forms,x+.01,y)
   assert_true(is_finite(left) and is_finite(right),"Continuous supported rock at the canonical ownership seam")
   assert_gt(minf(left,right),.5,"An interior module boundary must remain outside the native wall relief; restrained crags need not protrude a full metre")
   assert_lt(absf(left-right),.08,"Adjacent cell owners share the same physical front")
func test_rock_shoulders_reach_varied_heights_and_feet_jut_out_irregularly()->void:
 var forms:=_forms();var tops:Array[float]=[];var feet:Array[float]=[]
 for x in range(-36,37,3):
  var highest:=0.0
  for y in range(1,32):
   if _front(forms,x,y*.5)>.8:highest=y*.5
  tops.append(highest);feet.append(_front(forms,x,.15))
 print("CONTINUOUS_PROFILE top_range=",tops.min(),"..",tops.max()," foot_range=",feet.min(),"..",feet.max())
 assert_gt(tops.max(),13.0,"Some crags should reach the upper cliff")
 assert_gt(tops.max()-tops.min(),3.0,"The rock shoulder cannot be a parallel horizontal line")
 assert_gt(feet.max()-feet.min(),3.5,"The toe must have substantial irregular outward projection")

func test_production_relief_is_closed_and_never_rises_above_the_native_crown()->void:
 for rock:Dictionary in _forms():
  var edges:Dictionary={};var bad:=0;var highest:=-INF
  for i in range(0,rock.faces.size(),3):
   highest=maxf(highest,maxf(rock.faces[i].y,maxf(rock.faces[i+1].y,rock.faces[i+2].y)))
   for j in 3:
    var a:Vector3=rock.faces[i+j].snapped(Vector3.ONE*.0001);var b:Vector3=rock.faces[i+(j+1)%3].snapped(Vector3.ONE*.0001)
    var key:Array=[a,b] if a<b else [b,a]
    edges[key]=edges.get(key,0)+1
  for count:int in edges.values():
   if count!=2:bad+=1
  assert_eq(bad,0,"Every physical edge belongs to two actual triangles")
  assert_lte(highest,16.001,"Relief cannot protrude through the native grass crown")

func test_ferns_root_in_concave_stone_edges_instead_of_only_turf()->void:
 var forms:=_forms();var plants:=ROCKS.plants(forms,null,2697992464)
 var crevices:=0;var bad_roots:=0
 for plant:Dictionary in plants:
  if plant.attachment!="rock_crag":continue
  crevices+=1
  var support:Dictionary={}
  for rock:Dictionary in forms:
   if rock.id==plant.support_id:support=rock;break
  var point:Vector3=plant.support_point;var normal:Vector3=plant.support_normal
  var inverse:Transform3D=support.transform.affine_inverse();var hit:=false
  for i in range(0,support.faces.size(),3):
   var p=Geometry3D.ray_intersects_triangle(inverse*(point+normal*.15),inverse.basis*(-normal),support.faces[i],support.faces[i+1],support.faces[i+2])
   if p!=null and (support.transform*p).distance_to(point)<.01:hit=true;break
  if not hit:bad_roots+=1
 assert_gt(crevices,5,"Crevices, rather than only grass shelves, own the fern population")
 assert_eq(bad_roots,0,"Every crag root contacts actual production rock triangles")

func test_native_wall_ferns_have_actual_stone_contact_and_exposed_roots()->void:
 ROCKS.prepare()
 var plan:=HeightfieldPlan.new(2697992464,128,32,"mean",4)
 plan.set_raw_height_override(func(cx:int,_cz:int)->float:return 32.0 if cx<=3 else 0.0)
 var region:=plan.compute_region(4,4,12)
 var data:=ROCKS.compute(region,0,0,8,2697992464)
 var walls:Array=CliffDressing.compute(region,-1,-1,10).wall
 var contacts:=0;var failures:=0
 for plant:Dictionary in data.placements:
  if plant.kind!="foliage" or plant.attachment!="wall_crag":continue
  var supported:=false
  for wall:Transform3D in walls:
   if wall.origin!=plant.anchor:continue
   for crag:Dictionary in ROCKS._wall_crags:
    if (wall*crag.point).distance_to(plant.support_point)<.001:supported=true;break
  if supported:contacts+=1
  else:failures+=1
  for rock:Dictionary in data.placements:
   if rock.kind=="rock" and ROCKS._covered(rock,plant.support_point+plant.support_normal*.1):failures+=1
 assert_gt(contacts,5,"Ferns must also grow from exposed native wall crevices")
 assert_eq(failures,0,"Native contacts cannot float or remain buried under the added relief")
