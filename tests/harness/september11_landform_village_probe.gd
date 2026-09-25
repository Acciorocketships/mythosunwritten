extends SceneTree

func _init() -> void:
	var seed_value:=VillagePlan.warren_seed_for_cell(2697992464,Vector2i(51,22))
	var profile:=WarrenVillageScaleProfile.select(seed_value)
	var source:=WarrenMazeSitePlanner.plan(seed_value,{},profile)
	print("VILLAGE_SEED ",seed_value," profile=",profile.scale_id)
	print("SOURCE_PLOTS ",source.plots)
	print("SOURCE_AUDIT ",source.audit)
	var volume:=WarrenMazeVolumeAdapter.to_volume_plan(source)
	var parcels:=WarrenMazeBlockPartitioner.partition(source,volume)
	print("PARCELS ",parcels," ",WarrenMazeBlockPartitioner.last_failure," ",WarrenMazeBlockPartitioner.last_diagnostic)
	var fields:Dictionary={}
	for key in ["passage_kinds","market_zone","market_square_cells","feature_stamps","summit_cell","block_thickness","plots","audit"]: fields[key]=source.get(key)
	var excavation:Dictionary={}
	for key in ["route","lanes","loop_edges","bridge_spans","bridge_span_audit","frontage_reservations","carved","covered","transitions","portals"]: excavation[key]=source.excavation.get(key)
	var frozen:={"world_seed":source.world_seed,"profile":source.scale_profile.scale_id,"massif_columns":source.massif.columns,"massif_core":source.massif.core_top_bands,"excavation":excavation,"source":fields}
	FileAccess.open("res://tests/fixtures/september11/landforms/VillageRejectedSource.txt",FileAccess.WRITE).store_string(var_to_str(frozen))
	quit()
