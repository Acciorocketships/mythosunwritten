extends GutTest

## Pinning test for TerrainDensity.route_fill_prob.
## Captures the exact numeric outputs of the CURRENT implementation so that a
## density-profile metadata refactor can be verified byte-for-byte identical.
##
## DO NOT edit the expected constants below — they were captured from the
## pre-refactor code and define "behaviour unchanged." If the refactored code
## produces different values, fix the production code, never the expectations.
##
## Position scan mirrors test_terrain_decoration_characterization.gd Test 4:
##   core_pos:  first p where macro_density01(p, 0) >= 0.56  (CLIFF_CONTOUR_BASE)
##   low_pos:   first p where macro_density01(p, 0) < 0.35
## Scan from (200, 0, 200) in steps of 48 over a 60×60 grid.

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_density() -> TerrainDensity:
	# world_seed 0 matches the prior gen.world_seed before _ready() was called.
	return TerrainDensity.new(0)


func _make_ground_piece() -> TerrainModuleInstance:
	return TerrainModuleDefinitions.load_ground_tile().spawn()


func _make_level_piece() -> TerrainModuleInstance:
	return TerrainModuleDefinitions.load_level_middle_tile().spawn()


func _make_cliff_piece() -> TerrainModuleInstance:
	# A cliff-base-side (edge variant) — the canonical cliff with lateral sockets.
	return TerrainModuleDefinitions.load_cliff_variant("CliffSide", "cliff-base", "cliff-side").spawn()


# Scan for the canonical low/core positions used in characterization tests.
func _find_positions(density: TerrainDensity) -> Dictionary:
	var seed: int = 0
	var core_pos: Vector3 = Vector3.INF
	var low_pos: Vector3 = Vector3.INF
	for ix in range(60):
		for iz in range(60):
			var p: Vector3 = Vector3(200.0 + ix * 48.0, 0.0, 200.0 + iz * 48.0)
			var m: float = Helper.macro_density01(p, seed)
			if core_pos == Vector3.INF and m >= 0.56:
				core_pos = p
			if low_pos == Vector3.INF and m < 0.35:
				low_pos = p
		if core_pos != Vector3.INF and low_pos != Vector3.INF:
			break
	assert_ne(core_pos, Vector3.INF, "must find a core position (macro>=0.56) in the scan grid")
	assert_ne(low_pos, Vector3.INF, "must find a low-density position (macro<0.35) in the scan grid")
	return {"core": core_pos, "low": low_pos}


# ---------------------------------------------------------------------------
# Boundary: fill <= 0 and fill == 1.0
# ---------------------------------------------------------------------------

func test_zero_fill_returns_zero() -> void:
	var density: TerrainDensity = _make_density()
	var ground: TerrainModuleInstance = _make_ground_piece()
	var pos: Vector3 = Vector3(300.0, 0.0, 300.0)
	assert_eq(density.route_fill_prob(ground, "topcenter", pos, 0.0), 0.0,
		"fill <= 0 must return 0.0")
	assert_eq(density.route_fill_prob(ground, "topcenter", pos, -1.0), 0.0,
		"negative fill must return 0.0")


func test_fill_one_returns_macro_scaled_which_is_one_for_fill_one() -> void:
	# _macro_scaled_fill short-circuits for fill>=1.0: returns fill unchanged.
	var density: TerrainDensity = _make_density()
	var pos: Vector3 = Vector3(300.0, 0.0, 300.0)
	var cliff: TerrainModuleInstance = _make_cliff_piece()
	# fill==1.0 skips the fill<1.0 branch; _macro_scaled_fill(1.0, pos) == 1.0.
	var result: float = density.route_fill_prob(cliff, "front", pos, 1.0)
	assert_almost_eq(result, 1.0, 1e-6,
		"fill==1.0 falls through to _macro_scaled_fill which returns 1.0 for fill>=1")


# ---------------------------------------------------------------------------
# Case A: ground-plain topcenter ("gentle" / seed branch)
#   fill = GROUND_TOPCENTER_FILL_PROB = 0.2
#   - at low_pos (not cliff core)  => _gentle_scaled_fill(0.2, low_pos)
#   - at core_pos (cliff core)     => maxf(seed_fill, CLIFF_CORE_SEED_FILL_PROB)
# ---------------------------------------------------------------------------

