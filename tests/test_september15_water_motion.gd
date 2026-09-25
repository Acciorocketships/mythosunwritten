extends GutTest

func test_current_coverage_extends_beyond_the_old_48m_edge_without_coarsening_contact_ripples() -> void:
	var constants:Dictionary = (load("res://scripts/terrain/water/WaterRippleSim.gd") as GDScript).get_script_constant_map()
	assert_gte(float(constants.get("PACKET_DOMAIN",WaterRippleSim.DOMAIN)),192.0,
		"current wave coverage extends to at least 96m from the player")
	assert_eq(WaterRippleSim.DOMAIN/WaterRippleSim.RES,.375,
		"nearby entry rings retain their 37.5cm simulation grid")
	assert_eq(WaterRippleSim.FLOW_STEP,3.0,"contact advection retains native current resolution")
	var domain:float = constants.get("PACKET_DOMAIN",WaterRippleSim.DOMAIN)
	var density:float = WaterRippleSim.MAX_PACKETS/(domain*domain)
	assert_almost_eq(density,16.0/(96.0*96.0),.000001,
		"the expanded field neither thins wavelets out nor crowds them together")

func test_buoyancy_agrees_with_zero_wavelet_height_outside_rendered_domain() -> void:
	var sim:=WaterRippleSim.new()
	var packet:Dictionary={"p":Vector2(200,0),"dir":Vector2.RIGHT,"amp":.22,
		"wavelength":8.0,"radius":8.0,"phase":1.0,"age":2.0,"life":20.0}
	sim._packets.append(packet)
	assert_almost_eq(sim.packet_height_at(packet.p),0.0,.000001,
		"a transported packet outside the displayed field cannot move a floating body")
	sim.free()

func test_dry_or_saturated_water_does_not_spin_on_rejected_packet_candidates() -> void:
	var sim:=WaterRippleSim.new()
	sim._update_packets(.01)
	var attempts:=sim._packet_n
	for tick in 10: sim._update_packets(.033)
	assert_eq(sim._packet_n,attempts,"failed placement waits instead of searching again every two frames")
	sim.free()

func test_transition_is_wide_circular_and_continuous_when_player_crosses_a_lattice_boundary() -> void:
	var center:=Vector2(1.499,0)
	assert_eq(WaterRippleSim.packet_fade(center+Vector2(48,0),center),1.0,
		"the old boundary keeps full amplitude")
	assert_between(WaterRippleSim.packet_fade(center+Vector2(69,0),center),.49,.51,
		"the transition is halfway through after another 21m")
	for angle in range(0,360,15):
		var p:=center+Vector2(69,0).rotated(deg_to_rad(angle))
		assert_almost_eq(WaterRippleSim.packet_fade(p,center),.5,.00001,"no rectangular corners")
		assert_almost_eq(WaterRippleSim.packet_fade(p,Vector2(1.501,0)),.5,.0001,
			"crossing a 3m texture snap cannot snap the envelope")
	assert_eq(WaterRippleSim.packet_fade(Vector2(90,0),Vector2.ZERO),0.0,"outer edge closes")
	assert_lt(WaterRippleSim.packet_fade(Vector2(89.99,0),Vector2.ZERO),.000001,
		"the outer edge has no abrupt slope")

func _uniform_current(velocity:Vector2) -> WaterSampler:
	var sampler:=WaterSampler.new()
	sampler._origin=Vector2(-200,-200)
	sampler._step=100.0
	sampler._nx=5
	sampler._nz=5
	sampler._h.resize(25)
	sampler._h.fill(1.0)
	sampler._velocity.resize(25)
	sampler._velocity.fill(velocity)
	return sampler

func test_still_water_never_acquires_current_wavelets_and_flow_reaches_farther() -> void:
	var sim:=WaterRippleSim.new()
	sim._packet_origin=Vector2(-96,-96)
	sim._samplers.append(_uniform_current(Vector2.ZERO))
	for attempt in 5: assert_false(sim._spawn_packet(),"no current means no wave packets")
	sim._samplers.clear()
	sim._samplers.append(_uniform_current(Vector2(2,0)))
	var far_count:=0
	for attempt in 100:
		if sim._packets.size()>=WaterRippleSim.MAX_PACKETS: break
		sim._spawn_packet()
	for packet:Dictionary in sim._packets:
		if packet.p.length()>48.0 and packet.p.length()<90.0: far_count+=1
	assert_gt(far_count,8,"genuine wet current seeds the former flat distant zone")
	sim.free()
