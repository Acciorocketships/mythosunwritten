extends SceneTree
func _initialize()->void:
 var source=preload("res://scripts/terrain/field/CliffRockCrags.gd")
 var form:Dictionary=source.make(Transform3D(Basis.IDENTITY,Vector3(-13.5,0,10.5)),48,32,2697992464)[0]
 FileAccess.open("res://tests/fixtures/september18/cliff-continuous-bodies/source_faces.bin",FileAccess.WRITE).store_buffer(form.faces.to_byte_array())
 FileAccess.open("res://tests/fixtures/september18/cliff-continuous-bodies/source_green.bin",FileAccess.WRITE).store_buffer(form.green.to_byte_array())
 print("SOURCE_MESH ",form.faces.size()," green=",form.green.size())
 quit()
