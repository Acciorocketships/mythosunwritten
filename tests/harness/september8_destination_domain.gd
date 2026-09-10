extends SceneTree
func _init()->void:
	var frozen:=preload("res://tests/fixtures/frozen_maze_source.gd")
	var source:=frozen.read("res://tests/fixtures/september7-manual-source.txt")
	var end:Vector3i=source.excavation.route.back()
	print("TERMINAL ",end)
	for d:Vector2i in WarrenPassageLatticeRules.DIRECTIONS:
		var cell:=end+Vector3i(d.x,0,d.y)
		var column:=Vector2i(cell.x,cell.z)
		var carved:Array=[]
		for y in range(cell.y-1,cell.y+4):
			if source.excavation.carved.has(Vector3i(cell.x,y,cell.z)):carved.append(y)
		print("DOMAIN ",cell," base=",source.massif.base_at(column)," top=",source.massif.top_at(column)," carved=",carved,
			" borable=",WarrenPassageLatticeRules.slot_is_borable(source.massif,source.excavation,cell,3))
	quit()
