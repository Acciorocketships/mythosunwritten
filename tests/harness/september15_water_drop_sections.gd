extends SceneTree
func _init() -> void:
	var water:=TerrainWorldTuning.make_water(2697992464)
	var plan:=TerrainWorldTuning.make_heightfield(2697992464,water)
	var fields:=WorldFieldBlockCache.new(plan,water,26,0,64)
	var region:=fields.region(Vector2i(-2,-8))
	var before:=preload("res://tests/fixtures/september15/water-drops/field_before.gd")
	for phase in ["before","after"]:
		var ctx:Dictionary=before.ctx(water,Vector2i(-2,-8),region) if phase=="before" else WaterField.ctx(water,Vector2i(-2,-8),region)
		var file:=FileAccess.open("res://docs/qa/2026-09-15-manual/05-water-drops/sections-"+phase+".csv",FileAccess.WRITE)
		file.store_line("x,z,ground,water")
		for z in range(-1490,-1409):
			for ix in 121:
				var p:=Vector2(-252+ix*.25,z)
				var level:float=before.level_at(ctx,p) if phase=="before" else WaterField.level_at(ctx,p)
				file.store_csv_line([str(p.x),str(p.y),str(TerrainTileField.surface_y(region,p.x,p.y)),str(level)])
		file.close()
		print("DROP_SECTIONS_DONE ",phase)
	quit()
