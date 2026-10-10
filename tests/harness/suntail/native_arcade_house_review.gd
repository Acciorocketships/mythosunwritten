extends "res://tests/harness/pure_village_lineup.gd"
const HOUSE = preload("res://scripts/terrain/features/villages/grammar/PureVillageArcadeHouse.gd")
const ORACLE = preload("res://tests/fixtures/native_prefab_reconstruction.gd")


static func document(parts: Array[Dictionary]) -> Dictionary:
	var rows: Array[Dictionary] = []
	for part: Dictionary in parts:
		var t: Transform3D = part.transform
		var m := [
			t.basis.x.x,
			t.basis.x.y,
			t.basis.x.z,
			0,
			t.basis.y.x,
			t.basis.y.y,
			t.basis.y.z,
			0,
			t.basis.z.x,
			t.basis.z.y,
			t.basis.z.z,
			0,
			t.origin.x,
			t.origin.y,
			t.origin.z,
			1
		]
		rows.append(
			{
				"module": part.module,
				"module_source": part.module_source,
				"matrix": m,
				"materials": part.materials
			}
		)
	return {"complete": true, "parts": rows}


static func instantiate(parts: Array[Dictionary]) -> Node3D:
	var reference: Node3D = (
		load("res://assets/PureVillage/Models/Houses/StreetHouse_8c.glb").instantiate()
	)
	var extra := {}
	# Optional stock supplies its native hood material; the source house still
	# owns any common material names, preserving its coordinated wood palette.
	for part: Dictionary in parts:
		if part.module != "Window_5_2":
			continue
		var stock: Node3D = load("res://" + part.module_source).instantiate()
		for mesh: MeshInstance3D in stock.find_children("*", "MeshInstance3D", true, false):
			for surface in mesh.mesh.get_surface_count():
				var material := mesh.get_active_material(surface)
				extra[material.resource_name] = material
		stock.free()
	var result := ORACLE.instantiate(document(parts), reference, extra)
	reference.free()
	return result


static func instantiate_baked(parts: Array[Dictionary]) -> Node3D:
	var compiler = preload(
		"res://scripts/terrain/features/villages/grammar/NativeGrammarCompiler.gd"
	)
	var catalog := EnvironmentCatalog.load_default()
	var result := compiler.compile(
		parts,
		catalog,
		Transform3D.IDENTITY,
		&"arcade.review",
		AABB(Vector3.ONE * -100, Vector3.ONE * 200)
	)
	assert(result.ok, result.reason)
	var cache := EnvironmentRenderCache.new(catalog)
	var payload: EnvironmentInstancePayload = result.payload
	assert(cache.prepare(payload.asset_ids()))
	var house := Node3D.new()
	for id in payload.asset_ids():
		for pose: Transform3D in payload.batches[id].transforms:
			for piece: EnvironmentVisualPiece in cache.visual(id).pieces:
				var mesh := MeshInstance3D.new()
				mesh.mesh = piece.mesh
				mesh.material_override = piece.material_override
				mesh.transform = pose * piece.local_transform
				house.add_child(mesh)
	assert(
		(
			EnvironmentCollisionBuilder.commit(house, payload, cache, &"ArcadeCollision")
			== parts.size()
		)
	)
	return house


func _run():
	get_root().size = Vector2i(1600, 900)
	for spec: Array in [[1, "Window_1_2"], [2, "Window_5_2"]]:
		var count: int = spec[0]
		var stage := Node3D.new()
		root.add_child(stage)
		_light(stage)
		var parts := HOUSE.derive(count, spec[1])
		var house := (
			instantiate_baked(parts)
			if OS.get_cmdline_user_args().has("--baked")
			else instantiate(parts)
		)
		stage.add_child(house)
		for side in [-1, 1]:
			await _shoot(
				stage,
				Vector3(side * 20, 15, side * 24),
				Vector3(0, 7, 0),
				"upper%d_%s" % [count, "front" if side == 1 else "back"],
				50
			)
		stage.queue_free()
		await process_frame
	quit()


func _shoot(stage: Node3D, eye: Vector3, target: Vector3, name: String, fov := 50.0) -> void:
	var camera := Camera3D.new()
	camera.fov = fov
	stage.add_child(camera)
	camera.look_at_from_position(eye, target)
	camera.current = true
	for frame in 12:
		await process_frame
	# Native review must also capture when macOS suppresses automatic redraws.
	RenderingServer.force_draw(false)
	get_root().get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	camera.queue_free()
