extends SceneTree
## Diagnostic for the October 1 photo town. Production never reads photo pins.
const FROZEN := preload("res://tests/fixtures/frozen_maze_source.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var seed_value := 1260018864828801968
	var source := WarrenMazeSitePlanner.plan(seed_value, {},
		WarrenVillageScaleProfile.select(seed_value), &"", false)
	var spatial := FROZEN.spatial(source, program)
	var fabric := spatial.compiled_fabric_cache()
	var built := KitVillageBuildings.build(spatial, fabric, SuntailBuildingKit.create())
	print("PROFILE size=", WarrenVillageScaleProfile.select(seed_value).size)
	for roof: Dictionary in built.roofs:
		print("ROOF ", roof)
	for cell: Vector3i in spatial.route_floor_cells:
		if cell.x >= -3 and cell.x <= 8 and cell.z >= -3 and cell.z <= 8:
			print("ROUTE ", cell, " kind=", fabric.surface_plan.kind_at(cell))
	for mesh: Dictionary in fabric.surface_plan.mesh_payloads:
		if bool(mesh.get("is_transition", false)):
			print("FLIGHT ", mesh.stable_id, " span=", mesh.get("pending_guard_span"),
				" cells=", mesh.get("claim_cells"))
	print("AUDIT ", built.roof_audit)
	quit()
