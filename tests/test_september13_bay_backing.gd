extends GutTest

func test_photographed_roofed_bay_has_a_complete_parent_wall() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var spatial := frozen.spatial(frozen.read("res://docs/qa/2026-09-13-manual/09-upper-wall/current-source.txt"),program)
	var checked := 0
	for feature: WarrenFeatureReservation in spatial.features:
		if feature.kind != &"facade_bay": continue
		var unit := spatial.compiled_fabric_cache().unit(StringName("spatial.fabric.%s.component.00" % feature.stable_id))
		var recipe := program.recipe(unit.recipe_id)
		if not recipe.has_tag(&"native_width_gabled_bay"): continue
		var parent: WarrenRoomStamp
		for building: WarrenBuildingVolume in spatial.buildings:
			for room: WarrenRoomStamp in building.room_records:
				if room.stable_id == StringName(feature.audit.annex_room_id):
					parent = room
		assert_not_null(parent)
		if parent == null: continue
		for cell: Vector3i in recipe.solid_cells:
			if cell.z != -1 or cell.y > 1: continue
			var behind := FabricRecipe.transform_cell(cell+Vector3i.FORWARD,unit.lattice_origin,unit.yaw_quarters)
			assert_true(parent.private_cells.has(behind),"%s rear wall cell %s must meet its actual parent" % [feature.stable_id,behind])
		checked += 1
	assert_gt(checked,0,"Keep a complete roofed bay in the photographed town")
	var payload := SettlementFabricAssembler.payload(spatial.compiled_fabric_cache())
	var catalog := EnvironmentCatalog.load_default()
	var faces := PackedVector3Array()
	for asset: StringName in payload.batches:
		var visual: EnvironmentVisual = load(catalog.descriptor(asset).visual_path)
		for transform: Transform3D in payload.batches[asset].transforms:
			for piece: EnvironmentVisualPiece in visual.pieces:
				faces.append_array(EnvironmentBakeGeometry.triangle_faces(piece.mesh,transform*piece.local_transform))
	for feature: WarrenFeatureReservation in spatial.features:
		if feature.kind != &"facade_bay": continue
		var unit := spatial.compiled_fabric_cache().unit(StringName("spatial.fabric.%s.component.00" % feature.stable_id))
		if not program.recipe(unit.recipe_id).has_tag(&"native_width_gabled_bay"): continue
		for x: float in [-1.8,-.3]:
			for y: float in [.3,2.8,3.3]:
				# Native plaster is recessed behind its timber face. Cross the
				# complete measured wall depth, without reaching the opposite wall.
				var start := unit.transform()*Vector3(x,y,-2.85)
				var end := unit.transform()*Vector3(x,y,-2.1)
				var closed := false
				for i in range(0,faces.size(),3):
					if Geometry3D.segment_intersects_triangle(start,end,faces[i],faces[i+1],faces[i+2]) != null:
						closed = true
						break
				assert_true(closed,"%s actual native rear wall/roof closure at %s,%s" % [feature.stable_id,x,y])


func test_complete_backing_is_centred_in_each_facade_orientation() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var recipe := program.recipe(&"outcrop.blue")
	for yaw in 4:
		for width in [2,4,6]:
			var origin := Vector3i(7,6,-8)
			var room := WarrenRoomStamp.new(&"parent",&"parcel",&"tower",origin,yaw,2,false,false)
			for x in range(-width/2,width/2):
				for y in 2:
					room.private_cells.append(FabricRecipe.transform_cell(Vector3i(x,y,-2),origin,yaw))
			var misaligned := origin + FabricRecipe.transform_direction(Vector3i.RIGHT,yaw)
			var facing := FabricRecipe.transform_direction(Vector3i.BACK,yaw)
			var aligned := WarrenSpatialFeatureSolver._align_room_backing(recipe,misaligned,yaw,room,facing)
			assert_false(aligned.is_empty())
			if aligned.is_empty(): continue
			assert_eq(aligned.origin,origin,"Centre the two-cell opening across the complete parent facade")
			# A hole at either height cannot be hidden by a bounding-box overlap.
			for y in 2:
				var missing := FabricRecipe.transform_cell(Vector3i(-1,y,-2),origin,yaw)
				room.private_cells.erase(missing)
				assert_true(WarrenSpatialFeatureSolver._align_room_backing(recipe,misaligned,yaw,room,facing).is_empty(),
					"Reject an incomplete parent wall")
				room.private_cells.append(missing)
