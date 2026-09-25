extends GutTest

func _outline(source:GDScript,height:float)->Dictionary:
 var form:Dictionary=source.make(Transform3D(Basis.IDENTITY,Vector3(-13.5,0,10.5)),48,height,2697992464)[0]
 var result:Dictionary={}
 for p:Vector3 in form.faces:
  if p.z<0:continue
  var key:=Vector2(p.x,p.y)
  result[key]=maxf(result.get(key,-INF),p.z)
 return result

func test_upper_projection_recedes_without_shrinking_the_rooted_base()->void:
 var path:=OS.get_environment("STORY_COLUMN_GENERATOR")
 var source:GDScript=load("res://scripts/terrain/field/CliffRockCrags.gd" if path.is_empty() else path)
 var before:GDScript=load("res://tests/fixtures/september18/cliff-curved-descent/before.gd")
 var count:=0;var retreat:=0.0;var outward:=0.0;var foot_change:=0.0;var feet:=0
 for height:float in [16.0,32.0,64.0]:
  var old:=_outline(before,height);var current:=_outline(source,height)
  for key:Vector2 in current:
   if not old.has(key):continue
   if key.y<=.01:
    feet+=1;foot_change=maxf(foot_change,absf(current[key]-old[key]))
   if key.y<height*.75 or key.y>height-1.05:continue
   count+=1;retreat+=old[key]-current[key]
   outward=maxf(outward,current[key]-old[key])
 print("CURVED_DESCENT upper_samples=",count," mean_retreat=",retreat/maxi(1,count)," outward=",outward," roots=",feet," root_change=",foot_change)
 assert_gt(count,1000)
 assert_gt(retreat/maxi(1,count),.03,"The upper quarter should visibly recede while the lower rock retains its footprint")
 assert_lt(outward,.001,"The profile must not create a new projection below the crown")
 assert_gt(feet,100)
 assert_lt(foot_change,.001,"Curving the upper wall inward must preserve the actual rooted base")
