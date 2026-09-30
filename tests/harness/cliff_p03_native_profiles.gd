extends SceneTree
const ENV=preload("res://scripts/terrain/field/CliffSlopeEnvelope.gd")
func _init()->void:
 load("res://scripts/terrain/field/CliffRockStyle.gd").apply("sheet_bedrock")
 var d:Dictionary=FileAccess.open("res://docs/qa/2026-09-26-p03-continuity/native-inputs.var",FileAccess.READ).get_var()
 var index:=func(q:Vector2)->int:
  var p:=Vector2i(((q-d.origin)/.5).round()).clamp(Vector2i.ZERO,Vector2i(d.w-1,d.h-1))
  return p.y*d.w+p.x
 var ground:=func(q:Vector2)->float:return d.ground[index.call(q)]
 var water:=func(q:Vector2)->float:return d.wet[index.call(q)]
 var excluded:=func(q:Vector2)->bool:return d.excluded[index.call(q)]!=0
 var env=ENV.build(Rect2(476,924,92,96),ground,excluded,2697992464,water)
 var rows:=[]
 for x:float in [510,516,542,548]:
  var top:=948.0 if x<520 else 972.0
  var before:=[];var after:=[];var slopes_before:=[];var slopes_after:=[]
  for i in range(-4,29):
   var q:=Vector2(x,top-i*.5)
   before.append(float(d.surface[index.call(q)]));after.append(float(env.sample(q)))
   if i>=0 and i<16:
    var p:=q+Vector2(0,.25);var n:=q-Vector2(0,.25)
    slopes_before.append(rad_to_deg(atan(absf(d.surface[index.call(p)]-d.surface[index.call(n)])/.5)))
    slopes_after.append(rad_to_deg(atan(absf(env.sample(p)-env.sample(n))/.5)))
  rows.append({"x":x,"start_z":top+2.0,"step_z":-.5,"before":before,"after":after,"slope_before":slopes_before,"slope_after":slopes_after})
 FileAccess.open("res://docs/qa/2026-09-26-p03-continuity/native-profiles.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
 for q:Vector2 in [Vector2(490,934),Vector2(476,959),Vector2(508,934),Vector2(516,963)]:print("[camera_ground] ",q," before=",d.surface[index.call(q)]," after=",env.sample(q))
 quit()
