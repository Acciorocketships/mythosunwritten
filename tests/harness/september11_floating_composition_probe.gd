extends SceneTree

func _init() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var spatial := frozen.spatial(frozen.read("res://tests/fixtures/september11-floating-source.txt"), program)
	var rows: Array[Dictionary] = []
	for building: WarrenBuildingVolume in spatial.buildings:
		for room: WarrenRoomStamp in building.room_records:
			rows.append({"id": room.stable_id, "kind": room.kind,
				"origin": str(room.lattice_origin), "cells": str(room.private_cells),
				"audit": room.audit})
	var features: Array[Dictionary] = []
	for feature: WarrenFeatureReservation in spatial.features:
		if feature.kind == &"room_overhang_support":
			features.append({"id": feature.stable_id, "audit": feature.audit})
	var report := {"rooms": rows, "features": features, "audit": WarrenRoomCompositionPlanner.last_audit}
	FileAccess.open("res://docs/qa/2026-09-11-manual/05-floating/composition-candidate.json", FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	quit()
