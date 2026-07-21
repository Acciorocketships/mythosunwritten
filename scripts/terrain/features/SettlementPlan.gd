class_name SettlementPlan
extends RefCounted

## Seed-only future-village identities. This plan chooses sites but has no
## terrain API: villages never flatten, raise, carve, or otherwise stamp the
## procedural landscape. PathPlan validates the sites against the final fields
## and follows whatever walkable approaches the natural terrain provides.

const SEED_VERSION := 1
const SUPER_CELLS := 32
const SUPER_WORLD := SUPER_CELLS * TerrainSurfaceField.TILE
const SITE_PROBABILITY := 0.75
const SITE_CANDIDATES := 5
const MIN_MEADOW_WEIGHT := 0.08
const MAX_ROCKY_WEIGHT := 0.82
const WATER_CLEARANCE := 108.0
const LOCAL_RELIEF_WEIGHT := 220.0
const _CACHE_CAP := 128

const _SALT_EXIST := 1103
const _SALT_X := 1213
const _SALT_Z := 1321
const _SALT_TIE := 1427
const _SALT_ID := 1543

var _world_seed: int
var _water: WaterPlan
var _sites: Dictionary = {}

func _init(world_seed: int, water: WaterPlan) -> void:
	assert(water != null)
	_world_seed = world_seed
	_water = water

func site_for(super_cell: Vector2i) -> Dictionary:
	return _site(super_cell).duplicate()

func _site(super_cell: Vector2i) -> Dictionary:
	if _sites.has(super_cell):
		return _sites[super_cell]
	if _sites.size() >= _CACHE_CAP:
		_sites.clear()
	var site := _compute_site(super_cell)
	_sites[super_cell] = site
	return site

func _compute_site(super_cell: Vector2i) -> Dictionary:
	if _roll(_hash(_SALT_EXIST, [super_cell.x, super_cell.y])) >= SITE_PROBABILITY:
		return {}
	var candidates: Array[Dictionary] = []
	var seen: Dictionary = {}
	for index in SITE_CANDIDATES:
		var hx := _hash(_SALT_X, [super_cell.x, super_cell.y, index])
		var hz := _hash(_SALT_Z, [super_cell.x, super_cell.y, index])
		var cell := super_cell * SUPER_CELLS + Vector2i(
			8 + int(floor(_roll(hx) * 16.0)),
			8 + int(floor(_roll(hz) * 16.0)))
		if seen.has(cell):
			continue
		seen[cell] = true
		var point := Vector2(cell) * TerrainSurfaceField.TILE
		if _water.planning_signed_distance(point) < WATER_CLEARANCE:
			continue
		var world := Vector3(point.x, 0.0, point.y)
		var weights := Helper.biome_weights5(world, _world_seed)
		var meadow := float(weights[&"meadow"])
		var rocky := Helper.biome_rocky01(world, _world_seed)
		if meadow < MIN_MEADOW_WEIGHT or rocky > MAX_ROCKY_WEIGHT:
			continue
		var heights := PackedFloat32Array()
		for offset: Vector2 in [Vector2.ZERO, Vector2(-6.0, -6.0),
				Vector2(6.0, -6.0), Vector2(-6.0, 6.0), Vector2(6.0, 6.0)]:
			var sample := point + offset
			heights.append(HeightfieldPlan.height01(
				Vector3(sample.x, 0.0, sample.y), _world_seed, true))
		var lo := heights[0]
		var hi := heights[0]
		for height: float in heights:
			lo = minf(lo, height)
			hi = maxf(hi, height)
		candidates.append({"cell": cell,
			"score": (hi - lo) * LOCAL_RELIEF_WEIGHT + rocky * 3.0 - meadow,
			"tie": _hash(_SALT_TIE, [cell.x, cell.y, index])})
	if candidates.is_empty():
		return {}
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a.score), float(b.score)):
			return float(a.score) < float(b.score)
		if int(a.tie) != int(b.tie):
			return int(a.tie) < int(b.tie)
		return _cell_less(a.cell, b.cell))
	var winner: Dictionary = candidates[0]
	return {"id": _stable_id(super_cell), "cell": winner.cell}

static func super_of(cell: Vector2i) -> Vector2i:
	return Vector2i(int(floor(float(cell.x) / SUPER_CELLS)),
		int(floor(float(cell.y) / SUPER_CELLS)))

func _hash(salt: int, values: Array) -> int:
	var value := Helper._mix64(_world_seed ^ SEED_VERSION ^ salt)
	for part: Variant in values:
		value = Helper._mix64(value ^ Helper._mix64(int(part)))
	return value

func _stable_id(super_cell: Vector2i) -> StringName:
	return StringName("settlement.%016x" % (_hash(
		_SALT_ID, [super_cell.x, super_cell.y]) & 0x7FFFFFFFFFFFFFFF))

static func _roll(value: int) -> float:
	return float(value & 0x7FFFFFFF) / float(0x80000000)

static func _cell_less(a: Vector2i, b: Vector2i) -> bool:
	return a.x < b.x or (a.x == b.x and a.y < b.y)
