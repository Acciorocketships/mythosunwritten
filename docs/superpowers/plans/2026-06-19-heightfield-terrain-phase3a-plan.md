# Heightfield Terrain — Variant Mapping (Phase 3a) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Given a cell's surface height and its 8 neighbours' surface heights (from the heightfield plan), compute — as a pure, deterministic function — which terrain tile to place: its family (ground/level/cliff), its variant tag, its 90° rotation, and its origin Y. No scene instantiation.

**Architecture:** A new pure `HeightfieldVariant` helper. A cell's side is a "wall" exactly when that cardinal neighbour is a step *down*; the set of walls (plus inner-corner diagonals) maps to a variant tag + rotation via the same canonical-missing→tag machinery the existing edge rules use (`CANONICAL_MISSING_BY_TAG` + rotate-to-align, reusing `Helper.rotate_socket_name`). Phase 2's cliff-edge pin guarantees a cell's drops are all one magnitude (all 4m or all 0.5m), so family is unambiguous. This computes the final variant directly from the plan — no edge-rule retiling, no churn.

**Tech Stack:** Godot 4.5 typed GDScript, GUT. Pure logic — unit-tested with synthetic neighbour heights, no Node/scene code.

---

## Scope and Phasing

**Phase 3a of the Phase-3 group** (see `docs/superpowers/specs/2026-06-17-heightfield-terrain-design.md`). Phases 1–2 built the numerical plan (`HeightfieldPlan`: `tile_plan(cx,cz) → {storey, level, height}`). Phase 3a is the pure mapping from plan heights → tile descriptor. **Phase 3b** (instantiation: spawn the described tiles into `terrain_index`/`socket_index` at a place-radius, applying the rotation as a Y-axis basis and `origin_y` as the transform) and **Phase 3c** (cutover: make the plan the structural source, disable socket-growth for level/cliff, keep streaming/reveal/water/decorations) are follow-up plans. 3a touches **no live game code** and instantiates nothing — it is pure and fully unit-testable, like Phases 1–2.

## Background — reused conventions (read-only)

From `scripts/terrain/rules/LevelEdgeRule.gd`:
- `CANONICAL_MISSING_BY_TAG` (lines 13–29): maps a variant to its canonical set of "missing" sockets (sides without a same-family neighbour). The level and cliff tables are identical apart from the tag prefix; the bare shape (`side`=`["front"]`, `corner`=`["front","left"]`, `inner-corner`=`["frontleft"]`, …) is what we reuse.
- `LEVEL_TAG_ORDER` (lines 36–51): the priority order tags are tried in (most-connected first).
- `_rotation_steps_to_align_canonical` / `_rotate_socket_names_once` / `_same_socket_set` (lines 522–545): rotate a canonical set 0–3 times until it matches the desired set.
- `INNER_CORNER_CARDINALS_BY_DIAGONAL` (lines 30–35): a diagonal counts as an inner-corner notch only when *both* its adjoining cardinals are connected.

From `scripts/core/Helper.gd`:
- `SOCKET_ROTATION_90` (lines 5–14) and static `rotate_socket_name` (lines 371–383): rotate a socket name 90° (`front→right→back→left`, `frontleft→frontright→backright→backleft`). **Reused directly.**

Tile origin/height conventions (from `TerrainModuleDefinitions.gd`): every tile's origin sits at its **top** surface — ground origin y=0 (top at 0.5), level origin at its top, cliff origin at its plateau top. So a placed tile's `origin_y` equals the cell's surface height.

**Note on duplication:** 3a duplicates the small canonical-missing table (as family-agnostic bare tags) rather than refactoring the live `LevelEdgeRule`/`CliffEdgeRule` (which are load-bearing and will be removed in 3c). This keeps 3a isolated and risk-free; 3c subsumes the old rules.

## File Structure

- Create: `scripts/terrain/heightfield/HeightfieldVariant.gd` — pure static helper: bare canonical table, `variant_for_missing`, `missing_from_heights`, `cell_descriptor`. One responsibility: plan heights → tile descriptor.
- Create: `tests/test_heightfield_variant.gd` — GUT suite.

## Conventions

