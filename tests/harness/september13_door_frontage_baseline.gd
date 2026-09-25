extends "res://tests/test_september9_door_ownership.gd"
func before_all() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var old_assets: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/qa/2026-09-13-manual/39-door-panels/before-assets.json"))
	for asset: String in old_assets:
		var descriptor := catalog.descriptor(StringName(asset)).duplicate(true) as EnvironmentAssetDescriptor
		descriptor.visual_path = old_assets[asset]
		var visual := load(descriptor.visual_path) as EnvironmentVisual
		var bounds := AABB()
		for index in visual.pieces.size():
			var piece: EnvironmentVisualPiece = visual.pieces[index]
			var box: AABB = piece.local_transform*piece.mesh.get_aabb()
			bounds = box if index==0 else bounds.merge(box)
		descriptor.measured_aabb = bounds
		catalog._by_id[StringName(asset)] = descriptor
	program = SettlementFabricProgram.compile(catalog)