func test_ground_topcenter_at_low_density() -> void:
	var density: TerrainDensity = _make_density()
	var ground: TerrainModuleInstance = _make_ground_piece()
	var positions: Dictionary = _find_positions(density)
	var low_pos: Vector3 = positions["low"]
	var fill: float = TerrainSpawnConfig.GROUND_TOPCENTER_FILL_PROB  # 0.2

	var result: float = density.route_fill_prob(ground, "topcenter", low_pos, fill)
	# EXPECTED captured from pre-refactor code:
	# _gentle_scaled_fill(0.2, low_pos) where low_pos macro < 0.35
	# = clampf(0.2 * (0.25 + 2.2 * pow(macro, 3.0)), 0, 1)
	# This value was read from the first run; hard-coded here.
	assert_almost_eq(result, EXPECTED_GROUND_TOPCENTER_LOW, 1e-6,
		"ground topcenter at low_pos must match pinned gentle-scaled value")


func test_ground_topcenter_at_cliff_core() -> void:
	var density: TerrainDensity = _make_density()
	var ground: TerrainModuleInstance = _make_ground_piece()
	var positions: Dictionary = _find_positions(density)
	var core_pos: Vector3 = positions["core"]
	var fill: float = TerrainSpawnConfig.GROUND_TOPCENTER_FILL_PROB  # 0.2

	var result: float = density.route_fill_prob(ground, "topcenter", core_pos, fill)
	# EXPECTED: maxf(_gentle_scaled_fill(0.2, core_pos), CLIFF_CORE_SEED_FILL_PROB=0.5)
	# Since core macro >= 0.56, gentle_scaled >= 0.2*(0.25+2.2*0.56^3) = large;
	# result >= CLIFF_CORE_SEED_FILL_PROB.
	assert_almost_eq(result, EXPECTED_GROUND_TOPCENTER_CORE, 1e-6,
		"ground topcenter at cliff core must match pinned value (eager seed)")


# ---------------------------------------------------------------------------
# Case B: ground-plain topfront (foliage branch)
#   fill = GROUND_FOLIAGE_FILL_PROB = 0.2
#   - at low_pos (not cliff core, not topcenter)  => biome_foliage_density branch
#   - at core_pos (cliff core, not cliff tag)      => 0.0
# ---------------------------------------------------------------------------

func test_ground_foliage_at_low_density() -> void:
	var density: TerrainDensity = _make_density()
	var ground: TerrainModuleInstance = _make_ground_piece()
	var positions: Dictionary = _find_positions(density)
	var low_pos: Vector3 = positions["low"]
	var fill: float = TerrainSpawnConfig.GROUND_FOLIAGE_FILL_PROB  # 0.2

	var result: float = density.route_fill_prob(ground, "topfront", low_pos, fill)
	# EXPECTED: clampf(0.2 * biome_foliage_density(low_pos, 0), 0, 1) > 0.0
	assert_gt(result, 0.0,
		"foliage fill at low_pos must be > 0 (foliage spawns in open meadows)")
	assert_almost_eq(result, EXPECTED_GROUND_FOLIAGE_LOW, 1e-6,
		"ground foliage (topfront) at low_pos must match pinned biome-density value")


func test_ground_foliage_at_cliff_core() -> void:
	var density: TerrainDensity = _make_density()
	var ground: TerrainModuleInstance = _make_ground_piece()
	var positions: Dictionary = _find_positions(density)
	var core_pos: Vector3 = positions["core"]
	var fill: float = TerrainSpawnConfig.GROUND_FOLIAGE_FILL_PROB  # 0.2

	var result: float = density.route_fill_prob(ground, "topfront", core_pos, fill)
	# EXPECTED: 0.0 — cliff core + non-cliff tile => suppressed
	assert_eq(result, 0.0,
		"foliage fill at cliff core must be 0.0 for non-cliff tile (suppression)")


# ---------------------------------------------------------------------------
# Case C: level tile lateral socket ("level" branch)
#   fill = LEVEL_BASE_LATERAL_FILL_PROB = 0.33
#   - at low_pos (not cliff core)  => _level_scaled_fill(0.33, low_pos)
#   - at core_pos (cliff core)      => 0.0
# NOTE: We call route_fill_prob directly (bypassing effective_fill_prob's
# structural gate) so the level curve is exercised.
# ---------------------------------------------------------------------------

