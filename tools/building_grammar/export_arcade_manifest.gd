extends SceneTree
const DOCUMENT := "res://tests/fixtures/native_streethouse8c_derivation.json"
const MATERIALS := "res://terrain/environment/grammar/materials/arcade"
const MANIFEST := "res://tools/environment_bake/manifests/pure_village_arcade_grammar.json"
const DERIVATION := "res://terrain/environment/grammar/streethouse8c.json"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DOCUMENT))
	assert(doc.complete)
	var reference: Node3D = load("res://" + doc.source).instantiate()
	var material_paths := {}
	DirAccess.make_dir_recursive_absolute(MATERIALS)
	for mesh: MeshInstance3D in reference.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(surface)
			var name := material.resource_name
			if material_paths.has(name):
				continue
			var path := MATERIALS + "/" + name.to_lower() + ".tres"
			assert(ResourceSaver.save(material.duplicate(true), path) == OK)
			material_paths[name] = path
	# Preserve the measured alternative bay bindings alongside the source parts.
	var existing: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DERIVATION))
	doc.facade_variants = existing.facade_variants
	var hood: Node3D = (
		load("res://assets/PureVillage/Models/Architecture/Window_5_2.glb").instantiate()
	)
	for mesh: MeshInstance3D in hood.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(surface)
			var name := material.resource_name
			if material_paths.has(name):
				continue
			var path := MATERIALS + "/" + name.to_lower() + ".tres"
			assert(ResourceSaver.save(material.duplicate(true), path) == OK)
			material_paths[name] = path
	hood.free()
	var entries := {}
	var all_parts: Array = doc.parts.duplicate()
	for module: String in doc.facade_variants:
		doc.facade_variants[module].module = module
		all_parts.append(doc.facade_variants[module])
	for part: Dictionary in all_parts:
		var source: String = "res://" + part.module_source
		var stock: Node3D = load(source).instantiate()
		var meshes := stock.find_children("*", "MeshInstance3D", true, false)
		var bindings := []
		for index in meshes.size():
			var mesh: MeshInstance3D = meshes[index]
			for surface in mesh.mesh.get_surface_count():
				var target: String = part.materials[index][surface]
				if mesh.get_active_material(surface).resource_name == target:
					continue
				bindings.append(
					{
						"path": String(stock.get_path_to(mesh)),
						"surface": surface,
						"material": material_paths[target]
					}
				)
		var id := "pure_village.arcade." + String(part.module).to_lower()
		if not bindings.is_empty():
			id += ".binding." + JSON.stringify(bindings).sha256_text().left(12)
		var entry := {
			"id": id,
			"source": source,
			"pivot": [0, 0, 0],
			"merge_pieces": true,
			"tags": ["village", "pure_village_native_grammar", "building"],
			"tint_group": "identity",
			"supports_instance_color": true,
			"max_mesh_bytes": 8388608,
			"max_visual_triangles": 40000,
			"max_surfaces": 20,
			"collision_profile": "building_trimesh",
			"max_collision_triangles": 40000,
			"max_collision_pieces": 1
		}
		if not bindings.is_empty():
			entry.material_bindings = bindings
		part.asset_id = id
		entries[id] = entry
		# Preserve source matrices verbatim. The compiler canonicalizes reflected
		# runtime instances against these separately wound visual/collision assets.
		var reflected := entry.duplicate(true)
		reflected.id = id + ".mirror_x"
		reflected.mirror_axis = "x"
		entries[reflected.id] = reflected
		stock.free()
	reference.free()
	var assets: Array = []
	var ids := entries.keys()
	ids.sort()
	for id in ids:
		assets.append(entries[id])
	var manifest := {
		"pack": "pure_village_arcade_grammar",
		"license": "Unity Asset Store Standard EULA (BK Pure Village)",
		"default_scale": [1, 1, 1],
		"assets": assets,
		"texture_policy":
		{"compression": "basis_universal", "mipmaps": true, "namespace": "pure_village_kit"}
	}
	FileAccess.open(MANIFEST, FileAccess.WRITE).store_string(JSON.stringify(manifest, "  ") + "\n")
	FileAccess.open(DERIVATION, FileAccess.WRITE).store_string(JSON.stringify(doc, "  ") + "\n")
	print("Exported ", assets.size(), " baked stock variants for ", doc.parts.size(), " placements")
	quit()
