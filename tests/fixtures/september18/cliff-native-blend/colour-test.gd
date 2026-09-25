extends "res://tests/test_september17_stone_colour_gpu.gd"

func _sample(path:String,position:Vector3)->Image:
 return await super._sample("res://tests/fixtures/september18/cliff-native-blend/selected-shader.gdshader" if path.ends_with("cliff_crag.gdshader") else path,position)
