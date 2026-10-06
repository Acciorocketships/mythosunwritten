extends "res://tests/harness/suntail/building_gallery.gd"
## Isolate the FINISHED town payload, including clipped native roof meshes.
func _run() -> void:
	get_root().size=Vector2i(1600,1000)
	var kit := SuntailBuildingKit.create()
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var args := OS.get_cmdline_user_args()
	var profile := StringName(args[args.find("--profile")+1]) if args.has("--profile") else &"large"
	var spatial := WarrenVolumetricSolver.generate(_seed,{},program,WarrenVillageScaleProfile.for_id(profile))
	var built := KitVillageBuildings.build(spatial,spatial.compiled_fabric_cache(),kit)
	print("TOWER_AUDIT ",built.roof_audit.towers)
	var targets: Array[StringName]=[]
	for mass: BuildingMass in built.masses:
		if mass.storeys.any(func(s:Dictionary)->bool:return s.get("stepped_wing",false)):
			targets.append(mass.stable_id)
	if args.has("--roof-turrets"):
		targets.clear()
		for tower: Dictionary in built.towers:
			print("TOWER ",tower.host.stable_id," ",tower.attachment," ",tower.pose.origin," courses=",tower.storeys)
			if tower.attachment==&"roof": targets.append(tower.host.stable_id)
	if args.has("--hosts"):
		targets.clear()
		for id: String in args[args.find("--hosts")+1].split(","): targets.append(StringName(id))
	for host: StringName in targets:
		var payload := EnvironmentInstancePayload.new()
		for id: StringName in built.payload.batches:
			var batch: Dictionary = built.payload.batches[id]
			for index in batch.ids.size():
				if String(batch.ids[index]).begins_with(String(host)+"/"):
					payload.add(id,batch.transforms[index],batch.colors[index],batch.ids[index])
		for mesh: Dictionary in built.payload.surface_meshes:
			if String(mesh.stable_id).begins_with(String(host)+"/"): payload.add_surface_mesh(mesh)
		# Finished town geometry has party walls and roofs culled against its
		# neighbors. Context is required to judge those contacts; isolating the
		# payload alone exposes intentional internal omissions as apparent holes.
		# Include public decks and bridges too: the building batch is not a town.
		if args.has("--context"):
			payload = preload("res://tests/harness/suntail/kit_town_review.gd").town_payload(
				spatial,spatial.compiled_fabric_cache(),false)
		var stage := _stage()
		await _commit(stage,payload)
		var box := AABB()
		var first := true
		for mass: BuildingMass in built.masses:
			if mass.stable_id!=host:continue
			for floor: Dictionary in mass.storeys:
				for cell: Vector2i in floor.cells:
					var bounds := KitVillageBuildings.native_to_lattice(kit)*AABB(Vector3(cell.x*2,floor.floor_band*1.5,cell.y*2),Vector3(2,3,2))
					box=bounds if first else box.merge(bounds)
					first=false
		for tower: Dictionary in built.towers:
			if tower.host.stable_id==host: box=box.merge(KitVillageBuildings.native_to_lattice(kit)*tower.bounds)
		var centre := box.get_center()+Vector3.UP
		var reach := box.size.length()*1.5
		for side in [-1,1]:
			await _shoot(stage,centre+Vector3(side*.8,.5,1)*reach,centre,String(host)+("_context" if args.has("--context") else "")+"_%d"%side,50)
		print("ISOLATED ",host," parts=",payload.instance_count," meshes=",payload.surface_meshes.size())
		stage.queue_free()
		await process_frame
	quit()
