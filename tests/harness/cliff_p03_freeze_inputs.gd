extends SceneTree
func _init()->void:
 var d:Dictionary=FileAccess.open("res://docs/qa/2026-09-26-p03-continuity/native-inputs.var",FileAccess.READ).get_var()
 d.erase("surface");d.erase("rock");d.erase("uncut")
 var bytes:=var_to_bytes(d).compress(FileAccess.COMPRESSION_GZIP)
 FileAccess.open("res://tests/fixtures/september26-cliffs/p03-constrained-inputs.var.gz",FileAccess.WRITE).store_buffer(bytes)
 print("fixture bytes=",bytes.size());quit()
