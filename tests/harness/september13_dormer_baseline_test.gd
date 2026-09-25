extends "res://tests/test_settlement_fabric.gd"
func _program() -> SettlementFabricProgram:
	if _compiled_program == null:
		var original := GDScript.new()
		original.source_code = FileAccess.get_file_as_string("res://docs/qa/2026-09-13-manual/41-dormers/program-before.gd.txt").replace("class_name SettlementFabricProgram\n", "")
		assert(original.reload() == OK)
		_compiled_program = original.compile(EnvironmentCatalog.load_default())
	return _compiled_program
