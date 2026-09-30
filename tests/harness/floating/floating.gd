extends SceneTree
const USE := ["OUT", "ALLOC", "PUB_AIR", "DAY_AIR", "PRIV", "STRUCT", "SERVICE"]
func _init() -> void: call_deferred("_run")
func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var spatial := WarrenVolumetricSolver.generate(int(a[0]), {}, program, WarrenVillageScaleProfile.for_id(StringName(a[1])))
	var fabric := spatial.compiled_fabric_cache()
	var built := KitVillageBuildings.build(spatial, fabric, SuntailBuildingKit.create())
	var audit := KitFloatingMassAudit.audit(spatial, fabric, built.masses)
	var grid := spatial.grid
	for c: Vector3i in audit.floating_storey_cells:
		var line := "FLOAT %s world=%s retained=%s own=%s" % [c, Basis.from_scale(VillageWorldScale.frame_scale()) * (Vector3(c) * 1.5), fabric.retained_terrace_cells.has(c), grid.owner_name_at(c)]
		for y in range(c.y - 1, c.y + 4):
			var p := Vector3i(c.x, y, c.z)
			line += " | %d:%s/%s" % [y, USE[grid.use_at(p)], grid.owner_name_at(p)]
		print(line)
	for mass: BuildingMass in built.masses:
		if String(mass.stable_id).begins_with("kit.retained") or String(mass.stable_id).begins_with("kit.tunnel"):
			for s: Dictionary in mass.storeys:
				for c: Vector3i in audit.floating_storey_cells:
					if (s.cells as Dictionary).has(Vector2i(c.x, c.z)) and int(s.floor_band) == c.y:
						print("  in ", mass.stable_id, " storey band=", s.floor_band, " bands=", s.get("bands", 2))
	quit()
