extends SceneTree
func _init() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	var records := []
	for id: StringName in [&"roof.tower.orange.dormer.left",&"roof.square.orange.dormer.right",&"roof.tower.blue.dormer.left"]:
		var recipe := program.recipe(id)
		var items := []
		for placement: Dictionary in recipe.placements:
			var visual := load(catalog.descriptor(placement.asset_id).visual_path) as EnvironmentVisual
			var points := []
			for piece: EnvironmentVisualPiece in visual.pieces:
				for v: Vector3 in EnvironmentBakeGeometry.triangle_faces(piece.mesh,(placement.transform as Transform3D)*piece.local_transform): points.append([v.x,v.y,v.z])
			items.append({"id":str(placement.id),"asset":str(placement.asset_id),"transform":str(placement.transform),"faces":points})
		records.append({"recipe":str(id),"items":items})
	FileAccess.open("res://docs/qa/2026-09-13-manual/41-dormers/geometry-before.json",FileAccess.WRITE).store_string(JSON.stringify(records))
	quit()
