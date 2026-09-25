extends SceneTree
func _init() -> void:
	var rows: Array[Dictionary] = []
	for seed_value: int in [8922681140531148375,1,2,3,4,5,6,7,8,9,10,11,12]:
		var source := WarrenMazeSitePlanner.plan(seed_value,{},WarrenVillageScaleProfile.for_id(&"compact"))
		var spans: Array[Dictionary] = []
		for proof: Dictionary in source.excavation.bridge_span_audit.seeded:
			var compound := WarrenMazeCarver._bridge_proof_columns(proof)
			var groups: Array[Dictionary] = []
			for group: Array in proof.endpoint_groups:
				var neighbors: Array[Dictionary] = []
				for col: Vector2i in group:
					for dir: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
						var near := col+dir
						if compound.has(near): continue
						var plots: Array[Dictionary] = []
						for plot: Dictionary in source.plots:
							if near in plot.get("cells",[]): plots.append(plot)
						neighbors.append({"col":str(near),"mass_top":source.massif.top_at(near),"plots":plots})
				groups.append({"cells":str(group),"neighbors":neighbors})
			spans.append({"floor":proof.floor,"groups":groups,"proof":proof})
		rows.append({"seed":seed_value,"spans":spans})
	var args := OS.get_cmdline_user_args()
	var output := args[args.find("--output")+1]
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	print("SKYWALK_NEIGHBORHOODS ",output)
	quit()
