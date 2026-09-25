extends SceneTree

func _init() -> void:
	var sites:Dictionary={}
	for z in range(-6,7):
		for x in range(-6,7):
			var p:=Vector3(x*LandformField.SCALE,0,z*LandformField.SCALE)
			if p.length()<600: continue
			var weights:=Helper.biome_weights5(p,2697992464)
			var biome:=Helper.biome_at(p,2697992464)
			var choices:Array=LandformField.PROFILES[biome][2]
			var roll:=Helper._cell_hash01(2697992464+1301,x,z)
			var kind:int=choices[mini(int(roll*choices.size()),choices.size()-1)]
			var name:StringName=LandformField.NAMES[kind]
			var score:float=weights[biome]+float(LandformField.PROFILES[biome][1])*.1
			if sites.has(name) and sites[name].score>=score: continue
			sites[name]={"core":{"x":p.x,"z":p.z},"biome":biome,"score":score,"kind":kind}
	FileAccess.open("res://docs/qa/2026-09-11-manual/12-landforms/landmarks.json",FileAccess.WRITE).store_string(JSON.stringify(sites,"  "))
	print("LANDMARKS ",sites.keys())
	quit()
