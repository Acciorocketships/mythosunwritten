extends SceneTree
## Production-size survey; fixed seeds are review inputs, never generation rules.
func _initialize() -> void:
	var rows := []
	for seed_value in range(1,31):
		var profile := WarrenVillageScaleProfile.select(seed_value)
		var source := WarrenMazeSitePlanner.plan(seed_value,{},profile,&"",false)
		if source == null:
			rows.append({"seed":seed_value,"failed":true})
			continue
		var tunnels := []
		for lane: Dictionary in source.excavation.lanes:
			if lane.get("feature_kind",&"")!=&"wall_tunnel": continue
			tunnels.append({"anchor":str(lane.anchor),"length":lane.cells.size()})
		rows.append({"seed":seed_value,"platform":not source.massif.platform_columns().is_empty(),"tunnels":tunnels})
	var args := OS.get_cmdline_user_args()
	var path := args[args.find("--output")+1] if args.has("--output") else "/tmp/wall-tunnel-survey.json"
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	print("WALL_TUNNEL_SURVEY ",path)
	quit()
