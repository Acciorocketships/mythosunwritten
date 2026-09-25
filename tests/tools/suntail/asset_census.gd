extends SceneTree
## Counts non-kit assets and surface meshes left in a kit-built town payload.
## -s asset_census.gd -- --city 3:standard
const FROZEN := preload("res://tests/fixtures/frozen_maze_source.gd")
const REVIEW := preload("res://tests/harness/suntail/kit_town_review.gd")
func _init() -> void:
	var seed_value := 3; var scale := &"standard"
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--city":
			seed_value = int(args[i + 1].get_slice(":", 0)); scale = StringName(args[i + 1].get_slice(":", 1))
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var source := WarrenMazeSitePlanner.plan(seed_value, {}, WarrenVillageScaleProfile.for_id(scale), &"", false)
	var spatial := FROZEN.spatial(source, program)
	var fabric := spatial.compiled_fabric_cache()
	var payload: EnvironmentInstancePayload = REVIEW.town_payload(spatial, fabric, false)
	var rows := []
	for asset_id in payload.asset_ids():
		if String(asset_id).begins_with("suntail."): continue
		var batch: Dictionary = payload.batches[asset_id]
		var prefixes := {}
		for id in batch.ids: prefixes[String(id).get_slice("/", 0).substr(0, 40)] = true
		rows.append("%5d %s  %s" % [batch.transforms.size(), asset_id, str(prefixes.keys().slice(0, 3))])
	rows.sort()
	rows.reverse()
	for r in rows: print("LEGACY ", r)
	for asset_id in payload.asset_ids():
		if String(asset_id).contains("roof"):
			for id in payload.batches[asset_id].ids: print("ROOFID ", asset_id, " ", id)
	var meshes := {}
	for m in payload.surface_meshes:
		var p := String(m.get("stable_id", "")).get_slice("/", 0).substr(0, 30)
		meshes[p] = int(meshes.get(p, 0)) + 1
	print("SURFACES ", meshes)
	quit()
