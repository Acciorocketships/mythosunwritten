extends GutTest
## Old-look reachability (Oct 7 taste knobs): the pre-taste knob values
## (tests/fixtures/town_old_look.gd) rebuild the source plans of d912cd332,
## the commit before the taste work. Full 8-town check (slow):
##   godot --headless --path . -s res://tests/harness/town_fingerprint.gd -- --old-look \
##     --compare res://docs/qa/2026-10-07-town-odds/fingerprint/old_look_baseline.json --parts source
## Payloads are not pinned: lamps are dark wood now in every town.

const OLD := preload("res://tests/fixtures/town_old_look.gd")
const FINGERPRINT := preload("res://tests/harness/town_fingerprint.gd")
const BASELINE := "res://docs/qa/2026-10-07-town-odds/fingerprint/old_look_baseline.json"


func test_old_values_rebuild_the_pre_taste_source_plans() -> void:
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASELINE))
	var program := SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
	program.town_odds = program.town_odds.with_overrides(OLD.merge())
	# The two fastest fingerprint towns; the harness command covers all eight.
	for town: String in ["7:compact", "103:standard"]:
		var parts := town.split(":")
		var spatial := WarrenVolumetricSolver.generate(int(parts[0]), {}, program,
			WarrenVillageScaleProfile.for_id(StringName(parts[1])))
		assert_not_null(spatial, town)
		if spatial == null: continue
		var source := spatial.source_volume.mass_context.get(&"maze_source_plan") as WarrenMazeSourcePlan
		assert_eq(FINGERPRINT.source_hash_of(source), String(expected[town].source), town)
