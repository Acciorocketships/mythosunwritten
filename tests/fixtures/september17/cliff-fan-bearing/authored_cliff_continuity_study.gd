extends GutTest

func test_authored_bearing_is_continuous_across_its_widened_source_footprint()->void:
 var path:=OS.get_environment("STORY_MASS_GENERATOR")
 var generator:GDScript=load("res://scripts/terrain/field/CliffRockCrags.gd" if path.is_empty() else path)
 generator.prepare()
 var anchors:Array=FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin",FileAccess.READ).get_var()
 for height:float in [32,64]:anchors.append([Transform3D(Basis.IDENTITY,Vector3(-13.5,0,10.5)),48.0,height])
 var jump:=0.0;var location:=Vector3.ZERO;var samples:=0
 for anchor:Array in anchors:
  var pose:Transform3D=anchor[0];var width:float=anchor[1];var height:float=anchor[2]
  var coordinate:=pose.origin.dot(pose.basis.x)
  var salt:=2697992464+roundi(pose.origin.dot(pose.basis.z))*13+roundi(pose.origin.y)*71
  for y:float in [1.0,height*.35,height*.7]:
   var previous:=-INF
   for ix in ceili(width/.02)+1:
    var u:=coordinate-width*.5+ix*.02
    # Isolate the authored mass field that feeds the real photo formation.
    # A 2 cm horizontal move cannot legitimately expose a half-metre cut-off.
    var depth:float=generator._body_depth(u,y,2.0,height-.08,0.0,salt,[],generator._nature_mass_profile(u,height,salt))
    if is_finite(previous) and absf(depth-previous)>jump:
     jump=absf(depth-previous);location=pose*Vector3(u-coordinate,y,depth)
    previous=depth;samples+=1
 print("AUTHORED_BEARING_CONTINUITY jump=",jump," location=",location," samples=",samples)
 assert_lt(jump,.15,"Widening rock feet cannot be truncated at the upper mass's admission boundary")
