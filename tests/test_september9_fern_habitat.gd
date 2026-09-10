extends GutTest

const FERNS := [&"lpfv.plant.01", &"lpfv.plant.02", &"lpfv.plant.03", &"lpfv.plant.04"]

func _choices() -> Array:
	var index:=DressingCatalogIndex.new()
	index.sets.append(load("res://terrain/dressing/sets/ambient_flower.tres"))
	return DressingCompiler.compile(index,EnvironmentCatalog.load_default()).sets[0].choices

func test_broadleaf_species_is_confined_to_jade_estuary_and_its_blend() -> void:
	var choices:=_choices()
	for biome:StringName in BiomeRegistry.biome_ids():
		var weights:Dictionary={}
		for id:StringName in BiomeRegistry.biome_ids():weights[id]=float(id==biome)
		var count:=0
		for i in 1000:
			var choice:=DressingField._choose(choices,weights,(float(i)+0.5)/1000.0)
			if choice.asset_id in FERNS:count+=1
		if biome==&"jade_wetlands":assert_gt(count,0,"Jade Estuary must retain this species")
		else:assert_eq(count,0,"The broadleaf must not colonize %s"%biome)

func test_reported_moonfen_highland_community_cannot_choose_the_broadleaf() -> void:
	var weights:=Helper.biome_weights5(Vector3(77.59009,0,-2434.973),2697992464)
	assert_eq(weights[&"jade_wetlands"],0.0)
	var choice:=DressingField._choose(_choices(),weights,0.56894354152028)
	assert_false(choice.asset_id in FERNS,"The photographed proposal must not substitute a similar broadleaf variant")
