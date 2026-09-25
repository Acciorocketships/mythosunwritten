extends SceneTree
func _init() -> void:
	var cell := Vector2i(55,15)
	var args := OS.get_cmdline_user_args()
	if args.size() >= 2: cell=Vector2i(int(args[0]),int(args[1]))
	var seed_value := VillagePlan.warren_seed_for_cell(2697992464,cell)
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var spatial := WarrenVolumetricSolver.solve(seed_value,{},program,WarrenVillageScaleProfile.select(seed_value))
	if spatial == null:
		print("JOIN source failed ",WarrenVolumetricSolver.last_failure)
		print("JOIN detail ",WarrenVolumetricSolver.last_preplan_market_diagnostic)
		quit(1)
		return
	var plan := spatial.compiled_fabric_cache()
	var conflict := plan._continuous_roof_realization_conflict()
	print("JOIN conflict=",conflict)
	for synthetic: Dictionary in plan.continuous_roof_plan.synthetic_placements:
		if not conflict.begins_with(str(synthetic.stable_id)): continue
		print("JOIN synthetic=",synthetic)
		for unit: FabricUnit in plan.units:
			var recipe := plan.recipe(unit.recipe_id)
			for index in recipe.placements.size():
				var place: Dictionary = recipe.placements[index]
				if conflict.ends_with("%s/%s" % [unit.stable_id,place.id]):
					print("JOIN other unit=",unit.stable_id," recipe=",recipe.recipe_id," origin=",unit.lattice_origin," yaw=",unit.yaw_quarters," placement=",place," bounds=",unit.transform()*recipe.placement_bounds[index], " parents=",unit.parent_ids," seams=",unit.visual_seam_ids)
			if unit.stable_id in synthetic.get("roof_component_unit_ids",[]):
				print("JOIN roof unit=",unit.stable_id," recipe=",recipe.recipe_id," origin=",unit.lattice_origin," yaw=",unit.yaw_quarters," parents=",unit.parent_ids," seams=",unit.visual_seam_ids)
	quit()
