class_name TownOddsProgram
extends RefCounted
## Plain-data compilation of a TownOddsTable, safe to hand to the worker.

const BUILTIN_PATH := "res://terrain/villages/town_odds.tres"
static var _builtin: TownOddsProgram

var knobs: Dictionary = {}
var errors: PackedStringArray = PackedStringArray()
var overrides: Dictionary = {}


static func compile(table: TownOddsTable) -> TownOddsProgram:
	var program := TownOddsProgram.new()
	for knob: TownKnob in table.knobs:
		var label := String(knob.name)
		if label.is_empty():
			program.errors.append("knob with an empty name")
			continue
		if program.knobs.has(knob.name):
			program.errors.append("duplicate knob %s" % label)
			continue
		if knob.clamp_min > knob.clamp_max:
			program.errors.append("knob %s has clamp_min above clamp_max" % label)
			continue
		if knob.kind == TownKnob.Kind.WEIGHTS and (knob.options.is_empty() \
				or knob.weights_small.size() != knob.options.size() \
				or knob.weights_large.size() != knob.options.size()):
			program.errors.append("knob %s needs one small and one large weight per option" % label)
			continue
		program.knobs[knob.name] = {"kind": int(knob.kind), "small": knob.at_small,
			"large": knob.at_large, "spread": knob.spread, "min": knob.clamp_min,
			"max": knob.clamp_max, "options": Array(knob.options),
			"weights_small": Array(knob.weights_small), "weights_large": Array(knob.weights_large)}
	for message: String in program.errors:
		push_error("town odds: " + message)
	return program


static func builtin() -> TownOddsProgram:
	if _builtin == null:
		_builtin = compile(load(BUILTIN_PATH) as TownOddsTable)
	return _builtin


func with_overrides(values: Dictionary) -> TownOddsProgram:
	var copy := TownOddsProgram.new()
	copy.knobs = knobs.duplicate(true)
	copy.errors = errors.duplicate()
	copy.overrides = overrides.duplicate()
	for name: StringName in values:
		var knob: Dictionary = copy.knobs[name]
		knob["small"] = float(values[name])
		knob["large"] = float(values[name])
		knob["spread"] = 0.0
		copy.overrides[name] = float(values[name])
	return copy


static func parse_overrides(args: PackedStringArray, program: TownOddsProgram) -> Dictionary:
	var out := {}
	for i in args.size() - 1:
		if args[i] != "--odds":
			continue
		var pair := args[i + 1].split("=")
		var name := StringName(pair[0])
		if pair.size() != 2 or not program.knobs.has(name):
			var message := "unknown --odds knob '%s'; valid: %s" % [pair[0], ", ".join(program.knobs.keys())]
			push_error(message)
			return {"error": message}
		if not pair[1].is_valid_float():
			var message := "--odds %s needs a number, got '%s'" % [pair[0], pair[1]]
			push_error(message)
			return {"error": message}
		out[name] = float(pair[1])
	return out
