extends SceneTree

func _init() -> void:
	var rows:Array[Dictionary]=[]
	for site:Array in [[2697992464,Vector2i(-3,-1)],[991177,Vector2i(2,-4)],[314159,Vector2i(2,1)]]:
		var water:=TerrainWorldTuning.make_water(site[0])
		var fields:=WorldFieldBlockCache.new(TerrainWorldTuning.make_heightfield(site[0],water),water,26,0)
		var trace:=water.river_for(site[1])
		assert(trace!=null and not trace.land_bars.is_empty())
		for bar:Dictionary in trace.land_bars:
			var center:Vector2=bar.center
			var axis:Vector2=bar.axis
			var side:=Vector2(-axis.y,axis.x)
			var points:Array[Dictionary]=[]
			for offset:float in [0,-54,54]:
				var p:=center+side*offset
				var region:=fields.region_at(p)
				var field:=fields.water_at(p)
				var ground:=TerrainSurfaceField.surface_y(region,p.x,p.y)
				points.append({"offset":offset,"point":str(p),"ground":ground,"level":field.level_at(p) if is_finite(field.level_at(p)) else null,"wet":field.is_wet(p)})
			var passed:bool=not points[0].wet and points[1].wet and points[2].wet
			rows.append({"seed":site[0],"source":str(site[1]),"points":points,"passed":passed})
			FileAccess.open("res://docs/qa/2026-09-11-manual/12-landforms/bar-physical-census.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
			print("BAR_PHYSICAL ",site," ",center," passed=",passed," ",points)
	quit()
