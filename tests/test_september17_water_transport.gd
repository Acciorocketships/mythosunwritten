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
 # At most one nine-query surface frame at the origin and one at the midpoint;
 # no repeat for the crest. October 6: frames are memoized on a 0.25 m lattice,
 # so two points in one lattice cell share a single frame.
 assert_lte(sampler.queries,18,"No more than one surface frame per packet point")
 var before:=sampler.queries
 sampler.current_frame_at(Vector2(0.01,0.0))
 sampler.current_frame_at(Vector2(0.01,0.0))
 assert_lte(sampler.queries-before,9,"A repeated lookup reuses its memoized surface frame")
 assert_lt(sim._packets[0].p.x,0.0)
 assert_lt(sim._packets[0].dir.x,0.0)
 sim.free()

## October 6: production samplers carry only the native fill (no coarse _h
## grid); choosing a packet's chunk must not read _h (656k script errors).
func test_chunk_choice_reads_the_current_not_the_coarse_grid()->void:
 var sampler:=WaterSampler.new()
 sampler._origin=Vector2(-10,-10);sampler._step=10;sampler._nx=3;sampler._nz=3
 for j in 3:
  for i in 3:
   sampler._velocity.append(Vector2(-.3,0) if i<2 else Vector2.ZERO)
 assert_true(sampler._h.is_empty())
 assert_true(sampler.covers_current(Vector2(-5,0)),"a current reaches here")
 assert_false(sampler.covers_current(Vector2(50,50)),"outside the snapshot")
