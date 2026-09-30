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
	for c: Vector3i in audit.unborne_crown_cells:
		var up := c + Vector3i.UP
		var down := c + Vector3i.DOWN
		print("CROWN ", c, " retained=", fabric.retained_terrace_cells.has(c), " own=", grid.owner_name_at(c), " use=", USE[grid.use_at(c)], " up=", USE[grid.use_at(up)], "/", grid.owner_name_at(up), " down=", USE[grid.use_at(down)], "/", grid.owner_name_at(down), " downfloor=", grid.face_claim(down, Vector3i.DOWN).get("kind", -1))
	quit()
