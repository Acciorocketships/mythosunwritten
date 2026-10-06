extends SceneTree
## Actual character traversal on collision compiled from native architecture.
const Site = preload("res://scripts/terrain/features/villages/grammar/NativeHouseSite.gd")
const Recipe = preload("res://scripts/terrain/features/villages/grammar/NativeHouseRecipe.gd")
const Compiler = preload("res://scripts/terrain/features/villages/grammar/NativeGrammarCompiler.gd")


class WalkController:
	extends CharacterController
	var direction := Vector2.ZERO

	func get_move_vector(_character: CharacterBody3D, _delta: float) -> Vector2:
		return direction


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var catalog := EnvironmentCatalog.load_default()
	var cache := EnvironmentRenderCache.new(catalog)
	var results: Array[Dictionary] = []
	for case: Dictionary in [
		{"scale": 1.0, "seed": 31, "yaw": 0.0},
		{"scale": 2.0, "seed": 31, "yaw": PI * .5},
		{"scale": 2.0, "seed": 8, "yaw": PI},
		{"scale": 2.0, "seed": 11, "yaw": PI * 1.5},
	]:
		var scale_value: float = 2.0 if args.has("--recipe") else case.scale
		var stage := Node3D.new()
		root.add_child(stage)
		var site := Site.cross(
			catalog,
			2,
			1,
			case.seed,
			scale_value,
			Vector3(40, 3, -28),
			Basis(Vector3.UP, case.yaw) * Vector3.BACK
		)
		if args.has("--street"):
			site = Site.street(
				catalog,
				2,
				case.seed,
				scale_value,
				Vector3(40, 3, -28),
				Basis(Vector3.UP, case.yaw) * Vector3.BACK,
				args.has("--rear-jetty")
			)
		if args.has("--turret"):
			site = (
				preload("res://scripts/terrain/features/villages/grammar/NativeTurretSite.gd")
				. place(
					catalog,
					case.seed % 2,
					scale_value,
					Vector3(40, 3, -28),
					Basis(Vector3.UP, case.yaw) * Vector3.BACK,
					args.has("--recipe")
				)
			)
		if args.has("--arcade"):
			site = (
				preload("res://scripts/terrain/features/villages/grammar/NativeArcadeSite.gd")
				. place(
					catalog,
					1 + case.seed % 2,
					"Window_1_2",
					scale_value,
					Vector3(40, 3, -28),
					Basis(Vector3.UP, case.yaw) * Vector3.BACK
				)
			)

		assert(site.ok, site.reason)
		var payload: EnvironmentInstancePayload
		var collision_parent := stage
		if args.has("--recipe"):
			var recipe := Recipe.cross(catalog, &"native.walk", 2, 1, case.seed)
			if args.has("--street"):
				recipe = Recipe.street(catalog, &"native.walk", 2, case.seed, args.has("--rear-jetty"))
			if args.has("--turret"):
				recipe = Recipe.turret(catalog, &"native.walk", case.seed % 2)
			if args.has("--arcade"):
				recipe = Recipe.arcade(catalog, &"native.walk", 1 + case.seed % 2, "Window_1_2")
			assert(recipe != null)
			var fabric := preload("res://tests/fixtures/native_house_plan.gd").build(
				recipe, catalog, roundi(case.yaw / (PI * .5))
			)
			payload = SettlementFabricAssembler.payload(fabric)
			collision_parent = Node3D.new()
			stage.add_child(collision_parent)
			collision_parent.scale = VillageWorldScale.frame_scale()
			for route_index in range(1, site.entry_route.size()):
				site.entry_route[route_index] += Vector3.UP * VillageWorldScale.GROUND_DATUM_GUARD
		else:
			var compiled := Compiler.compile(
				site.parts, catalog, site.pose, &"entry.walk", site.envelope.grow(.001)
			)
			assert(compiled.ok, compiled.reason)
			payload = compiled.payload
		assert(cache.prepare(payload.asset_ids()))
		EnvironmentCollisionBuilder.commit(collision_parent, payload, cache, &"House")
		var ground := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(100, .2, 100)
		shape.shape = box
		shape.position = site.arrival - Vector3.UP * .1
		ground.add_child(shape)
		stage.add_child(ground)
		var player := (
			(load("res://characters/character.tscn") as PackedScene).instantiate()
			as CharacterBody3D
		)
		var controller := WalkController.new()
		player.controller = controller
		player.set_physics_process(false)
		root.add_child(player)
		player.set_physics_process(false)
		assert(player.body_model_root != null)
		await physics_frame
		await physics_frame
		for reverse in [false, true]:
			var route: Array = site.entry_route.duplicate()
			if reverse:
				route.reverse()
			var start: Vector3 = route.pop_front()
			var target: Vector3 = route.pop_front()
			player.global_position = start + Vector3.UP * .1
			player.velocity = Vector3.ZERO
			controller.direction = Vector2.ZERO
			for tick in 30:
				await physics_frame
				player._physics_process(1.0 / 60)
			var passed := false
			for tick in 600:
				var delta := Vector2(
					target.x - player.global_position.x, target.z - player.global_position.z
				)
				if (
					delta.length() < .2
					and player.is_on_floor()
					and absf(player.position.y - target.y) < .5
				):
					if route.is_empty():
						passed = true
						break
					target = route.pop_front()
					continue
				controller.direction = delta.normalized() * .6
				await physics_frame
				player._physics_process(1.0 / 60)
			var result := {
				"scale": scale_value,
				"recipe": args.has("--recipe"),
				"seed": case.seed,
				"yaw": case.yaw,
				"reverse": reverse,
				"passed": passed,
				"end": str(player.position),
				"target": str(target)
			}
			results.append(result)
			print("NATIVE_ENTRY_WALK ", result)
		player.queue_free()
		stage.queue_free()
		await process_frame
	var output: String = (
		args[args.find("--output") + 1] if args.has("--output") else "/tmp/native-entry-walk.json"
	)
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(results, "  "))
	var passed := true
	for result in results:
		passed = passed and result.passed
	quit(0 if passed else 1)
