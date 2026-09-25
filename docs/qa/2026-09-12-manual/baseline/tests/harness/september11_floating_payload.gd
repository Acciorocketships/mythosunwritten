extends SceneTree

func _init() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var spatial := frozen.spatial(frozen.read("res://tests/fixtures/september11-floating-source.txt"), program)
	var plan := spatial.compiled_fabric_cache()
	var payload := SettlementFabricAssembler.payload(plan)
	payload.append_from(SettlementFabricAssembler.structural_support_payload(plan))
	payload.append_from(SettlementFabricAssembler.production_surface_bundle(plan.surface_plan,
		SettlementFabricAssembler.maze_module_footprints(plan),
		SettlementFabricAssembler.maze_skin_panel_boxes_for(plan), plan.planned_plaza_cells))
	var args := OS.get_cmdline_user_args()
	var output := args[args.find("--output") + 1]
	var rooms: Array[Dictionary] = []
	for building: WarrenBuildingVolume in spatial.buildings:
		for room: WarrenRoomStamp in building.room_records:
			rooms.append({"id": room.stable_id, "origin": room.lattice_origin,
				"kind": room.kind, "cells": room.private_cells})
	var data := {"batches": payload.batches, "collision_boxes": payload.collision_boxes,
		"surface_meshes": payload.surface_meshes, "rooms": rooms,
		"walked": SettlementFabricAssembler.walked_floor_cells(plan.surface_plan),
		"skin": SettlementFabricAssembler.maze_ground_skin_transaction(plan)}
	FileAccess.open(output, FileAccess.WRITE).store_var(data)
	print("FLOATING_PAYLOAD ", output, " rooms=", rooms.size(), " instances=", payload.instance_count)
	quit()
