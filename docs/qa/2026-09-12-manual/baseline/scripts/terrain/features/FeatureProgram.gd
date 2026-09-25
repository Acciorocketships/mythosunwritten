class_name FeatureProgram
extends RefCounted

## Resource-free composition of every authored man-made feature family. Runtime
## consumers depend on these combined limits, so adding villages or later camps
## cannot leave streamer margins, asset demand, or collision halos path-sized.
var paths: PathProgram
var villages: VillageProgram
var query_margin: float
var shore_distance_limit: float
var maximum_clearance: float
var record_discovery_radius: float
var geometry_halo: int
var field_cache_cap: int
var surface_priorities: Dictionary
var referenced_asset_ids: Array[StringName] = []

static func compile(catalog: EnvironmentCatalog,
		village_authored: Dictionary = {},
		path_authored: Dictionary = {}) -> FeatureProgram:
	var path_program := PathProgram.compile(catalog, path_authored)
	if path_program == null:
		return null
	var village_program := VillageProgram.compile(village_authored, catalog)
	if village_program == null:
		return null
	var program := FeatureProgram.new()
	program.paths = path_program
	program.villages = village_program
	program.query_margin = maxf(path_program.query_margin,
		village_program.maximum_clearance)
	program.shore_distance_limit = path_program.shore_distance_limit
	program.maximum_clearance = maxf(path_program.maximum_clearance,
		village_program.maximum_clearance)
	program.record_discovery_radius = village_program.max_record_radius \
		+ program.maximum_clearance
	program.geometry_halo = maxi(path_program.feature_halo,
		village_program.geometry_halo)
	program.field_cache_cap = PathProgram.FIELD_CACHE_CAP
	program.surface_priorities = {
		FeatureGroundField.WORN_PATH: FeatureGroundField.PATH_PRIORITY,
	}
	var unique: Dictionary = {}
	for asset_id: StringName in path_program.referenced_asset_ids:
		unique[asset_id] = true
	for asset_id: StringName in village_program.referenced_asset_ids:
		unique[asset_id] = true
	program.referenced_asset_ids.assign(unique.keys())
	program.referenced_asset_ids.sort_custom(func(a: StringName,
			b: StringName) -> bool:
		return String(a) < String(b))
	return program
