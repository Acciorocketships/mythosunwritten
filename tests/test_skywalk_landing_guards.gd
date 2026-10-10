extends GutTest

const LANDINGS = preload("res://scripts/terrain/features/villages/kit/KitSkywalkLandings.gd")


func test_both_landing_guards_open_only_across_the_accepted_span() -> void:
	var mass := BuildingMass.new()
	var near := Vector2i(0, 0)
	var far := Vector2i(3, 0)
	var existing := BuildingMass.edge_key(near, 3)
	mass.decks.append({"band": 4, "cells": {near: true}, "open_edges": {existing: true}})
	mass.decks.append({"band": 4, "cells": {far: true}})
	mass.decks.append({"band": 6, "cells": {near: true}})
	var masses: Array[BuildingMass] = [mass]
	var spans: Array[Dictionary] = [
		{"cell": Vector3i(0, 4, 0), "step": Vector3i.RIGHT, "gap": 2, "width": 1, "enclosed": false}
	]
	LANDINGS.open_landings(masses, spans)
	assert_eq(
		mass.decks[0].open_edges.size(), 2, "Keep the existing door and open only the bridge edge"
	)
	assert_true(mass.decks[0].open_edges.has(BuildingMass.edge_key(near, 0)))
	assert_eq(mass.decks[1].open_edges, {BuildingMass.edge_key(far, 2): true})
	assert_false(mass.decks[2].has("open_edges"), "A different floor keeps its guard")


func test_two_lane_bridge_opens_both_modules_without_opening_other_edges() -> void:
	var mass := BuildingMass.new()
	mass.decks.append({"band": 2, "cells": {Vector2i.ZERO: true, Vector2i(0, 1): true}})
	var masses: Array[BuildingMass] = [mass]
	var spans: Array[Dictionary] = [
		{
			"cell": Vector3i(0, 2, 0),
			"step": Vector3i.RIGHT,
			"gap": 2,
			"width": 2,
			"cross": Vector3i.BACK,
			"enclosed": false
		}
	]
	LANDINGS.open_landings(masses, spans)
	assert_eq(
		mass.decks[0].open_edges,
		{
			BuildingMass.edge_key(Vector2i.ZERO, 0): true,
			BuildingMass.edge_key(Vector2i(0, 1), 0): true
		}
	)


func test_absent_bridge_keeps_all_guards() -> void:
	var mass := BuildingMass.new()
	mass.decks.append({"band": 4, "cells": {Vector2i.ZERO: true}})
	var masses: Array[BuildingMass] = [mass]
	var spans: Array[Dictionary] = []
	LANDINGS.open_landings(masses, spans)
	assert_false(mass.decks[0].has("open_edges"))
