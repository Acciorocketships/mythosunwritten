class_name PathProgram
extends RefCounted

const PATH_WIDTH := 4.0
const PATH_HALF_WIDTH := PATH_WIDTH * 0.5
# The future-village site keeps this compact validation footprint. Its path
# surface is a broad circular gathering place rather than a square stamp.
const NODE_SUPPORT_SIZE := 12.0
const PLAZA_RADIUS := 8.0
const PLAZA_SIZE := PLAZA_RADIUS * 2.0 # conservative rectangular reservation bound
# A bend's centreline follows a quarter circle. Offsetting that curve by half
# the path width rounds both the inner and outer edges at constant width.
const CORNER_RADIUS := PATH_WIDTH
const CORNER_INNER_RADIUS := CORNER_RADIUS - PATH_HALF_WIDTH
const CORNER_OUTER_RADIUS := CORNER_RADIUS + PATH_HALF_WIDTH
const JUNCTION_SIZE := CORNER_RADIUS * 2.0 # conservative reservation bound
const SUPER_CELLS := SettlementPlan.SUPER_CELLS
const NODE_MAX_SUPPORT_SPAN := 1.0
const ROUTE_VERTICAL_BUDGET_UNITS := 28
const ROUTE_TURN_COST := 2.0
const ROUTE_ROCKY_COST := 3.0
const ROUTE_BRIDGE_COST := 12.0
const BRIDGE_END_STEP_MAX := 0.4
const BRIDGE_BANK_SPAN_MAX := 2.0
const BRIDGE_WATER_SPREAD_MAX := 1.0
const BRIDGE_TERRAIN_GRADE_MAX := 12.0
const LOOP_EDGE_PROBABILITY := 0.18
const LAMP_KEEP_PROBABILITY := 0.9
const VILLAGE_GATE_MIN_STEPS := 4
const VILLAGE_GATE_SEARCH_STEPS := 12
const BIOME_GATE_VILLAGE_CLEARANCE := 144.0
const BIOME_GATE_MIN_SPACING := 96.0
const MAX_FEATURE_HALO := 1
const FIELD_CACHE_CAP := 192
const NODE_CACHE_CAP := 64
const BRIDGE_CACHE_CAP := 128
const ROUTE_CACHE_CAP := 64
const CONTEXT_CACHE_CAP := 96
const PLANNING_POINT_CACHE_CAP := 8192

# Path decision domains. SettlementPlan owns the independent site hashes, so
# changing lamp density cannot reshuffle sites or routes.
const SALT_ROUTE := 1657
const SALT_LOOP := 1777
const SALT_BRIDGE := 1879
const SALT_LAMP := 1993
const SALT_ARCH := 2089
const ASSET_IDS: Array[StringName] = [
	&"sfv.arch.001",
	&"sfv.arch.002",
	&"sfv.bridge.001",
	&"sfv.entrance_arch.001",
	&"sfv.light_pole.001",
]

var assets: Dictionary = {}
var referenced_asset_ids: Array[StringName] = []
var bridge: Dictionary = {}
var query_margin := 0.0
var shore_distance_limit := 0.0
var maximum_clearance := 0.0
var max_horizontal_footprint_radius := 0.0
var feature_halo := 0
var bridge_lookahead_cells := 0

