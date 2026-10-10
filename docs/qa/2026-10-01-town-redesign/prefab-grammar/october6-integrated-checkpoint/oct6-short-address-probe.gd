extends SceneTree
const District = preload("/tmp/oct6-short-address.gd")
func _init():call_deferred("_run")
func _run():
 var profile:=WarrenVillageScaleProfile.for_id(&"large")
 var source:=WarrenMazeSitePlanner.plan(31,{},profile,&"carve")
 var candidates:=[]
 var public:={}
 var walks:={}
 for c:Vector2i in source.massif.columns:
  var base:=source.massif.base_at(c)
  if source.massif.bearing_at(c)==base:candidates.append(Vector3i(c.x,base,c.y))
 for c:Vector3i in source.excavation.public_cells():public[c]=true
 for c:Vector3i in WarrenMazeCarver._walk_nodes(source.excavation):walks[c]=true
 var result:=District.propose(source.massif,source.excavation,profile,candidates,public,walks)
 print("ADDRESS_PAIR ",JSON.stringify(result))
 FileAccess.open("/tmp/oct6-short-address.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 quit()
