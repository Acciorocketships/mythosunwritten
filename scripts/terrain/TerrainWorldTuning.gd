class_name TerrainWorldTuning
extends RefCounted

## Canonical defaults for the production terrain field. Runtime streamers and
## production-representative corpus/review harnesses must read these values
## instead of copying literals, or a valid pin in a harness may not exist in
## the rendered world at all.
const HEIGHTFIELD_AMPLITUDE := 22.0
const HEIGHTFIELD_MAX_STOREYS := 8
const MAX_CLIFF_STEP := 3


static func make_water(world_seed: int) -> WaterPlan:
	return WaterPlan.new(world_seed, HEIGHTFIELD_AMPLITUDE,
		HEIGHTFIELD_MAX_STOREYS)


## The settlement relief stamp for a world, or null when this world does not
## stamp. Only MASS-FIRST towns get a terrain-authored hill; route-first
## villages conform to natural ground through the existing perch machinery and
## must keep seeing today's world byte-for-byte, so the gate is
## SettlementReliefPlan.is_active(). `settlements` may be reused from a caller
## that already built one (the streamer does) so site identity is resolved once.
static func make_relief(world_seed: int, water: WaterPlan,
		settlements: SettlementPlan = null) -> SettlementReliefPlan:
	if not SettlementReliefPlan.is_active():
		return null
	var sites := settlements
	if sites == null:
		sites = SettlementPlan.new(world_seed, water)
	return SettlementReliefPlan.new(world_seed, sites, HEIGHTFIELD_AMPLITUDE,
		HEIGHTFIELD_MAX_STOREYS)


## `relief` is untyped for the same reason HeightfieldPlan._relief_plan is:
## duck-typed, optional, and null in a route-first world.
static func make_heightfield(world_seed: int, water: WaterPlan = null,
		relief = null) -> HeightfieldPlan:
	var plan := HeightfieldPlan.new(world_seed, HEIGHTFIELD_AMPLITUDE,
		HEIGHTFIELD_MAX_STOREYS, "mean", MAX_CLIFF_STEP)
	if water != null:
		plan.set_water_plan(water)
	if relief != null:
		plan.set_relief_plan(relief)
	return plan