static func compile(catalog: EnvironmentCatalog,
		authored: Dictionary = {}) -> PathProgram:
	if catalog == null:
		return _fail("PathProgram requires an environment catalogue")
	var data := _authored_metrics() if authored.is_empty() else authored.duplicate(true)
	var program := PathProgram.new()
	program.query_margin = float(data.get("query_margin", -1.0))
	program.shore_distance_limit = float(data.get("shore_distance_limit", -1.0))
	program.maximum_clearance = float(data.get("maximum_clearance", -1.0))
	if not _finite_non_negative(program.query_margin) \
			or not _finite_non_negative(program.shore_distance_limit) \
			or not _finite_non_negative(program.maximum_clearance):
		return _fail("PathProgram margins must be finite and non-negative")
	if program.query_margin + program.shore_distance_limit \
			> WaterField.FILL_MARGIN * WaterField.FILL_STEP - WaterContour.MARGIN:
		return _fail("PathProgram water query margin exceeds canonical fill coverage")
	var asset_data: Dictionary = data.get("assets", {})
	for asset_id: StringName in ASSET_IDS:
		var descriptor := catalog.descriptor(asset_id)
		if descriptor == null:
			return _fail("PathProgram asset is missing: %s" % asset_id)
		var required_tag := &"bridge" if asset_id == &"sfv.bridge.001" \
			else (&"lamp" if asset_id == &"sfv.light_pole.001" else &"arch")
		if not descriptor.tags.has(&"feature") or not descriptor.tags.has(required_tag):
			return _fail("PathProgram asset %s lacks required feature tags" % asset_id)
		if descriptor.tint_group != &"identity" or not descriptor.supports_instance_color:
			return _fail("PathProgram asset %s must preserve identity colour" % asset_id)
		if descriptor.collision_piece_count <= 0 or not _valid_aabb(descriptor.measured_aabb):
			return _fail("PathProgram asset %s lacks finite collision/bounds" % asset_id)
		if not asset_data.has(asset_id):
			return _fail("PathProgram asset %s lacks authored placement metrics" % asset_id)
		var metrics: Dictionary = (asset_data[asset_id] as Dictionary).duplicate(true)
		metrics["aabb"] = descriptor.measured_aabb
		metrics["asset_id"] = asset_id
		if not _validate_footprint_bounds(metrics):
			return null
		program.assets[asset_id] = metrics
		program.referenced_asset_ids.append(asset_id)

	program.bridge = program.assets[&"sfv.bridge.001"]
	if not _validate_bridge(program.bridge):
		return null
	for asset_id: StringName in [&"sfv.arch.001", &"sfv.arch.002",
			&"sfv.entrance_arch.001"]:
		if not _validate_arch(program.assets[asset_id]):
			return null
	if not _validate_lamp(program.assets[&"sfv.light_pole.001"]):
		return null
	program.max_horizontal_footprint_radius = 0.0
	for metrics: Dictionary in program.assets.values():
		var footprint: Rect2 = metrics.footprint
		for corner: Vector2 in [footprint.position,
				footprint.position + Vector2(footprint.size.x, 0.0),
				footprint.position + Vector2(0.0, footprint.size.y), footprint.end]:
			program.max_horizontal_footprint_radius = maxf(
				program.max_horizontal_footprint_radius, corner.length())
	program.feature_halo = int(ceil(program.max_horizontal_footprint_radius
		/ TerrainChunkMesher.CHUNK_WORLD))
	if program.feature_halo > MAX_FEATURE_HALO:
		return _fail("PathProgram footprint requires halo %d, maximum is %d" % [
			program.feature_halo, MAX_FEATURE_HALO])
	program.bridge_lookahead_cells = int(ceil((float(program.bridge.usable_span)
		+ float(program.bridge.dry_landing_total)) / WaterPlan.TILE))
	if program.bridge_lookahead_cells * WaterPlan.TILE > WaterPlan.PATH_QUERY_MAX:
		return _fail("PathProgram bridge look-ahead exceeds WaterPlan's query bound")
	program.referenced_asset_ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b))
	return program

static func _authored_metrics() -> Dictionary:
	return {
		# Leaves four metres of the canonical 30m water-context budget for
		# dressing's shoreline distance while still covering path predicates.
		"query_margin": 26.0,
		"shore_distance_limit": 0.0,
		"maximum_clearance": 2.0,
		"assets": {
			&"sfv.bridge.001": {
				"footprint": Rect2(Vector2(-2.82, -31.53), Vector2(5.64, 63.06)),
				"usable_span": 57.6,
				"dry_landing_total": 8.0,
				"deck_contacts": PackedVector3Array([
					Vector3(0.0, 0.18, -28.8), Vector3(0.0, 0.18, 28.8)]),
				"landing_samples": PackedVector3Array([
					Vector3(-2.2, 0.0, -30.0), Vector3(2.2, 0.0, -30.0),
					Vector3(-2.2, 0.0, 30.0), Vector3(2.2, 0.0, 30.0)]),
				"support_samples": PackedVector3Array([
					Vector3(-2.2, 0.0, -28.8), Vector3(2.2, 0.0, -28.8),
					Vector3(-2.2, 0.0, 28.8), Vector3(2.2, 0.0, 28.8)]),
				"lateral_offsets": PackedFloat32Array([-2.0, 0.0, 2.0]),
				"opening": 4.58,
				"underside_height": 0.0,
				"deck_height": 0.35,
				"dynamic_clearance": 0.8,
			},
			&"sfv.light_pole.001": {
				"footprint": Rect2(Vector2(-0.36, -1.36), Vector2(0.72, 2.72)),
				"arm_direction": Vector2.DOWN,
			},
			&"sfv.arch.001": {
				"footprint": Rect2(Vector2(-10.56, -3.86), Vector2(21.12, 7.72)),
				"opening": 15.8,
				"leg_centres": PackedVector2Array([Vector2(-9.1, 0.0), Vector2(9.1, 0.0)]),
			},
			&"sfv.arch.002": {
				"footprint": Rect2(Vector2(-10.56, -3.86), Vector2(21.12, 7.72)),
				"opening": 15.8,
				"leg_centres": PackedVector2Array([Vector2(-9.1, 0.0), Vector2(9.1, 0.0)]),
			},
			&"sfv.entrance_arch.001": {
				"footprint": Rect2(Vector2(-3.88, -0.26), Vector2(7.76, 0.52)),
				"opening": 5.96,
				"leg_centres": PackedVector2Array([Vector2(-3.4, 0.0), Vector2(3.4, 0.0)]),
			},
		},
	}

