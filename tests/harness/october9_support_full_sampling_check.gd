extends "res://tests/harness/october9_water_support_area.gd"


func _run() -> void:
	var reference := GDScript.new()
	reference.source_code = FileAccess.get_file_as_string(
		"res://docs/qa/2026-10-08-manual-pass/source-support-before-node-sampling.gd"
	)
	if reference.reload() != OK:
		quit(1)
		return
	var support: GDScript = load("res://scripts/terrain/water/WaterSourceSupport.gd")
	var source := FileAccess.get_file_as_string("res://scripts/terrain/water/WaterSourceSupport.gd")
	source = source.replace(
		"extends RefCounted", "extends RefCounted\nstatic var test_reference: GDScript"
	)
	source = (
		source
		. replace(
			"\tvar started := Time.get_ticks_usec()",
			"\tvar expected := fine.duplicate(true)\n\ttest_reference.apply(c, region, base, columns, coarse, expected)\n\tvar started := Time.get_ticks_usec()"
		)
	)
	source = (
		source
		. replace(
			"## Equivalent",
			'\tvar same := var_to_bytes(fine) == var_to_bytes(expected)\n\tprint("SOURCE_SUPPORT_FULL_IDENTICAL ", same)\n\tassert(same, "optimized source solve differs from its reference")\n\n\n## Equivalent'
		)
	)
	support.source_code = source
	if support.reload(true) != OK:
		quit(1)
		return
	support.test_reference = reference
	await super._run()
