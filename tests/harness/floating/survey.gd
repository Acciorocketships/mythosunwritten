extends SceneTree
## -- CITY:PROFILE,... : floating-mass audit per town (KitFloatingMassAudit).
func _init() -> void: call_deferred("_run")
func _run() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var total := 0
	for job in OS.get_cmdline_user_args()[0].split(","):
		var parts := job.split(":")
		var started := Time.get_ticks_msec()
		var spatial := WarrenVolumetricSolver.generate(int(parts[0]), {}, program, WarrenVillageScaleProfile.for_id(StringName(parts[1])))
		if spatial == null:
			print("SURVEY ", job, " FAILED ", WarrenVolumetricSolver.last_failure)
			continue
		var fabric := spatial.compiled_fabric_cache()
		var built := KitVillageBuildings.build(spatial, fabric, SuntailBuildingKit.create())
		var audit := KitFloatingMassAudit.audit(spatial, fabric, built.masses)
		total += int(audit.count)
		print("SURVEY ", job, " crowns=", audit.unborne_crown_cells.size(), " floating=", audit.floating_storey_cells.size(), " skywalks=", audit.incomplete_skywalks, " ms=", Time.get_ticks_msec() - started)
	print("SURVEY_TOTAL ", total)
	quit()
