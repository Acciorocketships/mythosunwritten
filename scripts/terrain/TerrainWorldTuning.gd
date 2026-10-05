class_name TerrainWorldTuning
extends RefCounted

## Canonical defaults for the production terrain field. Runtime streamers and
## production-representative corpus/review harnesses must read these values
## instead of copying literals, or a valid pin in a harness may not exist in
## the rendered world at all.
## 320 m / 80 storeys since the large-scale elevation layer (owner reviews
## 2026-10-03/04): highland interiors sit up to 200 m above lowland basins,
## with a 44 m undulation over that, before any landform.
const HEIGHTFIELD_AMPLITUDE := 480.0
const HEIGHTFIELD_MAX_STOREYS := 120
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
