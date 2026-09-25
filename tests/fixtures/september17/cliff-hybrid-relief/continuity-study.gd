extends GutTest

func test_sharp_authored_faces_remain_continuous_at_finer_spatial_steps()->void:
 var path:=OS.get_environment("STORY_MASS_GENERATOR")
 var generator:GDScript=load("res://scripts/terrain/field/CliffRockCrags.gd" if path.is_empty() else path)
 generator.prepare()
 var anchors:Array=FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin",FileAccess.READ).get_var()
 for height:float in [32,64]:anchors.append([Transform3D(Basis.IDENTITY,Vector3(-13.5,0,10.5)),48.0,height])
 var worst_ratio:=0.0;var investigated:=0;var fine_max:=0.0
 for anchor:Array in anchors:
  var pose:Transform3D=anchor[0];var width:float=anchor[1];var height:float=anchor[2]
  var coordinate:=pose.origin.dot(pose.basis.x)
  var salt:=2697992464+roundi(pose.origin.dot(pose.basis.z))*13+roundi(pose.origin.y)*71
  for y:float in [1.0,height*.35,height*.7]:
   var previous:=-INF
   for ix in ceili(width/.02)+1:
    var u:=coordinate-width*.5+ix*.02
    var depth:float=generator._body_depth(u,y,2.0,height-.08,0.0,salt,[],generator._nature_mass_profile(u,height,salt))
    var coarse:=absf(depth-previous)
    if is_finite(previous) and coarse>.10:
     investigated+=1
     var last:=previous;var fine:=0.0
     for step in range(1,21):
      var sample_u:=u-.02+step*.001
      var value:float=generator._body_depth(sample_u,y,2.0,height-.08,0.0,salt,[],generator._nature_mass_profile(sample_u,height,salt))
      fine=maxf(fine,absf(value-last));last=value
     fine_max=maxf(fine_max,fine);worst_ratio=maxf(worst_ratio,fine/coarse)
    previous=depth
 print("AUTHORED_CONTINUITY steep_intervals=",investigated," ratio=",worst_ratio," fine_max=",fine_max)
 assert_lt(worst_ratio,.12,"Twenty smaller steps must reduce the jump: true admission seams persist under refinement")
