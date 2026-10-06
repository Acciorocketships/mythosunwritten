extends "res://tests/harness/pure_village_lineup.gd"
## Native course assemblies, before deciding how to allocate their footprints.
## Half towers need a host wall; the back view deliberately exposes that join.

func _run() -> void:
	if OS.get_cmdline_user_args().has("--designed"):
		await _run_designed()
		return
	if OS.get_cmdline_user_args().has("--baked"):
		await _run_baked()
		return
	get_root().size = Vector2i(1400, 1000)
	var reports: Array = []
	for kind: String in ["round", "attached"]:
		var stage := Node3D.new()
		get_root().add_child(stage)
		_light(stage)
		var tower := Node3D.new()
		stage.add_child(tower)
		var parts: Array = []
		if kind == "round":
			parts = [
				["StoneTower_Middle1_30x30", 0.0],
				["StoneTower_Window_30x30", 3.0],
				["StoneTower_Window_30x30", 6.0],
				["Roof_Tower_1", 8.5],
			]
		else:
			parts = [
				["StoneHalfTower_Middle1_30x30", 0.125],
				["StoneHalfTower_Window_30x30", 3.0],
				["StoneTower_Window_30x30", 6.0],
				["Roof_Tower_1", 8.5],
			]
		var measured: Array = []
		var previous := AABB()
		for part: Array in parts:
			var node := (load(R + "Architecture/" + part[0] + ".glb") as PackedScene).instantiate()
			tower.add_child(node)
			node.position.y = float(part[1])
			var bound := _aabb(node)
			if measured.is_empty():
				assert(absf(bound.position.y) < 0.001, "The base must meet the ground.")
			else:
				assert(bound.position.y <= previous.end.y, "Native courses must overlap at the join.")
			previous = bound
			measured.append({"asset": part[0], "y": part[1],
				"min": [bound.position.x, bound.position.y, bound.position.z],
				"size": [bound.size.x, bound.size.y, bound.size.z]})
		var bounds := _aabb(tower)
		reports.append({"kind": kind, "parts": measured})
		var centre := bounds.get_center()
		await _shoot(stage, centre + Vector3(13, 2, 19), centre, kind + "-front")
		await _shoot(stage, centre + Vector3(-13, 2, -19), centre, kind + "-back")
		await _shoot(stage, Vector3(7, 5, 9), Vector3(0, 3, 0), kind + "-courses")
		stage.queue_free()
		await process_frame
	FileAccess.open(_out.path_join("assemblies.json"), FileAccess.WRITE).store_string(JSON.stringify(reports, "  "))
	quit()


