extends RefCounted
func run(review:Node3D)->void:
 var include:ShaderInclude=load("res://terrain/materials/slope_green.gdshaderinc")
 include.code=FileAccess.get_file_as_string("res://terrain/materials/slope_green.gdshaderinc")
 var shader:Shader=load("res://terrain/materials/cliff_crag.gdshader")
 shader.code=FileAccess.get_file_as_string("res://terrain/materials/cliff_crag.gdshader")
 await review._capture_all(3)
 print("[crown_material] done")
