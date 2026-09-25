extends SceneTree
const OUT:="res://docs/qa/2026-09-19-manual/115-hillside-fill-stages/"
func _initialize() -> void:
	var d:Dictionary=FileAccess.open(OUT+"relax.bin",FileAccess.READ).get_var()
	var samples:Array=JSON.parse_string(FileAccess.get_file_as_string("res://docs/qa/2026-09-19-manual/114-hillside-surface-joins/candidate-samples.json"))
	var rows:Array[Dictionary]=[]
	for row:Dictionary in samples:
		if row.index<186:continue
		var p:=Vector2(row.point[0],row.point[1])
		var q:=Vector2i(((p-d.base)/6.0).floor())
		var corners:Array[Dictionary]=[]
		for dz in [0,1]:
			for dx in [0,1]:
				var node:=q+Vector2i(dx,dz)
				var i:int=node.y*int(d.size)+node.x
				var w:Vector2=d.base+Vector2(node)*6
				var h:float=d.levels[i];var r:float=d.rivers[i]
				corners.append({"point":[w.x,w.y],"head":h if is_finite(h) else null,"ground":d.ground[i],"anchor":r if is_finite(r) else null})
		rows.append({"index":row.index,"point":row.point,"corners":corners})
	FileAccess.open(OUT+"mouth-cells.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	quit()
