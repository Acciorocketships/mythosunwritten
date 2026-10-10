extends SceneTree
const Candidate=preload("/tmp/oct6-continuous-cap-designer.gd")
func _init():call_deferred("_run")
func _run():
 var data:Dictionary=str_to_var(FileAccess.get_file_as_string("/tmp/oct6-thin-crown-fixture.txt"))
 for mode:String in ["baseline","candidate","clearance_restored"]:
  var mass:=BuildingMass.new()
  mass.storeys.assign(data.storeys.duplicate(true))
  var designer=Candidate.new(SuntailBuildingKit.create()) if mode!="baseline" else BuildingDesigner.new(SuntailBuildingKit.create())
  designer.forbidden=func(c:Vector2i,b:int):return mode!="clearance_restored" and data.blocked.has(Vector3i(c.x,b,c.y))
  designer.covered=func(c:Vector2i,b:int):return b==8 and c in [Vector2i(8,3),Vector2i(9,3)]
  var rng:=RandomNumberGenerator.new()
  rng.seed=53
  designer._assign_roofs(mass,rng,&"red")
  var pitched:=[]
  var cap:={}
  for r:Dictionary in mass.roofs:
   if r.eave_band==8:pitched.append(r)
  for d:Dictionary in mass.decks:
   if d.band==8:cap.merge(d.cells)
  print("CAP_CHECK ",mode," ",JSON.stringify({"roofs":pitched,"cap_cells":cap.keys()}))
  if mode=="clearance_restored":assert(not pitched.is_empty())
  if mode=="candidate":
   assert(pitched.is_empty())
   assert(cap.size()==data.exposed.size())
   for c:Vector2i in data.exposed:assert(cap.has(c))
 quit()
