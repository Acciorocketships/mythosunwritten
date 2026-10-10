extends SceneTree
func _init():
 for spec in ["166029932451774690", "3910114991003307946", "6357506428441529412", "3613595803240038080:standard", "7:standard", "6052724565602100358", "3360408526109449337", "8702761491571936463", "6046713720826375059"]:
  var parts=spec.split(":")
  var seed_value=int(parts[0])
  var profile=WarrenVillageScaleProfile.for_id(StringName(parts[1])) if parts.size()>1 else WarrenVillageScaleProfile.select(seed_value)
  var p=WarrenMazeCarver.carve(seed_value,WarrenMassifBuilder.build(seed_value,{},profile),profile)
  if p==null:
   print("FAIL ",spec)
   continue
  var empty=[]
  var ground=0
  for c in p.passage_cells():
   var sides=0
   for d in WarrenPassageLatticeRules.DIRECTIONS:
    sides+=int(p._column_carries_house_at(Vector2i(c.x+d.x,c.z+d.y),c.y))
   if sides==0:
    empty.append(c)
    ground+=int(p.massif.is_reserved_ground(Vector2i(c.x,c.z)))
  print("FRONTAGE ",spec," ratio=",p.audit.frontage_ratio," passages=",p.passage_cells().size()," unfronted=",empty.size()," reserved_ground=",ground)
  if float(p.audit.frontage_ratio)<0.4:
   print("EMPTY ",empty)
   print("LANES ",p.excavation.lanes)
 quit()
