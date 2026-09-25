extends GutTest

func test_embedded_bay_centres_on_complete_parent_panels_in_every_orientation() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	for theme in ["blue", "orange", "amber"]:
		var recipe := program.recipe(StringName("outcrop.embedded."+theme))
		for yaw in 4:
			for width in [2,4,6]:
				var origin := Vector3i(7,6,-8)
				var room := WarrenRoomStamp.new(&"parent",&"parcel",&"tower",origin,yaw,2,false,false)
				for x in range(-width/2,width/2):
					for y in 2:
						room.private_cells.append(FabricRecipe.transform_cell(Vector3i(x,y,-1),origin,yaw))
				var facing := FabricRecipe.transform_direction(Vector3i.BACK,yaw)
				var result := WarrenSpatialFeatureSolver._align_room_backing(recipe,origin,yaw,room,facing)
				assert_false(result.is_empty())
				if result.is_empty(): continue
				var unit_pose := FabricRecipe.lattice_transform(result.origin,yaw)
				var face: Dictionary = recipe.placements.filter(func(p): return p.id == &"bay.face")[0]
				var relative: Vector3 = FabricRecipe.lattice_transform(origin,yaw).affine_inverse()*unit_pose*face.transform.origin
				# Parent panels start at the footprint's lower edge and span two
				# 1.5 m cells; their centres are halfway between those cell centres.
				var panel_index: float = (relative.x / 1.5 + float(width)/2.0 - .5)/2.0
				assert_almost_eq(panel_index,roundf(panel_index),.0001,"Bay replaces a panel centre, never the building corner or an inter-panel joint")
				assert_gte(relative.x-0.75,(-float(width)/2.0-.5)*1.5+.1)
				assert_lte(relative.x+0.75,(float(width)/2.0-.5)*1.5-.1)
				assert_eq(recipe.room_backing_cells.size(),4,"Both columns and both heights require real parent wall")

func test_photo_bays_replace_windows_with_closed_native_backing() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var spatial := frozen.spatial(frozen.read("res://docs/qa/2026-09-13-manual/07-platform/current-source.txt"),program)
	var fabric := spatial.compiled_fabric_cache()
	var checked := 0
	var photographed := false
	for feature: WarrenFeatureReservation in spatial.features:
		if feature.kind != &"facade_bay": continue
		var bay := fabric.unit(StringName("spatial.fabric.%s.component.00" % feature.stable_id))
		if not program.recipe(bay.recipe_id).has_tag(&"embedded_oriel"): continue
		photographed = photographed or StringName(feature.audit.annex_room_id) == &"spatial.maze_bridge_end.02.01.room01"
		var parent := fabric.unit(StringName("spatial.fabric.%s" % feature.audit.annex_room_id))
		var centre := bay.transform()*Vector3(-.75,0,-.75)
		var matches := 0
		for placement: Dictionary in program.recipe(parent.recipe_id).placements:
			if parent.suppressed_placement_ids.has(StringName(placement.id)): continue
			var pose: Transform3D = parent.transform()*placement.transform
			if pose.basis.z.normalized().dot(bay.transform().basis.z) < .99: continue
			var delta := pose.origin-centre
			if absf(delta.dot(bay.transform().basis.x)) > .001 or absf(delta.y) > .001: continue
			if absf(delta.dot(bay.transform().basis.z)) > .75: continue
			matches += 1
			assert_true(".wall.wood.plain." in String(placement.asset_id),"The centered bay must replace the underlying shutter/window")
		assert_eq(matches,1,"One complete parent wall panel owns the bay")
		checked += 1
	assert_gt(checked,0)
	assert_true(photographed,"Retain the exact photographed bay parent")
	gut.p("PHOTO_BAY_COUNT %d / features %d / rooms %d" % [checked,spatial.features.size(),fabric.units.size()])

func test_missing_backing_cannot_be_hidden_by_a_centred_bay() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var recipe := program.recipe(&"outcrop.embedded.blue")
	for yaw in 4:
		var origin := Vector3i(7,6,-8)
		var room := WarrenRoomStamp.new(&"parent",&"parcel",&"tower",origin,yaw,2,false,false)
		for x in [-1,0]:
			for y in 2:
				room.private_cells.append(FabricRecipe.transform_cell(Vector3i(x,y,-1),origin,yaw))
		var facing := FabricRecipe.transform_direction(Vector3i.BACK,yaw)
		for cell: Vector3i in room.private_cells.duplicate():
			room.private_cells.erase(cell)
			assert_true(WarrenSpatialFeatureSolver._align_room_backing(recipe,origin,yaw,room,facing).is_empty())
			room.private_cells.append(cell)

func test_backing_phase_preserves_existing_balcony_clearance() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var spatial := WarrenVolumetricSolver.solve(12, {}, program, WarrenVillageScaleProfile.for_id(&"grand"))
	assert_not_null(spatial, WarrenVolumetricSolver.last_failure)
