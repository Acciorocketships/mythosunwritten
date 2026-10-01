extends SceneTree
func _init() -> void:
	var fields:=preload("res://tests/fixtures/September10WaterFields.gd").get_fields()
	var region:=fields.region(Vector2i(3,-10))
	var old:=preload("res://tests/fixtures/september15/water-drops/field_before.gd")
	var water:=preload("res://tests/fixtures/september11/landforms/PhotoGeography.gd").make_water(2697992464)
	for phase in ["before","after"]:
		var ctx:Dictionary=old.ctx(water,Vector2i(3,-10),region) if phase=="before" else fields.water(Vector2i(3,-10)).raw_context()
		var samples:=[]
		for z in range(-1752,-1715,3):
			var row:=[]
			for x in range(672,709,3):
				var p:=Vector2(x,z)
				var level:float=old.level_at(ctx,p) if phase=="before" else WaterField.level_at(ctx,p)
				row.append([x,TerrainTileField.surface_y(region,p.x,p.y),level])
				samples.append([x,z,TerrainTileField.surface_y(region,p.x,p.y),level if is_finite(level) else null])
			print(phase," ",z," ",row)
		var data:Dictionary={"fill":ctx.fill,"fill_base":ctx.fill_base,"storeys":region._storeys,"levels":region._levels,"carved":region._carved}
		FileAccess.open("res://docs/qa/2026-09-15-manual/05-water-drops/legacy-"+phase+".bin",FileAccess.WRITE).store_var(data)
		FileAccess.open("res://docs/qa/2026-09-15-manual/05-water-drops/legacy-"+phase+".json",FileAccess.WRITE).store_string(JSON.stringify(samples))
	quit()
