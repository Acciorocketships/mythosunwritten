extends SceneTree

func _init() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var frozen := preload("res://tests/fixtures/frozen_maze_source.gd")
	var spatial := frozen.spatial(frozen.read("res://tests/fixtures/september11-floating-source.txt"),program)
	var plan := spatial.compiled_fabric_cache()
	var rows: Array[Dictionary] = []
	for building: WarrenBuildingVolume in spatial.buildings:
		for room: WarrenRoomStamp in building.room_records:
			var units: Array[Dictionary] = []
			for unit: FabricUnit in plan.units:
				if String(unit.stable_id).contains(String(room.stable_id)):
					var recipe := plan.recipe(unit.recipe_id)
					units.append({"id":unit.stable_id,"recipe":unit.recipe_id,
						"origin":unit.lattice_origin,"yaw":unit.yaw_quarters,
						"placements":recipe.placements,"bounds":unit.transform()*recipe.local_bounds,"parents":unit.parent_ids})
			rows.append({"id":room.stable_id,"cells":room.private_cells,"units":units,"audit":room.audit,"origin":room.lattice_origin,"kind":room.kind,"yaw":room.yaw_quarters,"source":room.source_parcel_id})
	var out := {"rooms":rows,"audit":plan.audit}
	FileAccess.open("res://docs/qa/2026-09-11-manual/08-skywalk/before.json",FileAccess.WRITE).store_string(JSON.stringify(out,"  "))
	quit()
