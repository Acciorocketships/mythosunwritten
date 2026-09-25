extends SceneTree
func _init() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	var report := []
	for theme: String in ["blue","orange","amber"]:
		var recipe := program.recipe(StringName("outcrop."+theme))
		var parts := {}
		for placement: Dictionary in recipe.placements:
			if placement.id not in [&"floor",&"support.bracket"]: continue
			var visual: EnvironmentVisual = load(catalog.descriptor(placement.asset_id).visual_path)
			var faces := PackedVector3Array()
			for piece: EnvironmentVisualPiece in visual.pieces:
				faces.append_array(EnvironmentBakeGeometry.triangle_faces(piece.mesh,placement.transform*piece.local_transform))
			parts[placement.id] = faces
		var floor_box := _bounds(parts[&"floor"])
		var bracket_box := _bounds(parts[&"support.bracket"])
		var overlap := floor_box.intersection(bracket_box)
		var contacts := 0
		for xi in 25:
			for zi in 9:
				var point := Vector3(overlap.position.x+overlap.size.x*(xi+.5)/25,2,overlap.position.z+overlap.size.z*(zi+.5)/9)
				var floor_hits := _interval(parts[&"floor"],point)
				var bracket_hits := _interval(parts[&"support.bracket"],point)
				if floor_hits.is_empty() or bracket_hits.is_empty(): continue
				if minf(floor_hits[1],bracket_hits[1])-maxf(floor_hits[0],bracket_hits[0]) > .005: contacts += 1
		assert(contacts>25,"The complete native bracket must physically join the bay floor")
		report.append({"recipe":recipe.recipe_id,"floor":str(floor_box),"bracket":str(bracket_box),"native_overlap":str(overlap),"contact_columns":contacts,"samples":225})
	FileAccess.open("res://docs/qa/2026-09-13-manual/44-bay-underside/contacts.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("BAY_CONTACTS ",report)
	quit()
func _bounds(faces: PackedVector3Array) -> AABB:
	var result := AABB(faces[0],Vector3.ZERO)
	for point: Vector3 in faces: result = result.expand(point)
	return result
func _interval(faces: PackedVector3Array,point: Vector3) -> Array:
	var lo := INF
	var hi := -INF
	for index in range(0,faces.size(),3):
		var hit: Variant = Geometry3D.segment_intersects_triangle(point,point-Vector3.UP*5,faces[index],faces[index+1],faces[index+2])
		if hit != null:
			lo = minf(lo,hit.y)
			hi = maxf(hi,hit.y)
	return [] if lo==INF else [lo,hi]
