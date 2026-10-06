extends SceneTree


func _init() -> void:
	var seed_value := 83
	var profile := &"grand"
	var output := "/tmp/fortified-facades.json"
	var args := OS.get_cmdline_user_args()
	for i in range(args.size() - 1):
		match args[i]:
			"--seed":
				seed_value = int(args[i + 1])
			"--profile":
				profile = StringName(args[i + 1])
			"--output":
				output = args[i + 1]
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var spatial := WarrenVolumetricSolver.generate(
		seed_value, {}, program, WarrenVillageScaleProfile.for_id(profile)
	)
	if spatial == null:
		push_error(WarrenVolumetricSolver.last_failure)
		quit(1)
		return
	var kit := SuntailBuildingKit.create()
	var built := KitVillageBuildings.build(spatial, spatial.compiled_fabric_cache(), kit)
	var rows := []
	var catalog := EnvironmentCatalog.load_default()
	var contacts := (
		preload("res://scripts/terrain/features/villages/kit/KitFacadeRoofContacts.gd")
		. prepare(built.roofs, kit, built.roof_kits, built.walls)
	)
	var recess := preload("res://scripts/terrain/features/villages/kit/KitRetainingRecesses.gd")
	for part: Dictionary in built.placements:
		if (
			part.role != &"wall.fort"
			or not String(part.stable_id).begins_with("kit.platform-wall/")
		):
			continue
		var pose: Transform3D = part.transform
		var blockers := []
		var candidate: Dictionary = part.duplicate()
		if part.get("fortified_window", false):
			pass
		elif recess.replace(candidate, catalog, [], contacts):
			for component: AABB in contacts.frames[recess.WINDOW]:
				var box: AABB = candidate.transform * component
				for other: Dictionary in built.placements:
					if other == part:
						continue
					if box.intersects(
						other.transform * catalog.descriptor(other.asset_id).measured_aabb
					):
						blockers.append(
							{
								"id": other.stable_id,
								"role": other.role,
								"asset": other.asset_id,
								"at": other.transform.origin
							}
						)
		rows.append(
			{
				"blockers": blockers,
				"id": part.stable_id,
				"origin": pose.origin,
				"normal": pose.basis.z.normalized(),
				"scale": pose.basis.get_scale(),
				"window": part.get("fortified_window", false)
			}
		)
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(rows, "\t"))
	quit()
