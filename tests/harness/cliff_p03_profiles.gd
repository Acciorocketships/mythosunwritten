extends SceneTree
func _init()->void:
 load("res://scripts/terrain/field/CliffRockStyle.gd").apply("sheet")
 var source:=FileAccess.get_file_as_string("res://docs/qa/2026-09-26-p03-followup/baseline-source/CliffSlopeEnvelope.gd")
 for variant:String in ["original","moderate","gentle"]:
  var code:=source
  if variant!="original":
   code=code.replace("const LOCAL_REACH:=14.0","const LOCAL_REACH:=24.0")
   code=code.replace("Vector2(1.8,4.8)","Vector2(3.0,6.4)").replace("const FOOT:=3.6","const FOOT:=4.5")
   code=code.replace("Vector2(.7,1.5)","Vector2(2.8,3.6)" if variant=="moderate" else "Vector2(4.5,4.0)")
   code=code.replace("3.4*(.2 if under", "6.4*(.2 if under")
  var script:=GDScript.new();script.source_code=code;assert(script.reload()==OK)
  for height:float in [4.0,12.0,24.0]:
   var env=script.build(Rect2(-20,-8,60,16),func(q:Vector2)->float:return height if q.x<=0 else 0.0,Callable(),2697992464)
   var grades:=[];var end:=0.0;var crest:=[]
   for x in range(-2,70):
    var q:=Vector2(x*.5,0);var y:float=env.sample(q)
    if x<5:crest.append(snappedf(y,.001))
    if y>.1 and y<height-.1:
     var gradient:float=(env.sample(q+Vector2(.25,0))-env.sample(q-Vector2(.25,0)))/.5
     grades.append(rad_to_deg(atan(absf(gradient))));end=q.x
   grades.sort()
   print("[profile] ",variant," height=",height," median=",grades[grades.size()/2]," p90=",grades[int(grades.size()*.9)]," foot=",end," crest=",crest)
 quit()
