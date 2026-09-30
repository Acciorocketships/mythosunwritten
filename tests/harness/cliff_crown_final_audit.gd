extends RefCounted
func run(review:Node3D)->void:
 for path:String in ["res://tests/harness/cliff_crown_rays.gd","res://tests/harness/cliff_p03_normals.gd","res://tests/harness/cliff_p03_surface_audit.gd","res://tests/harness/cliff_p03_audit.gd"]:
  var script:=GDScript.new();script.source_code=FileAccess.get_file_as_string(path)
  if script.reload()!=OK:push_error("Invalid audit: "+path);continue
  if path.ends_with("cliff_p03_audit.gd"):await script.new().run(review,"after")
  else:await script.new().run(review)
 print("[crown_final] audits complete")
