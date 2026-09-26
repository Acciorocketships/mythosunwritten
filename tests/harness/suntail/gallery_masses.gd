extends RefCounted
## Masses for the building gallery harness and kit tests.


static func masses(set_name: String, count: int, seed: int,
		kit: BuildingKit) -> Array[BuildingMass]:
	var out: Array[BuildingMass] = []
	match set_name:
		"replica":
			out.append(house_one())
			out.append(deep_hall())
			out.append(l_house())
			out.append(tall_house())
		"lots":
			for i in count:
				out.append(KitStandaloneHouse.design(kit, 4 + i % 2, 3 + (i / 2) % 2, 1, seed * 1000 + i))
		"loggias-before":
			var records: Array = str_to_var(FileAccess.get_file_as_string("res://tests/fixtures/town_depth_before_masses.var"))
			for record: Dictionary in records:
				var mass := BuildingMass.new()
				for key: String in record: mass.set(key, record[key])
				out.append(mass)
		"loggias":
			for i in count:
				var house := {"storeys": {}, "cells": [], "doors": [], "terrain_band": 0}
				for floor in 3 + i % 2:
					house.storeys[floor * 2] = BuildingMass.rect_cells(Rect2i(0, 0, 6 + i % 2, 4))
				out.append(KitVillageBuildings._mass_for(StringName("gallery.%d" % i), house,
					WarrenSpatialGrid.new(Vector3i.ZERO, Vector3i.ONE), {}, seed, kit))
		"designer":
			var designer := BuildingDesigner.new(kit)
			for i in count:
				out.append(designer.design_standalone(seed * 1000 + i))
	return out


## The pack's House_1: 3x2-module stone ground floor on a plinth, a jettied
## 4x3 timber upper storey, a red gable roof along X with two dormers.
static func house_one() -> BuildingMass:
	var mass := BuildingMass.new()
	mass.stable_id = &"gallery.house_one"
	mass.seed = 1
	var cells := BuildingMass.rect_cells(Rect2i(0, 0, 4, 3))
	var ground := mass.add_storey(0, cells, BuildingMass.MATERIAL_STONE, true, true)
	ground.openings[Vector3i(0, 1, 2)] = BuildingMass.OPENING_DOOR
	mass.add_storey(2, cells, BuildingMass.MATERIAL_TIMBER)
	var roof := mass.add_roof(Rect2i(0, 0, 4, 3), 0, 4, &"red")
	roof.dormers[Vector2i(0, 1)] = true
	roof.dormers[Vector2i(0, 3)] = true
	roof.ridge_peaks = true
	mass.decor.append({"kind": &"awning", "centre": Vector2(2.0, 2.5), "dir": 1, "y": 0.0})
	for x in [1.5, 2.5]:
		mass.decor.append({"kind": &"window_box", "centre": Vector2(x, 3.0), "dir": 1, "y": 3.0})
	return mass


## A deeper (4-module) hall: two roof rows per side, no ridge-top row.
static func deep_hall() -> BuildingMass:
	var mass := BuildingMass.new()
	mass.stable_id = &"gallery.deep_hall"
	mass.seed = 2
	var cells := BuildingMass.rect_cells(Rect2i(0, 0, 6, 4))
	var ground := mass.add_storey(0, cells, BuildingMass.MATERIAL_STONE, true, true)
	ground.openings[Vector3i(2, 0, 3)] = BuildingMass.OPENING_DOOR
	var upper := mass.add_storey(2, cells, BuildingMass.MATERIAL_TIMBER)
	upper.openings[Vector3i(5, 1, 0)] = BuildingMass.OPENING_BAY
	upper.openings[Vector3i(5, 2, 0)] = BuildingMass.OPENING_BAY
	upper.bay_colour = &"blue"
	var roof := mass.add_roof(Rect2i(0, 0, 6, 4), 0, 4, &"blue")
	for p in [1, 2, 4, 5]:
		roof.dormers[Vector2i(0, p)] = true
	return mass


## L-shaped plan: a main wing along X and a cross wing along Z.
static func l_house() -> BuildingMass:
	var mass := BuildingMass.new()
	mass.stable_id = &"gallery.l_house"
	mass.seed = 3
	var cells := BuildingMass.rect_cells(Rect2i(0, 0, 5, 3))
	cells.merge(BuildingMass.rect_cells(Rect2i(0, 3, 3, 3)))
	mass.add_storey(0, cells, BuildingMass.MATERIAL_STONE, true, true)
	mass.add_storey(2, cells, BuildingMass.MATERIAL_TIMBER)
	var main := mass.add_roof(Rect2i(0, 0, 5, 3), 0, 4, &"red")
	main.dormers[Vector2i(1, 2)] = true
	var wing := mass.add_roof(Rect2i(0, 3, 3, 3), 1, 4, &"red")
	wing.open_min = true
	wing.extend_min = 1
	return mass


## Three storeys with a jetty at each floor and a narrow 2-module crown.
static func tall_house() -> BuildingMass:
	var mass := BuildingMass.new()
	mass.stable_id = &"gallery.tall_house"
	mass.seed = 4
	var cells := BuildingMass.rect_cells(Rect2i(0, 0, 3, 2))
	mass.add_storey(0, cells, BuildingMass.MATERIAL_STONE, true, true)
	mass.add_storey(2, cells, BuildingMass.MATERIAL_TIMBER, false)
	mass.add_storey(4, cells, BuildingMass.MATERIAL_TIMBER)
	var roof := mass.add_roof(Rect2i(0, 0, 3, 2), 0, 6, &"blue")
	roof.dormers[Vector2i(1, 1)] = true
	return mass