- Socket names are abstract here: cardinals `front`/`right`/`back`/`left`, diagonals `frontright`/`backright`/`backleft`/`frontleft`. The mapping from world (dx,dz) offsets to these names is **Phase 3b's responsibility** and must be consistent; 3a only requires the same names the rotation map uses. Rotation handles final orientation.
- Run the suite from `/Users/ryko/story`:
```
/Applications/Godot.app/Contents/MacOS/Godot -d -s --path "$PWD" addons/gut/gut_cmdln.gd -gdir=res://tests -gconfig=res://tests/gutconfig.json -gselect=test_heightfield_variant.gd
```

---

### Task 1: `variant_for_missing` — missing-set → variant tag + rotation

**Files:**
- Create: `scripts/terrain/heightfield/HeightfieldVariant.gd`
- Test: `tests/test_heightfield_variant.gd`

- [ ] **Step 1: Write the failing tests** — create `tests/test_heightfield_variant.gd`:

```gdscript
extends GutTest

# ------------------------------------------------------------
# HeightfieldVariant — plan heights -> tile descriptor (Phase 3a)
# ------------------------------------------------------------

func test_variant_empty_missing_is_center_no_rotation() -> void:
	var v: Dictionary = HeightfieldVariant.variant_for_missing([])
	assert_eq(v["tag"], "center", "no walls => center")
	assert_eq(v["rotation_steps"], 0, "center needs no rotation")

func test_variant_single_wall_is_side() -> void:
	var v: Dictionary = HeightfieldVariant.variant_for_missing(["front"])
	assert_eq(v["tag"], "side", "one wall => side")
	assert_eq(v["rotation_steps"], 0, "canonical side wall is on front")

func test_variant_rotates_canonical_to_match() -> void:
	# A wall on the right is the side variant rotated one 90deg step (front->right).
	var v: Dictionary = HeightfieldVariant.variant_for_missing(["right"])
	assert_eq(v["tag"], "side", "one wall (any direction) => side")
	assert_eq(v["rotation_steps"], 1, "front rotates to right in one step")

func test_variant_adjacent_walls_is_corner() -> void:
	var v: Dictionary = HeightfieldVariant.variant_for_missing(["front", "left"])
	assert_eq(v["tag"], "corner", "two adjacent walls => corner")

func test_variant_opposite_walls_is_line() -> void:
	var v: Dictionary = HeightfieldVariant.variant_for_missing(["front", "back"])
	assert_eq(v["tag"], "line", "two opposite walls => line")

func test_variant_all_four_walls_is_island() -> void:
	var v: Dictionary = HeightfieldVariant.variant_for_missing(["front", "right", "back", "left"])
	assert_eq(v["tag"], "island", "four walls => island")

func test_variant_diagonal_is_inner_corner() -> void:
	var v: Dictionary = HeightfieldVariant.variant_for_missing(["frontleft"])
	assert_eq(v["tag"], "inner-corner", "a single diagonal notch => inner-corner")
```

- [ ] **Step 2: Run, confirm FAIL** (`HeightfieldVariant` unknown):
```
/Applications/Godot.app/Contents/MacOS/Godot -d -s --path "$PWD" addons/gut/gut_cmdln.gd -gdir=res://tests -gconfig=res://tests/gutconfig.json -gselect=test_heightfield_variant.gd
```

- [ ] **Step 3: Create `scripts/terrain/heightfield/HeightfieldVariant.gd`:**

```gdscript
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
```

- [ ] **Step 4: Run, confirm PASS.** Expected: 7 passing.

- [ ] **Step 5: Commit:**
```bash
git add scripts/terrain/heightfield/HeightfieldVariant.gd tests/test_heightfield_variant.gd
git commit -m "feat(terrain): variant tag + rotation from a missing-socket set

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: `missing_from_heights` — neighbour heights → missing-socket set

**Files:**
- Modify: `scripts/terrain/heightfield/HeightfieldVariant.gd`
- Modify: `tests/test_heightfield_variant.gd`

- [ ] **Step 1: Write the failing tests** — append to the END of `tests/test_heightfield_variant.gd`:

```gdscript
func test_missing_is_empty_when_all_neighbours_level() -> void:
	var flat: Dictionary = {"front": 4.0, "right": 4.0, "back": 4.0, "left": 4.0}
	var diag: Dictionary = {"frontright": 4.0, "backright": 4.0, "backleft": 4.0, "frontleft": 4.0}
	var missing: Array = HeightfieldVariant.missing_from_heights(4.0, flat, diag)
	assert_eq(missing.size(), 0, "no drops => no walls")

