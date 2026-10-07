extends SceneTree
func _init() -> void:
	for town in [[1,&"compact"],[2,&"compact"],[3,&"compact"],[4,&"compact"],[5,&"compact"],[6,&"standard"],[8,&"standard"],[9,&"standard"],[10,&"standard"],[11,&"standard"],[12,&"compact"]]:
		var p := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
		p.town_odds = p.town_odds.with_overrides({&"satellite_reach_scale":0.6,&"suburb_house_count":4.0,&"lone_house_path_chance":0.0})
		var profile := WarrenVillageScaleProfile.for_id(town[1])
		var s := WarrenVolumetricSolver.generate(town[0], {}, p, profile)
		var src: WarrenMazeSourcePlan = s.source_volume.mass_context.get(&"maze_source_plan") if s != null else null
		var sub := 0
		var foot := 0
		if src != null:
			for l in src.excavation.lanes: if l.get("feature_kind") == &"house_site_footway": foot += 1
		print("SWEEP ", town, " ok=", s != null, " footways=", foot, " fail=", WarrenVolumetricSolver.last_failure.substr(0, 300))
	quit()
