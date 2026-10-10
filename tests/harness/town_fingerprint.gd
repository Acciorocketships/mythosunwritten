extends SceneTree
## Byte-identity fingerprints for whole towns. A town's source plan (plots,
## passages, stamps, excavation) and its complete flat-ground payload are
## hashed incrementally with var_to_bytes, so identical generation gives
## identical hashes and any change in geometry, placement or dressing shows.

const REVIEW := preload("res://tests/harness/suntail/kit_town_review.gd")
const OLD_LOOK := preload("res://tests/fixtures/town_old_look.gd")
const DEFAULT_TOWNS := "53:grand,31:large,13:standard,43:large,83:grand,103:standard,7:compact,61:standard"

func _init() -> void:
	call_deferred("_run")

func _arg(args: PackedStringArray, name: String, fallback: String) -> String:
	var i := args.find(name)
	return args[i + 1] if i >= 0 and i + 1 < args.size() else fallback

static func _hash_values(values: Array) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	for value: Variant in values:
		ctx.update(var_to_bytes(value))
	return ctx.finish().hex_encode()

## The source-plan hash pinned by baseline.json / old_look_baseline.json.
static func source_hash_of(source: WarrenMazeSourcePlan) -> String:
	return _hash_values([source.plots, source.passage_kinds,
		source.feature_stamps, source.market_square_cells, source.summit_cell,
		source.excavation.carved, source.excavation.lanes,
		source.excavation.tunnel_cells, source.excavation.construction_reservations])

func _payload_hash(payload: EnvironmentInstancePayload) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	for id: Variant in payload.batches:
		ctx.update(var_to_bytes(id))
		ctx.update(var_to_bytes(payload.batches[id]))
	for box: Dictionary in payload.collision_boxes:
		ctx.update(var_to_bytes(box))
	for mesh: Dictionary in payload.surface_meshes:
		ctx.update(var_to_bytes(mesh))
	for skirt: Dictionary in payload.ground_skirts:
		ctx.update(var_to_bytes(skirt))
	return ctx.finish().hex_encode()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var towns := _arg(args, "--towns", DEFAULT_TOWNS).split(",")
	var out_path := _arg(args, "--out", "/tmp/town_fingerprint.json")
	var compare_path := _arg(args, "--compare", "")
	# --parts source compares source-plan hashes only (e.g. the old-look pin,
	# whose payloads legitimately differ: dark-wood lamps).
	var compare_parts := _arg(args, "--parts", "source,payload,error").split(",")
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	var overrides := TownOddsProgram.parse_overrides(args, program.town_odds)
	if overrides.has("error"):
		push_error(String(overrides.error))
		quit(2)
		return
	# --old-look builds every town under the pre-taste knob values
	# (tests/fixtures/town_old_look.gd); --odds still overrides on top.
	if args.has("--old-look"):
		overrides = OLD_LOOK.merge(overrides)
	if not overrides.is_empty():
		program.town_odds = program.town_odds.with_overrides(overrides)
	var results := {}
	for town: String in towns:
		var parts := town.split(":")
		var started := Time.get_ticks_msec()
		var profile := WarrenVillageScaleProfile.for_id(StringName(parts[1]))
		var spatial := WarrenVolumetricSolver.generate(int(parts[0]), {}, program, profile)
		if profile.character != null:
			print("TOWN_CHARACTER ", town, " ", JSON.stringify(profile.character.values))
		if spatial == null:
			results[town] = {"error": "no town"}
			print("FINGERPRINT_NO_TOWN ", town)
			continue
		var source := spatial.source_volume.mass_context.get(&"maze_source_plan") as WarrenMazeSourcePlan
		print("CLEARINGS ", town, " ", source.excavation.court_clearings.size(), " ", JSON.stringify(
			source.excavation.court_clearings.map(func(c: Dictionary) -> Dictionary:
				return {"floor": c.floor, "cells": (c.cells as Array).size(), "links": c.links,
					"shape": c.shape, "purpose": c.purpose})))
		var clearing_plots := source.plots.filter(func(p: Dictionary) -> bool:
			return WarrenPlotReservations.is_clearing_plot(p))
		print("CLEARING_PLOTS ", town, " ", clearing_plots.size(), " ", JSON.stringify(
			clearing_plots.map(func(p: Dictionary) -> Dictionary:
				return {"id": p.id, "floor": p.floor, "cells": (p.cells as Array).size(),
					"purpose": p.get("purpose", &""), "green": WarrenPlotReservations.is_green_court(p)})),
			" ", JSON.stringify(WarrenPlotPlanner.outcomes(source).get("clearings", [])))
		var fabric := spatial.compiled_fabric_cache()
		var source_hash := source_hash_of(source)
		var payload := REVIEW.town_payload(spatial, fabric, false)
		results[town] = {"source": source_hash, "payload": _payload_hash(payload),
			"ms": Time.get_ticks_msec() - started}
		print("FINGERPRINT ", town, " ", JSON.stringify(results[town]))
		if not overrides.is_empty():
			# Read-only diagnostics, after hashing: one centre feature per green.
			var facts := WarrenSpatialFabricCompiler.construction_diagnostics(spatial, fabric, program)
			print("GREEN_FEATURES ", town, " greens=", facts.get("maze_green_component_count", 0),
				" ", JSON.stringify(facts.get("maze_plaza_centre_features", [])))
	var file := FileAccess.open(out_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "  "))
	file.close()
	if compare_path.is_empty():
		quit(0)
		return
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(compare_path))
	var ok := true
	for town: String in towns:
		for part: String in compare_parts:
			if str((expected.get(town, {}) as Dictionary).get(part, "")) \
					!= str((results.get(town, {}) as Dictionary).get(part, "")):
				print("FINGERPRINT_MISMATCH ", town, " ", part)
				ok = false
	print("FINGERPRINT_MATCH" if ok else "FINGERPRINT_DIFFERS")
	quit(0 if ok else 1)
