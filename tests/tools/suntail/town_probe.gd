extends SceneTree
## Prints a planned town's buildings, features and fabric unit families.
## -s town_probe.gd -- --city 12:compact
const FROZEN := preload("res://tests/fixtures/frozen_maze_source.gd")
func _init() -> void:
	var seed_value := 12; var scale := &"compact"
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--city":
			seed_value = int(args[i + 1].get_slice(":", 0)); scale = StringName(args[i + 1].get_slice(":", 1))
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var source := WarrenMazeSitePlanner.plan(seed_value, {}, WarrenVillageScaleProfile.for_id(scale), &"", false)
	var spatial := FROZEN.spatial(source, program)
	var fabric := spatial.compiled_fabric_cache()
	for b: WarrenBuildingVolume in spatial.buildings:
		var ys := {}
		for c in b.private_cells: ys[c.y] = true
		var kinds := []
		for r in b.room_records: kinds.append("%s@%d%s" % [r.kind, r.lattice_origin.y, "T" if r.terrain_bearing else ""])
		print("BUILDING ", b.stable_id, " cells=", b.private_cells.size(), " bands=", ys.keys(), " rooms=", kinds, " doors=", b.thresholds.size(), " feats=", b.feature_ids)
	for f: WarrenFeatureReservation in spatial.features:
		var ys := {}
		for c in f.reserved_cells: ys[c.y] = true
		var recs := []
		for r in f.construction_records: recs.append(String(r.get("recipe_id", "")))
		print("FEATURE ", f.kind, " ", f.stable_id, " reserved=", f.reserved_cells.size(), " bands=", ys.keys(), " public=", f.public_cells.size(), " recs=", recs)
	var fams := {}
	for u: FabricUnit in fabric.units:
		var id := String(u.stable_id)
		var fam := id.get_slice(".", 0) + "." + id.get_slice(".", 1)
		if id.begins_with("spatial.fabric.") and not id.contains("room"): fam += "." + id.get_slice(".", 2).substr(0, 18)
		fams[fam] = int(fams.get(fam, 0)) + 1
	print("UNIT_FAMILIES ", fams)
	print("SPANS ", SettlementFabricAssembler.maze_skywalk_spans(fabric))
	var bridge_rooms := 0
	for b: WarrenBuildingVolume in spatial.buildings:
		for r in b.room_records:
			if String(r.stable_id).contains("bridge"): bridge_rooms += 1
	print("BRIDGE_ROOMS_IN_BUILDINGS ", bridge_rooms)
	for u: FabricUnit in fabric.units:
		if String(u.stable_id).begins_with("spatial.fabric.spatial"): print("FUNIT ", u.stable_id, " ", u.recipe_id)
	for f: WarrenFeatureReservation in spatial.features:
		if f.kind in [&"balcony", &"room_overhang_support", &"arcade_overhang_support", &"enclosed_skywalk", &"courtyard_bridge_house"]: print("FDATA ", f.kind, " reserved=", f.reserved_cells, " public=", f.public_cells.slice(0,6), " endpoints=", f.endpoints, " recs=", f.construction_records)
		if f.kind == &"prefab_landmark": print("LANDMARK ", f.stable_id, " endpoints=", f.endpoints, " rec=", f.construction_records, " audit=", f.audit)
	var prefixes := {}
	var local := SettlementFabricAssembler.terrace_retaining_payload(fabric, false)
	for asset_id in local.asset_ids():
		for id in local.batches[asset_id].ids:
			var p := String(id).get_slice("/", 0)
			prefixes[p] = int(prefixes.get(p, 0)) + 1
	print("TERRACE_PREFIXES ", prefixes)
	quit()
