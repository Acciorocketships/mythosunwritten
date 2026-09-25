extends GutTest
const ROCKS=preload("res://scripts/terrain/field/CliffRockDressing.gd")

func test_terraces_are_one_connected_surface_with_highest_ridge_inside_cliff()->void:
 ROCKS.prepare()
 for asset:StringName in ROCKS._definitions:
  if asset in ROCKS.PLANTS:continue
  var faces:PackedVector3Array=ROCKS._definitions[asset].faces
  var vertices:Array[Vector3]=[];var indices:Array[int]=[];var neighbors:Dictionary={}
  for p:Vector3 in faces:
   var index:=-1
   for i in vertices.size():
    if vertices[i].distance_to(p)<.0002:index=i;break
   if index<0:index=vertices.size();vertices.append(p);neighbors[index]={}
   indices.append(index)
  for i in range(0,indices.size(),3):
   for j in 3:
    var a:=indices[i+j];var b:=indices[i+(j+1)%3]
    neighbors[a][b]=true;neighbors[b][a]=true
  var seen:Dictionary={0:true};var queue:Array[int]=[0]
  while not queue.is_empty():
   var index:int=queue.pop_back()
   for other:int in neighbors[index]:
    if seen.has(other):continue
    seen[other]=true;queue.append(other)
  assert_eq(seen.size(),vertices.size(),str(asset)+": no separate upper/lower mounds")
  var exposed_high:=0;var embedded_high:=0
  for p:Vector3 in vertices:
   if p.y<.85:continue
   # Native wall relief starts 0.25 m outside its canonical plane;
   # production embeds the buttress origin by 0.25 m, at up to 12 m depth.
   if p.z*12.0-.25>=.25:exposed_high+=1
   else:embedded_high+=1
  assert_eq(exposed_high,0,str(asset)+": no independent summit beside wall")
  assert_gt(embedded_high,5,str(asset)+": broad high ridge buried into wall")

func test_each_panel_uses_one_connected_root_instead_of_separate_lower_rock()->void:
 ROCKS.prepare()
 var walls:=[]
 for x in range(-16,16):
  for y in 4:walls.append(Transform3D(Basis.IDENTITY,Vector3(x*3+1.5,y*4,10.5)))
 var anchors:Dictionary={}
 for rock:Dictionary in ROCKS.formations(walls,2697992464):
  assert_false(anchors.has(rock.anchor),"Lower terraces must be intrinsic to the same rooted solid")
  anchors[rock.anchor]=true
  var rear:Vector3=rock.transform*Vector3(0,.95,-.2)
  assert_lt(rear.z,10.5,"The high rear shoulder is behind the native wall plane")
 assert_gt(anchors.size(),2)

func test_buried_rear_fits_wall_and_short_remnants_do_not_grow_fins()->void:
 ROCKS.prepare()
 for asset:StringName in ROCKS._definitions:
  if asset in ROCKS.PLANTS:continue
  var escaped:=0
  for point:Vector3 in ROCKS._definitions[asset].faces:
   if point.z<=0.0 and absf(point.x)>.311:escaped+=1
  assert_eq(escaped,0,str(asset)+": rear bearing stays inside the supporting wall width")
 var walls:=[]
 for y in 4:walls.append(Transform3D(Basis.IDENTITY,Vector3(1.5,y*4,10.5)))
 assert_eq(ROCKS.formations(walls,2697992464).size(),0,"A three-meter wall remnant cannot grow a tall freestanding outcrop")