func test_missing_includes_a_lower_cardinal() -> void:
	var cards: Dictionary = {"front": 0.0, "right": 4.0, "back": 4.0, "left": 4.0}
	var diag: Dictionary = {"frontright": 4.0, "backright": 4.0, "backleft": 4.0, "frontleft": 4.0}
	var missing: Array = HeightfieldVariant.missing_from_heights(4.0, cards, diag)
	assert_eq(missing, ["front"], "a lower front neighbour is a wall")

func test_missing_ignores_higher_neighbours() -> void:
	# A higher neighbour means THIS cell is at the foot of that wall — no wall here.
	var cards: Dictionary = {"front": 8.0, "right": 4.0, "back": 4.0, "left": 4.0}
	var diag: Dictionary = {"frontright": 4.0, "backright": 4.0, "backleft": 4.0, "frontleft": 4.0}
	var missing: Array = HeightfieldVariant.missing_from_heights(4.0, cards, diag)
	assert_eq(missing.size(), 0, "higher neighbours are not walls")

func test_missing_diagonal_only_when_both_cardinals_connected() -> void:
	# frontleft lower, but front and left are level => inner-corner notch.
	var cards: Dictionary = {"front": 4.0, "right": 4.0, "back": 4.0, "left": 4.0}
	var diag: Dictionary = {"frontright": 4.0, "backright": 4.0, "backleft": 4.0, "frontleft": 0.0}
	var missing: Array = HeightfieldVariant.missing_from_heights(4.0, cards, diag)
	assert_eq(missing, ["frontleft"], "diagonal drop with connected cardinals => inner corner")

func test_missing_diagonal_suppressed_when_a_cardinal_is_a_wall() -> void:
	# Both front and frontleft are lower: the diagonal is absorbed by the front
	# wall (the canonical 'side'/'corner' shapes already cover it), so only the
	# cardinal is reported.
	var cards: Dictionary = {"front": 0.0, "right": 4.0, "back": 4.0, "left": 4.0}
	var diag: Dictionary = {"frontright": 4.0, "backright": 4.0, "backleft": 4.0, "frontleft": 0.0}
	var missing: Array = HeightfieldVariant.missing_from_heights(4.0, cards, diag)
	assert_eq(missing, ["front"], "diagonal not reported when an adjoining cardinal is a wall")
```

- [ ] **Step 2: Run, confirm FAIL** (`missing_from_heights` not found).

- [ ] **Step 3: Append to `scripts/terrain/heightfield/HeightfieldVariant.gd`:**

```gdscript
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
```

- [ ] **Step 4: Run, confirm PASS.** Expected: 12 passing.

- [ ] **Step 5: Commit:**
```bash
git add scripts/terrain/heightfield/HeightfieldVariant.gd tests/test_heightfield_variant.gd
git commit -m "feat(terrain): missing-socket set from neighbour heights

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: `cell_descriptor` — full tile descriptor (family, tag, rotation, Y)

**Files:**
- Modify: `scripts/terrain/heightfield/HeightfieldVariant.gd`
- Modify: `tests/test_heightfield_variant.gd`

- [ ] **Step 1: Write the failing tests** — append to the END of `tests/test_heightfield_variant.gd`:

