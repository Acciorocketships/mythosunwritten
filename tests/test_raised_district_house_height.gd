extends GutTest


func test_raised_district_optional_rooms_stay_within_the_planned_crown() -> void:
	var columns := {
		Vector2i.ZERO: {"base": 0, "top": 10, "plinth": 4},
		Vector2i.RIGHT: {"base": 0, "top": 12, "plinth": 4}
	}
	var massif := WarrenMassif.with_columns(1, columns, 12)
	var profile := WarrenVillageScaleProfile.for_id(&"grand")
	var exercised := 0
	for seed_value in range(1, 33):
		var plan := WarrenMazeSourcePlan.new(
			seed_value, profile, massif, WarrenExcavation.new(seed_value)
		)
		var cells: Array[Vector2i] = [Vector2i.ZERO, Vector2i.RIGHT]
		var building := {"floor": 4, "seed": Vector2i.ZERO, "door": Vector3i.ZERO, "cells": cells}
		var roof := WarrenPlotPlanner._rolled_seed_top(plan, building)
		assert_lte(
			roof,
			10 + WarrenBuildingParcel.ROOF_RESERVATION_BANDS,
			"Optional walls must not grow above the volume that streets bored through"
		)
		exercised += int(roof == 10 + WarrenBuildingParcel.ROOF_RESERVATION_BANDS)
	assert_gt(exercised, 0, "Keep the full planned height available")


func test_required_upper_street_and_room_keep_their_bearing_height() -> void:
	var columns := {}
	for x in range(-5, 6):
		for z in range(-5, 6):
			columns[Vector2i(x, z)] = {"base": 0, "top": 6, "plinth": 4}
	var massif := WarrenMassif.with_columns(1, columns, 4)
	var plan := WarrenMazeSourcePlan.new(
		1, WarrenVillageScaleProfile.for_id(&"grand"), massif, WarrenExcavation.new(1)
	)
	var cells: Array[Vector2i] = [Vector2i.ZERO]
	var building := {"floor": 4, "seed": Vector2i.ZERO, "door": Vector3i.ZERO, "cells": cells}
	assert_lte(WarrenPlotPlanner._rolled_seed_top(plan, building), 8)
	var street := WarrenPlotPlanner._building_top(plan, {Vector2i.ZERO: [10]}, {}, building)
	assert_eq(street.top, 10, "An existing upper street cannot lose its supporting house")
	assert_true(street.tiered)
	var carried := WarrenPlotPlanner._building_top(plan, {}, {Vector2i.ZERO: [10]}, building)
	assert_eq(carried.top, 10, "An existing upper room cannot lose its supporting house")


func test_ground_and_mixed_datum_houses_keep_their_original_height_roll() -> void:
	for mixed in [false, true]:
		var columns := {
			Vector2i.ZERO: {"base": 0, "top": 6, "plinth": 4 if mixed else 0},
			Vector2i.RIGHT: {"base": 0, "top": 6}
		}
		var massif := WarrenMassif.with_columns(1, columns, 6)
		for seed_value in range(1, 33):
			var profile := WarrenVillageScaleProfile.for_id(&"grand")
			var plan := WarrenMazeSourcePlan.new(
				seed_value, profile, massif, WarrenExcavation.new(seed_value)
			)
			var building := {
				"floor": 4 if mixed else 0,
				"seed": Vector2i.ZERO,
				"door": Vector3i.ZERO,
				"cells": [Vector2i.ZERO, Vector2i.RIGHT] as Array[Vector2i]
			}
			var raw := (
				int(building.floor)
				+ WarrenBuildingParcel.ROOF_RESERVATION_BANDS
				+ (
					WarrenBuildingParcel.STOREY_BANDS
					* WarrenPlotPlanner._building_roll(
						plan,
						building,
						WarrenPlotPlanner.STOREY_SALT,
						profile.scaled(WarrenPlotPlanner.STOREY_BUDGET)
					)
				)
			)
			assert_eq(
				WarrenPlotPlanner._rolled_seed_top(plan, building),
				raw,
				"Only wholly raised houses use the crown envelope"
			)


func test_raised_neighboring_street_keeps_a_complete_overhead_room_budget() -> void:
	var massif := WarrenMassif.with_columns(
		1, {Vector2i.ZERO: {"base": 0, "top": 6, "plinth": 4}}, 6
	)
	var profile := WarrenVillageScaleProfile.for_id(&"grand")
	for seed_value in range(1, 33):
		var plan := WarrenMazeSourcePlan.new(
			seed_value, profile, massif, WarrenExcavation.new(seed_value)
		)
		var building := {
			"floor": 4,
			"seed": Vector2i.ZERO,
			"door": Vector3i.ZERO,
			"cells": [Vector2i.ZERO] as Array[Vector2i]
		}
		var raw := (
			4
			+ WarrenBuildingParcel.ROOF_RESERVATION_BANDS
			+ (
				WarrenBuildingParcel.STOREY_BANDS
				* WarrenPlotPlanner._building_roll(
					plan,
					building,
					WarrenPlotPlanner.STOREY_SALT,
					profile.scaled(WarrenPlotPlanner.STOREY_BUDGET)
				)
			)
		)
		plan.passage_kinds[Vector3i(1, 6, 0)] = WarrenMazeSourcePlan.PASSAGE_SPINE
		var roof := WarrenPlotPlanner._rolled_seed_top(plan, building)
		assert_gte(
			roof, mini(raw, 12), "The raised street needs its headroom, a complete room and roof"
		)
		assert_lte(roof, raw, "A potential cover cannot invent extra storeys")
		plan.passage_kinds.clear()
		assert_eq(
			WarrenPlotPlanner._rolled_seed_top(plan, building),
			8,
			"Without a street the small crown supports one room"
		)