func _run_baked() -> void:
	const TOWER := preload("res://scripts/terrain/features/villages/kit/KitTowerAssembly.gd")
	get_root().size = Vector2i(1400, 1000)
	var catalog := EnvironmentCatalog.load_default()
	var cache := EnvironmentRenderCache.new(catalog)
	for storeys in [2, 3]:
		for form: int in [TOWER.Form.ROUND, TOWER.Form.GROUNDED_HALF, TOWER.Form.CORBELLED_HALF]:
			var stage := Node3D.new()
			get_root().add_child(stage)
			_light(stage)
			var body := Node3D.new()
			stage.add_child(body)
			var payload := EnvironmentInstancePayload.new()
			var assembly := TOWER.parts(storeys, form)
			var base := 3.0 if form == TOWER.Form.CORBELLED_HALF else 0.0
			var offset := Transform3D(Basis.IDENTITY, Vector3.UP * base)
			for i in assembly.size():
				var part: Dictionary = assembly[i]
				payload.add(part.asset_id, offset * part.transform, Color.WHITE,
					StringName("tower.%d" % i), true)
			if form != TOWER.Form.ROUND:
				# A complete native host closes the attachment's otherwise open
				# rear, and carries the inward half of its upper round course.
				var height := base + TOWER.host_height(storeys, form)
				for floor_index in int(roundf(height / 3.0)):
					for x: float in [-1.0, 1.0]:
						payload.add(&"pure_village.wall.stone.plain",
							Transform3D(Basis.IDENTITY, Vector3(x, floor_index * 3.0, -0.03)),
							Color.WHITE, StringName("host.%d.%s" % [floor_index, x]), true)
						payload.add(&"pure_village.wall.stone.plain",
							Transform3D(Basis(Vector3.UP, PI), Vector3(x, floor_index * 3.0, -4.0)),
							Color.WHITE, StringName("host.back.%d.%s" % [floor_index, x]), true)
					for z: float in [-1.0, -3.0]:
						for side: int in [-1, 1]:
							payload.add(&"pure_village.wall.stone.plain",
								Transform3D(Basis(Vector3.UP, side * PI * 0.5), Vector3(side * 2.0, floor_index * 3.0, z)),
								Color.WHITE, StringName("host.side.%d.%s.%d" % [floor_index, z, side]), true)
				var kit := SuntailBuildingKit.create()
				for x: float in [-1.0, 1.0]:
					for z: float in [-1.0, -3.0]:
						payload.add(kit.asset(&"deck.board"),
							Transform3D(Basis.IDENTITY, Vector3(x, height, z)) * kit.anchor(&"deck.board"),
							Color.WHITE, StringName("host.bearing.%s.%s" % [x, z]), true)
			assert(payload.validate())
			assert(cache.prepare(payload.asset_ids()))
			var queue := FeatureCommitQueue.new(cache)
			queue.enqueue(Vector2i.ZERO, 1, body, payload)
			while queue.pending_count() > 0:
				queue.drain(100000, 100000, 100000)
				await process_frame
			var bounds := offset * TOWER.bounds(assembly, catalog)
			var centre := bounds.get_center()
			var label := "baked-%d-%d" % [form, storeys]
			await _shoot(stage, centre + Vector3(13, 2, 19), centre, label + "-front")
			await _shoot(stage, centre + Vector3(-13, 2, -19), centre, label + "-back")
			stage.queue_free()
			await process_frame
	quit()


