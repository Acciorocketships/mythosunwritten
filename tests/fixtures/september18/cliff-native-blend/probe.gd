extends SceneTree
func _initialize()->void:
 var source=load("res://scripts/terrain/field/CliffRockCrags.gd")
 source.prepare()
 var lo:=INF;var hi:=-INF
 for depth:float in source._wall_depth:lo=minf(lo,depth);hi=maxf(hi,depth)
 print("NATIVE_DEPTH_RANGE ",lo," ",hi)
 quit()
