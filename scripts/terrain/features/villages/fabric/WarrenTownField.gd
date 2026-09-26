extends RefCounted

## A continuous family of town envelopes. Independently sampled elliptical
## lobes determine density, gaps and height BEFORE any street is bored. Low
## connective shoulders keep the route domain connected without filling the
## space between clusters with tall blocks. Missing columns are deliberate air.
static func sample(seed_value: int, profile: WarrenVillageScaleProfile) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, &"town-field"])
	var radius := float(profile.radius_cells)
	var spread := rng.randf_range(0.65, 1.45)
	var density := rng.randf_range(0.35, 1.0)
	var phase := rng.randf() * TAU
	var core := rng.randf_range(profile.core_target_band_range.x, profile.core_target_band_range.y)
	var lobes: Array[Dictionary] = [{"centre": Vector2.ZERO,
		"width": Vector2(radius * rng.randf_range(0.65, 0.9), radius * rng.randf_range(0.6, 0.85)),
		"height": core, "angle": phase}]
	var count := rng.randi_range(2, 5)
	for i in count:
		var angle := phase + TAU * (float(i) + rng.randf_range(-0.15, 0.15)) / float(count)
		lobes.append({"centre": Vector2.from_angle(angle) * radius * spread * rng.randf_range(0.65, 1.15),
			"width": Vector2(maxf(2.25, radius * density * rng.randf_range(0.5, 0.85)),
				maxf(2.25, radius * density * rng.randf_range(0.4, 0.7))),
			"height": rng.randf_range(4.0, core), "angle": angle + rng.randf_range(-0.8, 0.8)})
	# Broad voids are part of the same sampled field, not streets widened after
	# houses were chosen. Their strength varies continuously down to zero.
	var court_angle := phase + rng.randf_range(0.5, 2.5)
	var court := Vector2.from_angle(court_angle) * radius * rng.randf_range(0.5, 1.05)
	var court_width := radius * rng.randf_range(0.25, 0.5)
	var openness := rng.randf()
	var solid := {}
	var air := {}
	var extent := ceili(radius * 2.5)
	for z in range(-extent, extent + 1):
		for x in range(-extent, extent + 1):
			var p := Vector2(x, z)
			var raw := 0.0
			for lobe: Dictionary in lobes:
				var q := (p - (lobe.centre as Vector2)).rotated(-float(lobe.angle)) / (lobe.width as Vector2)
				raw = maxf(raw, float(lobe.height) * exp(-q.length_squared() * 1.4))
			var court_q := p.distance_to(court) / court_width
			raw *= 1.0 - openness * exp(-pow(court_q, 4.0))
			for lobe: Dictionary in lobes.slice(1):
				var centre := lobe.centre as Vector2
				var along := clampf(p.dot(centre) / centre.length_squared(), 0.0, 1.0)
				var distance := p.distance_to(centre * along)
				raw = maxf(raw, 3.4 * exp(-distance * distance / 2.25))
			# Gentle coherent boundary roughness, shared by every height layer.
			var noise := WarrenMassifBuilder._value_noise(seed_value, 0x51A, Vector2i(x, z), 4)
			raw *= lerpf(0.82, 1.18, noise)
			if raw >= WarrenMassifBuilder.MIN_COLUMN_BANDS:
				solid[Vector2i(x, z)] = raw
			else:
				air[Vector2i(x, z)] = true
	return {"solid": solid, "air": air, "lobes": lobes,
		"spread": spread, "density": density, "openness": openness}
