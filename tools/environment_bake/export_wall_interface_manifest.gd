extends SceneTree

## Discover the finite full-height wall vocabulary offline. Floors and roofs
## close generated room courses; their horizontal surface must have one owner.
func _init() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://tools/environment_bake/manifests/fantasy_village_fabric.json"))
	var entries: Dictionary = {}
	for entry: Dictionary in source.assets:
		entries[String(entry.id)] = entry
	for spec: Dictionary in source.get("mirror_variants", []):
		for entry: Dictionary in source.assets:
			for prefix: String in spec.id_prefixes:
				if not String(entry.id).begins_with(prefix):
					continue
				var mirrored := entry.duplicate(true)
				mirrored.id = String(entry.id) + String(spec.suffix)
				mirrored["mirror_axis"] = spec.axis
				entries[mirrored.id] = mirrored
	var uncut := entries.duplicate(true)
	for id: String in uncut:
		for prefix: String in source.facade_miter_prefixes:
			if not id.begins_with(prefix):
				continue
			for mask in range(1, 4):
				var cut := (uncut[id] as Dictionary).duplicate(true)
				cut.id = "%s.miter%d" % [id, mask]
				cut["facade_miter_ends"] = mask
				entries[cut.id] = cut
	var returns: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://tools/environment_bake/manifests/fantasy_village_door_returns.json"))
	for entry: Dictionary in returns.assets:
		entries[String(entry.id)] = entry
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	var demanded: Dictionary = {}
	# Adapter masonry and facade courses meet private floors as well as the
	# generated room walls. They use the same finite cap-ownership variants.
	for id: StringName in program.referenced_asset_ids:
		var key := String(id).trim_suffix(".course_open")
		if not key.begins_with("sfv.fabric.wall.") or not entries.has(key): continue
		var descriptor := catalog.descriptor(StringName(key))
		# Match the compiler's full-course range, including below-datum door feet.
		if absf(descriptor.measured_aabb.end.y-3.0)>0.001 or absf(descriptor.measured_aabb.position.y)>0.005: continue
		var entry := (entries[key] as Dictionary).duplicate(true)
		entry.id = key + ".course_open"
		entry["omit_coplanar_y"] = 3.0
		entry["omit_coplanar_tolerance"] = 0.001
		demanded[entry.id] = entry
	var ids := demanded.keys()
	ids.sort()
	var assets: Array = []
	for id: String in ids:
		assets.append(demanded[id])
	var manifest := {"pack": "fantasy_village_wall_interfaces", "license": source.license,
		"default_scale": source.default_scale, "assets": assets,
		"generated_by": "res://tools/environment_bake/export_wall_interface_manifest.gd"}
	var output := FileAccess.open(
		"res://tools/environment_bake/manifests/fantasy_village_wall_interfaces.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(manifest, " ") + "\n")
	print("WALL_INTERFACE_DEMAND variants=", assets.size())
	quit()
