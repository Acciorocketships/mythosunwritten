extends "res://tests/harness/pure_village_lineup.gd"
const CORNER := preload("res://scripts/terrain/features/villages/kit/KitCornerTowers.gd")
const HOST := preload("res://scripts/terrain/features/villages/kit/KitTowerHostFit.gd")
const TOWER := preload("res://scripts/terrain/features/villages/kit/KitTowerAssembly.gd")
const UNION := preload("res://scripts/terrain/features/villages/kit/KitRoofMeshUnion.gd")


func _run() -> void:
	get_root().size = Vector2i(1400, 1000)
	var kit := (
		(
			preload("res://scripts/terrain/features/villages/kit/PureVillageBuildingKit.gd")
			. roof_study()
		)
		if OS.get_cmdline_user_args().has("--pure")
		else SuntailBuildingKit.create()
	)
	var args := OS.get_cmdline_user_args()
	if args.has("--palette"):
		preload("res://scripts/terrain/features/villages/kit/TownRoofPalette.gd").apply(kit,StringName(args[args.find("--palette")+1]))
	var catalog := EnvironmentCatalog.load_default()
	if args.has("--frame"):
		catalog = preload("res://scripts/terrain/features/villages/kit/TownFramePalette.gd").study_catalog(catalog, StringName(args[args.find("--frame")+1]))
	var cache := EnvironmentRenderCache.new(catalog)
	var mass := BuildingMass.new()
	mass.stable_id = &"kit.corner"
	mass.seed = 10
	var levels := 1 if OS.get_cmdline_user_args().has("--low") else 3
	for level in levels:
		var band := level * 2
		mass.add_storey(
			band, BuildingMass.rect_cells(Rect2i(0, 0, 4, 3)), BuildingMass.MATERIAL_TIMBER
		)
	mass.add_roof(Rect2i(0, 0, 4, 3), 0, levels * 2, &"blue")
	mass.roofs[0]["union_index"] = 0
	var candidate := CORNER.propose(
		mass,
		kit,
		catalog,
		[],
		[],
		[],
		Callable(),
		func(_column: Vector2i, band: int) -> bool: return band == 0,
		{},
		args.has("--corbelled")
	)
	assert(not candidate.is_empty())
	preload("res://scripts/terrain/features/villages/kit/KitTowerPalette.gd").apply(candidate)
	HOST.apply(mass, candidate.host_plan)
	var parts := BuildingKitAssembler.new(kit).assemble(mass)
	HOST.fit_parts(parts, candidate, kit, catalog)
	var core: Array = FileAccess.open(candidate.cap_core_path, FileAccess.READ).get_var()
	var cuts := TOWER.placed_cutters(core, candidate.pose * candidate.parts[-1].transform)
	for part: Dictionary in parts:
		if int(part.get("roof_index", -1)) < 0:
			continue
		part["clip_volumes"] = cuts
	var payload := EnvironmentInstancePayload.new()
	UNION.append_prepared(parts, UNION.prepare(mass.roofs, [], kit), Transform3D.IDENTITY, payload)
	for index in candidate.parts.size():
		var part: Dictionary = candidate.parts[index]
		payload.add(
			part.asset_id,
			candidate.pose * part.transform,
			Color.WHITE,
			StringName("tower.%d" % index),
			true
		)
	var stage := Node3D.new()
	get_root().add_child(stage)
	_light(stage)
	var building := Node3D.new()
	stage.add_child(building)
	assert(cache.prepare(payload.asset_ids()))
	var queue := FeatureCommitQueue.new(cache)
	queue.enqueue(Vector2i.ZERO, 1, building, payload)
	while queue.pending_count() > 0:
		queue.drain(100000, 100000, 100000)
		await process_frame
	var target: Vector3 = candidate.pose.origin + Vector3.UP * (levels * 1.5 + 1.5)
	await _shoot(
		stage, target + candidate.pose.basis * Vector3(12, 5, 20), target, "corner-front", 55
	)
	await _shoot(
		stage, target + candidate.pose.basis * Vector3(12, 15, 18), target, "corner-above", 55
	)
	var join: Vector3 = candidate.pose.origin + Vector3.UP * (levels * 3)
	await _shoot(stage, join + candidate.pose.basis * Vector3(5, 1, 7), join, "corner-junction", 60)
	if args.has("--corbelled"):
		await _shoot(stage,candidate.pose.origin+candidate.pose.basis*Vector3(0,1,5),
			candidate.pose.origin,"corbel-seat",60)
		var centre: Vector3 = candidate.pose.origin+Vector3.UP*2
		await _shoot(stage,centre+candidate.pose.basis*Vector3(0,3,14),centre,"corbel-both-faces",55)
	print("CORNER_GALLERY_DONE ", candidate.pose)
	quit()
