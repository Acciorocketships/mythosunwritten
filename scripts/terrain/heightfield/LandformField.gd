class_name LandformField
extends RefCounted

## Broad geological provinces on a 768m lattice. Smooth interpolation of the
## four bounded analytic fields prevents region seams and query-order effects.
## Both river descent and final terrain sample this same geography.
const SCALE := 768.0
const NAMES: Array[StringName] = [&"escarpment", &"amphitheatre", &"terraced_valley",
	&"mesa", &"ridgeline", &"sheltered_hollow", &"cleft", &"mountain_range",
	&"hanging_valley", &"delta_fan"]

## Base height, relief, and geological vocabulary. Values multiply the single
## production amplitude; biome weights continuously mix complete shapes.
const PROFILES := {
	&"meadow": [.015,.18,[2,4,5,5]],
	&"deep_forest": [.03,.35,[1,2,5,6]],
	&"highland": [.13,.85,[7,7,4,8,6]],
	&"blossom_grove": [.02,.26,[1,2,5,8]],
	&"twilight_marsh": [.01,.08,[5,9,9]],
	&"amber_heath": [.06,.50,[0,2,3,3,6]],
	&"jade_wetlands": [.012,.15,[2,5,9,9]],
}

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
		6: # Narrow winding cleft between two broad rock shoulders.
			var cleft := exp(-pow((p.y + sin(p.x * 4.0) * 0.12) / 0.055, 2.0))
			return 0.65 - 0.53 * cleft
		7: # Several linked summits along a broad spine, with subsidiary shoulders.
			var spine := exp(-pow((p.y+sin(p.x*3.0)*.12)/.30,2))
			var peaks := .68+.32*pow(.5+.5*cos(p.x*10.0),2)
			return .10+.88*spine*peaks
		8: # High tributary floor ends at the lip above a deeper trunk valley.
			var trunk := smoothstep(.10,.30,absf(p.y))
			var tributary := exp(-pow((p.x-.18)/.15,2))*smoothstep(.12,.25,p.y)
			return .12+.68*trunk-.30*tributary
		_: # Broad depositional apron with low diverging drainage corridors.
			var fan := clampf((p.x+.8)/1.6,0,1)
			var spread := .10+.24*fan
			var channels := maxf(exp(-pow((p.y-spread)/.08,2)),exp(-pow((p.y+spread)/.08,2)))
			return .20+.34*(1.0-fan)-.14*channels

# The geological orientation and shape-selection roll depend only on seed and
# province. Continuous samples still evaluate their exact local coordinates.
# Shared readers receive immutable double values; bounded FIFO storage prevents
# an endless journey from retaining every visited province.
const OWNER_CACHE_LIMIT := 4096
static var _owners: Dictionary = {}
static var _owner_keys: Array = []
static var _owner_cursor := 0
static var _owner_mutex := Mutex.new()

static func _owner_parameters(seed: int, owner: Vector2i) -> PackedFloat64Array:
	var key := [seed,owner]
	_owner_mutex.lock()
	var cached = _owners.get(key)
	if cached != null:
		_owner_mutex.unlock()
		return cached
	var values := PackedFloat64Array([
		Helper._cell_hash01(seed+1303,owner.x,owner.y)*TAU,
		Helper._cell_hash01(seed+1301,owner.x,owner.y)])
	if _owner_keys.size() == OWNER_CACHE_LIMIT:
		_owners.erase(_owner_keys[_owner_cursor])
		_owner_keys[_owner_cursor] = key
		_owner_cursor = (_owner_cursor+1)%OWNER_CACHE_LIMIT
	else:
		_owner_keys.append(key)
	_owners[key] = values
	_owner_mutex.unlock()
	return values

static func height01(pos: Vector3, seed: int, weights: Dictionary = {}) -> float:
	if weights.is_empty(): weights = Helper.biome_weights5(pos,seed)
	var q := Vector2(pos.x, pos.z) / SCALE
	var cell := Vector2i(floori(q.x), floori(q.y))
	var f := Vector2(SlopeProfile.smootherstep(q.x - cell.x), SlopeProfile.smootherstep(q.y - cell.y))
	var h := 0.0
	for z in 2:
		for x in 2:
			var owner := cell + Vector2i(x, z)
			var local := q - Vector2(owner)
			var parameters := _owner_parameters(seed,owner)
			var angle := parameters[0]
			local = local.rotated(angle)
			var weight := (f.x if x == 1 else 1.0 - f.x) * (f.y if z == 1 else 1.0 - f.y)
			var roll := parameters[1]
			for biome: StringName in weights:
				var biome_weight: float = weights[biome]
				if biome_weight <= 0.0: continue
				var profile: Array = PROFILES[biome]
				var choices: Array = profile[2]
				var kind: int = choices[mini(int(roll*choices.size()),choices.size()-1)]
				h += (float(profile[0])+float(profile[1])*shape(kind,local))*weight*biome_weight
	return clampf(h, 0.0, 1.0)
