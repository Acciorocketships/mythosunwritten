extends RefCounted
const ROOT="res://terrain/environment/textures/meadow/"
static func make(number:int)->ShaderMaterial:
 var mat:=ShaderMaterial.new();mat.shader=load("res://terrain/materials/meadow_rock.gdshader")
 var n:=mini(number,6)
 mat.set_shader_parameter("base_albedo",load(ROOT+"T_Rock_%02d_A.res"%n))
 mat.set_shader_parameter("base_normal",load(ROOT+"T_Rock_%02d_N.res"%n))
 mat.set_shader_parameter("base_sma",load(ROOT+"T_Rock_%02d_SMA.res"%n))
 load("res://scripts/terrain/field/CliffRockCrags.gd").apply_moss(mat)
 return mat