static func _validate_bridge(metrics: Dictionary) -> bool:
	if not _valid_footprint(metrics.get("footprint")) \
		or not _positive(metrics.get("usable_span")) \
		or not _positive(metrics.get("dry_landing_total")) \
		or not _positive(metrics.get("opening")) \
		or not _finite_non_negative(float(metrics.get("underside_height", -1.0))) \
		or not _positive(metrics.get("deck_height")) \
		or not _finite_non_negative(float(metrics.get("dynamic_clearance", -1.0))):
		return _fail_bool("Bridge metrics are missing, non-finite, or invalid")
	var bounds: AABB = metrics.aabb
	for field: String in ["deck_contacts", "landing_samples", "support_samples"]:
		var samples: PackedVector3Array = metrics.get(field, PackedVector3Array())
		var expected := 2 if field == "deck_contacts" else 0
		if samples.is_empty() or (expected > 0 and samples.size() != expected):
			return _fail_bool("Bridge %s has an invalid sample count" % field)
		for point: Vector3 in samples:
			if not _finite_vector3(point) or not bounds.grow(0.02).has_point(point):
				return _fail_bool("Bridge %s lies outside measured bounds" % field)
	var offsets: PackedFloat32Array = metrics.get("lateral_offsets", PackedFloat32Array())
	if offsets.is_empty():
		return _fail_bool("Bridge lateral offsets must not be empty")
	for offset: float in offsets:
		if not is_finite(offset):
			return _fail_bool("Bridge lateral offsets must be finite")
	return true

static func _validate_arch(metrics: Dictionary) -> bool:
	if not _valid_footprint(metrics.get("footprint")) or not _positive(metrics.get("opening")):
		return _fail_bool("Arch metrics are missing or invalid")
	var legs: PackedVector2Array = metrics.get("leg_centres", PackedVector2Array())
	return legs.size() == 2 or _fail_bool("Arch requires exactly two leg centres")

static func _validate_lamp(metrics: Dictionary) -> bool:
	if not _valid_footprint(metrics.get("footprint")):
		return _fail_bool("Lamp footprint is invalid")
	var arm: Vector2 = metrics.get("arm_direction", Vector2.ZERO)
	return is_equal_approx(arm.length(), 1.0) or _fail_bool("Lamp arm direction must be unit length")

static func _validate_footprint_bounds(metrics: Dictionary) -> bool:
	if not _valid_footprint(metrics.get("footprint")):
		return _fail_bool("Asset footprint is invalid")
	var footprint: Rect2 = metrics.footprint
	var bounds: AABB = metrics.aabb
	var grown := Rect2(Vector2(bounds.position.x, bounds.position.z),
		Vector2(bounds.size.x, bounds.size.z)).grow(0.05)
	for corner: Vector2 in [footprint.position,
			Vector2(footprint.end.x, footprint.position.y),
			Vector2(footprint.position.x, footprint.end.y), footprint.end]:
		if not grown.has_point(corner):
			return _fail_bool("Asset footprint lies outside measured bounds")
	return true

static func _valid_aabb(bounds: AABB) -> bool:
	return bounds.has_volume() and _finite_vector3(bounds.position) and _finite_vector3(bounds.size)

static func _valid_footprint(value: Variant) -> bool:
	if not value is Rect2:
		return false
	var rect: Rect2 = value
	return rect.has_area() and _finite_vector2(rect.position) and _finite_vector2(rect.size)

static func _positive(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and float(value) > 0.0

static func _finite_non_negative(value: float) -> bool:
	return is_finite(value) and value >= 0.0

static func _finite_vector2(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y)

static func _finite_vector3(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)

static func _fail(message: String) -> PathProgram:
	push_error(message)
	return null

static func _fail_bool(message: String) -> bool:
	push_error(message)
	return false
