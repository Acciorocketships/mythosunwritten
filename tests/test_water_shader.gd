extends GutTest

const SHADER_PATH := "res://terrain/water/water_unified.gdshader"

var _source := ""


func before_all() -> void:
	_source = FileAccess.get_file_as_string(SHADER_PATH)
	assert_false(_source.is_empty(), "unified water shader source loads")


func _float_default(name: String) -> float:
	var regex := RegEx.new()
	var err: int = regex.compile("uniform\\s+float\\s+" + name + "[^=;]*=\\s*([0-9.]+)")
	assert_eq(err, OK, "uniform regex compiles")
	var hit: RegExMatch = regex.search(_source)
	assert_not_null(hit, "shader declares a default for %s" % name)
	return float(hit.get_string(1)) if hit != null else NAN


## The owner's motion carrier is refraction-only, but it still has to move
## enough pixels to be readable in an ordinary gameplay view.  The previous
## 0.05 scale produced only ~2-3 RGB values of paired-frame change across
## the pinned river while the land control was static, which read as still.
func test_downstream_refraction_motion_has_readable_amplitude() -> void:
	var distort: float = _float_default("distort_anim")
	assert_true(distort >= 0.09,
		"advected refraction distortion is visibly readable (%.3f >= 0.09)" % distort)
	assert_true(_source.contains("water_distort_wobble(noise_tex"),
		"two-phase advected wobble remains the river motion source")
	assert_true(_source.contains("wobble * distort_anim"),
		"advected wobble perturbs the refraction offset")


## Reference-like clarity means the refracted scene dominates a two-metre
## reach and pale sky reflection cannot wash it into a flat milky plane.
## These are material-budget invariants, not screenshot colour matching:
## they leave the palette tunable while preventing the two mechanisms that
## hid the bed in the reported frames.
func test_clarity_budget_keeps_the_bed_dominant() -> void:
	var clarity: float = _float_default("clarity_depth")
	var floor_v: float = _float_default("body_floor")
	var shallow: float = _float_default("shallow_tint")
	var sky: float = _float_default("sky_reflect")
	var depth_t: float = maxf(1.0 - exp(-2.0 / clarity),
		floor_v * smoothstep(0.05, 0.55, 2.0))
	assert_true(depth_t <= 0.09,
		"at 2m, deep tint occupies <=9%% and the refracted bed remains dominant (%.3f)" % depth_t)
	assert_true(floor_v <= 0.05, "body tint floor stays clear (%.3f <= 0.05)" % floor_v)
	assert_true(shallow <= 0.04, "shallow glass tint stays clear (%.3f <= 0.04)" % shallow)
	assert_true(sky <= 0.20, "sky reflection cannot milk-wash the body (%.3f <= 0.20)" % sky)


## Motion must remain optical: no later readability tweak may smuggle the
## wobble into height, lighting normal, or albedo streaks.
func test_advected_motion_remains_refraction_only() -> void:
	var wobble_at: int = _source.find("vec2 wobble = water_distort_wobble")
	var roff_at: int = _source.find("vec2 roff =", wobble_at)
	var albedo_at: int = _source.find("ALBEDO =", roff_at)
	assert_true(wobble_at >= 0 and roff_at > wobble_at and albedo_at > roff_at,
		"wobble feeds the optical offset before the single body ALBEDO write")
	assert_eq(_source.count("ALBEDO ="), 1,
		"unified shader has one body-colour write and no flow/foam albedo layer")
