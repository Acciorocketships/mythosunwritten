class_name GrassProgram
extends RefCounted

const CANOPY_CHANNEL := &"woodland_canopy"
const CANOPY_SCALE := 132.0
static var CANOPY_COVERAGE := PackedFloat32Array([0.22, 0.82, 0.14, 0.72, 0.42])
const CANOPY_SOFTNESS := 0.11
const FEATURE_CLEARANCE := 0.3
const QUERY_MARGIN := DressingCompiler.SURFACE_STENCIL

var grass_seed_version: int
var coverage_by_biome := PackedFloat32Array()
var variant_asset_ids: Array[StringName] = []
var scale_range := Vector2.ZERO
var max_grade: float
var shore_clearance: float
var query_margin := QUERY_MARGIN
var shore_distance_limit: float
## Value-only metadata keyed by asset ID. Meshes/materials remain in the
## main-thread EnvironmentRenderCache.
var assets: Dictionary = {}
var referenced_asset_ids: Array[StringName] = []

static func compile(settings: GrassSettings, catalog: EnvironmentCatalog,
		render_cache: EnvironmentRenderCache) -> GrassProgram:
	if settings == null or catalog == null or render_cache == null:
		return _fail("Grass compilation requires settings and both environment indexes")
	if settings.grass_seed_version < 1:
		return _fail("Grass seed version must be at least one")
	if not _ordered_finite(settings.scale_range) or settings.scale_range.x <= 0.0:
		return _fail("Grass scale range must be finite, ordered, and positive")
	if not is_finite(settings.max_grade) or settings.max_grade < 0.0 \
			or not is_finite(settings.shore_clearance) or settings.shore_clearance < 0.0:
		return _fail("Grass grade and shore clearance must be finite and non-negative")
	var biome_ids := BiomeRegistry.biome_ids()
	var coverage := _coverage_array(settings.coverage_by_biome, biome_ids)
	if coverage.is_empty():
		return null
	var referenced := _sorted_unique(settings.variant_asset_ids)
	if referenced.is_empty() \
			or referenced.size() != settings.variant_asset_ids.size():
		return _fail("Grass asset variants must be non-empty and unique")
	if not render_cache.prepare(referenced):
		return _fail("Grass visuals could not be prepared")
	var program := GrassProgram.new()
	program.grass_seed_version = settings.grass_seed_version
	program.coverage_by_biome = coverage
	program.variant_asset_ids = referenced
	program.scale_range = settings.scale_range
	program.max_grade = settings.max_grade
	program.shore_clearance = settings.shore_clearance
	program.shore_distance_limit = settings.shore_clearance
	program.referenced_asset_ids = referenced
	for asset_id: StringName in referenced:
		var metadata := _compile_asset(asset_id, catalog, render_cache)
		if metadata.is_empty():
			return null
		program.assets[asset_id] = metadata
	return program