```gdscript
# Convenience: a flat neighbourhood at height h (all 8 neighbours == h).
func _flat(h: float) -> Array:
	var cards: Dictionary = {"front": h, "right": h, "back": h, "left": h}
	var diag: Dictionary = {"frontright": h, "backright": h, "backleft": h, "frontleft": h}
	return [cards, diag]

func test_descriptor_flat_ground() -> void:
	var nb: Array = _flat(0.0)
	var d: Dictionary = HeightfieldVariant.cell_descriptor(0.0, 0, 0, nb[0], nb[1])
	assert_eq(d["family"], "ground", "storey 0 level 0 flat => ground")
	assert_eq(d["variant_tag"], "ground", "ground tile tag")
	assert_almost_eq(d["origin_y"], 0.0, 0.0001, "ground at y=0")

func test_descriptor_cliff_edge() -> void:
	# Storey 1 (origin 4m), front drops a full storey to ground.
	var cards: Dictionary = {"front": 0.0, "right": 4.0, "back": 4.0, "left": 4.0}
	var diag: Dictionary = {"frontright": 4.0, "backright": 4.0, "backleft": 4.0, "frontleft": 4.0}
	var d: Dictionary = HeightfieldVariant.cell_descriptor(4.0, 1, 0, cards, diag)
	assert_eq(d["family"], "cliff", "a 4m drop => cliff family")
	assert_eq(d["variant_tag"], "cliff-side", "one cliff wall => cliff-side")
	assert_almost_eq(d["origin_y"], 4.0, 0.0001, "cliff plateau top at storey*4")

func test_descriptor_level_edge() -> void:
	# Storey 0 level 1 (origin 0.5m), front drops one level to 0.
	var cards: Dictionary = {"front": 0.0, "right": 0.5, "back": 0.5, "left": 0.5}
	var diag: Dictionary = {"frontright": 0.5, "backright": 0.5, "backleft": 0.5, "frontleft": 0.5}
	var d: Dictionary = HeightfieldVariant.cell_descriptor(0.5, 0, 1, cards, diag)
	assert_eq(d["family"], "level", "a 0.5m drop => level family")
	assert_eq(d["variant_tag"], "level-side", "one level wall => level-side")
	assert_almost_eq(d["origin_y"], 0.5, 0.0001, "level top at storey*4 + level*0.5")

func test_descriptor_cliff_plateau_interior() -> void:
	var nb: Array = _flat(4.0)
	var d: Dictionary = HeightfieldVariant.cell_descriptor(4.0, 1, 0, nb[0], nb[1])
	assert_eq(d["family"], "cliff", "elevated flat cell is cliff family")
	assert_eq(d["variant_tag"], "cliff-interior", "flat cliff top => cliff-interior")

func test_descriptor_level_center() -> void:
	var nb: Array = _flat(0.5)
	var d: Dictionary = HeightfieldVariant.cell_descriptor(0.5, 0, 1, nb[0], nb[1])
	assert_eq(d["family"], "level", "raised-but-flat level cell")
	assert_eq(d["variant_tag"], "level-center", "flat level => level-center")

func test_descriptor_cliff_corner_with_rotation() -> void:
	# Drops on right and back (a corner) at storey 1.
	var cards: Dictionary = {"front": 4.0, "right": 0.0, "back": 0.0, "left": 4.0}
	var diag: Dictionary = {"frontright": 0.0, "backright": 0.0, "backleft": 4.0, "frontleft": 4.0}
	var d: Dictionary = HeightfieldVariant.cell_descriptor(4.0, 1, 0, cards, diag)
	assert_eq(d["family"], "cliff", "two cliff walls")
	assert_eq(d["variant_tag"], "cliff-corner", "adjacent cliff walls => cliff-corner")
	assert_true(d["rotation_steps"] >= 0 and d["rotation_steps"] <= 3, "rotation in range")
```

- [ ] **Step 2: Run, confirm FAIL** (`cell_descriptor` not found).

- [ ] **Step 3: Append to `scripts/terrain/heightfield/HeightfieldVariant.gd`:**

