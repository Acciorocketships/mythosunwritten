extends SceneTree
const ENV=preload("res://scripts/terrain/field/CliffSlopeEnvelope.gd")
const STYLE=preload("res://scripts/terrain/field/CliffRockStyle.gd")
func _init()->void:
 var fixtures:=[]
 for z in [4,5]:fixtures.append(FileAccess.open("res://docs/qa/2026-09-26-p03-followup/water-2-%d.var"%z,FileAccess.READ).get_var())
 var ground:=func(q:Vector2)->float:
  var d:Dictionary=fixtures[1 if q.y>=960 else 0]
  var p:=Vector2i(((q-d.origin)/.5).round());p=p.clamp(Vector2i.ZERO,Vector2i(d.w-1,d.h-1))
  return d.ground[p.y*d.w+p.x]
 var water:=func(q:Vector2)->float:
  var d:Dictionary=fixtures[1 if q.y>=960 else 0]
  var p:=Vector2i(((q-d.origin)/.5).round());p=p.clamp(Vector2i.ZERO,Vector2i(d.w-1,d.h-1))
  var y:float=d.wet[p.y*d.w+p.x]
  return y if not is_nan(y) and y>ground.call(q)+.4 else NAN
 var out:={}
 for mode:String in ["plain","cut","rock"]:
  STYLE.apply("sheet_bedrock" if mode=="rock" else "sheet")
  var env=ENV.build(Rect2(480,928,84,84),ground,Callable(),2697992464,water if mode!="plain" else Callable())
  var grid:=[]
  for z in range(1856,2025):
   var row:=[]
   for x in range(960,1129):row.append(env.sample(Vector2(x,z)*.5))
   grid.append(row)
  out[mode]=grid
 out.ground=[];out.water=[]
 for z in range(1856,2025):
  var row:=[];var wet:=[]
  for x in range(960,1129):
   var q:=Vector2(x,z)*.5
   row.append(ground.call(q));var y:float=water.call(q);wet.append(y if is_finite(y) else null)
  out.ground.append(row);out.water.append(wet)
 FileAccess.open("res://docs/qa/2026-09-26-p03-continuity/constrained-profiles.json",FileAccess.WRITE).store_string(JSON.stringify(out))
 quit()
