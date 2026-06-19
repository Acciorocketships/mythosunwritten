class_name HeightfieldVariant
extends RefCounted

## Pure mapping from heightfield-plan surface heights to a terrain tile descriptor
## (family / variant tag / 90-degree rotation / origin Y). No scene instantiation.
## See docs/superpowers/specs/2026-06-17-heightfield-terrain-design.md (Phase 3a).
##
## The canonical "missing sockets" shapes mirror LevelEdgeRule/CliffEdgeRule but are
## family-agnostic (bare tags). A side is "missing" (a wall) when its neighbour is a
## step down. The live edge rules are subsumed in Phase 3c.

const STOREY_HEIGHT: float = 4.0
const LEVEL_HEIGHT: float = 0.5

const CARDINALS: Array[String] = ["front", "right", "back", "left"]
const DIAGONALS: Array[String] = ["frontright", "backright", "backleft", "frontleft"]
const DIAG_CARDINALS: Dictionary = {
	"frontright": ["front", "right"],
	"backright": ["back", "right"],
	"backleft": ["back", "left"],
	"frontleft": ["front", "left"],
}

const CANONICAL_MISSING_BY_TAG: Dictionary = {
	"center": [],
	"side": ["front"],
	"line": ["front", "back"],
	"corner": ["front", "left"],
	"peninsula": ["front", "left", "right"],
	"island": ["front", "right", "back", "left"],
	"inner-corner": ["frontleft"],
	"inner-corner-diag": ["frontleft", "backright"],
	"inner-corner-side": ["frontleft", "backleft"],
	"inner-corner-edge1": ["frontleft", "back"],
	"inner-corner-edge2": ["frontleft", "right"],
	"inner-corner-edge-both": ["frontleft", "back", "right"],
	"inner-corner-side-edge": ["frontleft", "backleft", "right"],
	"inner-corner-three": ["frontleft", "backleft", "backright"],
	"inner-corner-all": ["frontright", "backright", "backleft", "frontleft"],
}
const TAG_ORDER: Array[String] = [
	"center", "side", "line", "corner", "peninsula", "island",
	"inner-corner", "inner-corner-diag", "inner-corner-side",
	"inner-corner-edge1", "inner-corner-edge2", "inner-corner-edge-both",
	"inner-corner-side-edge", "inner-corner-three", "inner-corner-all",
]


## Map a set of missing-socket names to {"tag": bare_variant, "rotation_steps": 0..3}.
## Tries tags in priority order; for each, rotates its canonical set until it matches.
static func variant_for_missing(missing: Array) -> Dictionary:
	for tag in TAG_ORDER:
		var steps: int = _rotation_steps_to_align(tag, missing)
		if steps >= 0:
			return {"tag": tag, "rotation_steps": steps}
	return {"tag": "center", "rotation_steps": 0}


static func _rotation_steps_to_align(tag: String, desired: Array) -> int:
	var canonical: Array = (CANONICAL_MISSING_BY_TAG[tag] as Array).duplicate()
	for step in range(4):
		if _same_set(canonical, desired):
			return step
		var rotated: Array = []
		for socket_name in canonical:
			rotated.append(Helper.rotate_socket_name(socket_name))
		canonical = rotated
	return -1


static func _same_set(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for x in a:
		if not b.has(x):
			return false
	return true


## Compute the missing-socket set from a cell's surface height and its neighbours'.
## A cardinal is a wall when its neighbour is lower by more than `eps`. A diagonal
## is an inner-corner notch only when its neighbour is lower AND both adjoining
## cardinals are connected (not themselves walls). `cardinals`/`diagonals` map a
## socket name to that neighbour's surface height; a missing entry defaults to h0
## (treated as level/connected).
static func missing_from_heights(
	h0: float, cardinals: Dictionary, diagonals: Dictionary, eps: float = 0.1
) -> Array[String]:
	var missing: Array[String] = []
	var card_wall: Dictionary = {}
	for c in CARDINALS:
		var hc: float = float(cardinals.get(c, h0))
		var is_wall: bool = hc < h0 - eps
		card_wall[c] = is_wall
		if is_wall:
			missing.append(c)
	for d in DIAGONALS:
		var hd: float = float(diagonals.get(d, h0))
		if hd < h0 - eps:
			var pair: Array = DIAG_CARDINALS[d]
			if not card_wall[pair[0]] and not card_wall[pair[1]]:
				missing.append(d)
	return missing
