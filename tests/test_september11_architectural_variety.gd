extends GutTest

func test_photographed_facades_use_available_supported_bays() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var spatial := frozen.spatial(frozen.read("res://tests/fixtures/september11-floating-source.txt"), program)
	var bay_owners: Dictionary = {}
	var corners := 0
	for feature: WarrenFeatureReservation in spatial.features:
		if feature.kind == &"facade_bay":
			bay_owners[StringName(feature.audit.annex_source_parcel_id)] = true
		if feature.kind == &"balcony" and bool(feature.audit.get("balcony_wraparound",false)):
			corners += 1
	assert_gt(bay_owners.size(), 2,
		"The photographed village has clear supported bay candidates beyond its two-skywalk-derived cap")
	assert_gt(corners,0,"The complete lower room is a real knee bearing, not an unrelated obstacle")
	assert_gt(int(spatial.compiled_fabric_cache().audit.dormered_roof_unit_count),1,
		"Exposed lower-house crowns must retain feasible dormers too")
	assert_eq(WarrenSpatialFabricCompiler.validation_errors(
		spatial.compiled_fabric_cache()), PackedStringArray())
	_check_corner_native_contacts(spatial,program)


func _check_corner_native_contacts(spatial: WarrenSpatialPlan,
		program: SettlementFabricProgram) -> void:
	var plan := spatial.compiled_fabric_cache()
	var payload := SettlementFabricAssembler.payload(plan)
	var catalog := EnvironmentCatalog.load_default()
	for feature: WarrenFeatureReservation in spatial.features:
		if feature.kind != &"balcony" or not String(feature.audit.balcony_recipe_id).begins_with("balcony.corner."):
			continue
		var lower_ids: Dictionary = {}
		for building: WarrenBuildingVolume in spatial.buildings:
			for room: WarrenRoomStamp in building.room_records:
				for cell: Vector3i in feature.audit.balcony_bearing_contact_cells:
					if room.private_cells.has(cell):
						lower_ids[StringName("spatial.fabric.%s" % room.stable_id)] = true
		var lower_faces := PackedVector3Array()
		for asset: StringName in payload.batches:
			var batch: Dictionary = payload.batches[asset]
			for index in batch.ids.size():
				var owner := StringName(String(batch.ids[index]).get_slice("/",0))
				if not lower_ids.has(owner):
					continue
				lower_faces.append_array(_faces(catalog,asset,batch.transforms[index]))
		var unit := plan.unit(StringName("spatial.fabric.%s.component.00" % feature.stable_id))
		var recipe := plan.recipe(unit.recipe_id)
		var floor_faces := PackedVector3Array()
		for placement: Dictionary in recipe.placements:
			if String(placement.id).begins_with("floor."):
				floor_faces.append_array(_faces(catalog,placement.asset_id,unit.transform()*placement.transform))
		var contacts := 0
		for placement: Dictionary in recipe.placements:
			if not String(placement.id).begins_with("support.knee."):
				continue
			var stock := program.module_program.contract(placement.asset_id).visual_bounds
			var transform: Transform3D = unit.transform()*placement.transform
			var axis := transform.basis.y.normalized()
			for end in 2:
				var point := transform*Vector3(stock.get_center().x,
					stock.position.y if end == 0 else stock.end.y,stock.get_center().z)
				var touches := _segment_hits(lower_faces,point-axis*.20,point+axis*.20) \
					if end == 0 else _inside_native_floor(floor_faces,point)
				assert_true(touches,
					"%s/%s end %d contacts actual wall/floor triangles" % [feature.stable_id,placement.id,end])
				contacts += 1
		assert_eq(contacts,10)


func _faces(catalog: EnvironmentCatalog, asset: StringName, transform: Transform3D) -> PackedVector3Array:
	var visual: EnvironmentVisual = load(catalog.descriptor(asset).visual_path)
	var out := PackedVector3Array()
	for piece: EnvironmentVisualPiece in visual.pieces:
		out.append_array(transform*piece.local_transform*EnvironmentBakeGeometry.triangle_faces(piece.mesh))
	return out


func _segment_hits(faces: PackedVector3Array, start: Vector3, end: Vector3) -> bool:
	for index in range(0,faces.size(),3):
		if Geometry3D.segment_intersects_triangle(start,end,faces[index],faces[index+1],faces[index+2]) != null:
			return true
	return false


func _inside_native_floor(faces: PackedVector3Array, point: Vector3) -> bool:
	# A knee head embedded inside a slab need not cross its boundary along a
	# short axial ray. Measure the actual slab's lower/upper triangles at this
	# X/Z and require the head to lie between them, rather than accepting a gap.
	var low := INF
	var high := -INF
	for index in range(0,faces.size(),3):
		var hit: Variant = Geometry3D.segment_intersects_triangle(point-Vector3.UP,
			point+Vector3.UP,faces[index],faces[index+1],faces[index+2])
		if hit is Vector3:
			low = minf(low,(hit as Vector3).y)
			high = maxf(high,(hit as Vector3).y)
	return high > low and point.y >= low-.001 and point.y <= high+.001


func test_private_corner_walkout_can_share_two_real_walls_without_occupying_them() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	for side: int in [-1, 1]:
		var recipe := program.recipe(StringName("balcony.corner.%s.blue" %
			("left" if side < 0 else "right")))
		assert_not_null(recipe, "A private corner walkout needs complete native construction")
		if recipe == null:
			continue
		for yaw in 4:
			var grid := WarrenSpatialGrid.new(Vector3i(-8,-4,-8),Vector3i(16,8,16))
			var walls: Array[Vector3i] = []
			for x: int in [-side, 0]:
				for z: int in [-1, -2]:
					for y in range(-1, 2):
						walls.append(FabricRecipe.transform_cell(Vector3i(x,y,z),Vector3i.ZERO,yaw))
			var tx := grid.begin_transaction(&"fixture")
			assert_true(tx.assign_use(walls,WarrenSpatialGrid.Use.PRIVATE_VOLUME,&"house"))
			assert_true(tx.commit())
			var body := WarrenSpatialFeatureSolver._feature_recipe_cells(recipe,Vector3i.ZERO,yaw)
			assert_true(WarrenVolumetricSolver._skywalk_body_fits_grid(grid,body),
				"Corner floor and headroom must remain outside the parent room")
			assert_true(WarrenSpatialFeatureSolver._balcony_supports_attach_to_parent(
				grid,recipe,Vector3i.ZERO,yaw,&"house",
				FabricRecipe.transform_direction(Vector3i.BACK,yaw)),
				"Both supported wall edges must coexist with the complete L deck")
			assert_true(recipe.socket(&"stair.low").is_empty(),
				"The private walkout must not invent a public staircase")


func test_tight_terminal_crowns_offer_dormers_without_changing_the_roof_seam() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	for kind: StringName in [&"tower",&"slim",&"row"]:
		for theme: StringName in [&"blue",&"orange"]:
			var plain := program.recipe(StringName("roof.terminal.tight.%s.%s" % [kind,theme]))
			for hand: StringName in [&"left",&"right"]:
				var decorated := program.recipe(StringName("roof.terminal.tight.%s.%s.dormer.%s" % [kind,theme,hand]))
				assert_not_null(decorated,"Tight eaves must not automatically erase a feasible dormer")
				if decorated == null:
					continue
				assert_true(decorated.has_tag(&"dormer"))
				for placement: Dictionary in plain.placements:
					assert_true(decorated.placements.has(placement),
						"Every native roof piece, transform and seam remains identical")
