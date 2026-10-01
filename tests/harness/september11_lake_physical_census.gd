extends SceneTree

func _init() -> void:
	var census:Array=JSON.parse_string(FileAccess.get_file_as_string("res://docs/qa/2026-09-11-manual/12-landforms/river-survey-joined.json"))
	var rows:Array[Dictionary]=[]
	for seed_value:int in [2697992464,991177,314159]:
		var water:=TerrainWorldTuning.make_water(seed_value)
		var fields:=WorldFieldBlockCache.new(TerrainWorldTuning.make_heightfield(seed_value,water),water,26,0)
		for peninsula:bool in [false,true]:
			for candidate:Dictionary in census:
				if int(candidate.seed)!=seed_value or candidate.peninsula!=peninsula or candidate.island_radius<=0: continue
				var source:=Vector2i(candidate.source[0],candidate.source[1])
				var trace:=water.river_for(source)
				var pond:=trace.pond
				if pond==null or pond.island_radius<=0: continue
				var center:=pond.center+pond.island_offset
				var axis:=pond.island_offset.normalized()
				var samples:Array[Dictionary]=[]
				var points:Array[Vector2]=[center]
				for i in 12:
					var direction:=Vector2.from_angle(TAU*float(i)/12)
					if peninsula and direction.dot(axis)>.25: continue
					points.append(center+direction*(pond.island_radius*1.25+12))
				var passed:=true
				for i in points.size():
					var p:=points[i]
					var field:=fields.water_at(p)
					var ground:=TerrainTileField.surface_y(fields.region_at(p),p.x,p.y)
					var wet:=field.is_wet(p)
					passed=passed and (not wet if i==0 else wet)
					samples.append({"point":str(p),"ground":ground,"level":field.level_at(p) if is_finite(field.level_at(p)) else null,"wet":wet})
				rows.append({"seed":seed_value,"source":str(source),"peninsula":peninsula,"center":str(center),"samples":samples,"passed":passed})
				FileAccess.open("res://docs/qa/2026-09-11-manual/12-landforms/lake-physical-census.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
				print("LAKE_PHYSICAL seed=",seed_value," source=",source," peninsula=",peninsula," center=",center," passed=",passed," samples=",samples)
				break
	quit()
