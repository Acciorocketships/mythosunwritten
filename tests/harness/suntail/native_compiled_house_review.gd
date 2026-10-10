extends "res://tests/harness/pure_village_lineup.gd"
const House = preload("res://scripts/terrain/features/villages/grammar/PureVillageCrossHouse.gd")
const Foundation = preload(
	"res://scripts/terrain/features/villages/grammar/PureVillageCrossFoundation.gd"
)
const Compiler = preload("res://scripts/terrain/features/villages/grammar/NativeGrammarCompiler.gd")


func _run() -> void:
	get_root().size = Vector2i(1600, 900)
	var args := OS.get_cmdline_user_args()
	var entry_scale := (
		float(args[args.find("--entry-scale") + 1]) if args.has("--entry-scale") else 1.0
	)
	var catalog := EnvironmentCatalog.load_default()
	var cache := EnvironmentRenderCache.new(catalog)
	var choices := House.sample(31, 2, 1)
	var parts := House.derive(2, 1, choices)
	parts.append_array(Foundation.derive(parts, 2, 1, entry_scale))
	var compiled := Compiler.compile(
		parts,
		catalog,
		Transform3D.IDENTITY,
		&"review.house",
		AABB(Vector3(-30, -3, -30), Vector3(60, 30, 60))
	)
	assert(compiled.ok, compiled.reason)
	for mode: String in ["source", "baked"]:
		var stage := Node3D.new()
		get_root().add_child(stage)
		_light(stage)
		for child in stage.get_children():
			if child is MeshInstance3D:
				child.position.y = -1.5
		if mode == "source":
			for part in parts:
				var instance: Node3D = (
					load("res://assets/PureVillage/Models/Architecture/" + part.module + ".glb")
					. instantiate()
				)
				stage.add_child(instance)
				instance.transform = part.transform
		else:
			var payload: EnvironmentInstancePayload = compiled.payload
			assert(cache.prepare(payload.asset_ids()))
			for id in payload.asset_ids():
				var visual := cache.visual(id)
				for pose: Transform3D in payload.batches[id].transforms:
					for piece: EnvironmentVisualPiece in visual.pieces:
						var instance := MeshInstance3D.new()
						instance.mesh = piece.mesh
						instance.material_override = piece.material_override
						instance.transform = pose * piece.local_transform
						stage.add_child(instance)
			var collisions := EnvironmentCollisionBuilder.commit(
				stage, payload, cache, &"NativeHouseCollision"
			)
			assert(collisions == parts.size(), "Every module owns one baked collision piece")
			await physics_frame
			await physics_frame
			var door: Transform3D
			for part in parts:
				if String(part.module).begins_with("Door_"):
					door = part.transform
			var hits := 0
			for index in 10:
				var point := Vector3(0, 0, .2 + index * (.13 if entry_scale == 2.0 else .2))
				var query := PhysicsRayQueryParameters3D.create(
					door * (point + Vector3.UP * .5), door * (point - Vector3.UP * 2)
				)
				var hit := stage.get_world_3d().direct_space_state.intersect_ray(query)
				assert(not hit.is_empty(), "Baked stair collision missing")
				hits += 1
			print(
				(
					"Compiled native house: %d instances, %d colliders, %d stair ray hits"
					% [payload.instance_count, collisions, hits]
				)
			)
		await _shoot(stage, Vector3(18, 10, 20), Vector3(0, 3, 0), mode + "_front")
		await _shoot(stage, Vector3(-18, 10, -20), Vector3(0, 3, 0), mode + "_back")
		var entry := Transform3D.IDENTITY
		for part in parts:
			if String(part.module).begins_with("Door_"):
				entry = part.transform
		await _shoot(
			stage, entry * Vector3(3, 1.5, 5), entry * Vector3(0, -.4, .7), mode + "_entry"
		)
		stage.queue_free()
		await process_frame
	quit()
