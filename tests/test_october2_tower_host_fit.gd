extends GutTest
const TOWER := preload("res://scripts/terrain/features/villages/kit/KitTowerAssembly.gd")
const HOST_FIT := preload("res://scripts/terrain/features/villages/kit/KitTowerHostFit.gd")

func _host() -> BuildingMass:
	var host := BuildingMass.new()
	for band in [0, 2, 4]:
		host.add_storey(band, BuildingMass.rect_cells(Rect2i(0, -3, 4, 3)), BuildingMass.MATERIAL_TIMBER)
	host.add_roof(Rect2i(0, -3, 4, 3), 1, 6, &"red")
	return host

func _candidate(host: BuildingMass, kit: BuildingKit, catalog: EnvironmentCatalog) -> Dictionary:
	return TOWER.fit(host, kit, catalog, Transform3D(Basis.IDENTITY, Vector3(4, 3, 0)),
		3, TOWER.Form.CORBELLED_HALF, Callable())

func test_changes_only_matched_gable_and_preserves_tighter_public_verge() -> void:
	var kit := SuntailBuildingKit.create()
	var catalog := EnvironmentCatalog.load_default()
	var host := _host()
	host.add_roof(Rect2i(6, -3, 4, 3), 1, 6, &"red")
	host.add_roof(Rect2i(0, -3, 4, 3), 0, 6, &"red")
	host.roofs[0].verge_max = 0.1
	var plan := HOST_FIT.prepare(host, kit, catalog, _candidate(host, kit, catalog))
	assert_false(plan.is_empty())
	assert_eq(plan.wings.size(), 1, "A compound's other parallel and perpendicular wings keep their roof ends.")
	HOST_FIT.apply(host, plan)
	assert_eq(host.roofs[0].verge_max, 0.1, "A tower cannot widen an existing public clearance.")
	assert_false(host.roofs[0].has("verge_min"))
	assert_false(host.roofs[1].has("verge_max"))
	assert_false(host.roofs[2].has("verge_max"))

func test_open_branch_and_door_reject_without_partial_host_changes() -> void:
	var kit := SuntailBuildingKit.create()
	var catalog := EnvironmentCatalog.load_default()
	var host := _host()
	var candidate := _candidate(host, kit, catalog)
	host.roofs[0].open_max = true
	assert_true(HOST_FIT.prepare(host, kit, catalog, candidate).is_empty())
	host.roofs[0].open_max = false
	host.storeys[1].openings[Vector3i(1, -1, 1)] = BuildingMass.OPENING_DOOR
	var before := host.storeys.duplicate(true)
	assert_true(HOST_FIT.prepare(host, kit, catalog, candidate).is_empty())
	assert_eq(host.storeys, before, "Failure preserves every original opening.")
	assert_false(host.roofs[0].has("verge_max"), "Failure cannot shorten a roof first.")

func test_only_intersecting_optional_dressing_is_removed() -> void:
	var kit := SuntailBuildingKit.create()
	var catalog := EnvironmentCatalog.load_default()
	var host := _host()
	var candidate := _candidate(host, kit, catalog)
	var parts: Array[Dictionary] = []
	for offset: float in [0.0, 20.0]:
		parts.append({"role": &"window_box", "asset_id": kit.asset(&"window_box"),
			"transform": Transform3D(Basis.IDENTITY, Vector3(4 + offset, 4, 0))})
	parts.append({"role": &"post.timber", "asset_id": kit.asset(&"post.timber"),
		"transform": Transform3D(Basis.IDENTITY, Vector3(4, 4, 0))})
	assert_eq(HOST_FIT.fit_parts(parts, candidate, kit, catalog), 1)
	assert_eq(parts.size(), 2)
	assert_eq(parts[0].transform.origin.x, 24.0, "Unrelated facade dressing survives.")
	assert_eq(parts[1].role, &"post.timber", "This helper must never silently remove structural pieces.")

