extends SceneTree

# Demand discovery runs offline against the finite room vocabulary. Production
# only selects these already-baked square/miter/back-plane alternatives.
func _init() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/environment_bake/manifests/fantasy_village_fabric.json"))
	var entries: Dictionary = {}
	for entry: Dictionary in source.assets: entries[String(entry.id)]=entry
	for spec: Dictionary in source.get("mirror_variants",[]):
		for entry: Dictionary in source.assets:
			for prefix: String in spec.id_prefixes:
				if not String(entry.id).begins_with(prefix): continue
				var mirrored := entry.duplicate(true)
				mirrored.id=String(entry.id)+String(spec.suffix)
				mirrored["mirror_axis"]=spec.axis
				entries[mirrored.id]=mirrored
	var demanded: Dictionary = {}
	for recipe: FabricRecipe in program.recipes():
		for variant: Dictionary in program.module_program.finish_door_returns(recipe):
			var entry: Dictionary = (entries[variant.base_asset] as Dictionary).duplicate(true)
			entry.id=variant.id
			entry["facade_miter_ends"]=variant.facade_miter_ends
			entry["facade_return_depths"]=variant.facade_return_depths
			demanded[entry.id]=entry
	var ids := demanded.keys()
	ids.sort()
	var assets: Array = []
	for id: String in ids: assets.append(demanded[id])
	var output := {"pack":source.pack,"license":source.license,"default_scale":source.default_scale,
		"assets":assets,"generated_by":"res://tools/environment_bake/export_door_return_manifest.gd"}
	var file := FileAccess.open("res://tools/environment_bake/manifests/fantasy_village_door_returns.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(output," ")+"\n")
	print("DOOR_RETURN_DEMAND variants=",assets.size())
	quit()
