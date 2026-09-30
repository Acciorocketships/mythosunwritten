extends SceneTree
func _init()->void:
 var d:Dictionary=bytes_to_var(FileAccess.get_file_as_bytes("res://tests/fixtures/september26-cliffs/p03-constrained-inputs.var.gz").decompress_dynamic(4000000,FileAccess.COMPRESSION_GZIP))
 var index:=func(q:Vector2)->int:
  var p:=Vector2i(((q-d.origin)/.5).round()).clamp(Vector2i.ZERO,Vector2i(d.w-1,d.h-1));return p.y*d.w+p.x
 var ground:=func(q:Vector2)->float:return d.ground[index.call(q)]
 var wet:=func(q:Vector2)->float:return d.wet[index.call(q)]
 var cut:=func(q:Vector2)->bool:return d.excluded[index.call(q)]!=0
 var envs:=[]
 for mode:String in ["wet","dry","bedrock"]:
  load("res://scripts/terrain/field/CliffRockStyle.gd").apply("sheet_bedrock" if mode=="bedrock" else "sheet")
  envs.append(load("res://scripts/terrain/field/CliffSlopeEnvelope.gd").build(Rect2(476,924,92,96),ground,cut,2697992464,Callable() if mode=="dry" else wet))
 var rows:=[]
 for q:Vector2 in [Vector2(493.3,958.2),Vector2(492.3,946.45),Vector2(516.8,970.5)]:
  for o:float in [-2,-1,0,1,2,3,4]:
   var p:=q+Vector2(.7,-.7)*o
   var vals:=[]
   for env in envs:vals.append(env.sample(p))
   rows.append({"q":p,"ground":ground.call(p),"water":wet.call(p),"excluded":cut.call(p),"wet_dry_bedrock":vals})
 print(JSON.stringify(rows,"  "));quit()