static func _compile_asset(asset_id: StringName, catalog: EnvironmentCatalog,
		render_cache: EnvironmentRenderCache) -> Dictionary:
	var descriptor := catalog.descriptor(asset_id)
	var visual := render_cache.visual(asset_id)
	if descriptor == null or visual == null:
		_fail("Grass references unknown asset %s" % asset_id)
		return {}
	if not descriptor.supports_instance_color or descriptor.collision_piece_count != 0 \
			or not visual.collisions.is_empty() or visual.pieces.size() != 1:
		_fail("Grass asset %s must be colourable, single-piece, and collision-free" % asset_id)
		return {}
	var piece: EnvironmentVisualPiece = visual.pieces[0]
	if piece == null or piece.mesh == null or not piece.local_transform.is_finite():
		_fail("Grass asset %s has an invalid visual piece" % asset_id)
		return {}
	var transform := piece.local_transform
	var scale := transform.basis.get_scale()
	if scale.x <= 0.0 or not scale.is_finite() \
			or not is_equal_approx(scale.x, scale.y) \
			or not is_equal_approx(scale.x, scale.z):
		_fail("Grass asset %s requires one positive uniform piece scale" % asset_id)
		return {}
	var rotation := Basis(transform.basis.x / scale.x,
		transform.basis.y / scale.y, transform.basis.z / scale.z)
	if rotation.determinant() < 0.999 \
			or rotation.y.dot(Vector3.UP) < 0.999 \
			or absf(rotation.x.y) > 0.001 or absf(rotation.z.y) > 0.001 \
			or absf(transform.origin.x) > 0.001 or absf(transform.origin.z) > 0.001:
		_fail("Grass asset %s must be upright with no XZ piece offset" % asset_id)
		return {}
	var mesh_bounds := piece.mesh.get_aabb()
	if not _valid_aabb(mesh_bounds) or not _valid_aabb(descriptor.measured_aabb) \
			or mesh_bounds.size.y <= 0.0:
		_fail("Grass asset %s requires finite non-empty bounds" % asset_id)
		return {}
	var albedo_key := ""
	var has_albedo_texture := false
	for surface_index in piece.mesh.get_surface_count():
		var material := piece.mesh.surface_get_material(surface_index) as StandardMaterial3D
		if material == null:
			_fail("Grass asset %s requires a baked standard material" % asset_id)
			return {}
		if material.albedo_texture != null:
			var key := material.albedo_texture.resource_path
			if has_albedo_texture and key != albedo_key:
				_fail("Grass asset %s uses more than one albedo texture" % asset_id)
				return {}
			has_albedo_texture = true
			albedo_key = key
	return {
		"piece_transform": transform,
		"descriptor_aabb": descriptor.measured_aabb,
		"footprint_radius": _horizontal_radius(descriptor.measured_aabb),
		"mesh_aabb": mesh_bounds,
		"local_base_y": mesh_bounds.position.y,
		"local_height": mesh_bounds.size.y,
		"albedo_path": albedo_key,
		"has_albedo_texture": has_albedo_texture,
	}

static func _horizontal_radius(bounds: AABB) -> float:
	var x0 := bounds.position.x
	var x1 := bounds.end.x
	var z0 := bounds.position.z
	var z1 := bounds.end.z
	return maxf(maxf(Vector2(x0, z0).length(), Vector2(x0, z1).length()),
		maxf(Vector2(x1, z0).length(), Vector2(x1, z1).length()))

static func _coverage_array(source: Dictionary,
		biome_ids: Array[StringName]) -> PackedFloat32Array:
	if source.size() != biome_ids.size():
		_fail("Grass coverage must contain exactly the canonical biome IDs")
		return PackedFloat32Array()
	var out := PackedFloat32Array()
	for biome_id: StringName in biome_ids:
		var key: Variant = biome_id if source.has(biome_id) else String(biome_id)
		if not source.has(key):
			_fail("Grass coverage is missing biome %s" % biome_id)
			return PackedFloat32Array()
		var amount := float(source[key])
		if not is_finite(amount) or amount < 0.0 or amount > 1.0:
			_fail("Grass coverage for %s must stay in [0,1]" % biome_id)
			return PackedFloat32Array()
		out.append(amount)
	return out

static func _sorted_unique(source: Array[StringName]) -> Array[StringName]:
	var seen: Dictionary = {}
	var out: Array[StringName] = []
	for asset_id: StringName in source:
		if asset_id.is_empty() or seen.has(asset_id):
			continue
		seen[asset_id] = true
		out.append(asset_id)
	out.sort_custom(_id_less)
	return out

static func _id_less(a: StringName, b: StringName) -> bool:
	return String(a) < String(b)

static func _ordered_finite(value: Vector2) -> bool:
	return value.is_finite() and value.x <= value.y

static func _valid_aabb(value: AABB) -> bool:
	return value.position.is_finite() and value.size.is_finite() \
		and value.size.x >= 0.0 and value.size.y >= 0.0 and value.size.z >= 0.0

static func _fail(message: String):
	push_error(message)
	return null
