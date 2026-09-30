extends RefCounted
func run(review:Node3D)->void:
 review.set_meta("all_chunks",true)
 review.set_meta("iteration",3)
 var script:=GDScript.new();script.source_code=FileAccess.get_file_as_string("res://tests/harness/cliff_p03_continuity_rebuild.gd");assert(script.reload()==OK)
 await script.new().run(review)
 for path:String in ["res://tests/harness/cliff_crown_rays.gd","res://tests/harness/cliff_crown_pocket_walks.gd","res://tests/harness/cliff_ledge_contacts.gd"]:
  script=GDScript.new();script.source_code=FileAccess.get_file_as_string(path);assert(script.reload()==OK)
  await script.new().run(review)
 print("[ledge_review] final capture, contacts and walks complete")
