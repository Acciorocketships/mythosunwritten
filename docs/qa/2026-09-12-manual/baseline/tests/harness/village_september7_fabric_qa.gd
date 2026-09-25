extends SceneTree

## Fast diagnosis of the pinned construction; acceptance still uses the streamed
## village_september7_qa scene. Input is the resource-free production probe.
func _init() -> void: call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1718,1035)
	Engine.max_fps = 30
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("/tmp/village-september7-probe.json"))
	var catalog := EnvironmentCatalog.load_default()
	var program := SettlementFabricProgram.compile(catalog)
	var plan := SettlementFabricPlan.new(&"september7.fast.junctions")
	plan.set_asset_visual_bounds(program.asset_visual_bounds)
	var world_pose := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*2),Vector3(238.5,8.08,-365.5))
	for fact: Dictionary in report.units:
		var recipe := program.recipe(StringName(fact.recipe))
		if recipe == null or not recipe.has_tag(&"room"): continue
		plan.register_recipe(recipe)
		var pose := world_pose.affine_inverse()*_pose(fact.world)
		var yaw := posmod(roundi(atan2(pose.basis.z.x,pose.basis.z.z)/(PI*0.5)),4)
		var unit := FabricUnit.new(StringName(fact.id),recipe.recipe_id,Vector3i((pose.origin/1.5).round()),yaw)
		unit.suppressed_placement_ids.assign(fact.suppressed)
		plan.append_constructed_unit(unit)
	plan._assign_facade_corner_joints()
	var replacements: Dictionary = {}
	for unit: FabricUnit in plan.units:
		var recipe := plan.recipe(unit.recipe_id)
		for panel: Dictionary in recipe.placements:
			replacements["%s/%s" % [unit.stable_id,panel.id]] = {"recipe":recipe,"unit":unit,"panel":panel}
	var stage := Node3D.new()
	root.add_child(stage)
	var world: Node = (load("res://scenes/world.tscn") as PackedScene).instantiate()
	var character := world.find_child("Character",true,false) as CharacterBody3D
	character.get_parent().remove_child(character)
	character.owner = null
	stage.add_child(character)
	character.set_physics_process(false)
	for child in world.get_children():
		if child is WorldEnvironment or child is DirectionalLight3D:
			world.remove_child(child)
			child.owner = null
			stage.add_child(child)
	world.free()
	for entry: Dictionary in report.entries:
		var id := String(entry.id).trim_prefix("settlement.29bc5c240c52f84a/")
		if id.begins_with("facade-joint/") or id.begins_with("masonry-joint/"): continue
		var asset := StringName(entry.asset)
		if replacements.has(id):
			var value: Dictionary = replacements[id]
			asset = (value.recipe as FabricRecipe).realized_facade_asset(value.panel,
				value.unit.suppressed_placement_ids,String(asset).ends_with(".course_open"),
				int(value.unit.square_corner_end_masks.get(value.panel.id,0)))
		_add(stage,catalog,asset,_pose(entry.transform))
	for joint: Dictionary in plan.facade_corner_placements:
		print("JOINT ",joint)
		_add(stage,catalog,joint.asset_id,world_pose*joint.transform)
	var transaction: Dictionary = str_to_var(FileAccess.get_file_as_string("/tmp/september7-skin-transaction.txt"))
	var returns := SettlementFabricAssembler.masonry_room_returns(transaction.retained,plan.inhabited_room_cells(),transaction.walked)
	for asset: StringName in returns.batches:
		for pose: Transform3D in returns.batches[asset].transforms: _add(stage,catalog,asset,world_pose*pose)
	var enclosed: Dictionary = transaction.solids.duplicate()
	enclosed.merge(plan.inhabited_room_cells())
	var joints := SettlementFabricAssembler.masonry_corner_joints(transaction.retained,enclosed)
	for asset: StringName in joints.batches:
		for pose: Transform3D in joints.batches[asset].transforms: _add(stage,catalog,asset,world_pose*pose)
	print("MASONRY_RETURNS ",returns.instance_count)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.current = true
	var output := "/tmp/september7-fast"
	var args := OS.get_cmdline_user_args()
	if args.size()>0: output=args[0]
	DirAccess.make_dir_recursive_absolute(output)
	var harness := load("res://tests/harness/village_september7_qa.gd").new() as Node3D
	var spots: Array = harness._spots()
	harness.free()
	for spot: Array in spots:
		character.position=spot[2]
		var original := ReviewCam.solve_cam(spot[2],spot[3])
		for angle in [0.0,-90.0,90.0,180.0]:
			camera.position=Vector3(spot[2])+(original-Vector3(spot[2])).rotated(Vector3.UP,deg_to_rad(angle))
			camera.look_at(spot[2])
			for frame in 5: await process_frame
			RenderingServer.force_draw()
			await process_frame
			root.get_texture().get_image().save_png(output+"/"+spot[0]+"_"+str(int(angle))+".png")
	print("FAST_JUNCTION_REVIEW joints=",plan.facade_corner_placements.size()," output=",output)
	quit()

func _add(stage: Node3D,catalog: EnvironmentCatalog,asset: StringName,pose: Transform3D) -> void:
	var visual: EnvironmentVisual = load(catalog.descriptor(asset).visual_path)
	for piece: EnvironmentVisualPiece in visual.pieces:
		var mesh := MeshInstance3D.new()
		mesh.mesh=piece.mesh
		mesh.material_override=piece.material_override
		mesh.transform=pose*piece.local_transform
		stage.add_child(mesh)

func _pose(value: String) -> Transform3D:
	var regex := RegEx.new()
	regex.compile("-?[0-9]+\\.[0-9]+")
	var f: Array[float] = []
	for m: RegExMatch in regex.search_all(value): f.append(m.get_string().to_float())
	return Transform3D(Basis(Vector3(f[0],f[1],f[2]),Vector3(f[3],f[4],f[5]),Vector3(f[6],f[7],f[8])),Vector3(f[9],f[10],f[11]))
