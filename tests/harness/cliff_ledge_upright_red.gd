extends "res://tests/test_p03_constrained_cliffs.gd"
func _native_surface(style:String):
 var f:=FileAccess.open("res://tests/fixtures/september26-cliffs/p03-constrained-inputs.var.gz",FileAccess.READ)
 var d:Dictionary=bytes_to_var(f.get_buffer(f.get_length()).decompress_dynamic(4000000,FileAccess.COMPRESSION_GZIP))
 var index:=func(q:Vector2)->int:
  var p:=Vector2i(((q-d.origin)/.5).round()).clamp(Vector2i.ZERO,Vector2i(d.w-1,d.h-1))
  return p.y*d.w+p.x
 var ground:=func(q:Vector2)->float:return d.ground[index.call(q)]
 var water:=func(q:Vector2)->float:return d.wet[index.call(q)]
 var excluded:=func(q:Vector2)->bool:return d.excluded[index.call(q)]!=0
 var area:=Rect2(476,924,92,96)
 STYLE.apply(style)
 var script:=GDScript.new()
 script.source_code=FileAccess.get_file_as_string("res://docs/qa/2026-09-26-rock-ledge-restoration/upright-envelope.gd.txt")
 assert(script.reload()==OK)
 return script.build(area,ground,excluded,2697992464,water)

