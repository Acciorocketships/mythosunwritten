extends Node3D

## Phase-0 structural physics gate. It sweeps the canonical player capsule
## through each reviewed doorway metric in the actual baked collision. Broad
## facade scans produce false openings through windows/eaves and can miss a
## usable door by continuing into furniture; this probe asks the stronger fact
## planning relies on: the declared outside-to-just-inside crossing is clear.
const SAMPLE_STEP := 0.10
const LATERAL_SCAN := 1.5
const OUTSIDE_DISTANCE := 2.0
const FLOOR_CLEARANCE := 0.005

var _catalog: EnvironmentCatalog
var _cache: EnvironmentRenderCache
var _program: VillageProgram


func _ready() -> void:
	_catalog = EnvironmentCatalog.load_default()
	assert(_catalog != null)
	_program = VillageProgram.compile({}, _catalog)
	assert(_program != null)
	_cache = EnvironmentRenderCache.new(_catalog)
	var assets: Array[StringName] = []
	for asset_id: StringName in _program.referenced_asset_ids:
		if _program.spec_for_asset(asset_id) != null:
			assets.append(asset_id)
	assert(_cache.prepare(assets))
	_run.bind(assets).call_deferred()


func _run(assets: Array[StringName]) -> void:
	var report: Array[Dictionary] = []
	var failed := false
	for asset_id: StringName in assets:
		var body := _collision_body(asset_id)
		add_child(body)
		await get_tree().physics_frame
		var result := _probe(asset_id)
		report.append(result)
		failed = failed or not bool(result.accepted)
		body.queue_free()
		await get_tree().physics_frame
	print(JSON.stringify(report, "  "))
	get_tree().quit(1 if failed else 0)


func _collision_body(asset_id: StringName) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = String(asset_id).replace(".", "_")
	var visual := _cache.visual(asset_id)
	for collision: EnvironmentCollisionPiece in visual.collisions:
		var node := CollisionShape3D.new()
		node.shape = collision.shape
		node.transform = collision.local_transform
		body.add_child(node)
	return body


func _probe(asset_id: StringName) -> Dictionary:
	var spec := _program.spec_for_asset(asset_id)
	var entrance := spec.entrance_local
	var outward := spec.entrance_outward
	var tangent := Vector2(-outward.y, outward.x)
	var probe_bottom_y := spec.entrance_floor_local_y + FLOOR_CLEARANCE
	var clear_centres := PackedFloat32Array()
	var offset := -LATERAL_SCAN
	while offset <= LATERAL_SCAN + 0.001:
		var start := entrance + outward * OUTSIDE_DISTANCE + tangent * offset
		if _capsule_sweep_clear(start, -outward \
				* (OUTSIDE_DISTANCE \
				+ VillageAssetSpec.ENTRANCE_INTERIOR_DEPTH), probe_bottom_y):
			clear_centres.append(offset)
		offset += SAMPLE_STEP
	var intervals := _intervals(clear_centres)
	var centre_fraction := _capsule_sweep_fraction(
		entrance + outward * OUTSIDE_DISTANCE,
		-outward * (OUTSIDE_DISTANCE \
		+ VillageAssetSpec.ENTRANCE_INTERIOR_DEPTH), probe_bottom_y)
	var declared_clear := centre_fraction >= 0.9999
	var containing_width := 0.0
	for interval: Dictionary in intervals:
		if float(interval.centre_min) <= 0.001 \
				and float(interval.centre_max) >= -0.001:
			containing_width = float(interval.estimated_aperture_width)
	var accepted := declared_clear \
		and containing_width + SAMPLE_STEP >= TraversalEnvelope.MIN_APERTURE_WIDTH
	return {
		"asset_id": String(asset_id),
		"planning_asset_id": String(spec.asset_id),
		"entrance_local": [entrance.x, entrance.y],
		"outward": [outward.x, outward.y],
		"probe_bottom_y": probe_bottom_y,
		"outside_distance": OUTSIDE_DISTANCE,
		"inside_distance": VillageAssetSpec.ENTRANCE_INTERIOR_DEPTH,
		"declared_centre_clear": declared_clear,
		"declared_centre_safe_fraction": centre_fraction,
		"containing_aperture_width": containing_width,
		"minimum_aperture_width": TraversalEnvelope.MIN_APERTURE_WIDTH,
		"clear_intervals": intervals,
		"accepted": accepted,
	}


func _capsule_sweep_clear(start_xz: Vector2, motion_xz: Vector2,
		bottom_y: float) -> bool:
	return _capsule_sweep_fraction(start_xz, motion_xz, bottom_y) >= 0.9999


func _capsule_sweep_fraction(start_xz: Vector2, motion_xz: Vector2,
		bottom_y: float) -> float:
	var capsule := CapsuleShape3D.new()
	capsule.radius = TraversalEnvelope.CAPSULE_RADIUS
	capsule.height = TraversalEnvelope.CAPSULE_HEIGHT
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(Basis.IDENTITY, Vector3(start_xz.x,
		bottom_y \
			+ TraversalEnvelope.CAPSULE_HEIGHT * 0.5, start_xz.y))
	query.motion = Vector3(motion_xz.x, 0.0, motion_xz.y)
	query.collision_mask = 1
	var result := get_world_3d().direct_space_state.cast_motion(query)
	return float(result[0]) if result.size() == 2 else 0.0


static func _intervals(samples: PackedFloat32Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if samples.is_empty():
		return out
	var start := samples[0]
	var previous := start
	for index in range(1, samples.size()):
		var value := samples[index]
		if value - previous > SAMPLE_STEP * 1.5:
			out.append(_interval(start, previous))
			start = value
		previous = value
	out.append(_interval(start, previous))
	return out


static func _interval(start: float, end: float) -> Dictionary:
	return {
		"centre_min": start,
		"centre_max": end,
		"estimated_aperture_width": end - start \
			+ TraversalEnvelope.capsule_diameter(),
	}
