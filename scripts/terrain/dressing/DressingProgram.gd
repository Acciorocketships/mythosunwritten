class_name DressingProgram
extends RefCounted

## Immutable-by-convention worker data produced by DressingCompiler. Every
## member is a primitive value/container; no authored Resource crosses over.
var sets: Array[Dictionary] = []
var referenced_asset_ids: Array[StringName] = []
var query_margin: float = 0.0
var shore_distance_limit: float = 0.0
var maximum_spacing_radius: float = 0.0
var maximum_feature_clearance: float = 0.0
var estimated_proposals_per_chunk: int = 0

func is_empty() -> bool:
	return sets.is_empty()
