extends SceneTree
const PRIOR_SIM=preload("res://tests/fixtures/september17/water-transport/sim_before.gd")
const PRIOR_SAMPLER=preload("res://tests/fixtures/september17/water-transport/prior_sampler.gd")
const UNSHARED_SIM=preload("res://tests/fixtures/september17/water-transport/unshared_sim.gd")
func _initialize()->void:
 var reports:=[]
 var snapshots:Array=FileAccess.open("res://docs/qa/2026-09-16-manual/03-water-flow/production-final/P10/samplers.bin",FileAccess.READ).get_var()
 for cycle in 2:
  var phases:=["prior","unshared","shared"] if cycle==0 else ["shared","unshared","prior"]
  for phase:String in phases:
   var sim=PRIOR_SIM.new() if phase=="prior" else UNSHARED_SIM.new() if phase=="unshared" else WaterRippleSim.new()
   for values:Dictionary in snapshots:
    var sampler:WaterSampler=PRIOR_SAMPLER.new() if phase=="prior" else WaterSampler.new()
    for key:String in values:sampler.set(key,values[key])
    sim._samplers.append(sampler)
   sim._packet_origin=Vector2(-1110.7,-757.5)-Vector2.ONE*WaterRippleSim.PACKET_DOMAIN*.5
   var times:Array[float]=[]
   var digest:=HashingContext.new();digest.start(HashingContext.HASH_SHA256)
   for frame in 900:
    var start:=Time.get_ticks_usec()
    sim._update_packets(1.0/30)
    var elapsed:=Time.get_ticks_usec()-start
    if frame>=300:times.append(elapsed/1000.0)
    digest.update(var_to_bytes(sim._packets))
   times.sort()
   var sum:=0.0
   for elapsed:float in times:sum+=elapsed
   var report:={"cycle":cycle,"phase":phase,"mean_ms":sum/times.size(),"median_ms":times[times.size()/2],"p95_ms":times[floori(times.size()*.95)],"frames":times.size(),"all_packet_states_sha256":digest.finish().hex_encode()}
   reports.append(report);print("TRANSPORT_COST ",JSON.stringify(report));sim.free()
 FileAccess.open("res://docs/qa/2026-09-16-manual/15-water-transport/cost.json",FileAccess.WRITE).store_string(JSON.stringify(reports,"  "))
 quit()
