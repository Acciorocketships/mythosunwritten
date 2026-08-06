class_name DressingProgram
extends RefCounted

## Immutable-by-convention worker data produced by DressingCompiler. Every
## member is a primitive value/container; no authored Resource crosses over.
var sets: Array[Dictionary] = []
var referenced_asset_ids: Array[StringName] = []
## Unscaled near-ground visual radius per collidable asset. Runtime systems
## may use this worker-safe metadata without loading the authored mesh again.
var ground_radius_by_asset: Dictionary = {}
## Ordered radial outline of the same near-ground visual vertices. Keeping the
## actual stencil lets main-thread grass suppression follow a long rock/tree
## base instead of replacing every asset with an oversized circle.
var ground_stencil_by_asset: Dictionary = {}
## Region/water sampling reach of near-ground support points.
var query_margin: float = 0.0
## Independent reach needed when projected visual bounds query authored
## feature reservations. This may exceed water's finite canonical margin
## because it never samples terrain or water there.
var feature_query_margin: float = 0.0
var shore_distance_limit: float = 0.0
var maximum_spacing_radius: float = 0.0
var maximum_feature_clearance: float = 0.0
var estimated_proposals_per_chunk: int = 0

func is_empty() -> bool:
	return sets.is_empty()
