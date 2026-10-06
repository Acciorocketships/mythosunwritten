extends RefCounted


## Isolated native house with one real terrain landing in the fabric pipeline.
static func build(
	recipe: FabricRecipe, catalog: EnvironmentCatalog, yaw: int
) -> SettlementFabricPlan:
	var plan := SettlementFabricPlan.new(&"native.fixture.plan")
	var bounds := {}
	for asset_id in catalog.ids():
		bounds[asset_id] = catalog.descriptor(asset_id).measured_aabb
	assert(plan.set_asset_visual_bounds(bounds))
	assert(plan.register_recipe(recipe))
	var origin := Vector3i(10, 1, -7)
	assert(
		plan.add_unit(FabricUnit.new(&"native.house", recipe.recipe_id, origin, yaw)),
		plan.last_rejection
	)
	var landing := FabricRecipe.new(
		&"native.fixture.landing", [&"topology_only", &"public_walk", &"route_landing"], 0
	)
	landing.walk_cells = [Vector3i.ZERO]
	landing.headroom_cells = [Vector3i.ZERO, Vector3i.UP]
	landing.public_air_cells.assign(landing.headroom_cells)
	assert(landing.seal(catalog), landing.last_rejection)
	assert(plan.register_recipe(landing))
	var cell := FabricRecipe.transform_cell(Vector3i.BACK, origin, yaw)
	assert(
		plan.add_unit(FabricUnit.new(&"native.landing", landing.recipe_id, cell, yaw)),
		plan.last_rejection
	)
	var surface := PublicRealmSurfacePlan.new(&"native.fixture.surface")
	assert(
		surface.add_claim(
			cell, PublicRealmSurfacePlan.SurfaceKind.TERRAIN_STREET, &"native.landing"
		)
	)
	assert(surface.seal([cell] as Array[Vector3i]), surface.last_rejection)
	assert(plan.set_surface_plan(surface))
	assert(plan.seal(), plan.last_rejection)
	return plan
