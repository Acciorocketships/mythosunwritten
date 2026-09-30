extends SceneTree
## Prints the production world frame (kit_town_review --frame) of a town and the
## ReviewCam eye for an F3 photo.  -- CITY PROFILE CX CZ DATUM_Y [PX PY PZ CX CY CZ]
func _init() -> void: call_deferred("_run")
func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var plan := WarrenVolumetricSolver.generate(int(a[0]), {}, program, WarrenVillageScaleProfile.for_id(StringName(a[1])))
	var volume := plan.source_volume
	var entry := volume.entry_cell
	var entry_local := Vector3(entry.x * 3.0 + 0.75, 0.0, entry.z * 3.0 + 0.75)
	var delta := volume.primary_itinerary[1] - entry
	var inward := Vector3(delta.x, 0, delta.z).normalized()
	var yaw := snappedf(inward.signed_angle_to(Vector3(0, 0, 1), Vector3.UP), PI * 0.5)
	var basis := VillageWorldScale.production_basis(yaw)
	var contact := entry_local - inward * (3.0 + PathProgram.PATH_HALF_WIDTH / VillageWorldScale.PRODUCTION_UNIFORM_SCALE)
	var rc := basis * contact
	var o := Vector3(float(a[2]) - rc.x, float(a[4]), float(a[3]) - rc.z)
	print("FRAME %f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f" % [basis.x.x, basis.x.y, basis.x.z, basis.y.x, basis.y.y, basis.y.z, basis.z.x, basis.z.y, basis.z.z, o.x, o.y, o.z])
	if a.size() >= 11:
		var p := Vector3(float(a[5]), float(a[6]), float(a[7]))
		var c := Vector3(float(a[8]), float(a[9]), float(a[10]))
		var eye := ReviewCam.solve_cam(p, c)
		print("EYE %f,%f,%f TARGET %f,%f,%f" % [eye.x, eye.y, eye.z, p.x, p.y + 1.0, p.z])
	quit()
