extends SceneTree
const E = preload("res://scripts/terrain/field/CliffSlopeEnvelope.gd")
func _init() -> void:
	var saved: Dictionary=FileAccess.open("res://tests/fixtures/october8/dents-lattice.var",FileAccess.READ).get_var()
	var region:=HeightfieldRegion.new(saved.storeys,saved.levels)
	var ground:=func(p:Vector2)->float:return TerrainTileField.surface_y(region,p.x,p.y)
	var capture:Dictionary={}
	var env=E._build(Rect2(-336,1332,60,48),ground,Callable(),2697992464,Callable(),Callable(),Callable(),true,1,capture)
	var worst: Array=[]
	for z in range(2676,2716):
		for x in range(-658,-594):
			var p:=Vector2(x,z)*.5
			for axis in [Vector2.RIGHT,Vector2.DOWN]:
				var a:float=ground.call(p-axis*2);var b:float=ground.call(p);var c:float=ground.call(p+axis*2)
				var original:=maxf(0,minf(a,c)-b)
				var dip:float=minf(env.at(p-axis*2),env.at(p+axis*2))-env.at(p)-original
				if dip>.04:worst.append({"p":p,"axis":axis,"dip":dip,"ground":b,"sheet":env.at(p)})
	worst.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return a.dip>b.dip)
	for i in mini(20,worst.size()):print(worst[i])
	var lines:Array=[]
	for x in range(-624,-590):
		var p:=Vector2(x*.5,1342)
		var idx:int=roundi((p.y-env.origin.y)/E.H)*env.w+roundi((p.x-env.origin.x)/E.H)
		var item:Dictionary={"x":p.x,"ground":env.ground[idx],"sheet":env.surface[idx]}
		for key in ["narrow","wide","tight","tight_wide","blend","fillet","bedrock","lips"]:
			item[key]=capture[key][idx]
		lines.append(item)
	FileAccess.open("/tmp/oct8-dent-stages.json",FileAccess.WRITE).store_string(JSON.stringify(lines,"  "))
	quit()
