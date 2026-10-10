extends SceneTree
## Resource-free source admission census. Optional --cities seed:profile,...
func _init() -> void:
	var jobs: Array = [[1260018864828801968,&"compact"],
		[1998423929946073270,&"compact"],[3,&"standard"],[6,&"large"]]
	var args := OS.get_cmdline_user_args()
	if args.has("--cities"):
		jobs.clear()
		for value in args[args.find("--cities")+1].split(","):
			var parts := value.split(":")
			jobs.append([int(parts[0]),StringName(parts[1])])
	for job: Array in jobs:
		var source := WarrenMazeSitePlanner.plan(job[0],{},WarrenVillageScaleProfile.for_id(job[1]),&"",false)
		if source == null:
			print(JSON.stringify({"seed":job[0],"profile":job[1],"failed":true}))
			continue
		var assets: Array = WarrenPlotPlanner.outcomes(source).get("assets",[])
		var admitted := 0
		for asset: Dictionary in assets: admitted += int(bool(asset.realisable))
		print(JSON.stringify({"seed":job[0],"profile":job[1],"admitted":admitted,
			"preselected":source.audit.get("preselected_landmarks",[]).size(),
			"quota":assets.size(),"assets":assets}))
	quit()