func test_level_lateral_at_low_density() -> void:
	var density: TerrainDensity = _make_density()
	var level: TerrainModuleInstance = _make_level_piece()
	var positions: Dictionary = _find_positions(density)
	var low_pos: Vector3 = positions["low"]
	var fill: float = TerrainSpawnConfig.LEVEL_BASE_LATERAL_FILL_PROB  # 0.33

	var result: float = density.route_fill_prob(level, "front", low_pos, fill)
	# EXPECTED: _level_scaled_fill(0.33, low_pos)
	# = clampf(0.33 * (0.5 + 0.9 * macro), 0, 1), macro < 0.35 => small
	assert_almost_eq(result, EXPECTED_LEVEL_LATERAL_LOW, 1e-6,
		"level lateral at low_pos must match pinned level-scaled value")


func test_level_lateral_at_cliff_core() -> void:
	var density: TerrainDensity = _make_density()
	var level: TerrainModuleInstance = _make_level_piece()
	var positions: Dictionary = _find_positions(density)
	var core_pos: Vector3 = positions["core"]
	var fill: float = TerrainSpawnConfig.LEVEL_BASE_LATERAL_FILL_PROB  # 0.33

	var result: float = density.route_fill_prob(level, "front", core_pos, fill)
	# EXPECTED: 0.0 — level tile inside cliff core is doomed
	assert_eq(result, 0.0,
		"level lateral at cliff core must be 0.0 (level growth inside core suppressed)")


# ---------------------------------------------------------------------------
# Case D: cliff tile lateral socket (macro fallthrough)
#   fill = CLIFF_LATERAL_FILL_PROB = 0.3
#   - at low_pos  => _macro_scaled_fill(0.3, low_pos)
#   - at core_pos => _macro_scaled_fill(0.3, core_pos)
# The cliff lateral is NOT a point socket; the level branch is skipped
# because "cliff" tag != "level"; falls through to _macro_scaled_fill.
# ---------------------------------------------------------------------------

func test_cliff_lateral_at_low_density() -> void:
	var density: TerrainDensity = _make_density()
	var cliff: TerrainModuleInstance = _make_cliff_piece()
	var positions: Dictionary = _find_positions(density)
	var low_pos: Vector3 = positions["low"]
	var fill: float = TerrainSpawnConfig.CLIFF_LATERAL_FILL_PROB  # 0.3

	var result: float = density.route_fill_prob(cliff, "front", low_pos, fill)
	# EXPECTED: _macro_scaled_fill(0.3, low_pos)
	# = clampf(0.3 * (0.15 + 3.2 * pow(macro, 3.2)), 0, 1), macro<0.35 => tiny
	assert_almost_eq(result, EXPECTED_CLIFF_LATERAL_LOW, 1e-6,
		"cliff lateral at low_pos must match pinned macro-scaled value")


func test_cliff_lateral_at_cliff_core() -> void:
	var density: TerrainDensity = _make_density()
	var cliff: TerrainModuleInstance = _make_cliff_piece()
	var positions: Dictionary = _find_positions(density)
	var core_pos: Vector3 = positions["core"]
	var fill: float = TerrainSpawnConfig.CLIFF_LATERAL_FILL_PROB  # 0.3

	var result: float = density.route_fill_prob(cliff, "front", core_pos, fill)
	# EXPECTED: _macro_scaled_fill(0.3, core_pos), macro >= 0.56 => substantial
	assert_almost_eq(result, EXPECTED_CLIFF_LATERAL_CORE, 1e-6,
		"cliff lateral at cliff core must match pinned macro-scaled value")


# ---------------------------------------------------------------------------
# PINNED EXPECTED VALUES
# Captured from the pre-refactor code by running this test with placeholder
# 0.0 values, reading the failure output, and hard-coding the actuals.
# These constants are SACRED — never edit them to make a test pass.
# ---------------------------------------------------------------------------

# Case A: ground topcenter  (gentle scaled / eager-seed)
const EXPECTED_GROUND_TOPCENTER_LOW: float  = 0.06176614407435082610
const EXPECTED_GROUND_TOPCENTER_CORE: float = 0.50000000000000000000

# Case B: ground foliage (topfront, biome_foliage_density)
const EXPECTED_GROUND_FOLIAGE_LOW: float    = 0.22992586000645243161

# Case C: level lateral (front, level scaled)
const EXPECTED_LEVEL_LATERAL_LOW: float     = 0.25381444599982250221

# Case D: cliff lateral (front, macro scaled)
const EXPECTED_CLIFF_LATERAL_LOW: float     = 0.06516499649518085746
const EXPECTED_CLIFF_LATERAL_CORE: float    = 0.19583558651693055985