func _run_designed() -> void:
	const HOST_FIT := preload("res://scripts/terrain/features/villages/kit/KitTowerHostFit.gd")
	const TOWER := preload("res://scripts/terrain/features/villages/kit/KitTowerAssembly.gd")
	const PURE := preload("res://scripts/terrain/features/villages/kit/PureVillageBuildingKit.gd")
	const UNION := preload("res://scripts/terrain/features/villages/kit/KitRoofMeshUnion.gd")
	var tower_data: Dictionary = FileAccess.open(TOWER.ROOF_GEOMETRY, FileAccess.READ).get_var()
	var tower_core: Array = FileAccess.open(TOWER.ROOF_CORE, FileAccess.READ).get_var()
	get_root().size = Vector2i(1400, 1000)
	var catalog := EnvironmentCatalog.load_default()
	var cache := EnvironmentRenderCache.new(catalog)
	for kit: BuildingKit in [SuntailBuildingKit.create(), PURE.roof_study()]:
		var count := 0
		for seed_value in range(1, 101):
			var designer := BuildingDesigner.new(kit)
			var mass := designer.design_standalone(seed_value)
			if mass.storeys.size() < 3 or mass.roofs.size() != 1: continue
			var top: Dictionary = mass.storeys[-1]
			var candidate := {}
			for slot: Dictionary in designer.slots_of(mass, top):
				var centre := designer._oriel_gable_centre(mass, slot, int(top.floor_band))
				if not centre.is_finite(): continue
				var pose := Transform3D(Basis(Vector3.UP, BuildingKitAssembler.yaw_for_dir(slot.dir)),
					Vector3(centre.x * kit.module_width, (int(top.floor_band) - 2) * kit.band_height(), centre.y * kit.module_width))
				for courses in [3, 2]:
					candidate = TOWER.fit(mass, kit, catalog, pose, courses, TOWER.Form.CORBELLED_HALF, Callable())
					if not candidate.is_empty(): break
				if not candidate.is_empty(): break
			if candidate.is_empty(): continue
			var host_plan := HOST_FIT.prepare(mass, kit, catalog, candidate)
			assert(not host_plan.is_empty(), "Supported study host must have a matching closed gable.")
			HOST_FIT.apply(mass, host_plan)
			for roof_index in mass.roofs.size():
				mass.roofs[roof_index]["union_index"] = roof_index
			var placements := BuildingKitAssembler.new(kit).assemble(mass)
			var omitted := HOST_FIT.fit_parts(placements, candidate, kit, catalog)
			print("TOWER_HOST_DECOR omitted=", omitted, " original=", mass.decor.size())
			var payload := EnvironmentInstancePayload.new()
			var roof_pose: Transform3D = candidate.pose * candidate.parts[-1].transform
			var cutters := TOWER.placed_cutters(tower_core, roof_pose)
			if OS.get_cmdline_user_args().has("--exact-roof-union"):
				cutters = TOWER.roof_cutters(tower_data[&"pure_village.tower.roof"], roof_pose)
			var context := UNION.prepare(mass.roofs, [], kit)
			for part: Dictionary in placements:
				if int(part.get("roof_index", -1)) < 0: continue
				var box: AABB = part.transform * catalog.descriptor(part.asset_id).measured_aabb
				var nearby: Array[Dictionary] = []
				for cutter: Dictionary in cutters:
					if box.grow(0.001).intersects(cutter.bounds): nearby.append(cutter)
				nearby.append_array(part.get("clip_volumes", []))
				part["clip_volumes"] = nearby
			var union_started := Time.get_ticks_msec()
			UNION.append_prepared(placements, context, Transform3D.IDENTITY, payload)
			print("TOWER_UNION ", kit.kit_id, "/", seed_value, " ms=", Time.get_ticks_msec() - union_started,
				" surfaces=", payload.surface_meshes.size(), " cutters=", cutters.size())
			assert(not payload.surface_meshes.is_empty(), "The study must exercise actual roof cuts.")
			for i in candidate.parts.size():
				var part: Dictionary = candidate.parts[i]
				payload.add(part.asset_id, candidate.pose * part.transform, Color.WHITE, StringName("tower.%d" % i), true)
			var stage := Node3D.new()
			get_root().add_child(stage)
			_light(stage)
			var building := Node3D.new()
			stage.add_child(building)
			assert(cache.prepare(payload.asset_ids()))
			var queue := FeatureCommitQueue.new(cache)
			queue.enqueue(Vector2i.ZERO, 1, building, payload)
			while queue.pending_count() > 0:
				queue.drain(100000, 100000, 100000)
				await process_frame
			var pose: Transform3D = candidate.pose
			var target := pose * Vector3(0, candidate.local_bounds.get_center().y, -1)
			var distance_scale := maxf(1.0, (candidate.bounds as AABB).size.y / 12.0)
			var label := "designed-%s-%d" % [kit.kit_id, seed_value]
			print("TOWER_HOST ", label, " pose=", pose, " bounds=", candidate.bounds)
			await _shoot(stage, target + pose.basis * Vector3(13, 4, 19) * distance_scale, target, label + "-front")
			await _shoot(stage, target + pose.basis * Vector3(-13, 5, -19) * distance_scale, target, label + "-back")
			var join_target := roof_pose * Vector3(0, 1.8, -0.3)
			await _shoot(stage, join_target + pose.basis * Vector3(6, 1.5, 8), join_target, label + "-join")
			stage.queue_free()
			await process_frame
			count += 1
			if count == 3: break
		assert(count == 3, "Need three independently generated supported host examples per kit.")
	quit()
