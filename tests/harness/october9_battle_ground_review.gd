extends RefCounted
## Run in cliff_site_review centered at (-192, 0, 960), radius 1.
## All positions are ray-grounded; unloaded anchors are reported, never photographed.
const Features = preload("res://scripts/terrain/heightfield/LandformFeatures.gd")
var _space: PhysicsDirectSpaceState3D
var _excluded: Array[RID] = []
var _evidence: Array = []


func run(review: Node) -> void:
	_space = review.get_world_3d().direct_space_state
	for body: StaticBody3D in review.find_children(
		"DressingCollision", "StaticBody3D", true, false
	):
		_excluded.append(body.get_rid())
	var old: Array[Dictionary] = review._views.duplicate()
	review._views.clear()
	# Photo 6: its Z coordinate is 914.2, not the later review's 1150.
	var original := Vector3(-274.1, 63.9, 914.2)
	var old_crosshair := Vector3(-162.1, 33.6, 879.8)
	var hit := _ground(Vector2(original.x, original.z))
	if not hit.is_empty():
		var player: Vector3 = hit.position
		var crosshair := old_crosshair + Vector3.UP * (player.y - original.y)
		var pivot := player + Vector3.UP * CameraMouseView.PIVOT_HEIGHT
		var delta := crosshair - pivot
		var pitch := atan2(-delta.y, Vector2(delta.x, delta.z).length())
		var camera := ReviewCam.solve_cam(
			player,
			crosshair,
			CameraMouseView.BOOM_LENGTH * cos(pitch),
			CameraMouseView.PIVOT_HEIGHT + CameraMouseView.BOOM_LENGTH * sin(pitch),
			CameraMouseView.PIVOT_HEIGHT
		)
		camera = _clear_boom(pivot, camera)
		review._views.append(
			{
				"id": "valley_original_direction",
				"position": camera,
				"target": pivot,
				"fov": 75.0,
				"player": player
			}
		)
		_evidence.append(
			{
				"id": "valley_original_direction",
				"ground": str(player),
				"camera": str(camera),
				"target": str(pivot)
			}
		)
	else:
		_evidence.append({"id": "valley_original_direction", "error": "ground not loaded"})
	var candidates: Array[Dictionary] = []
	for z in range(4, 7):
		for x in range(-2, 1):
			var f: Dictionary = Features.local_candidate(2697992464, Vector2i(x, z))
			if not f.is_empty():
				candidates.append(f)
	candidates.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return a.pos.distance_to(Vector2(-274, 914)) < b.pos.distance_to(Vector2(-274, 914))
	)
	var chosen: Dictionary = {}
	for f: Dictionary in candidates:
		var kind: String = "hollow" if f.hollow else "ridge"
		if chosen.has(kind):
			continue
		var anchor: Vector2
		var target: Vector2
		if f.hollow:
			anchor = f.pos + Vector2(f.offset, -55).rotated(f.angle)
			target = f.pos + Vector2(f.offset, 45).rotated(f.angle)
		else:
			anchor = f.pos + f.nodes[1].rotated(f.angle)
			target = f.pos + f.nodes[0].rotated(f.angle)
		if _add_view(review, kind + "_ground", anchor, target):
			chosen[kind] = true
			_evidence.append(
				{"kind": kind, "feature_position": str(f.pos), "height": f.height, "angle": f.angle}
			)
			var a: Vector2 = f.pos + Vector2(-100, -65).rotated(f.angle)
			_add_view(review, kind + "_approach", a, f.pos)
	await review._capture_all(52)
	review._views = old
	(
		FileAccess
		. open(review._output_dir + "/battle-ground-review.json", FileAccess.WRITE)
		. store_string(JSON.stringify(_evidence, "  "))
	)
	print("BATTLE_GROUND_REVIEW ", JSON.stringify(_evidence))


func _add_view(review: Node, id: String, anchor: Vector2, target: Vector2) -> bool:
	var a := _ground(anchor)
	var b := _ground(target)
	if a.is_empty() or b.is_empty():
		_evidence.append(
			{"id": id, "error": "ground not loaded", "anchor": str(anchor), "target": str(target)}
		)
		return false
	var at: Vector3 = a.position
	var toward: Vector3 = b.position
	var camera := at + Vector3.UP * 2.8
	var aim := toward + Vector3.UP * 1.5
	review._views.append({"id": id, "position": camera, "target": aim, "fov": 75.0, "player": at})
	_evidence.append(
		{
			"id": id,
			"ground": str(at),
			"ground_normal": str(a.normal),
			"camera": str(camera),
			"target": str(aim),
			"collider": str(a.collider.get_path())
		}
	)
	return true


func _ground(p: Vector2) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(p.x, 1000, p.y), Vector3(p.x, -500, p.y), 1
	)
	query.exclude = _excluded
	return _space.intersect_ray(query)


func _clear_boom(pivot: Vector3, eye: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(pivot, eye, 1)
	query.exclude = _excluded
	var hit := _space.intersect_ray(query)
	if hit.is_empty():
		return eye
	return hit.position + (pivot - hit.position).normalized() * .5
