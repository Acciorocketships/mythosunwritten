class_name TownCharacter
extends RefCounted
## A town's drawn value for every knob, plus deterministic per-decision
## rolls. Every knob has its own stream (town seed x knob name), and every
## roll adds the decision's key, so changing one knob never moves another
## knob's draw or roll.

const FNV_OFFSET := -3750763034362895579  # 0xcbf29ce484222325 as signed int64
const FNV_PRIME := 1099511628211

var town_seed := 0
var size := 0.0
var values: Dictionary = {}
var overridden := false


static func stable_hash(text: String) -> int:
	var h := FNV_OFFSET
	for byte: int in text.to_utf8_buffer():
		h = (h ^ byte) * FNV_PRIME
	return h


static func _unit(h: int) -> float:
	return float(Helper._mix64(h) & 0x1FFFFFFFFFFFFF) / 9007199254740992.0


static func _key_hash(key: Variant) -> int:
	match typeof(key):
		TYPE_INT: return key
		TYPE_VECTOR2I: return key.x * 73856093 ^ key.y * 19349663
		TYPE_VECTOR3I: return key.x * 73856093 ^ key.y * 19349663 ^ key.z * 83492791
		TYPE_VECTOR4I: return key.x * 73856093 ^ key.y * 19349663 ^ key.z * 83492791 ^ key.w * 2654435761
		TYPE_STRING, TYPE_STRING_NAME: return stable_hash(String(key))
	return stable_hash(var_to_str(key))


func _stream(name: StringName, salt := 0) -> int:
	return town_seed ^ stable_hash(String(name)) ^ Helper._mix64(salt)


static func draw(program: TownOddsProgram, p_seed: int, p_size: float) -> TownCharacter:
	var c := TownCharacter.new()
	c.town_seed = p_seed
	c.size = clampf(p_size, 0.0, 1.0)
	c.overridden = not program.overrides.is_empty()
	for name: StringName in program.knobs:
		var knob: Dictionary = program.knobs[name]
		var spread := float(knob.spread)
		match int(knob.kind):
			TownKnob.Kind.WEIGHTS:
				var out := {}
				var total := 0.0
				var options: Array = knob.options
				for i in options.size():
					var centre := lerpf(float(knob.weights_small[i]), float(knob.weights_large[i]), c.size)
					var jitter := 1.0 + spread * (2.0 * _unit(c._stream(name, i + 1)) - 1.0)
					var w := maxf(0.0, centre * jitter)
					out[StringName(options[i])] = w
					total += w
				for option: StringName in out:
					out[option] = float(out[option]) / total if total > 0.0 else 1.0 / float(out.size())
				c.values[name] = out
			TownKnob.Kind.RANGE_INT:
				var centre := lerpf(float(knob.small), float(knob.large), c.size)
				var v := centre + spread * (2.0 * _unit(c._stream(name, 1)) - 1.0)
				c.values[name] = clampf(floorf(v + _unit(c._stream(name, 2))), float(knob.min), float(knob.max))
			_:
				var centre := lerpf(float(knob.small), float(knob.large), c.size)
				var v := centre + spread * (2.0 * _unit(c._stream(name, 1)) - 1.0)
				c.values[name] = clampf(v, float(knob.min), float(knob.max))
	return c


func value(name: StringName) -> float:
	assert(values.has(name), "unknown town knob %s" % name)
	return float(values[name])


func count(name: StringName) -> int:
	return int(value(name))


func weights(name: StringName) -> Dictionary:
	assert(values.has(name), "unknown town knob %s" % name)
	return values[name]


func roll(name: StringName, key: Variant) -> float:
	return _unit(_stream(name) ^ Helper._mix64(_key_hash(key)))


func chance(name: StringName, key: Variant, boost := 1.0) -> bool:
	return roll(name, key) < clampf(value(name) * boost, 0.0, 1.0)


func pick(name: StringName, key: Variant) -> StringName:
	var r := roll(name, key)
	var last := &""
	for option: StringName in weights(name):
		last = option
		r -= float(values[name][option])
		if r < 0.0:
			return option
	return last


func signature_suffix() -> String:
	if not overridden:
		return ""
	return "/odds:" + var_to_str(values).sha256_text().substr(0, 12)


static func attach(profile: WarrenVillageScaleProfile, program: TownOddsProgram,
		p_seed: int) -> TownCharacter:
	profile.character = draw(program, p_seed, profile.size)
	return profile.character


static func of(profile: WarrenVillageScaleProfile, p_seed: int) -> TownCharacter:
	if profile.character != null and profile.character.town_seed == p_seed:
		return profile.character
	return attach(profile, TownOddsProgram.builtin(), p_seed)
