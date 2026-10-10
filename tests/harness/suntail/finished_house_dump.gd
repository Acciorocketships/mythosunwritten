extends SceneTree
func _init() -> void: call_deferred("_run")
func _run() -> void:
	var args:=OS.get_cmdline_user_args()
	var seed_value:=int(args[args.find("--seed")+1]) if args.has("--seed") else 31
	var profile:=StringName(args[args.find("--profile")+1]) if args.has("--profile") else &"large"
	var program:=SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var spatial:=WarrenVolumetricSolver.generate(seed_value,{},program,WarrenVillageScaleProfile.for_id(profile))
	assert(spatial!=null,WarrenVolumetricSolver.last_failure)
	var built:=KitVillageBuildings.build(spatial,spatial.compiled_fabric_cache(),SuntailBuildingKit.create())
	var output:={"houses":{},"rooms":{}}
	for mass:BuildingMass in built.houses:
		var floors:=[]
		for floor:Dictionary in mass.storeys:
			floors.append({"band":floor.floor_band,"cells":floor.cells.keys(),"openings":floor.openings,"loggia":floor.get("loggia",false),"stepped_wing":floor.get("stepped_wing",false)})
		output.houses[mass.stable_id]={"seed":mass.seed,"floors":floors}
	for building:WarrenBuildingVolume in spatial.buildings:
		for room:WarrenRoomStamp in building.room_records:
			output.rooms[room.stable_id]={"source":room.source_parcel_id,"audit":room.audit,"cells":room.private_cells}
	FileAccess.open(args[args.find("--output")+1],FileAccess.WRITE).store_string(JSON.stringify(output,"\t"))
	quit()
