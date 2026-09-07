class_name LandformField
extends RefCounted

## Broad geological provinces on a 768m lattice. Smooth interpolation of the
## four bounded analytic fields prevents region seams and query-order effects.
## Both river descent and final terrain sample this same geography.
const SCALE := 768.0
const NAMES: Array[StringName] = [&"escarpment", &"amphitheatre", &"terraced_valley",
	&"mesa", &"ridgeline", &"sheltered_hollow", &"cleft"]

static func province(seed: int, cell: Vector2i) -> int:
	return mini(int(Helper._cell_hash01(seed + 1301, cell.x, cell.y) * NAMES.size()), NAMES.size() - 1)

static func shape(kind: int, p: Vector2) -> float:
	var radius := p.length()
	match kind:
		0: # Long undulating escarpment, with a broad high and low side.
			return 0.16 + 0.64 * smoothstep(-0.07, 0.08, p.y + sin(p.x * 5.0) * 0.10)
		1: # Horseshoe ridge opens through a wide natural amphitheatre mouth.
			var ring := exp(-pow((radius - 0.58) / 0.19, 2.0))
			var mouth := smoothstep(-0.2, 0.28, p.y)
			return 0.12 + 0.74 * ring * (1.0 - mouth * 0.85)
		2: # Gentle treads separated by distinct narrow risers, never saw teeth.
			var valley := clampf(absf(p.y + sin(p.x * 3.0) * 0.14), 0.0, 1.0)
			var tier := valley * 4.0
			return 0.12 + (floorf(tier) + smoothstep(0.70, 1.0, fposmod(tier, 1.0))) * 0.17
		3: # An isolated flat crown with a low skirt and subsidiary rock needle.
			var mesa := 1.0 - smoothstep(0.34, 0.49, radius)
			var needle := exp(-pow(p.distance_to(Vector2(0.55, -0.38)) / 0.10, 2.0))
			return 0.13 + mesa * 0.72 + needle * 0.56
		4: # Continuous ridge with a traversable saddle/pass through its spine.
			var ridge := exp(-pow((p.y + sin(p.x * 3.5) * 0.15) / 0.22, 2.0))
			var saddle := 1.0 - 0.68 * exp(-pow(p.x / 0.16, 2.0))
			return 0.12 + 0.75 * ridge * saddle
		5: # Sheltered sink-like bowl surrounded by a smooth raised shoulder.
			return 0.16 + 0.48 * smoothstep(0.20, 0.55, radius)
		_: # Narrow winding cleft between two broad rock shoulders.
			var cleft := exp(-pow((p.y + sin(p.x * 4.0) * 0.12) / 0.09, 2.0))
			return 0.65 - 0.53 * cleft

static func height01(pos: Vector3, seed: int) -> float:
	var q := Vector2(pos.x, pos.z) / SCALE
	var cell := Vector2i(floori(q.x), floori(q.y))
	var f := Vector2(SlopeProfile.smootherstep(q.x - cell.x), SlopeProfile.smootherstep(q.y - cell.y))
	var h := 0.0
	for z in 2:
		for x in 2:
			var owner := cell + Vector2i(x, z)
			var local := q - Vector2(owner)
			var angle := Helper._cell_hash01(seed + 1303, owner.x, owner.y) * TAU
			local = local.rotated(angle)
			var weight := (f.x if x == 1 else 1.0 - f.x) * (f.y if z == 1 else 1.0 - f.y)
			h += shape(province(seed, owner), local) * weight
	return clampf(h, 0.0, 1.0)
