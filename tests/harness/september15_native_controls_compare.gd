extends SceneTree
func _init():
 for spot in ["P07","P08","P09"]:
  var original=preload("res://tests/fixtures/frozen_terrain_grade.gd").region("res://docs/qa/2026-09-15-manual/01-grass/%s-field.txt"%spot)
  for grade in original.terrain_grades:
   var a=preload("res://tests/fixtures/september15/native_grade_all_claims.gd").controls(grade,original)
   var b=preload("res://scripts/terrain/field/NativeTerrainGrade.gd").controls(grade,original)
   var diffs=[]
   for key in a:
    if not b.has(key) or a[key]!=b[key]: diffs.append([key,a[key],b.get(key)])
   for key in b:
    if not a.has(key): diffs.append([key,null,b[key]])
   print(spot," fixed=",preload("res://scripts/terrain/field/NativeTerrainGrade.gd").fixed_claims(grade).size()," claims=",grade._claims.size()," DIFFS=",diffs)
 quit()
