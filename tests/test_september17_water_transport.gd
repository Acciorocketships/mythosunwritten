extends GutTest

class CountedSampler extends WaterSampler:
 var queries:=0
 func _current_surface_level_at(p:Vector2)->float:
  queries+=1
  return super._current_surface_level_at(p)

func test_packet_shares_one_surface_frame_for_current_and_crest()->void:
 var sampler:=CountedSampler.new()
 sampler._origin=Vector2(-10,-10);sampler._step=10;sampler._nx=3;sampler._nz=3
 for j in 3:
  for i in 3:
   sampler._h.append(10+float(i))
   sampler._velocity.append(Vector2(-.3,0))
   sampler._vorticity.append(0);sampler._compression.append(0)
 var sim:=WaterRippleSim.new()
 sim._samplers.append(sampler);sim._packet_timer=10
 sim._packets.append({"id":0,"p":Vector2.ZERO,"dir":Vector2.RIGHT,"phase":0.0,"age":2.0,"life":20.0,"wavelength":8.0,"radius":8.0,"amp":.2})
 sim._update_packets(1.0/30)
 assert_eq(sampler.queries,18,"One nine-query surface frame at the origin and one at the midpoint; no repeat for the crest")
 assert_lt(sim._packets[0].p.x,0.0)
 assert_lt(sim._packets[0].dir.x,0.0)
 sim.free()
