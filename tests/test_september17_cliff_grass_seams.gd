extends GutTest
const RELIEF=preload("res://scripts/terrain/field/CliffRockRelief.gd")
func _rock(heights:Array)->Dictionary:
 var faces:=PackedVector3Array()
 for i in heights.size()-1:
  var a:=Vector3(0,heights[i],i*.25);var b:=Vector3(1.5,heights[i],i*.25)
  var c:=Vector3(0,heights[i+1],(i+1)*.25);var d:=Vector3(1.5,heights[i+1],(i+1)*.25)
  faces.append_array(PackedVector3Array([a,c,b,b,c,d]))
 var bounds:=AABB(faces[0],Vector3.ZERO)
 for p:Vector3 in faces:bounds=bounds.expand(p)
 return {"green":faces,"faces":faces,"id":"seam","transform":Transform3D.IDENTITY,"bounds":bounds.grow(.001)}
func test_submillimetre_bend_is_not_a_false_planting_edge()->void:
 var rock:=_rock([0.0,.0345,.0695])
 var borders:Dictionary=RELIEF._turf_component_borders(rock,[rock])
 assert_eq(borders["seam/turf/0"].size(),12,"Tiny tessellation bends share the complete outer border")
func test_curvature_cannot_accumulate_into_a_flat_support_claim()->void:
 var rock:=_rock([0.0,.0345,.0695,.105,.141,.1775,.2145])
 var borders:Dictionary=RELIEF._turf_component_borders(rock,[rock])
 assert_lt(borders["seam/turf/0"].size(),28,"The complete component must fit the support plane tolerance")
func test_real_ledge_crease_retains_its_edge()->void:
 var rock:=_rock([0.0,0.0,.04])
 var borders:Dictionary=RELIEF._turf_component_borders(rock,[rock])
 assert_eq(borders["seam/turf/0"].size(),8,"A visible crease cannot become a fictitious planar grass cap")
