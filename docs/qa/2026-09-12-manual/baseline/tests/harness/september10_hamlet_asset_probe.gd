extends SceneTree
func _init() -> void:
	var program := VillageProgram.compile({}, EnvironmentCatalog.load_default())
	for spec: VillageAssetSpec in program.outskirts_program.house_specs:
		print("HAMLET_ASSET ",spec.asset_id," allowed=",spec.allowed_in(&"hamlet")," bounds=",spec.measured_aabb," ground=",spec.ground_contact_local_rect)
	quit()
