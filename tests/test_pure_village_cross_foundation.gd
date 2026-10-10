extends "res://tests/test_pure_village_cross_roof.gd"
const House = preload("res://scripts/terrain/features/villages/grammar/PureVillageCrossHouse.gd")
const Foundation = preload(
	"res://scripts/terrain/features/villages/grammar/PureVillageCrossFoundation.gd"
)
const Native = preload("res://scripts/terrain/features/villages/grammar/PureVillageNativeRoof.gd")


func test_native_foundation_courses_cover_final_wall_bays_and_door_entry() -> void:
	for dimensions: Vector2i in [Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)]:
		var shell := House.derive(
			dimensions.x, dimensions.y, House.sample(31, dimensions.x, dimensions.y)
		)
		var parts := Foundation.derive(shell, dimensions.x, dimensions.y)
		var root := Node3D.new()
		add_child(root)
		var stairs := 0
		for part in parts:
			var instance: Node3D = load(Native.MODULE_ROOT + part.module + ".glb").instantiate()
			root.add_child(instance)
			instance.transform = part.transform
			if part.has("entry_for"):
				stairs += 1
		assert_eq(stairs, 1)
		var triangles := _triangles(root, false)
		for part in parts:
			if not String(part.module).begins_with("WallStone_Bottom"):
				continue
			var half: bool = String(part.module).contains("End_15")
			for x in [.25, .75, 1.25] if half else [-1.25, -.75, 0, .75, 1.25]:
				for y in [.3, .8, 1.2]:
					var front: Vector3 = part.transform * Vector3(x, y, .7)
					var back: Vector3 = part.transform * Vector3(x, y, -.7)
					assert_true(_hit(triangles, front, back), "Foundation gap at %s" % front)
		root.free()


func test_native_stair_treads_connect_ground_to_door_datum() -> void:
	var stair: Node3D = load(Native.MODULE_ROOT + "Stone_Stair_2.glb").instantiate()
	add_child(stair)
	stair.position = Vector3(0, -1.5, .1)
	var triangles := _triangles(stair, false)
	for x in [-.35, 0, .35]:
		var previous := .05
		for index in 19:
			var z := .2 + index * .1
			var height := -INF
			for vertex in range(0, triangles.size(), 3):
				var hit: Variant = Geometry3D.segment_intersects_triangle(
					Vector3(x, .5, z),
					Vector3(x, -2, z),
					triangles[vertex],
					triangles[vertex + 1],
					triangles[vertex + 2]
				)
				if hit != null:
					height = maxf(height, hit.y)
			assert_true(is_finite(height), "Missing tread at %s" % Vector2(x, z))
			assert_lte(height - previous, .08, "Treads descend away from door")
			assert_lte(previous - height, .4, "No excessive native step")
			if index == 0:
				assert_lt(absf(height), .16, "Top tread meets door datum")
			previous = height
		assert_lte(
			previous + 1.5, .4, "Exterior ground-to-first-tread rise meets the same step limit"
		)
	stair.free()


func test_native_entry_risers_remain_walkable_at_production_scale() -> void:
	var player_script = preload("res://characters/character.gd")
	for world_scale: float in [1.0, 2.0]:
		var shell := House.derive(2, 1, House.sample(31, 2, 1))
		var foundation := Foundation.derive(shell, 2, 1, world_scale)
		var door := Transform3D.IDENTITY
		for wall in shell:
			if String(wall.module).begins_with("Door_"):
				door = wall.transform
		for part in foundation:
			if not part.has("entry_for"):
				continue
			var stair: Node3D = load(Native.MODULE_ROOT + part.module + ".glb").instantiate()
			add_child(stair)
			# Inspect in door-local world metres, including the real exterior ground.
			stair.transform = (
				Transform3D(
					Basis.IDENTITY.scaled(Vector3.ONE * world_scale), Vector3.UP * 1.5 * world_scale
				)
				* door.affine_inverse()
				* part.transform
			)
			var triangles := _triangles(stair, false)
			var run := 3.0 if world_scale == 2.0 else 2.0
			for x in [-.35, 0, .35]:
				var previous := 0.0
				for index in range(int((run - .1) / .025) + 1):
					var z := .1 * world_scale + run - index * .025
					var height := -INF
					for vertex in range(0, triangles.size(), 3):
						var hit: Variant = Geometry3D.segment_intersects_triangle(
							Vector3(x, 4, z),
							Vector3(x, -.1, z),
							triangles[vertex],
							triangles[vertex + 1],
							triangles[vertex + 2]
						)
						if hit != null:
							height = maxf(height, hit.y)
					assert_true(is_finite(height), "Continuous entry support")
					assert_lte(
						height - previous,
						player_script.DEFAULT_MAX_STEP_HEIGHT,
						"Actual native riser must remain within the player's step height"
					)
					previous = height
				assert_lt(absf(previous - 1.5 * world_scale), .1, "Stair meets the doorway")
			stair.free()
