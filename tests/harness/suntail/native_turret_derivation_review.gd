extends "res://tests/harness/pure_village_lineup.gd"
const Oracle = preload("res://tests/fixtures/native_prefab_reconstruction.gd")


func _run() -> void:
	get_root().size = Vector2i(1400, 1100)
	var doc: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://tests/fixtures/native_house16c_derivation.json")
	)
	var stage := Node3D.new()
	root.add_child(stage)
	_light(stage)
	var generated: Node3D
	if OS.get_cmdline_user_args().has("--baked"):
		generated = _baked()
	else:
		var reference: Node3D = (
			load("res://assets/PureVillage/Models/Houses/House_16c.glb").instantiate()
		)
		generated = Oracle.instantiate(doc, reference)
		reference.free()
	stage.add_child(generated)
	if OS.get_cmdline_user_args().has("--site"):
		await _shoot(stage, Vector3(0, 5, 7), Vector3(-.5, 2.5, -3.5), "turret-ground-entry", 60)
	var box := _aabb(generated)
	var target := box.get_center()
	await _shoot(stage, target + Vector3(1, .35, 1) * box.size.length(), target, "house16c-front")
	await _shoot(stage, target + Vector3(-1, .35, -1) * box.size.length(), target, "house16c-back")
	quit()


func _baked() -> Node3D:
	var args := OS.get_cmdline_user_args()
	var extra := int(args[args.find("--extra-storeys") + 1]) if args.has("--extra-storeys") else 0
	var parts := (
		preload("res://scripts/terrain/features/villages/grammar/PureVillageTurretHouse.gd")
		. derive(extra)
	)
	var root := Node3D.new()
	var catalog := EnvironmentCatalog.load_default()
	var cache := EnvironmentRenderCache.new(catalog)
	var payload := EnvironmentInstancePayload.new()
	var site_pose := Transform3D.IDENTITY
	if args.has("--site"):
		var site := (
			preload("res://scripts/terrain/features/villages/grammar/NativeTurretSite.gd")
			. place(catalog, extra, 2.0, Vector3.ZERO, Vector3.BACK)
		)
		assert(site.ok, site.reason)
		parts = site.parts
		site_pose = site.pose
	for index in parts.size():
		var part: Dictionary = parts[index]
		var pose: Transform3D = site_pose * part.transform
		payload.add(
			StringName(part.asset_id), pose, Color.WHITE, StringName("turret.%d" % index), true
		)
	assert(cache.prepare(payload.asset_ids()))
	for id in payload.asset_ids():
		for pose: Transform3D in payload.batches[id].transforms:
			for piece: EnvironmentVisualPiece in cache.visual(id).pieces:
				var mesh := MeshInstance3D.new()
				mesh.mesh = piece.mesh
				mesh.material_override = piece.material_override
				mesh.transform = pose * piece.local_transform
				root.add_child(mesh)
	var colliders := EnvironmentCollisionBuilder.commit(
		root, payload, cache, &"TurretHouseCollision"
	)
	assert(colliders == parts.size())
	print(
		"Baked turret house: ",
		payload.instance_count,
		" placements; ",
		colliders,
		" collision pieces"
	)
	return root
