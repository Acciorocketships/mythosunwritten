extends SceneTree
func _initialize()->void:
 for version:String in ["bearing","plain-diagnostic"]:
  var g:GDScript=load("res://tests/fixtures/september17/cliff-local-terraces/"+version+".gd");g.prepare()
  var u:=-8.5;var height:=32.0;var salt:=2697992464+roundi(10.5)*13
  var core:float=lerpf(1.6,2.0,g._noise(u/13.0,salt+53))*clampf(height/10.0,.35,1.15)
  var boulder:float=2.5*smoothstep(.38,.84,g._noise(u/5.7,salt+83))*clampf(height/16.0,.25,1.0)
  var crest:float=height-.08-height*.34*pow(g._noise(u/3.7,salt+91),12.0)
  var generic:Array=g._mass_profile(u,height,salt)
  for mass:Array in generic:mass[3]*=lerpf(.65,.9,smoothstep(16.0,64.0,height))
  var nature:Array=g._nature_mass_profile(u,height,salt)
  var all:Array=generic.duplicate();all.append_array(nature)
  for masses:Array in [[],generic,nature,all]:
   var values:Array=[]
   for y:float in [21.8,19.4]:
    values.append(g._body_depth(u,y,core,crest,boulder,salt,g._fracture_profile(u,height,salt),masses))
   print("BODY version=",version," count=",masses.size()," depths=",values," loss=",values[0]-values[1])
 quit()