func test_host_fitting_rotates_with_all_four_facades() -> void:
	var kit := SuntailBuildingKit.create()
	var catalog := EnvironmentCatalog.load_default()
	for dir in 4:
		var host := BuildingMass.new()
		for band in [0, 2, 4]:
			host.add_storey(band, BuildingMass.rect_cells(Rect2i(0, 0, 4, 4)), BuildingMass.MATERIAL_TIMBER)
		host.add_roof(Rect2i(0, 0, 4, 4), dir % 2, 6, &"red")
		var outward := Vector3(BuildingMass.DIRS[dir].x, 0, BuildingMass.DIRS[dir].y)
		var pose := Transform3D(Basis(Vector3.UP, BuildingKitAssembler.yaw_for_dir(dir)), Vector3(4, 3, 4) + outward * 4)
		var candidate := TOWER.fit(host, kit, catalog, pose, 3, TOWER.Form.CORBELLED_HALF, Callable())
		assert_false(candidate.is_empty())
		var plan := HOST_FIT.prepare(host, kit, catalog, candidate)
		assert_false(plan.is_empty())
		assert_eq(plan.wings[0], "verge_max" if dir < 2 else "verge_min")
		assert_gt(plan.openings.size(), 0)
		for opening: Dictionary in plan.openings:
			assert_eq(opening.edge.z, dir, "Only the tower's actual facade changes.")
		HOST_FIT.apply(host, plan)
		assert_eq(host.storeys[1].openings.size(), 2, "Only complete panels behind the tower lose their openings.")

func test_replaced_opening_loses_its_window_box_even_below_corbel() -> void:
	var kit := SuntailBuildingKit.create()
	var catalog := EnvironmentCatalog.load_default()
	var host := _host()
	host.decor.append({"kind": &"window_box", "centre": Vector2(1.5, 0), "dir": 1, "y": 0.0})
	host.decor.append({"kind": &"window_box", "centre": Vector2(0.5, 0), "dir": 1, "y": 0.0})
	host.decor.append({"kind": &"ivy", "centre": Vector2(1.5, 0), "dir": 1, "y": 0.0})
	var plan := HOST_FIT.prepare(host, kit, catalog, _candidate(host, kit, catalog))
	HOST_FIT.apply(host, plan)
	assert_eq(host.decor.size(), 2)
	assert_eq(host.decor[0].centre, Vector2(0.5, 0), "Adjacent unchanged window keeps its flowers.")
	assert_eq(host.decor[1].kind, &"ivy", "Plain walls can retain unrelated ivy.")

func test_eave_attachment_uses_source_cap_datum_and_keeps_native_overhang() -> void:
	var catalog := EnvironmentCatalog.load_default()
	for kit: BuildingKit in [SuntailBuildingKit.create(),preload("res://scripts/terrain/features/villages/kit/PureVillageBuildingKit.gd").roof_study()]:
		var host := BuildingMass.new()
		for band in [0,2,4]:
			host.add_storey(band,BuildingMass.rect_cells(Rect2i(0,0,4,4)),BuildingMass.MATERIAL_TIMBER)
		host.add_roof(Rect2i(0,0,4,4),0,6,&"red")
		var pose := Transform3D(Basis.IDENTITY,Vector3(4,0,8))
		var candidate := TOWER.fit(host,kit,catalog,pose,3,TOWER.Form.GROUNDED_HALF,
			Callable(),func(_cell: Vector2i,band: int)->bool:return band==0)
		assert_false(candidate.is_empty())
		candidate["attachment"] = &"eave"
		var plan := HOST_FIT.prepare(host,kit,catalog,candidate)
		assert_false(plan.is_empty(),"The native cap meets the roof along an eave, not just a gable")
		assert_eq(plan.wings[0],"")
		HOST_FIT.apply(host,plan)
		assert_false(host.roofs[0].has("verge_max"),"Eave joining does not shorten unrelated gables")
		assert_false(host.roofs[0].has("verge_min"))
		assert_gt(plan.openings.size(),0,"The shaft replaces overlapping host windows")
		candidate.pose.origin.y += TOWER.COURSE
		assert_true(HOST_FIT.prepare(host,kit,catalog,candidate).is_empty(),
			"The former elevated cap datum cannot be treated as an eave junction")
