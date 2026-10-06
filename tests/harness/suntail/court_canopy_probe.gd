extends SceneTree
## Finished native courtyard trees, after building and public-headroom clearance.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var cities := (
		args[args.find("--cities") + 1]
		if args.has("--cities")
		else "13:grand,83:grand,43:grand,101:large,31:large,7:standard,8:grand,9:grand"
	)
	var output := (
		args[args.find("--output") + 1] if args.has("--output") else "/tmp/court-canopy.json"
	)
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	var rows: Array[Dictionary] = []
	for city: String in cities.split(","):
		var bits := city.split(":")
		var spatial := WarrenVolumetricSolver.generate(
			int(bits[0]), {}, program, WarrenVillageScaleProfile.for_id(StringName(bits[1]))
		)
		var row := {"city": city, "trees": []}
		if spatial == null:
			row.failure = WarrenVolumetricSolver.last_failure
		else:
			var fabric := spatial.compiled_fabric_cache()
			var payload := preload("res://tests/harness/suntail/kit_town_review.gd").town_payload(
				spatial, fabric, false
			)
			for asset: StringName in payload.batches:
				var batch: Dictionary = payload.batches[asset]
				for i in batch.ids.size():
					if not String(batch.ids[i]).begins_with("maze-plaza-centre/"):
						continue
					var pose: Transform3D = batch.transforms[i]
					var box: AABB = pose * catalog.descriptor(asset).measured_aabb
					row.trees.append(
						{
							"asset": asset,
							"height": box.size.y,
							"origin": str(pose.origin),
							"basis": str(pose.basis)
						}
					)
		rows.append(row)
		print("COURT_CANOPY ", row)
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(rows, "  "))
	quit()
