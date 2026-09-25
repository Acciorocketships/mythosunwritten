extends SceneTree

func _init() -> void:
	var plan := TerrainWorldTuning.make_heightfield(2697992464)
	var region := plan.compute_region(0,0,128)
	var data := preload("res://scripts/terrain/field/NaturalArches.gd").compute(region,-112,-112,224,2697992464,null,Vector2.ZERO)
	var rows: Array[Dictionary] = []
	var near: Array[Dictionary] = []
	for z in range(-110,112,4):
		for x in range(-110,112,4):
			for axis: Vector2i in [Vector2i.RIGHT,Vector2i.DOWN,Vector2i(1,1),Vector2i(1,-1)]:
				var a := region.surface_height(x-axis.x,z-axis.y)
				var b := region.surface_height(x+axis.x,z+axis.y)
				var low := region.surface_height(x,z)
				if minf(a,b)-low>=4:
					near.append({"cell":str(Vector2i(x,z)),"axis":str(axis),"rise":minf(a,b)-low,"difference":absf(a-b),
						"roll":Helper._cell_hash01(2697992464+1371,x,z),
						"accepted":not preload("res://scripts/terrain/field/NaturalArches.gd")._site(region,Vector2i(x,z),axis,null).is_empty(),
						"flat_a":TerrainSurfaceField.is_flat_cell(region,x-axis.x,z-axis.y),"flat_b":TerrainSurfaceField.is_flat_cell(region,x+axis.x,z+axis.y)})
	near.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.rise>b.rise)
	FileAccess.open("res://docs/qa/2026-09-11-manual/12-landforms/arch-near-sites.json",FileAccess.WRITE).store_string(JSON.stringify(near,"  "))
	for record: Dictionary in data.placements:
		rows.append({"x":record.center.x,"z":record.center.y,"top":record.top,"low":record.low,"axis":str(record.axis)})
	print("NATURAL_ARCH_SITES ",rows.size())
	FileAccess.open("res://docs/qa/2026-09-11-manual/12-landforms/arch-sites.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	quit()
