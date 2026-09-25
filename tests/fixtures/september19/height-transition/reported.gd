extends "res://tests/harness/september16_manual_qa.gd"
func _capture_views(world:Node3D)->void:
 _freeze_material_clocks(world)
 _capture_view.size=Vector2i(1600,1000)
 _character.visible=false
 for site:String in ["P05","P12","P17","P20"]:
  var path:="res://docs/qa/2026-09-16-manual/10-rounded-ledges/production-01/"+site+"/poses.json"
  var records:Array=JSON.parse_string(FileAccess.get_file_as_string(path))
  for record:Dictionary in records:
   var numbers:=RegEx.new();numbers.compile("-?[0-9]+(?:\\.[0-9]+)?")
   var values:Array[float]=[]
   for match in numbers.search_all(record.camera):values.append(float(match.get_string()))
   assert(values.size()==12)
   _camera.global_transform=Transform3D(Basis(Vector3(values[0],values[1],values[2]),Vector3(values[3],values[4],values[5]),Vector3(values[6],values[7],values[8])),Vector3(values[9],values[10],values[11]))
   _camera.fov=record.fov
   await _shot(site+"_reported_%d"%int(record.angle))
