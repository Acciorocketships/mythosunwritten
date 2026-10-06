extends "res://tests/harness/pure_village_lineup.gd"
## Deliberately isolated material options on the same authored corner-tower
## prefab. Not production palette selection or proof of procedural assembly.
const PALETTE_SHADER := preload("res://tests/harness/suntail/town_palette_study.gdshader")
const WOOD := preload("res://assets/PureVillage/Textures/Wood/Wood_a_1001.png")
const OPTIONS := [
	{
		"id": "01-oak-walnut",
		"title": "Oak shingles / walnut framing",
		"roof": "9d7045",
		"wood": "533725",
		"plaster": "dbcfb3",
		"stone": "a8a093",
		"grain": true
	},
	{
		"id": "02-walnut-oak",
		"title": "Walnut shingles / pale oak framing",
		"roof": "594439",
		"wood": "ad875b",
		"plaster": "d8c9ad",
		"stone": "a6a19a",
		"grain": true
	},
	{
		"id": "03-blue-birch",
		"title": "Blue slate / pale birch framing",
		"roof": "6f9baa",
		"wood": "c7b68e",
		"plaster": "e0d6bf",
		"stone": "abaeaa",
		"grain": false
	},
	{
		"id": "04-sage-oak",
		"title": "Muted sage tiles / oak framing",
		"roof": "6f7962",
		"wood": "89613d",
		"plaster": "d9cdb2",
		"stone": "a6a395",
		"grain": false
	},
	{
		"id": "05-limestone-charcoal",
		"title": "Warm limestone / charcoal roof",
		"roof": "555e62",
		"wood": "60574a",
		"plaster": "c9b995",
		"stone": "c9b995",
		"grain": false,
		"smooth": true
	},
]


func _run() -> void:
	get_root().size = Vector2i(1400, 1100)
	var ledger := {}
	var args := OS.get_cmdline_user_args()
	var manifest := FileAccess.open(_out + "/options.json", FileAccess.WRITE)
	manifest.store_string(JSON.stringify(OPTIONS, "\t"))
	manifest.close()
	if args.has("--manifest-only"):
		quit()
		return
	for palette: Dictionary in OPTIONS:
		if args.has("--option") and palette.id != args[args.find("--option") + 1]:
			continue
		print("PALETTE_START ", palette.id)
		var stage := Node3D.new()
		get_root().add_child(stage)
		_light(stage)
		var house := (load(R + "Houses/House_16c.glb") as PackedScene).instantiate() as Node3D
		stage.add_child(house)
		var changed := {}
		var variants := {}
		var source_stone: StandardMaterial3D
		for mesh: MeshInstance3D in house.find_children("*", "MeshInstance3D", true, false):
			for index in mesh.mesh.get_surface_count():
				var mat := mesh.get_active_material(index) as StandardMaterial3D
				if mat != null and mat.resource_name == "Stones":
					source_stone = mat
		for mesh: MeshInstance3D in house.find_children("*", "MeshInstance3D", true, false):
			for index in mesh.mesh.get_surface_count():
				var mat := mesh.get_active_material(index) as StandardMaterial3D
				if mat == null:
					continue
				var name := mat.resource_name
				var family := ""
				if name.begins_with("Roof"):
					family = "roof"
				elif (
					name.begins_with("Wood")
					or name.begins_with("Planks")
					or name.begins_with("DoorShutter")
				):
					family = "wood"
				elif name.begins_with("Stone"):
					family = "stone"
				elif name == "Plaster":
					family = "plaster"
				if family == "" or mat.albedo_texture == null:
					continue
				if palette.get("smooth", false) and family == "plaster" and source_stone != null:
					mat = source_stone
				if variants.has(name):
					mesh.set_surface_override_material(index, variants[name])
					continue
				var variant := ShaderMaterial.new()
				variant.shader = PALETTE_SHADER
				variant.set_shader_parameter("source_albedo", mat.albedo_texture)
				variant.set_shader_parameter("source_normal", mat.normal_texture)
				variant.set_shader_parameter(
					"has_normal", mat.normal_enabled and mat.normal_texture != null
				)
				variant.set_shader_parameter(
					"relief",
					0.25 if palette.get("smooth", false) and family in ["stone", "plaster"] else 1.0
				)
				variant.set_shader_parameter("tone", Color(palette[family]))
				variant.set_shader_parameter("grain_roof", family == "roof" and palette.grain)
				variant.set_shader_parameter("wood_grain", WOOD)
				variants[name] = variant
				mesh.set_surface_override_material(index, variant)
				changed[name] = family
		var box := _aabb(house)
		var centre := box.get_center()
		await _shoot(stage, centre + Vector3(24, 10, 30), centre, palette.id, 50)
		await _shoot(stage, Vector3(15, 12, 16), Vector3(4.625, 9, 3), palette.id + "-corner", 50)
		print("PALETTE_DONE ", palette.id)
		ledger[palette.id] = {"palette": palette, "materials": changed}
		stage.queue_free()
		await process_frame
	var suffix := "-" + String(args[args.find("--option") + 1]) if args.has("--option") else ""
	var file := FileAccess.open(_out + "/materials" + suffix + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(ledger, "\t"))
	quit()
