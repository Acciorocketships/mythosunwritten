extends SceneTree
const FIELD=preload("res://scripts/terrain/field/CliffSlopeField.gd")
const STYLE=preload("res://scripts/terrain/field/CliffRockStyle.gd")
func _initialize()->void:_run.call_deferred()
func _run()->void:
 STYLE.apply("sheet_bedrock")
 var area:=Rect2(278,982,32,36)
 var water:=TerrainWorldTuning.make_water(2697992464)
 var plan:=TerrainWorldTuning.make_heightfield(2697992464,water)
 var region:=plan.compute_region(12,42,6)
 var field=FIELD.new([],2697992464,region,area)
 var env=field.envelope()
 var rows:=[]
 for z in range(1964,2036):
  for x in range(556,620):
   var q:=Vector2(x,z)*.5
   var y:float=env.at(q)
   var prominence:=0.0
   for d:Vector2 in [Vector2(.5,0),Vector2(0,.5),Vector2(.5,.5),Vector2(.5,-.5)]:
    prominence=maxf(prominence,y-maxf(env.at(q+d),env.at(q-d)))
   if prominence>1.0:rows.append({"q":str(q),"height":y,"ground":env.ground_node(q),"prominence":prominence})
 rows.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return a.prominence>b.prominence)
 var dir:="res://docs/qa/2026-09-26-manual-cliffs"
 FileAccess.open(dir+"/fins.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
 FileAccess.open(dir+"/photo13-envelope.var",FileAccess.WRITE).store_var({"origin":env.origin,"w":env.w,"h":env.h,"ground":env.ground,"surface":env.surface,"rock":env.rock})
 print("FINS ",rows.size()," worst ",rows.slice(0,8));quit()
