extends GutTest
const Frozen = preload("res://tests/fixtures/frozen_maze_source.gd")

func test_photographed_room_overhang_has_visible_native_support() -> void:
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	var spatial := Frozen.spatial(Frozen.read("res://tests/fixtures/september11-floating-source.txt"), program)
	var plan := spatial.compiled_fabric_cache()
	var photographed: WarrenRoomStamp
	for building: WarrenBuildingVolume in spatial.buildings:
		for room: WarrenRoomStamp in building.room_records:
			if room.stable_id == &"spatial.parcel.maze.bridge.00.end.1.lower.part01.room00":
				photographed = room
	assert_not_null(photographed, "The lower bridge building must remain")
	if photographed != null:
		var borne := true
		for cell: Vector3i in photographed.private_cells:
			if cell.y != photographed.lattice_origin.y: continue
			borne = borne and spatial.grid.use_at(cell + Vector3i.DOWN) == WarrenSpatialGrid.Use.PRIVATE_VOLUME
		assert_true(borne, "The compact room beneath the bridge endpoint has complete immediate building bearing")
	var support := plan.unit(&"spatial.fabric.spatial.feature.room_overhang.00.component.00")
	assert_not_null(support)
	if support == null: return
	var recipe := plan.recipe(support.recipe_id)
	var faces := PackedVector3Array()
	for placement: Dictionary in recipe.placements:
		var visual: EnvironmentVisual = load(catalog.descriptor(placement.asset_id).visual_path)
		for piece: EnvironmentVisualPiece in visual.pieces:
			faces.append_array(support.transform() * (placement.transform as Transform3D)
				* piece.local_transform * EnvironmentBakeGeometry.triangle_faces(piece.mesh))
	assert_gt(faces.size(), 0, "The photographed projecting room needs actual native support, not an empty reservation")
	var payload := SettlementFabricAssembler.payload(plan)
	var contacts := 0
	for feature: WarrenFeatureReservation in spatial.features:
		if feature.kind != &"room_overhang_support": continue
		var lower := StringName("spatial.fabric.%s" % feature.audit.overhang_lower_room_id)
		var upper := StringName("spatial.fabric.%s" % feature.audit.overhang_upper_room_id)
		for record_index in feature.construction_records.size():
			var unit := plan.unit(StringName("spatial.fabric.%s.component.%02d" % [feature.stable_id,record_index]))
			if unit == null or not String(unit.recipe_id).begins_with("outcrop.support.bracketed."): continue
			for placement: Dictionary in plan.recipe(unit.recipe_id).placements:
				var bounds := catalog.descriptor(placement.asset_id).measured_aabb
				var transform: Transform3D = unit.transform()*placement.transform
				var axis := transform.basis.y.normalized()
				for end in 2:
					var point := transform*Vector3(bounds.get_center().x,
						bounds.position.y if end==0 else bounds.end.y,bounds.get_center().z)
					var owner := lower if end==0 else upper
					assert_true(_native_contact(payload,catalog,owner,point-axis*.20,point+axis*.20),
						"%s %s end %d meets the actual %s mesh" % [unit.stable_id,placement.id,end,owner])
					contacts += 1
	assert_eq(contacts,8,"Both selected paired support courses have four native endpoint contacts")
	assert_eq(WarrenSpatialFabricCompiler.validation_errors(plan),PackedStringArray())

func _native_contact(payload: EnvironmentInstancePayload, catalog: EnvironmentCatalog,
		owner: StringName, start: Vector3, end: Vector3) -> bool:
	for asset: StringName in payload.batches:
		var batch: Dictionary = payload.batches[asset]
		for index in batch.ids.size():
			if not String(batch.ids[index]).begins_with(String(owner)+"/"): continue
			var visual: EnvironmentVisual = load(catalog.descriptor(asset).visual_path)
			for piece: EnvironmentVisualPiece in visual.pieces:
				var faces: PackedVector3Array = (batch.transforms[index] as Transform3D) \
					* piece.local_transform * EnvironmentBakeGeometry.triangle_faces(piece.mesh)
				for face in range(0,faces.size(),3):
					if Geometry3D.segment_intersects_triangle(start,end,faces[face],faces[face+1],faces[face+2]) != null:
						return true
	return false
