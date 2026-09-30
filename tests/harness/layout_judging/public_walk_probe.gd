extends SceneTree
## Public-walk dead-end probe for one town.
##   godot --headless --path . -s res://tests/harness/layout_judging/public_walk_probe.gd -- \
##     --city SEED:PROFILE [--at wx,wz]  (production centre/yaw frame, street axis +Z)
func _init() -> void: call_deferred("_run")

func _run() -> void:
	var city := 0
	var scale := &""
	var at := Vector2.INF
	var centre := Vector2.ZERO
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		match args[i]:
			"--city":
				var parts := args[i + 1].split(":")
				city = int(parts[0])
				scale = StringName(parts[1]) if parts.size() > 1 else &""
			"--at":
				var p := args[i + 1].split(",")
				at = Vector2(float(p[0]), float(p[1]))
			"--centre":
				var c := args[i + 1].split(",")
				centre = Vector2(float(c[0]), float(c[1]))
	var profile := WarrenVillageScaleProfile.select(city) if scale == &"" \
		else WarrenVillageScaleProfile.for_id(scale)
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var plan := WarrenVolumetricSolver.generate(city, {}, program, profile)
	if plan == null:
		print("FAIL ", WarrenVolumetricSolver.last_failure)
		quit(1)
		return
	var fabric := plan.compiled_fabric_cache()
	var report := PublicWalkAudit.audit(fabric, plan)
	print("AUDIT ", report.summary)
	var source: WarrenMazeSourcePlan = plan.source_volume.mass_context.get(&"maze_source_plan")
	var ex := source.excavation
	print("ROUTE ", ex.route)
	print("SPINE_TRANSITIONS ", ex.transitions.map(func(t): return [t.from, t.to, t.kind]))
	for lane: Dictionary in ex.lanes:
		print("LANE anchor=", lane.anchor, " cells=", lane.cells, " kind=", lane.get("feature_kind", &""))
	print("LOOPS ", ex.loop_edges.map(func(t): return [t.from, t.to]))
	print("PORTALS ", ex.portals, " stamps=", source.feature_stamps.map(func(s): return [s.kind, s.get("cells", []).size()]))
	print("BRIDGES ", ex.bridge_spans, " tunnels=", ex.tunnel_cells.size())
	for p in source.plots: print("PLOT ", p.id, " kind=", p.kind, " floor=", p.floor, " door=", p.door_walk, " cells=", p.cells, " access=", p.get("access_transition", {}))
	print("READDRESSED ", source.audit.get("flight_doors_readdressed", -1))
	print("SOURCE_AUDIT withdrawn=", source.audit.get("withdrawn_terminal_public_cells", []), " reclaimed=", source.audit.get("reclaimed_ground_street_cells", []))
	for leaf: Dictionary in report.dead_ends:
		var id := String(leaf.id)
		var macro := Vector3i()
		if id.begins_with("volume.walk."):
			macro = plan.source_volume.walk_cells[int(id.get_slice(".", 2))]
		var addressed := source.plots.filter(func(p): return p.door_walk == macro).map(func(p): return [p.id, p.kind, p.floor])
		var units := []
		for p in source.plots:
			if p.door_walk != macro: continue
			for u: FabricUnit in plan.compiled_fabric_cache().units:
				if String(u.stable_id).contains(String(p.id) + ".") and String(u.stable_id).contains("room00") and not String(u.stable_id).contains("roof"):
					units.append([u.stable_id, u.recipe_id])
		print("DEAD_END ", leaf, " macro=", macro, " on_route=", ex.route.has(macro), " plots=", addressed, " units=", units)
	if at.is_finite():
		var volume := plan.source_volume
		var entry := volume.entry_cell
		var entry_local := Vector3(entry.x * 3.0 + 0.75, 0.0, entry.z * 3.0 + 0.75)
		var delta := volume.primary_itinerary[1] - entry
		var inward := Vector3(delta.x, 0, delta.z).normalized()
		var yaw := snappedf(inward.signed_angle_to(Vector3(0, 0, 1), Vector3.UP), PI * 0.5)
		var basis := VillageWorldScale.production_basis(yaw)
		var contact := entry_local - inward * (3.0 + PathProgram.PATH_HALF_WIDTH / VillageWorldScale.PRODUCTION_UNIFORM_SCALE)
		var rc := basis * contact
		var frame := Transform3D(basis, Vector3(centre.x - rc.x, 0, centre.y - rc.z))
		var b := frame.basis
		print("FRAME %f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f" % [b.x.x, b.x.y, b.x.z, b.y.x, b.y.y, b.y.z, b.z.x, b.z.y, b.z.z, frame.origin.x, 12.0, frame.origin.z])
		var local := frame.affine_inverse() * Vector3(at.x, 0, at.y)
		var cell := Vector2i(floori(local.x / 1.5), floori(local.z / 1.5))
		print("AT world=", at, " local=", local, " fine=", cell, " yaw=", yaw)
		for node: PublicRealmNode in fabric.public_realm.nodes:
			for c: Vector3i in node.surface_cells:
				if absi(c.x - cell.x) <= 1 and absi(c.z - cell.y) <= 1:
					print("  NEAR node=", node.stable_id, " kind=", node.episode_kind, " cells=", node.surface_cells.size(), " cell=", c)
					break
	quit()
