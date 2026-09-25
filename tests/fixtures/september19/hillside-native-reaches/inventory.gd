extends SceneTree
func _initialize() -> void:
	var long_routes := "--long" in OS.get_cmdline_user_args()
	var script = preload("res://tests/fixtures/september19/hillside-native-reaches/long_reach_plan.gd") if long_routes else preload("res://tests/fixtures/september19/hillside-native-reaches/reach_plan.gd")
	var water = script.new(2697992464,128,32)
	var regions: Array[Dictionary] = []
	for cell: Vector2i in [Vector2i(-2,-2),Vector2i(-2,-1),Vector2i(-1,-2),Vector2i(-1,-1)]:
		var record: Dictionary = water._region_for(cell)
		regions.append({"cell":str(cell),"rivers":record.rivers.size(),"ponds":record.ponds.size()})
		print("REACH_REGION ",regions[-1]," resolved=",water.route_audits.size()," rejected=",water.rejected_routes.size())
	var output := {"regions":regions,"routes":water.route_audits,"rejected":water.rejected_routes,"radius":water._study_radius(),"halo":water._study_halo()}
	var suffix := "-long" if long_routes else ""
	FileAccess.open("res://docs/qa/2026-09-19-manual/112-hillside-native-reaches/inventory"+suffix+".json",FileAccess.WRITE).store_string(JSON.stringify(output,"  "))
	water._study = null # break the study/plan reference cycle
	quit(0 if water.rejected_routes.is_empty() else 1)
