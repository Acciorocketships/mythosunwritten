extends GutTest
const ROCKS=preload("res://scripts/terrain/field/CliffRockDressing.gd")
func test_outcrops_form_broad_overlapping_groups()->void:
 ROCKS.prepare()
 var walls:=[]
 for x in range(-32,32):
  for y in 4:walls.append(Transform3D(Basis.IDENTITY,Vector3(x*3+1.5,y*4,10.5)))
 var placements:=ROCKS.formations(walls,2697992464)
 var narrow:=0;var connected:=0
 for rock:Dictionary in placements:
  var box:AABB=rock.bounds
  var bearing_width:float=box.size.x
  var joins:=false
  for other:Dictionary in placements:
   if other.anchor==rock.anchor:continue
   if box.grow(.01).intersects(other.bounds):
    joins=true; bearing_width+=other.bounds.size.x
  if bearing_width<box.size.z*1.5:narrow+=1
  if joins:connected+=1
 assert_eq(narrow,0,"P17: outward depth must be carried by a substantially broader rocky shoulder")
 assert_gt(float(connected)/placements.size(),.7,"P11: neighboring formations should compose joined clusters, not isolated evenly spaced ornaments")
