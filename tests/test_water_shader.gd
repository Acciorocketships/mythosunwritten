extends GutTest

const SHADER_PATH := "res://terrain/water/water_unified.gdshader"
const RIPPLE_SHADER_PATH := "res://terrain/water/ripple_sim.gdshader"

var _source := ""
var _ripple_source := ""


func before_all() -> void:
	_source = FileAccess.get_file_as_string(SHADER_PATH)
	_ripple_source = FileAccess.get_file_as_string(RIPPLE_SHADER_PATH)
	assert_false(_source.is_empty(), "unified water shader source loads")
	assert_false(_ripple_source.is_empty(), "ripple simulation shader source loads")


func _float_default(name: String) -> float:
	var regex := RegEx.new()
	var err: int = regex.compile("uniform\\s+float\\s+" + name + "[^=;]*=\\s*([0-9.]+)")
	assert_eq(err, OK, "uniform regex compiles")
	var hit: RegExMatch = regex.search(_source)
	assert_not_null(hit, "shader declares a default for %s" % name)
	return float(hit.get_string(1)) if hit != null else NAN


## A moving feature must be one physical surface event: the SAME sampled
## height displaces vertices and its gradient bends refraction.  Fragment-only
## noise can change pixels without ever looking like a travelling wave.
func test_dynamic_height_couples_geometry_normals_and_refraction() -> void:
	assert_true(_source.contains("water_dynamic_height("),
		"the unified shader exposes one dynamic surface-height function")
	var vertex_at: int = _source.find("void vertex()")
	var fragment_at: int = _source.find("void fragment()")
	var vertex_height_at: int = _source.find("water_dynamic_height(", vertex_at)
	var displacement_at: int = _source.find("VERTEX +=", vertex_height_at)
	var fragment_height_at: int = _source.find("water_dynamic_height(", fragment_at)
	var refraction_at: int = _source.find("refraction_offset", fragment_height_at)
	assert_true(vertex_height_at > vertex_at and displacement_at > vertex_height_at,
		"dynamic height physically displaces the water mesh")
	assert_true(fragment_height_at > fragment_at and refraction_at > fragment_height_at,
		"the same height field drives optical refraction")
	assert_false(_source.contains("water_distort_wobble"),
		"the rejected fragment-only scrolling distortion is gone")
	assert_true(_source.contains("+ ripple_height_at(world_xz)"),
		"the simulated ripple height physically displaces the shared mesh")


## Clear water must still behave like a refractive surface, but screen-space
## refraction may use only the displaced SURFACE SLOPE.  Feeding the whole
## view-space plane normal into UV offset adds camera tilt, folding a submerged
## silhouette into a second copy and pulling bank pixels through cliff walls.
func test_refraction_is_readable_but_cannot_fold_with_camera_tilt() -> void:
	assert_true(_float_default("refraction_strength") >= 0.09,
		"submerged silhouettes retain the proven readable refraction amplitude")
	assert_true(_source.contains("water_view_normal.xy - mesh_view_normal.xy"),
		"only displaced slope—not the plane's camera tilt—bends screen UVs")
	assert_false(_source.contains("water_view_normal.xy * refraction_strength"),
		"the whole view-space normal cannot become a large constant screen offset")
	assert_true(_source.contains("max_refraction_offset"),
		"screen-space displacement has a hard fold/disocclusion bound")
	assert_true(_source.contains("water_signed_height_world(depth_texture, refracted_uv"),
		"the restored refraction still rejects samples above the water surface")


## Restore the pre-overhaul interaction read: a swimmer creates a crisp,
## clear normal/refraction ring. It must not be replaced by an albedo-white
## impulse blob, and the old 8x texture-gradient response remains explicit.
func test_swim_ripple_is_clear_and_keeps_the_old_normal_response() -> void:
	assert_true(_source.contains("ripple_normal_gradient"),
		"interaction ripples retain their dedicated texture-gradient normal")
	assert_true(_float_default("ripple_normal_strength") >= 8.0,
		"interaction ring keeps the proven pre-overhaul normal strength")
	assert_false(_source.contains("ripple_foam"),
		"swim and entry impulses never become a white material blur")
	assert_false(_ripple_source.contains("foam += impulse"),
		"the ripple simulation stores clear wave state, not white impulse energy")
	assert_true(_source.contains("render_mode specular_schlick_ggx"),
		"the restored normal ring can catch the real scene light again")
	assert_true(_source.contains("EMISSION = body") and _source.contains("SPECULAR ="),
		"clear transmission stays unlit while physical ripple normals retain a specular read")
	assert_true(_source.contains("interaction_reflection")
		and _source.contains("length(interaction_gradient)"),
		"the clear ring has a narrow gradient-driven sky reflection, not a filled blur")


