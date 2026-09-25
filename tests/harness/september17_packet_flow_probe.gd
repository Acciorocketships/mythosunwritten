extends SceneTree
const QA := "res://docs/qa/2026-09-16-manual/03-water-flow"
const PRIOR_SAMPLER = preload("res://tests/fixtures/september17/water-transport/prior_sampler.gd")
const PRIOR_SIM = preload("res://tests/fixtures/september17/water-transport/sim_before.gd")

class OldSampler extends WaterSampler:
	func velocity_at(p: Vector2) -> Vector2:
		var v := Vector2.ZERO
		for corner: Array in _corners(p):
			v += _velocity[corner[1]*_nx+corner[0]]*corner[2]
		return v

func _initialize() -> void:
	var reports := []
	for phase: String in ["original", "prior", "after"]:
		var path := "res://docs/qa/2026-09-16-manual/baseline/P10/samplers.bin" if phase == "original" else QA+"/production-final/P10/samplers.bin"
		var data: Array = FileAccess.open(path,FileAccess.READ).get_var()
		var sim = WaterRippleSim.new() if phase == "after" else PRIOR_SIM.new()
		for values: Dictionary in data:
			var sampler: WaterSampler = OldSampler.new() if phase == "original" else PRIOR_SAMPLER.new() if phase == "prior" else WaterSampler.new()
			for key: String in values: sampler.set(key,values[key])
			sim._samplers.append(sampler)
		sim._packet_origin = Vector2(-1110.7,-757.5)-Vector2.ONE*WaterRippleSim.PACKET_DOMAIN*.5
		var checked := 0
		var rising := []
		var crest_rising := []
		var max_envelope := 0.0
		var max_crest := 0.0
		for frame in 1800:
			var prior := {}
			for packet: Dictionary in sim._packets: prior[packet.id] = packet.duplicate()
			sim._update_packets(1.0/30)
			for packet: Dictionary in sim._packets:
				if not prior.has(packet.id): continue
				var old: Dictionary = prior[packet.id]
				var sampler: WaterSampler = sim._sampler_at(old.p)
				if sampler == null: continue
				var h0 := sampler.level_at(old.p)
				var h1 := sampler.level_at(packet.p)
				if not is_finite(h0) or not is_finite(h1): continue
				checked += 1
				max_envelope = maxf(max_envelope,h1-h0)
				if h1-h0 > .001:
					rising.append({"frame":frame,"id":packet.id,"p":str(old.p),"rise":h1-h0})
				var crest_motion: Vector2 = packet.p-old.p + packet.dir*(old.phase-packet.phase)*packet.wavelength/TAU
				var hcrest := sampler.level_at(old.p+crest_motion)
				if is_finite(hcrest): max_crest = maxf(max_crest,hcrest-h0)
				if is_finite(hcrest) and hcrest-h0 > .001:
					crest_rising.append({"frame":frame,"id":packet.id,"p":str(old.p),"rise":hcrest-h0})
		var result := {"phase":phase,"checked":checked,"uphill_envelope_steps":rising.size(),"uphill_crest_steps":crest_rising.size(),"max_envelope_rise":max_envelope,"max_crest_rise":max_crest,"examples":rising.slice(0,8),"crest_examples":crest_rising.slice(0,8)}
		reports.append(result)
		print("PACKET_FLOW ",JSON.stringify(result))
		sim.free()
	FileAccess.open("res://docs/qa/2026-09-16-manual/15-water-transport/packet-flow-probe.json",FileAccess.WRITE).store_string(JSON.stringify(reports,"  "))
	quit()
