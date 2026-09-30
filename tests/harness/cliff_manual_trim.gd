extends SceneTree
const ENV=preload("res://scripts/terrain/field/CliffSlopeEnvelope.gd")
func _initialize()->void:
 var d:Dictionary=FileAccess.open("res://docs/qa/2026-09-26-manual-cliffs/photo13-envelope.var",FileAccess.READ).get_var()
 var env=ENV.new()
 for key:String in d:env.set(key,d[key])
 var cropped:={"origin":Vector2(288,998),"w":17,"h":17}
 for key:String in ["ground","surface","rock"]:
  var values:=PackedFloat64Array();var source:PackedFloat64Array=env.get(key)
  for z in 17:
   for x in 17:
    var q:Vector2=cropped.origin+Vector2(x,z)*.5
    var ij:=Vector2i((q-env.origin)/.5);values.append(source[ij.y*env.w+ij.x])
  cropped[key]=values
 FileAccess.open("res://tests/fixtures/september26-cliffs/photo13-fins.var",FileAccess.WRITE).store_var(cropped)
 quit()