## River turbulence is a real advected height-field simulation input. The
## forcing must enter the wave equation's velocity before the height update;
## directly painting a fragment colour would still be 'just a shader'.
func test_current_drives_geometric_surface_turbulence_without_polluting_swim_ripples() -> void:
	assert_true(_source.contains("+ packet_height_at(world_xz)"),
		"flow-transported wave particles physically displace the shared surface")
	assert_true(_ripple_source.contains("current * flow_dt / domain_size"),
		"the restored interaction ripple itself is still advected downstream")
	assert_false(_ripple_source.contains("flow_turbulence_force"),
		"continuous river forcing cannot saturate or blur the interaction-ripple state")


func test_flow_wave_particle_is_a_compact_oscillating_surface_wavelet() -> void:
	assert_true(WaterRippleSim.MAX_PACKETS <= 16,
		"the surface cannot turn into an overlapping wave-train carpet")
	assert_true(WaterRippleSim.PACKET_AMPLITUDE_MAX >= 0.20
		and WaterRippleSim.PACKET_AMPLITUDE_MAX <= 0.25,
		"river wavelets stay readable without becoming opaque-looking ridges")
	var packet: Dictionary = {
		"p": Vector2.ZERO,
		"dir": Vector2.RIGHT,
		"amp": 0.24,
		"wavelength": 8.0,
		"radius": 11.0,
		"phase": 0.0,
		"age": 2.0,
		"life": 12.0,
	}
	var previous_sign := 0
	var sign_changes := 0
	var peak := 0.0
	for x in range(-12, 13):
		var h: float = WaterRippleSim.packet_height(packet, Vector2(float(x), 0.0))
		peak = maxf(peak, absf(h))
		var sign_v := signf(h)
		if previous_sign != 0 and sign_v != 0 and sign_v != previous_sign:
			sign_changes += 1
		if sign_v != 0:
			previous_sign = sign_v
	var outside: float = WaterRippleSim.packet_height(packet, Vector2(50.0, 0.0))
	print("MEAS compact flow wavelet peak=%.4f sign_changes=%d outside=%.6f" % [
		peak, sign_changes, outside])
	assert_true(peak >= 0.08, "wave particle has readable geometric amplitude")
	assert_true(sign_changes >= 3,
		"one compact particle contains several rise/trough crests, not one closed blur")
	assert_almost_eq(outside, 0.0, 0.001,
		"wave particle is spatially compact rather than a repeated streak train")


## Crystal-clear water is transmitted scene light attenuated per channel,
## plus the small amount actually scattered back.  A scalar mix toward teal
## cannot preserve the riverbed's contrast.
func test_clarity_is_spectral_transmission_not_a_teal_mix() -> void:
	assert_true(_source.contains("exp(-absorption * depth)"),
		"Beer-Lambert transmittance preserves the scene at shallow depth")
	assert_true(_source.contains("scene * transmittance"),
		"the refracted riverbed remains the body of the water")
	assert_false(_source.contains("mix(scene * mix(vec3(1.0), color_shallow"),
		"the old scalar teal-overlay formula is removed")
	assert_true(_source.contains("caustic"),
		"the moving surface can focus light onto the visible bottom")
	assert_true(_source.contains("vec3(0.003, 0.001, 0.0005)"),
		"the spectral budget stays crystal-clear even across a deep river view")
	assert_true(_float_default("reflection_strength") <= 0.04,
		"broad sky reflection cannot veil the transmitted bottom")
	assert_true(_float_default("wave_height") <= 0.5,
		"ambient pond swell stays subordinate to downstream packets")
	assert_true(_source.contains("packet_curvature"),
		"bright focusing pockets are compact flow-transported packets, not ambient stripes")


## White is legal only when generated from simulated breaking/interaction
## energy.  There must be no repeating white streak texture on ordinary water.
func test_foam_is_event_generated_and_advected() -> void:
	assert_true(_source.contains("packet_breaking") and _source.contains("flow_compression"),
		"foam comes from breaking wave packets and compressed current")
	assert_false(_source.contains("ripple_foam"),
		"player interaction ripples remain clear")
	assert_false(_source.contains("foam_tex"),
		"no tiled white foam/streak texture is applied to normal water")
	assert_true(_source.contains("foam_amount"),
		"generated foam has one explicit, bounded material contribution")
