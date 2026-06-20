extends SceneTree
## Enumerate every missing-socket set that missing_from_heights can produce, then
## check variant_for_missing matches it exactly (no fallback-to-center with a
## non-empty set, no wrong-cardinality match). Unmatched sets = a cell that needs
## walls but gets a wall-less interior tile (open sides). Run headless:
##   Godot --headless -s --path . res://tests/harness/hf_variant_coverage.gd

const CARDINALS: Array = ["front", "right", "back", "left"]
const DIAGONALS: Array = ["frontright", "backright", "backleft", "frontleft"]
const DIAG_PAIR: Dictionary = {
	"frontright": ["front", "right"], "backright": ["back", "right"],
	"backleft": ["back", "left"], "frontleft": ["front", "left"],
}


func _init() -> void:
	var bad: Array = []
	var total: int = 0
	# Every subset of wall-cardinals.
	for wmask in range(16):
		var walls: Array = []
		for i in range(4):
			if wmask & (1 << i):
				walls.append(CARDINALS[i])
		# Diagonals eligible to be a notch: both adjoining cardinals are NOT walls.
		var eligible: Array = []
		for d in DIAGONALS:
			var pair: Array = DIAG_PAIR[d]
			if not walls.has(pair[0]) and not walls.has(pair[1]):
				eligible.append(d)
		# Every subset of eligible diagonals.
		for dmask in range(1 << eligible.size()):
			var diags: Array = []
			for j in range(eligible.size()):
				if dmask & (1 << j):
					diags.append(eligible[j])
			var missing: Array = walls.duplicate()
			missing.append_array(diags)
			total += 1
			var v: Dictionary = HeightfieldVariant.variant_for_missing(missing)
			# Reconstruct what tile that (tag, rotation) actually covers and compare.
			var covered: Array = _covered_set(v["tag"], int(v["rotation_steps"]))
			if not _same_set(covered, missing):
				bad.append({"missing": missing, "got": v["tag"], "rot": v["rotation_steps"], "covers": covered})
	print("[coverage] enumerated %d missing-sets, %d UNMATCHED:" % [total, bad.size()])
	for b in bad:
		print("  missing=%s -> tag=%s rot=%d covers=%s" % [str(b["missing"]), b["got"], b["rot"], str(b["covers"])])
	quit()


func _covered_set(tag: String, steps: int) -> Array:
	var canonical: Array = (HeightfieldVariant.CANONICAL_MISSING_BY_TAG[tag] as Array).duplicate()
	for _s in range(steps):
		var rotated: Array = []
		for name in canonical:
			rotated.append(Helper.rotate_socket_name(name))
		canonical = rotated
	return canonical


func _same_set(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for x in a:
		if not b.has(x):
			return false
	return true
