extends SceneTree
func _init() -> void:
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var a := program.recipe(&"room.row.upper.blue.f")
	var b := program.recipe(&"room.tower.upper.blue.d")
	var ta := FabricRecipe.lattice_transform(Vector3i(5,6,3),1)
	var tb := FabricRecipe.lattice_transform(Vector3i(7,8,1),0)
	for i in a.placements.size():
		for j in b.placements.size():
			var aa := ta*a.placement_bounds[i]
			var bb := tb*b.placement_bounds[j]
			if SettlementFabricPlan._aabb_overlaps_volume(aa,bb):
				print("PAIR ",a.placements[i].id," ",b.placements[j].id," overlap=",aa.intersection(bb))
	quit()
