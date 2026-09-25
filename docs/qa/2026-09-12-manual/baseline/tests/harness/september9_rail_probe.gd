extends SceneTree
func _init() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var spatial := frozen.spatial(frozen.read("res://tests/fixtures/september9-east-source.txt"),program)
	var fabric := spatial.compiled_fabric_cache()
	var frame := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*2),Vector3(238.5,8.08,-365.5))
	var report := {"contacts":[],"guards":[]}
	for spec: Dictionary in VillageWarrenFabricSolver.terrain_contact_specs(spatial,fabric):
		var geometry := VillageWarrenFabricSolver.terrain_contact_local_geometry(spec)
		report.contacts.append({"spec":str(spec),"local_geometry":str(geometry),
			"start":str(frame*geometry.inner_centre),"end":str(frame*geometry.stair_end),"outer":str(frame*geometry.outer_centre)})
	for guard: Dictionary in fabric.surface_plan.guard_segments:
		var a: Vector3 = frame*guard.a
		var b: Vector3 = frame*guard.b
		if minf(a.distance_to(Vector3(251,10.3,-344.9)),b.distance_to(Vector3(251,10.3,-344.9)))<10:
			report.guards.append({"a":str(a),"b":str(b),"record":str(guard)})
	FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	quit()
