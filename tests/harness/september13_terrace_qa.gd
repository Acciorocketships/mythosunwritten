extends "res://tests/harness/september13_path_qa.gd"

func _run() -> void:
	if _frozen and "--candidate" in OS.get_cmdline_user_args():
		var terraces := preload("res://scripts/terrain/field/CliffTerraces.gd")
		terraces.prepare()
		var world := _character.get_parent().get_parent()
		var meshes := {}
		for asset: StringName in terraces._pieces:
			if asset != terraces.ROCK: meshes[var_to_bytes(terraces._pieces[asset][0].get_faces())] = asset
		var replacements := []
		var seen := {}
		for node: MultiMeshInstance3D in world.find_children("*", "MultiMeshInstance3D", true, false):
			var asset: StringName = meshes.get(var_to_bytes(node.multimesh.mesh.get_faces()), &"")
			if asset == &"": continue
			var local: Transform3D = terraces._pieces[asset][1]
			for i in node.multimesh.instance_count:
				var pose := node.global_transform * node.multimesh.get_instance_transform(i) * local.affine_inverse()
				# The frozen scene also retains depth-view copies of native meshes.
				var key := [asset, pose]
				if seen.has(key): continue
				seen[key] = true
				var before := PackedVector3Array()
				var after := PackedVector3Array()
				terraces._append_faces(before, asset, pose)
				terraces._append_collision_faces(after, asset, pose)
				replacements.append({"before":before,"after":after})
		var replaced := 0
		for physical: CollisionShape3D in world.find_children("NativeTerraces", "CollisionShape3D", true, false):
			var original: PackedVector3Array = physical.shape.get_faces()
			var faces := PackedVector3Array()
			var index := 0
			while index < original.size():
				var found := false
				for replacement: Dictionary in replacements:
					var before: PackedVector3Array = replacement.before
					if index + before.size() > original.size() or original[index].distance_to(before[0]) > .001: continue
					var same := true
					for j in before.size():
						if original[index + j].distance_to(before[j]) > .001: same = false; break
					if not same: continue
					faces.append_array(replacement.after)
					index += before.size()
					replaced += 1
					found = true
					break
				if not found:
					faces.append_array(original.slice(index, index + 3))
					index += 3
			var shape := ConcavePolygonShape3D.new()
			shape.set_faces(faces)
			physical.shape = shape
		print("TERRACE_REPLAY_COLLISIONS replaced=", replaced, " candidates=", replacements.size(), " bodies=", world.find_children("NativeTerraces", "CollisionShape3D", true, false).size())
		assert(replaced > 0 and replaced == replacements.size())

	await super._run()

func _grass_enabled() -> bool:
	return true

class TerraceJumpController extends CharacterController:
	var direction := Vector2.ZERO
	var jumping := false
	func get_move_vector(_body: CharacterBody3D, _delta: float) -> Vector2:
		return direction
	func wants_jump(_body: CharacterBody3D, _delta: float) -> bool:
		return jumping

func _walk_corridor(_world: Node3D) -> void:
	var controller := TerraceJumpController.new()
	_character.controller = controller
	_camera.global_position = Vector3(910, 25, 1083)
	_camera.look_at(Vector3(901, 18, 1074))
	var rows := []
	for offset: float in [-1, 0, 1]:
		_character.global_position = Vector3(904, 16.03, 1074 + offset)
		_character.velocity = Vector3.ZERO
		controller.direction = Vector2.LEFT
		controller.jumping = false
		for tick in 40:
			await get_tree().physics_frame
			_character._physics_process(1.0 / 60)
		var start := _character.global_position
		var highest := start.y
		var contacts := 0
		var reached := false
		var trace := []
		for tick in 100:
			controller.jumping = tick == 0
			await get_tree().physics_frame
			_character._physics_process(1.0 / 60)
			highest = maxf(highest, _character.global_position.y)
			for c in _character.get_slide_collision_count():
				if _character.get_slide_collision(c).get_normal().y < -.05: contacts += 1
			trace.append({"tick":tick,"position":str(_character.global_position),"velocity":str(_character.velocity)})
			if _character.is_on_floor() and _character.global_position.y >= 19.78:
				reached = true
				break
		rows.append({"offset":offset,"start":str(start),"end":str(_character.global_position),
			"highest":highest,"ceiling_contacts":contacts,"reached":reached,"trace":trace})
		print("TERRACE_GAME_JUMP offset=",offset," reached=",reached," ceiling_contacts=",contacts," highest=",highest)
		await _shot("jump_%d" % int(offset))
	FileAccess.open(_output_dir.path_join("jump.json"),FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))

func _spots() -> Array:
	var poses: Array = JSON.parse_string(FileAccess.get_file_as_string("res://docs/qa/2026-09-13-manual/photo-poses.json"))
	var out := []
	for spot: Dictionary in poses:
		if String(spot.id) in ["P16", "P18", "P20"]:
			out.append([spot.id, "September terrace review", Vector3(spot.player[0], spot.player[1], spot.player[2]),
				Vector3(spot.crosshair[0], spot.crosshair[1], spot.crosshair[2])])
	return out

func _wait_for_site() -> bool:
	if not await super._wait_for_site(): return false
	var origin := Vector2(_spot[2].x, _spot[2].z)
	var started := Time.get_ticks_msec()
	var wanted: Array[Vector2i] = []
	for tile in GrassStreamer.desired_tiles(origin):
		if GrassStreamer.distance_to_tile(origin, tile) <= 38: wanted.append(tile)
	while true:
		var missing := 0
		for tile in wanted:
			if not _streamer._grass_streamer._built.has(tile): missing += 1
		if missing == 0: break
		if Time.get_ticks_msec() - started > 180000:
			push_error("Terrace grass review timed out: %d missing local tiles" % missing)
			return false
		await get_tree().create_timer(.25).timeout
	var roots := []
	for tile in wanted:
		var parent := GrassField.parent_chunk(tile)
		var sampling: GrassSamplingContext = _streamer._built[parent].get_meta(&"grass_sampling")
		var record: Dictionary = _streamer._grass_streamer._built[tile]
		if record.node == null: continue
		for node: MultiMeshInstance3D in record.node.find_children("*", "MultiMeshInstance3D", true, false):
			for i in node.multimesh.instance_count:
				var root := node.global_transform * node.multimesh.get_instance_transform(i).origin
				if root.y <= TerrainSurfaceField.surface_y(sampling.region, root.x, root.z) + .5: continue
				var support := GrassSupportSurfaces.at_point(sampling.supports, Vector2(root.x, root.z))
				if support.is_empty() or absf(root.y - float(support.y)) > .001: continue
				roots.append({"root": str(root), "support": support.support_id, "tile": str(tile)})
	assert(not roots.is_empty(), "The actual visual worker must publish grass on native ledges")
	FileAccess.open(_output_dir.path_join("grass-worker.json"), FileAccess.WRITE).store_string(JSON.stringify({
		"local_tiles": wanted.size(), "grass_wait_ms": Time.get_ticks_msec() - started,
		"roots": roots, "stats": _streamer._grass_streamer.stats()}, "  "))
	print("TERRACE_GAME_GRASS tiles=", wanted.size(), " ledge_roots=", roots.size())
	return true
