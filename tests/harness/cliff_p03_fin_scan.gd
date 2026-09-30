extends SceneTree
const ENV=preload("res://scripts/terrain/field/CliffSlopeEnvelope.gd")
func _init()->void:
 var d:Dictionary=FileAccess.open("res://docs/qa/2026-09-26-p03-continuity/native-inputs.var",FileAccess.READ).get_var()
 var index:=func(q:Vector2)->int:
  var p:=Vector2i(((q-d.origin)/.5).round()).clamp(Vector2i.ZERO,Vector2i(d.w-1,d.h-1))
  return p.y*d.w+p.x
 var ground:=func(q:Vector2)->float:return d.ground[index.call(q)]
 var water:=func(q:Vector2)->float:return d.wet[index.call(q)]
 var excluded:=func(q:Vector2)->bool:return d.excluded[index.call(q)]!=0
 var style=load("res://scripts/terrain/field/CliffRockStyle.gd")
 style.apply("sheet");var plain=ENV.build(Rect2(476,924,92,96),ground,excluded,2697992464,water)
 style.apply("sheet_bedrock");var env=ENV.build(Rect2(476,924,92,96),ground,excluded,2697992464,water)
 var peaks:=[];var base_peaks:=[]
 for x in range(980,1011):
  for z in range(1880,1949):
   var q:=Vector2(x,z)*.5
   for dir:Vector2 in [Vector2(.5,0),Vector2(0,.5)]:
    var a:float=env.at(q-dir);var b:float=env.at(q);var c:float=env.at(q+dir)
    var peak:=maxf(b-maxf(a,c),minf(a,c)-b)
    var plain_spike:float=maxf(plain.at(q)-maxf(plain.at(q-dir),plain.at(q+dir)),minf(plain.at(q-dir),plain.at(q+dir))-plain.at(q))
    if plain_spike>1.0:base_peaks.append({"q":str(q),"peak":plain_spike})
    var base_peak:float=absf(plain.at(q)-(plain.at(q-dir)+plain.at(q+dir))*.5)
    if peak>1.0 and base_peak<.2:peaks.append({"q":str(q),"dir":str(dir),"peak":peak,"heights":[a,b,c]})
 peaks.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return a.peak>b.peak)
 print("[fin_scan] ",JSON.stringify(peaks))
 print("[base_fins] ",JSON.stringify(base_peaks))
 FileAccess.open("res://docs/qa/2026-09-26-p03-continuity/fin-scan.json",FileAccess.WRITE).store_string(JSON.stringify(peaks,"  "))
 quit()
