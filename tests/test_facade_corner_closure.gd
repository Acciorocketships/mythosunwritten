extends GutTest

# Slice the actual authored walls rather than proving a substitute box. A
# finish may remove intersections, but cannot introduce a view into a room.
func test_finished_corners_preserve_the_enclosure_of_the_original_walls() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	for recipe_id: StringName in [&"room.tower.base.rock", &"room.tower.upper.blue"]:
		var room := program.recipe(recipe_id)
		for height: float in [0.35, 1.05, 2.65]:
			var uncut := _wall_slice(room,catalog,height,true)
			var finished := _wall_slice(room,catalog,height,false)
			var failures := PackedInt32Array()
			var centre := Vector2(-0.75,-0.75)
			for angle in 360:
				var end := centre + Vector2.from_angle(deg_to_rad(float(angle))) * 10.0
				if _crosses(centre,end,uncut) and not _crosses(centre,end,finished):
					failures.append(angle)
			assert_true(failures.is_empty(),"%s y=%s: newly open directions %s" % [recipe_id,height,failures])

func _crosses(a: Vector2,b: Vector2,segments: Array[Vector2]) -> bool:
	for index in range(0,segments.size(),2):
		if Geometry2D.segment_intersects_segment(a,b,segments[index],segments[index+1]) != null:
			return true
	return false

func _wall_slice(room: FabricRecipe,catalog: EnvironmentCatalog,height: float,
		uncut: bool) -> Array[Vector2]:
	var segments: Array[Vector2] = []
	for placement: Dictionary in room.placements:
		if not String(placement.asset_id).begins_with("sfv.fabric.wall."): continue
		var id := StringName(placement.asset_id)
		if uncut and room.facade_end_owners.has(placement.id):
			id = room.facade_end_owners[placement.id].base_asset
		elif not uncut:
			id = room.realized_facade_asset(placement, [])
		var visual: EnvironmentVisual = load(catalog.descriptor(id).visual_path)
		for piece: EnvironmentVisualPiece in visual.pieces:
			var transform: Transform3D = placement.transform * piece.local_transform
			var faces := piece.mesh.get_faces()
			for offset in range(0,faces.size(),3):
				var hits: Array[Vector2] = []
				for edge in 3:
					var a := transform * faces[offset+edge]
					var b := transform * faces[offset+(edge+1)%3]
					if (a.y < height) == (b.y < height): continue
					var hit := a.lerp(b,(height-a.y)/(b.y-a.y))
					hits.append(Vector2(hit.x,hit.z))
				if hits.size()==2: segments.append_array(hits)
	return segments
