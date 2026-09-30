extends RefCounted
func run(review:Node3D)->void:
 var source:=load("res://scripts/terrain/field/CliffSlopeEnvelope.gd").source_code as String
 source=source.replace("var uncut:=env.surface.duplicate()","env.set_meta(\"wet\",wet_level)\n env.set_meta(\"caps\",caps)\n var uncut:=env.surface.duplicate()")
 var script:=GDScript.new();script.source_code=source;assert(script.reload()==OK)
 var rows:=[]
 for chunk:Vector2i in [Vector2i(2,4),Vector2i(2,5)]:
  var input:Dictionary=review._inputs[chunk]
  var area:=Rect2(Vector2(chunk*8)*24.0-Vector2(12,12),Vector2.ONE*192.0)
  var field=load("res://scripts/terrain/field/CliffSlopeField.gd").new([],2697992464,input.region,area,input.features,input.water)
  var rect:=area.grow(12.0)
  var env=script.build(rect,field._ground_sampler(),field._exclusion(rect.grow(33)),2697992464,field._water_level())
  var wet:PackedFloat64Array=env.get_meta("wet");var caps:PackedFloat64Array=env.get_meta("caps")
  for q:Vector2 in [Vector2(497,948),Vector2(506,948),Vector2(516,948),Vector2(526,948),Vector2(536,947),Vector2(530,960)]:
   var i:=roundi((q.x-env.origin.x)/.5);var k:=roundi((q.y-env.origin.y)/.5)
   rows.append({"chunk":str(chunk),"q":str(q),"wet":wet[k*env.w+i],"cap":caps[k*env.w+i],"point_water":field._water_level().call(q),"ground":env.ground_node(q),"coverage":str(input.water.coverage())})
  var fixture:={"origin":env.origin,"w":env.w,"h":env.h,"ground":env.ground,"wet":wet,"caps":caps}
  FileAccess.open(review._output_dir+"/water-%s-%s.var"%[chunk.x,chunk.y],FileAccess.WRITE).store_var(fixture)
 FileAccess.open(review._output_dir+"/water-control.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
 print("[p03_water_control] ",JSON.stringify(rows))
