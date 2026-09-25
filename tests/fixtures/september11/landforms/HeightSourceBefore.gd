extends RefCounted
const LandformField = preload("res://tests/fixtures/september11/landforms/LandformBefore.gd")

static func height01(pos: Vector3, p_world_seed: int, include_detail: bool = true) -> float:
	var base: float = Helper._value_noise01(pos, p_world_seed, 320.0)
	var hills: float = Helper._value_noise01(pos, p_world_seed + 5, 120.0)
	var h: float
	if include_detail:
		var detail: float = Helper._value_noise01(pos, p_world_seed + 9, 46.0)
		h = (base + hills * 0.5 + detail * 0.25) / 1.75
	else:
		h = (base + hills * 0.5) / 1.5
	var rocky: float = Helper.biome_rocky01(pos, p_world_seed)
	h *= 0.35 + 1.5 * rocky
	if rocky > 0.5:
		# Ridged noise (sharp peaks) for mountain spines in rocky cores.
		var n: float = Helper._value_noise01(pos, p_world_seed + 17, 190.0)
		var ridge: float = 1.0 - absf(2.0 * n - 1.0)
		h += ridge * ridge * (rocky - 0.5) * 0.9
	h = lerpf(h, LandformField.height01(pos, p_world_seed), 0.7)
	var falloff: float = SlopeProfile.smootherstep(clampf((Vector2(pos.x, pos.z).length() - 60.0) / 180.0, 0.0, 1.0))
	return clampf(h * falloff, 0.0, 1.0)

