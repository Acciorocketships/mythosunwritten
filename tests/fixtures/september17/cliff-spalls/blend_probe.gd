extends GutTest
# Experimental hypothesis only: the 0.9 m blend candidate was rejected visually.
# Not a production acceptance test; baseline failure is retained for diagnosis.
const CRAGS=preload("res://scripts/terrain/field/CliffRockCrags.gd")

func test_native_shading_is_confined_to_thin_attachments()->void:
 var path:=OS.get_environment("STORY_BLEND_GENERATOR")
 var generator:GDScript=CRAGS if path.is_empty() else load(path)
 var anchors:Array=FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin",FileAccess.READ).get_var()
 var exposed:=0;var suppressed:=0;var thin:=0;var detached:=0
 for index:int in [0,4,12,20]:
  var entry:Array=anchors[index]
  var form:Dictionary=generator.make(entry[0],entry[1],entry[2],2697992464,null,entry[3],entry[4])[0]
  var mesh:ArrayMesh=generator.mesh(form)
  var arrays:=mesh.surface_get_arrays(0)
  var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
  var colors:PackedColorArray=arrays[Mesh.ARRAY_COLOR]
  var origin:float=form.transform.origin.dot(form.transform.basis.x)
  for i in points.size():
   var p:=points[i]
   var thickness:float=p.z-generator._native_depth(origin+p.x,p.y)
   if thickness>=.9:
    exposed+=1
    if colors[i].a<.99:suppressed+=1
   if thickness>=0 and thickness<=.08:
    thin+=1
    if colors[i].a>.01:detached+=1
 print("BLEND_EXTENT exposed=",exposed," suppressed=",suppressed," thin=",thin," detached=",detached)
 assert_gt(exposed,1000,"Inspect actual thick stone from the reported locations")
 assert_gt(thin,100,"Inspect genuine near-contact shading")
 assert_eq(suppressed,0,"Rock standing at least 90 cm beyond the native face must retain its own detail, not copied native shading")
 assert_eq(detached,0,"The first eight centimetres must still shade continuously with the native wall")
