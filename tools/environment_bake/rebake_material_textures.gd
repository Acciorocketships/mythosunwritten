@tool
extends "res://tools/environment_bake/environment_bake.gd"
## Apply a manifest's texture encoding policy to its existing native materials.
## Geometry, collision, material palette and source provenance remain intact.
## Use only for lossless baked input; compressed input must be rebuilt from source.
## --manifest res://...json --keep-existing

var _records: Dictionary = {}
var _rebaked: Dictionary = {}

func _run() -> void:
	if not OS.get_cmdline_user_args().has("--keep-existing"):
		_fail("Texture-only rebake requires --keep-existing")
		quit(1)
		return
	super._run()

func _bake_asset(pack: String, _license_label: String, entry: Dictionary,
		_default_scale: Variant) -> Dictionary:
	if not _records.has(pack):
		var path := "res://tools/environment_bake/provenance/%s.json" % _slug(pack)
		var previous: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var records := {}
		for record: Dictionary in previous.assets: records[record.id] = record
		_records[pack] = records
	var id := String(entry.id)
	if not _records[pack].has(id):
		_fail("No existing bake for %s" % id)
		return {}
	var record: Dictionary = _records[pack][id].duplicate(true)
	# JSON decodes every number as float; preserve the baker's integer counters.
	for counter: String in ["collision_piece_count","collision_triangles","mesh_bytes",
			"surface_count","visual_piece_count","visual_triangles"]:
		if record.metrics.has(counter): record.metrics[counter] = int(record.metrics[counter])
	if record.has("geometry_tool_version"):
		record.geometry_tool_version = int(record.geometry_tool_version)
	if record.parameters != entry:
		_fail("Texture-only rebake cannot change geometry parameters: %s" % id)
		return {}
	if record.get("texture_policy",{}) == _texture_policy:
		return record
	var directory := "res://terrain/environment/materials/%s/" % _slug(pack)
	var count := 0
	for filename: String in DirAccess.get_files_at(directory):
		if not filename.begins_with(_slug(id)+"_piece_") or not filename.ends_with(".tres"): continue
		var path := directory+filename
		var material := load(path) as Material
		for property: Dictionary in material.get_property_list():
			if property.type != TYPE_OBJECT: continue
			var texture := material.get(property.name) as Texture2D
			if texture == null: continue
			var normal_map := String(property.name).contains("normal")
			var key := "%s:%s:%s" % [pack,texture.resource_path,normal_map]
			if _rebaked.has(key):
				material.set(property.name,_rebaked[key])
				continue
			if texture.get_image().is_compressed():
				_fail("Rebuild compressed source pixels with environment_bake.gd: %s" % path)
				return {}
			var baked := _bake_texture(texture,pack,-1.0,normal_map)
			if baked == null: return {}
			_rebaked[key] = baked
			material.set(property.name,baked)
		if ResourceSaver.save(material,path) != OK:
			_fail("Cannot save %s" % path)
			return {}
		count += 1
	if count == 0:
		_fail("No native materials for %s" % id)
		return {}
	record["geometry_tool_version"] = int(record.get("tool_version",0))
	print("TEXTURE_REBAKE ",id," materials=",count)
	return record
