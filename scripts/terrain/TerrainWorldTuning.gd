class_name TerrainWorldTuning
extends RefCounted

## Canonical defaults for the production terrain field. Runtime streamers and
## production-representative corpus/review harnesses must read these values
## instead of copying literals, or a valid pin in a harness may not exist in
## the rendered world at all.
## 192 m / 48 storeys since the large-scale elevation layer (owner review
## 2026-10-03): highlands sit up to ~64 m above lowlands before any landform.
const HEIGHTFIELD_AMPLITUDE := 192.0
const HEIGHTFIELD_MAX_STOREYS := 48
const MAX_CLIFF_STEP := 3


static func make_water(world_seed: int) -> WaterPlan:
	return WaterPlan.new(world_seed, HEIGHTFIELD_AMPLITUDE,
		HEIGHTFIELD_MAX_STOREYS)


static func make_heightfield(world_seed: int,
		water: WaterPlan = null) -> HeightfieldPlan:
	var plan := HeightfieldPlan.new(world_seed, HEIGHTFIELD_AMPLITUDE,
		HEIGHTFIELD_MAX_STOREYS, "mean", MAX_CLIFF_STEP)
	if water != null:
		plan.set_water_plan(water)
	return plan
