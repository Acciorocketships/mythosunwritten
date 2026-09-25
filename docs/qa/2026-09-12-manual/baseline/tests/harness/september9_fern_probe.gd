extends SceneTree

# Record species proposals before terrain qualification; this identifies the
# photographed asset without replacing production ground or water acceptance.
func _init() -> void:
	var index:=DressingCatalogIndex.new()
	index.sets.append(load("res://terrain/dressing/sets/ambient_flower.tres"))
	var program:=DressingCompiler.compile(index,EnvironmentCatalog.load_default())
	var data:Dictionary=program.sets[0]
	var result:Array=[]
	var seed:=2697992464
	for z in range(-103,-100):
		for x in range(2,5):
			for slot in data.slot_count:
				var identity:=DressingField._identity(seed,data,Vector2i(x,z),slot)
				var anchor:=Vector2((x+DressingField._roll(identity,DressingField.SALT_JITTER_X))*24,(z+DressingField._roll(identity,DressingField.SALT_JITTER_Z))*24)
				if anchor.distance_to(Vector2(76.8,-2437.9))>20:continue
				var weights:=Helper.biome_weights5(Vector3(anchor.x,0,anchor.y),seed)
				var choice_roll:=DressingField._roll(identity,DressingField.SALT_CHOICE)
				var community:=DressingEcology.community_roll(anchor,seed,data.community_hash,data.community_scale)
				choice_roll=lerpf(choice_roll,community,data.community_strength)
				var choice:=DressingField._choose(data.choices,weights,choice_roll)
				result.append({"anchor":str(anchor),"distance":anchor.distance_to(Vector2(76.8,-2437.9)),"asset":String(choice.get("asset_id","")),"weights":weights,"roll":choice_roll})
	result.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return a.distance<b.distance)
	FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("FERN_PROPOSALS ",result)
	quit()
