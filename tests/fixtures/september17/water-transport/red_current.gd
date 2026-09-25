extends GutTest
const PriorCurrent = preload("res://tests/fixtures/september17/water-transport/current_before.gd")
const PriorSim = preload("res://tests/fixtures/september17/water-transport/sim_before.gd")
func test_current_obeys_finished_surface_and_bank_together()->void:
 var uphill:=0;var dry_entry:=0;var stopped:=0
 for turn in 32:
  var grade:=Vector2.RIGHT.rotated(turn*TAU/32.0)*.3
  for bank_turn in 16:
   var inward:=Vector2.RIGHT.rotated(bank_turn*TAU/16.0)
   var desired:=PackedVector2Array();var bank:=PackedFloat32Array();var grades:=PackedVector2Array()
   for j in 5:
    for i in 5:
     desired.append(grade.normalized()*2.0)
     grades.append(grade)
     bank.append(3.0+inward.dot(Vector2(i-2,j-2))*.5)
   var solved:=PriorCurrent.solve_local(desired,bank,5,5,1.0,grades)
   var actual:Vector2=solved.velocity[12]
   if actual.dot(grade)>.00001:uphill+=1
   if actual.dot(inward)<-.00001:dry_entry+=1
   if actual.length()<.1 and (-grade.normalized()).dot(inward)>.1:stopped+=1
 assert_eq(uphill,0,"P10: finished water height must override an uphill river tangent")
 assert_eq(dry_entry,0,"Correcting downhill flow must not drive it through the bank")
 assert_eq(stopped,0,"An open downhill direction must flow rather than being frozen")
func test_flat_current_remains_identical()->void:
 var v:=PackedVector2Array([Vector2(2,.7)]);var bank:=PackedFloat32Array([8.0])
 assert_eq(PriorCurrent.solve_local(v,bank,1,1,3.0,PackedVector2Array([Vector2.ZERO])),PriorCurrent.solve_local(v,bank,1,1,3.0))

func test_current_uses_the_local_side_of_a_sharp_surface_minimum()->void:
 var height:=func(p:Vector2)->float:return -3.0*p.x if p.x<0.0 else p.x
 for x in [.06,.1,.2]:
  var p:=Vector2(x,0)
  var v:=PriorCurrent.sample_surface_current(Vector2(3,0),p,height)
  assert_lte(v.x,0.0,"A steeper far bank cannot make the nearer rising bank read as downhill")
  assert_gt(v.length(),.1,"The locally open downhill direction retains motion")

func test_wave_front_turns_downhill_when_its_current_turns()->void:
 var s:=WaterSampler.new()
 s._origin=Vector2(-10,-10);s._step=10;s._nx=3;s._nz=3
 for j in 3:
  for i in 3:
   s._h.append(10+float(i))
   s._velocity.append(Vector2(-.3,0))
   s._vorticity.append(0);s._compression.append(0)
 var sim:=PriorSim.new()
 sim._samplers.append(s);sim._packet_timer=10
 sim._packets.append({"id":0,"p":Vector2.ZERO,"dir":Vector2.RIGHT,"phase":0.0,"age":2.0,"life":20.0,"wavelength":8.0,"radius":8.0,"amp":.2})
 sim._update_packets(1.0/30)
 var packet:Dictionary=sim._packets[0]
 var crest:Vector2=packet.p+packet.dir*(-packet.phase)*packet.wavelength/TAU
 assert_lte(crest.x,0.0,"Turning inertia must not send the visible crest up a rising surface")
 assert_lt(packet.p.x,0.0,"The wave envelope continues with the actual current")
 sim.free()
