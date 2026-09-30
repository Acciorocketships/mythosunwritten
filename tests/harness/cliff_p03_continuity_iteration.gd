extends RefCounted
func run(review:Node3D)->void:
 review.set_meta("iteration",7)
 review.set_meta("all_chunks",true)
 var script:=GDScript.new()
 script.source_code=FileAccess.get_file_as_string("res://tests/harness/cliff_p03_continuity_rebuild.gd")
 assert(script.reload()==OK)
 await script.new().run(review)
