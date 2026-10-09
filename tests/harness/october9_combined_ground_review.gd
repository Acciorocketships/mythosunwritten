extends RefCounted
func run(review:Node)->void:
	for path:String in ["res://tests/harness/october9_battle_ground_review.gd","res://tests/harness/october9_foliage_motion_review.gd","res://tests/harness/october9_water_branch_supply.gd"]:
		var script:=GDScript.new()
		script.source_code=FileAccess.get_file_as_string(path)
		if script.reload()!=OK:return
		await script.new().run(review)
	print("COMBINED_GROUND_REVIEW done")
