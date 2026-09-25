extends SceneTree

func _init() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var spatial := frozen.spatial(frozen.read("res://docs/qa/2026-09-13-manual/04-path/source.txt"),program)
	var fabric := spatial.compiled_fabric_cache()
	var town := Transform3D(Basis.from_scale(Vector3(-2,2,-2)),Vector3(-214.5,8.08,-944.5))
	print("P07_CLAIM ",fabric.surface_plan._claims.get("5:2:8",{}))
	var report := {"transitions":[],"walls":[]}
	for transition: WarrenVolumeTransition in spatial.source_volume.transitions:
		if not transition.is_vertical(): continue
		var ends := WarrenTransitionSurfaceBuilder._span_endpoints(transition)
		var a: Vector3 = town*ends.start
		var b: Vector3 = town*ends.end
		if a.distance_to(Vector3(-225.8,14.1,-977.8))<15:
			report.transitions.append({"id":str(transition.stable_id),"kind":transition.kind,"from":str(a),"to":str(b)})
	for kind in PublicRealmSurfacePlan.SurfaceKind.size():
		for cell: Vector3i in fabric.surface_plan.cells_for_kind(kind):
			var p := town*(Vector3(cell)*FabricRecipe.CELL_SIZE)
			if p.distance_to(Vector3(-225.8,14.1,-977.8))<14:
				report.walls.append({"kind":kind,"cell":str(cell),"world":str(p)})
	FileAccess.open("res://docs/qa/2026-09-13-manual/07-platform/route.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	quit()
