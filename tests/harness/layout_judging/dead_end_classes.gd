extends SceneTree
## Why each remaining dead-end public node has no destination.
##   -- SEED:PROFILE [SEED:PROFILE ...]   (PROFILE may be `select`)
func _init() -> void: call_deferred("_run")

func _run() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var totals: Dictionary = {}
	for job in OS.get_cmdline_user_args():
		var seed_value := int(job.get_slice(":", 0))
		var scale := job.get_slice(":", 1)
		var profile := WarrenVillageScaleProfile.select(seed_value) if scale == "select" \
			else WarrenVillageScaleProfile.for_id(StringName(scale))
		var plan := WarrenVolumetricSolver.generate(seed_value, {}, program, profile)
		if plan == null:
			print("FAIL ", job, " ", WarrenVolumetricSolver.last_failure.left(200))
			continue
		var fabric := plan.compiled_fabric_cache()
		var source: WarrenMazeSourcePlan = plan.source_volume.mass_context.get(&"maze_source_plan")
		var report := PublicWalkAudit.audit(fabric, plan)
		var gates := {}
		for record in plan.audit.get("maze_uncomposed_parcels", []):
			gates[String(record.parcel_id).trim_prefix("parcel.maze.")] = String(record.gate) + ":" + String(record.detail).left(80)
		var composed := {}
		for b: WarrenBuildingVolume in plan.buildings:
			var id := String(b.stable_id)
			if id.contains("maze."):
				composed[id.substr(id.find("maze.") + 5).get_slice(".part", 0)] = true
		var closed := {}
		for u: FabricUnit in fabric.units:
			var id := String(u.stable_id)
			if id.contains("maze.") and fabric.recipe(u.recipe_id).entrances.is_empty() \
					and String(u.recipe_id).contains(".closed"):
				closed[id.substr(id.find("maze.") + 5).get_slice(".part", 0)] = true
		for dead: Dictionary in report.dead_ends:
			var node: PublicRealmNode = null
			for n: PublicRealmNode in fabric.public_realm.nodes:
				if n.stable_id == dead.id: node = n
			var macros := {}
			for c: Vector3i in node.surface_cells:
				macros[Vector3i(floori(c.x / 2.0), c.y, floori(c.z / 2.0))] = true
			var why := []
			for p in source.plots:
				if not macros.has(p.door_walk): continue
				var id := String(p.id)
				var cls := "deck" if p.kind == &"deck" else "uncomposed:" + String(gates.get(id, "?")) \
					if not composed.has(id) else "closed_facade" if closed.has(id) else "composed_open"
				why.append("%s(%s)" % [id, cls])
				var key := cls.get_slice(":", 0) + ":" + cls.get_slice(":", 1) if cls.begins_with("uncomposed") else cls
				totals[key] = int(totals.get(key, 0)) + 1
			if why.is_empty():
				totals["no_plot"] = int(totals.get("no_plot", 0)) + 1
			print("DEAD ", job, " ", dead.id, " cells=", dead.cells, " ", why)
	print("TOTALS ", totals)
	quit()
