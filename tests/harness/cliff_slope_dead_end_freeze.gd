extends SceneTree
## Freezes the dead-end probe's native envelope inputs (ground, exclusion
## kinds, water) as a compressed test fixture (September 27, issue D).
##   Godot --headless --path . -s res://tests/harness/cliff_slope_dead_end_freeze.gd -- /abs/native-inputs.var
func _init()->void:
 var d:Dictionary=FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.READ).get_var()
 d.erase("surface")
 var bytes:=var_to_bytes(d).compress(FileAccess.COMPRESSION_GZIP)
 FileAccess.open("res://tests/fixtures/september26-cliffs/dead-end-road-inputs.var.gz",FileAccess.WRITE).store_buffer(bytes)
 print("fixture bytes=",bytes.size()," w=",d.w," h=",d.h," origin=",d.origin);quit()
