extends GutTest

func test_photo_exposed_bodies_widen_downward_instead_of_extruding_vertical_panels()->void:
 var path:=OS.get_environment("STORY_FAN_GENERATOR")
 var generator:GDScript=load("res://scripts/terrain/field/CliffRockCrags.gd" if path.is_empty() else path)
 var anchors:Array=FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin",FileAccess.READ).get_var()
 var total:=0.0;var supported_slope:=0.0
 for anchor:Array in anchors:
  var form:Dictionary=generator.make(anchor[0],anchor[1],anchor[2],2697992464,null,anchor[3],anchor[4])[0]
  var faces:PackedVector3Array=form.faces
  var coordinate:float=anchor[0].origin.dot(anchor[0].basis.x)
  for i in range(0,faces.size(),3):
   var a:=faces[i];var b:=faces[i+1];var c:=faces[i+2]
   var middle:Vector3=(a+b+c)/3.0
   if middle.y<.5 or middle.y>anchor[2]*.7:continue
   if middle.z-generator._native_depth(coordinate+middle.x,middle.y)<1.0:continue
   var cross:Vector3=(c-a).cross(b-a)
   var normal:=cross.normalized()
   if normal.z<.5 or normal.y>.7:continue # Exclude caps, backs and closing ends.
   var area:=cross.length()*.5
   total+=area
   if normal.y>.12:supported_slope+=area
 print("LOWER_FANS total=",total," inclined=",supported_slope," ratio=",supported_slope/maxf(total,.001))
 assert_gt(total,150.0,"Measure substantial exposed rock across the actual photograph formations")
 assert_gt(supported_slope/maxf(total,.001),.45,"Nearly half the lower exposed bodies should widen toward their bearing, rather than retain upright extrusion walls")
