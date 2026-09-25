extends SceneTree
func _init()->void:
 var sources:Array=FileAccess.open("res://docs/qa/2026-09-19-manual/122-bank-attachments/sources.bin",FileAccess.READ).get_var()
 var maximum:=0.0;var failures:Array=[];var samples:=0
 for rock:Dictionary in sources:
  var b:AABB=rock.bounds;var rect:=Rect2(Vector2(b.position.x,b.position.z),Vector2(b.size.x,b.size.z))
  for x in range(floori(rect.position.x/192),floori(rect.end.x/192)+1):
   for z in range(floori(rect.position.y/192),floori(rect.end.y/192)+1):
    var core:=Rect2(Vector2(x,z)*192,Vector2.ONE*192)
    var reach:=rect.grow(3)
    var margin:=maxf(maxf(core.position.x-reach.position.x,core.position.y-reach.position.y),maxf(reach.end.x-core.end.x,reach.end.y-core.end.y))
    maximum=maxf(maximum,margin);samples+=1
    if margin>26:failures.append({"anchor":rock.anchor,"core":Vector2i(x,z),"needed":margin,"kind":rock.replay_recipe.kind})
 var report:={"samples":samples,"max_margin":maximum,"failures":failures}
 FileAccess.open("res://docs/qa/2026-09-19-manual/122-bank-attachments/margins.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("BANK_MARGINS ",report)
 quit()
