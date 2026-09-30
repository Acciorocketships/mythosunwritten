extends RefCounted
func run(review:Node3D)->void:
 var shader:Shader=load("res://terrain/materials/cliff_crag.gdshader")
 shader.code=FileAccess.get_file_as_string("res://terrain/materials/cliff_crag.gdshader")
 await review._capture_all(6)
 print("[shader_review] done")
