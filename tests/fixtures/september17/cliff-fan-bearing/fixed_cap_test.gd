extends GutTest

func test_merged_cap_has_no_stone_channel_across_its_interior()->void:
 var path:=OS.get_environment("STORY_CHANNEL_GENERATOR")
 var generator=load("res://scripts/terrain/field/CliffRockCrags.gd" if path.is_empty() else path)
 var a:Array=FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin",FileAccess.READ).get_var()[11]
 var form:Dictionary=generator.make(a[0],a[1],a[2],2697992464,null,a[3],a[4])[0]
 var covered:=0;var hit_count:=0
 for x:float in [5.05,5.125,5.2]:
  for z:float in [3.4,3.5,3.6]:
   var origin:=Vector3(x,3.5,z);var shell:=-INF;var turf:=-INF
   for type:String in ["faces","green"]:
    var faces:PackedVector3Array=form[type]
    for i in range(0,faces.size(),3):
     var hit=Geometry3D.ray_intersects_triangle(origin,Vector3.DOWN,faces[i],faces[i+1],faces[i+2])
     if hit==null:continue
     if type=="faces":shell=maxf(shell,hit.y)
     else:turf=maxf(turf,hit.y)
   if shell>2.0:hit_count+=1
   if shell>2.0 and absf(turf-shell)<.0001:covered+=1
 print("MERGED_CAP_INTERIOR hits=",hit_count," covered=",covered)
 assert_eq(hit_count,9,"The reported ledge remains physically present")
 assert_eq(covered,9,"A merged ledge is one turf surface without triangular stone channels")
