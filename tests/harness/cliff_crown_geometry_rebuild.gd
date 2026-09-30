extends RefCounted
func run(review:Node3D)->void:
 review.set_meta("all_chunks",true)
 review.set_meta("iteration",4)
 var script:=GDScript.new()
 script.source_code=FileAccess.get_file_as_string("res://tests/harness/cliff_p03_continuity_rebuild.gd")
 if script.reload()!=OK:push_error("Invalid rebuild");return
 await script.new().run(review)
 var ray_script:=GDScript.new();ray_script.source_code=FileAccess.get_file_as_string("res://tests/harness/cliff_crown_rays.gd")
 if ray_script.reload()==OK:await ray_script.new().run(review)
