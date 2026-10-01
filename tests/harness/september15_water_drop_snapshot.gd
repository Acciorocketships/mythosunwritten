extends SceneTree
func _init() -> void:
	var data:Dictionary=FileAccess.open("res://docs/qa/2026-09-15-manual/05-water-drops/candidate-field.bin",FileAccess.READ).get_var()
	var region:=HeightfieldRegion.new(data.storeys,data.levels,data.carved)
	var ctx:Dictionary={"region":region,"fill":data.fill,"fill_base":data.fill_base}
	print("BASE ",data.fill_base," keys ",data.fill.keys()," size ",data.fill.levels.size())
	for z in [-1440,-1437,-1434,-1431,-1428,-1425,-1422]:
		var row:=[]
		for x in [-237,-234,-231,-228,-225,-222]:
			var p:=Vector2(x,z)
			row.append([x,TerrainTileField.surface_y(region,p.x,p.y),WaterField.level_at(ctx,p)])
		print(z," ",row)
	for z in [-1434,-1431,-1428]:
		var a:=Vector2(-231,z)
		var p:=Vector2(-228,z)
		var inside:=p-Vector2(.01,0)
		print("APPROACH ",z," bounds=",TerrainTileField.height_bounds(region,Rect2(a,inside-a).abs())," crown=",TerrainTileField.surface_y(region,inside.x,inside.y)," foot=",TerrainTileField.surface_y(region,p.x+.01,p.y))
	quit()
