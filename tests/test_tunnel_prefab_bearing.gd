extends GutTest

class BearingPlan extends WarrenMazeSourcePlan:
	func _init():
		super(0, null, null, WarrenExcavation.new(0))
	func solid_at(_cell: Vector3i) -> bool:
		return true

func _plan(asset_floor: int) -> WarrenMazeSourcePlan:
	var plan := BearingPlan.new()
	plan.passage_kinds = {Vector3i.ZERO: &"spine", Vector3i(0,0,-1): &"spine", Vector3i(0,0,1): &"spine"}
	plan.plots.append({"kind":WarrenMazeSourcePlan.PLOT_ASSET,"floor":asset_floor,"top":8})
	plan._plot_columns[Vector2i.RIGHT] = [0]
	return plan

func test_prefab_reservation_is_not_a_solid_tunnel_jamb() -> void:
	assert_true(WarrenPlotPlanner._tunnel_jambs(_plan(0), Vector3i.ZERO, 2).is_empty(),
		"A nominally solid asset envelope cannot supply a masonry bearing")

func test_existing_masonry_below_a_raised_asset_remains_a_bearing() -> void:
	assert_eq(WarrenPlotPlanner._tunnel_jambs(_plan(4), Vector3i.ZERO, 2).size(), 2,
		"Real source-solid courses below the asset retain their support role")

func test_asset_starting_at_the_crown_cannot_supply_its_top_bearing() -> void:
	assert_true(WarrenPlotPlanner._tunnel_jambs(_plan(2), Vector3i.ZERO, 2).is_empty())
