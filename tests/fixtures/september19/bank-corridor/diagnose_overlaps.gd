extends SceneTree
const OUT="res://docs/qa/2026-09-19-manual/129-bank-corridor"
const ROCKS=preload("res://scripts/terrain/field/CliffRockDressing.gd")
func _init()->void:
 var forms:Array=FileAccess.open(OUT.path_join("validated-banks.bin"),FileAccess.READ).get_var()
 var report:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT.path_join("native-contact.json")))
 var rows:Array=[]
 for error:Dictionary in report.errors:
  if not error.has("clear"):continue
  var p:=parse_vector(error.point);var clear:=parse_vector(error.clear)
  var direction:Vector3=(clear-p).normalized()
  var owners:Array=[]
  for form:Dictionary in forms:
   if not (form.bounds as AABB).grow(.01).has_point(p+direction*.02):continue
   if ROCKS._covered(form,p+direction*.02):owners.append(form.id)
  rows.append({"point":p,"clear":clear,"covering_solids":owners})
 FileAccess.open(OUT.path_join("overlap-diagnosis.json"),FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
 print("BANK_OVERLAPS ",rows)
 quit()
func parse_vector(value:String)->Vector3:
 var parts:=value.trim_prefix("(").trim_suffix(")").split(",")
 return Vector3(float(parts[0]),float(parts[1]),float(parts[2]))
