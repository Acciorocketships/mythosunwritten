extends GutTest

class DryPlanningWater extends WaterPlan:
	func _init(seed_value: int) -> void:
		super(seed_value, 22.0, 8)
	func bodies_near(_center_cell: Vector2i, _radius_cells: int) -> Dictionary:
		return {"ponds": [], "rivers": []}
	func planning_signed_distance(_point: Vector2) -> float:
		return PATH_QUERY_MAX
	func planning_intervals(_a: Vector2, _b: Vector2) -> Array[Vector2]:
		return []

func _present_site(plan: SettlementPlan) -> Dictionary:
	for z in range(-4, 5):
		for x in range(-4, 5):
			var site := plan.site_for(Vector2i(x, z))
			if not site.is_empty():
				return site
	return {}

func test_site_is_deterministic_and_publishes_future_village_identity() -> void:
	var a := SettlementPlan.new(4242, DryPlanningWater.new(4242))
	var b := SettlementPlan.new(4242, DryPlanningWater.new(4242))
	var site := _present_site(a)
	assert_false(site.is_empty())
	var super_cell := SettlementPlan.super_of(site.cell)
	assert_eq(b.site_for(super_cell), site)
	assert_true(String(site.id).begins_with("settlement."))
	assert_eq(site.keys().size(), 2)
	assert_true(site.has("id") and site.has("cell"))

func test_settlements_have_no_terrain_mutation_api() -> void:
	var settlements := SettlementPlan.new(4242, DryPlanningWater.new(4242))
	var heights := HeightfieldPlan.new(4242, 22.0, 8, "mean", 3)
	assert_false(settlements.has_method("terrain_height"))
	assert_false(heights.has_method("set_settlement_plan"))

func test_site_queries_leave_the_natural_heightfield_untouched() -> void:
	var water := DryPlanningWater.new(4242)
	var settlements := SettlementPlan.new(4242, water)
	var heights := HeightfieldPlan.new(4242, 22.0, 8, "mean", 3)
	var cells: Array[Vector2i] = [
		Vector2i(-97, 43), Vector2i.ZERO, Vector2i(12, -28), Vector2i(81, 119)]
	var before: Array[float] = []
	for cell: Vector2i in cells:
		before.append(heights.raw_height(cell.x, cell.y))
	for z in range(-5, 6):
		for x in range(-5, 6):
			settlements.site_for(Vector2i(x, z))
	for index in cells.size():
		var cell := cells[index]
		assert_eq(heights.raw_height(cell.x, cell.y), before[index],
			"discovering villages cannot alter natural terrain")