```gdscript
## Full tile descriptor for a cell: {family, variant_tag, rotation_steps, origin_y}.
## family is "ground"/"level"/"cliff". Family is chosen by the magnitude of the
## cardinal drops (a ~4m drop => cliff, a ~0.5m drop => level); a flat cell's family
## comes from its elevation (storey>0 => cliff plateau, level>0 => level plateau,
## else ground). origin_y is the cell's surface height (tiles' origins sit at their
## top). variant_tag is the family-prefixed bare variant ("center" maps to
## "level-center" / "cliff-interior").
static func cell_descriptor(
	h0: float, storey: int, level: int,
	cardinals: Dictionary, diagonals: Dictionary, eps: float = 0.1
) -> Dictionary:
	var missing: Array[String] = missing_from_heights(h0, cardinals, diagonals, eps)
	var has_cliff_drop: bool = false
	var has_level_drop: bool = false
	for c in CARDINALS:
		var drop: float = h0 - float(cardinals.get(c, h0))
		if drop > eps:
			if absf(drop - STOREY_HEIGHT) < absf(drop - LEVEL_HEIGHT):
				has_cliff_drop = true
			else:
				has_level_drop = true
	var family: String
	if has_cliff_drop:
		family = "cliff"
	elif has_level_drop:
		family = "level"
	elif storey > 0:
		family = "cliff"
	elif level > 0:
		family = "level"
	else:
		family = "ground"
	var origin_y: float = float(storey) * STOREY_HEIGHT + float(level) * LEVEL_HEIGHT
	if family == "ground":
		return {"family": "ground", "variant_tag": "ground", "rotation_steps": 0, "origin_y": origin_y}
	var v: Dictionary = variant_for_missing(missing)
	var bare: String = v["tag"]
	var variant_tag: String
	if family == "cliff":
		variant_tag = "cliff-interior" if bare == "center" else "cliff-" + bare
	else:
		variant_tag = "level-center" if bare == "center" else "level-" + bare
	return {
		"family": family,
		"variant_tag": variant_tag,
		"rotation_steps": int(v["rotation_steps"]),
		"origin_y": origin_y,
	}
```

- [ ] **Step 4: Run, confirm PASS.** Expected: 18 passing.

- [ ] **Step 5: Run the FULL suite to confirm no regressions:**
```
/Applications/Godot.app/Contents/MacOS/Godot -d -s --path "$PWD" addons/gut/gut_cmdln.gd -gdir=res://tests -gconfig=res://tests/gutconfig.json
```
Expected: all prior suites plus the new 18 tests, 0 failing. (The leaked-RID lines at shutdown are normal teardown noise.)

- [ ] **Step 6: Commit:**
```bash
git add scripts/terrain/heightfield/HeightfieldVariant.gd tests/test_heightfield_variant.gd
git commit -m "feat(terrain): full cell -> tile descriptor (family, variant, rotation, Y)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Self-Review

**Spec coverage (Phase 3a scope):**
- Variant selection from plan neighbour-deltas → Task 1 (`variant_for_missing`) + Task 2 (`missing_from_heights`).
- Reuse of the existing canonical-missing→tag+rotation logic → Task 1 (bare table + `Helper.rotate_socket_name`).
- Family disambiguation (cliff vs level vs ground) relying on Phase 2's cliff-edge pin → Task 3. Instantiation, streaming, and cutover are explicitly Phases 3b/3c.

**Placeholder scan:** No TBD/TODO; every code step is complete; every run step has the command and expected counts.

**Type/name consistency:** `variant_for_missing` returns `{"tag", "rotation_steps"}`, consumed by `cell_descriptor`. `missing_from_heights` returns `Array[String]`, consumed by `cell_descriptor`. Constants `CARDINALS`, `DIAGONALS`, `DIAG_CARDINALS`, `CANONICAL_MISSING_BY_TAG`, `TAG_ORDER`, `STOREY_HEIGHT`, `LEVEL_HEIGHT` defined in Task 1/2 and used consistently. `Helper.rotate_socket_name` is the real static API. The descriptor keys (`family`, `variant_tag`, `rotation_steps`, `origin_y`) are the contract Phase 3b will consume.

**Assumption guard:** Family exclusivity (a cell's drops are all 4m or all 0.5m, never mixed) is guaranteed by Phase 2's cliff-edge pin (cells at a storey boundary are pinned to level 0, so they have no 0.5m drops). The `absf(drop-4) < absf(drop-0.5)` classification is robust to the only magnitudes the plan can produce (0, 0.5, 4). Phase 3b will feed `cell_descriptor` from `HeightfieldPlan.tile_plan` + `surface_height` of the 8 neighbours, and is responsible for the consistent (dx,dz)→socket-name mapping.
