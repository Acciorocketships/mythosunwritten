extends GutTest

func _knob(name: StringName, kind: int, small: float, large: float,
		spread := 0.0, lo := 0.0, hi := 1.0) -> TownKnob:
	var knob := TownKnob.new()
	knob.name = name
	knob.kind = kind
	knob.at_small = small
	knob.at_large = large
	knob.spread = spread
	knob.clamp_min = lo
	knob.clamp_max = hi
	return knob

func _weights(name: StringName, options: PackedStringArray, small: PackedFloat32Array,
		large: PackedFloat32Array, spread := 0.0) -> TownKnob:
	var knob := _knob(name, TownKnob.Kind.WEIGHTS, 0.0, 0.0, spread)
	knob.options = options
	knob.weights_small = small
	knob.weights_large = large
	return knob

func _program(knobs: Array[TownKnob]) -> TownOddsProgram:
	var table := TownOddsTable.new()
	table.knobs = knobs
	var program := TownOddsProgram.compile(table)
	assert_eq(program.errors.size(), 0, str(program.errors))
	return program

func test_spread_zero_is_the_size_blend_and_clamped() -> void:
	var p := _program([_knob(&"a", TownKnob.Kind.RANGE_FLOAT, 0.2, 0.8)])
	assert_almost_eq(TownCharacter.draw(p, 1, 0.5).value(&"a"), 0.5, 1e-6)
	var q := _program([_knob(&"b", TownKnob.Kind.CHANCE, 1.4, 1.4)])
	assert_eq(TownCharacter.draw(q, 1, 0.0).value(&"b"), 1.0)

func test_same_seed_same_values_different_seeds_vary() -> void:
	var p := _program([_knob(&"a", TownKnob.Kind.RANGE_FLOAT, 0.5, 0.5, 0.4)])
	assert_eq(TownCharacter.draw(p, 7, 0.3).value(&"a"), TownCharacter.draw(p, 7, 0.3).value(&"a"))
	var seen := {}
	for seed_value in 50:
		seen[snappedf(TownCharacter.draw(p, seed_value, 0.3).value(&"a"), 0.01)] = true
	assert_gt(seen.size(), 20)

func test_one_knob_change_leaves_other_knobs_and_rolls_untouched() -> void:
	var a := _knob(&"a", TownKnob.Kind.RANGE_FLOAT, 0.5, 0.5, 0.4)
	var before := TownCharacter.draw(_program([a, _knob(&"b", TownKnob.Kind.CHANCE, 0.3, 0.3, 0.1)]), 11, 0.4)
	var after := TownCharacter.draw(_program([_knob(&"z", TownKnob.Kind.CHANCE, 0.9, 0.9), a,
		_knob(&"b", TownKnob.Kind.CHANCE, 0.6, 0.6, 0.3)]), 11, 0.4)
	assert_eq(before.value(&"a"), after.value(&"a"))
	for key in 200:
		assert_eq(before.roll(&"a", Vector3i(key, 2, 3)), after.roll(&"a", Vector3i(key, 2, 3)))

func test_range_int_mean_matches_fractional_centre() -> void:
	var p := _program([_knob(&"n", TownKnob.Kind.RANGE_INT, 0.25, 0.25, 0.0, 0.0, 10.0)])
	var total := 0
	for seed_value in 4000:
		total += TownCharacter.draw(p, seed_value, 0.0).count(&"n")
	assert_almost_eq(float(total) / 4000.0, 0.25, 0.03)

func test_weights_normalised_and_centre_without_spread() -> void:
	var p := _program([_weights(&"w", PackedStringArray(["x", "y"]),
		PackedFloat32Array([1.0, 3.0]), PackedFloat32Array([1.0, 3.0]))])
	var w := TownCharacter.draw(p, 5, 0.5).weights(&"w")
	assert_almost_eq(float(w[&"x"]), 0.25, 1e-6)
	assert_almost_eq(float(w[&"y"]), 0.75, 1e-6)

func test_chance_extremes_and_boost() -> void:
	var p := _program([_knob(&"one", TownKnob.Kind.CHANCE, 1.0, 1.0),
		_knob(&"zero", TownKnob.Kind.CHANCE, 0.0, 0.0),
		_knob(&"half", TownKnob.Kind.CHANCE, 0.25, 0.25)])
	var c := TownCharacter.draw(p, 3, 0.0)
	var boosted := 0
	for key in 1000:
		assert_true(c.chance(&"one", key))
		assert_false(c.chance(&"zero", key))
		if c.chance(&"half", key, 4.0): boosted += 1
	assert_eq(boosted, 1000, "0.25 x 4 clamps to certainty")

func test_overrides_fix_value_and_mark_character() -> void:
	var p := _program([_knob(&"a", TownKnob.Kind.RANGE_FLOAT, 0.2, 0.8, 0.3)])
	var c := TownCharacter.draw(p.with_overrides({&"a": 0.7}), 9, 0.1)
	assert_almost_eq(c.value(&"a"), 0.7, 1e-6)
	assert_true(c.overridden)
	assert_true(c.signature_suffix().begins_with("/odds:"))
	assert_eq(TownCharacter.draw(p, 9, 0.1).signature_suffix(), "")

func test_compile_reports_bad_knobs() -> void:
	var table := TownOddsTable.new()
	var bad := _weights(&"w", PackedStringArray(["x", "y"]), PackedFloat32Array([1.0]), PackedFloat32Array([1.0, 2.0]))
	var inverted := _knob(&"i", TownKnob.Kind.RANGE_FLOAT, 0.5, 0.5, 0.0, 2.0, 1.0)
	table.knobs = [_knob(&"d", TownKnob.Kind.CHANCE, 0.5, 0.5), _knob(&"d", TownKnob.Kind.CHANCE, 0.5, 0.5), bad, inverted]
	var errors := " ".join(TownOddsProgram.compile(table).errors)
	assert_push_error("duplicate knob d")
	assert_push_error("knob w needs")
	assert_push_error("knob i has")
	assert_string_contains(errors, "duplicate knob d")
	assert_string_contains(errors, "knob w")
	assert_string_contains(errors, "knob i")

func test_parse_overrides_rejects_unknown_and_non_numeric() -> void:
	var p := _program([_knob(&"a", TownKnob.Kind.CHANCE, 0.5, 0.5)])
	assert_eq(TownOddsProgram.parse_overrides(PackedStringArray(["--odds", "a=0.3"]), p), {&"a": 0.3})
	assert_true(TownOddsProgram.parse_overrides(PackedStringArray(["--odds", "nope=1"]), p).has("error"))
	assert_push_error("unknown --odds knob")
	assert_true(TownOddsProgram.parse_overrides(PackedStringArray(["--odds", "a=lots"]), p).has("error"))
	assert_push_error("needs a number")

func test_builtin_table_compiles_cleanly() -> void:
	assert_eq(TownOddsProgram.builtin().errors.size(), 0)
