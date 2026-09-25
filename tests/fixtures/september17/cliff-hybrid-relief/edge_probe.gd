extends SceneTree
func _initialize()->void:
 var generator=load("res://tests/fixtures/september17/cliff-hybrid-relief/balanced.gd");generator.prepare()
 var salt:=2697992464+roundi(10.5)*13
 for index in range(-4,5):
  var u:=10.45+index*.002
  var masses:Array=generator._nature_mass_profile(u,64,salt)
  var samples:Array=[]
  for mass:Array in masses:
   var ny:float=clampf(44.8/mass[1],0,1)*32.0;var row:=mini(31,floori(ny))
   samples.append([mass[1],mass[3],lerpf(mass[4][row],mass[4][row+1],ny-row)])
  print("EDGE ",u," depth=",generator._body_depth(u,44.8,2,63.92,0,salt,[],masses)," shapes=",samples)
 quit()
