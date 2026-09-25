extends SceneTree
func _initialize()->void:
 var source=preload("res://scripts/terrain/field/CliffRockCrags.gd")
 var anchors:Array=FileAccess.open("res://tests/fixtures/september17/cliff-plants/anchors.bin",FileAccess.READ).get_var()
 var records:Array=[]
 for i in anchors.size():
  var a:Array=anchors[i];var pose:Transform3D=a[0]
  if absf(pose.origin.x+483)>50 or absf(pose.origin.z+249)>40:continue
  var form:Dictionary=source.make(pose,a[1],a[2],2697992464,null,a[3],a[4])[0]
  var path:="res://tests/fixtures/september18/cliff-continuous-bodies/world-source-%02d.bin"%i
  FileAccess.open(path,FileAccess.WRITE).store_buffer(form.faces.to_byte_array())
  records.append({"index":i,"path":path,"width":a[1],"height":a[2],"origin":[pose.origin.x,pose.origin.y,pose.origin.z],"normal":[pose.basis.z.x,pose.basis.z.y,pose.basis.z.z]})
 FileAccess.open("res://tests/fixtures/september18/cliff-continuous-bodies/world-sources.json",FileAccess.WRITE).store_string(JSON.stringify(records,"  "))
 print("WORLD_SOURCES ",records.size())
 quit()
