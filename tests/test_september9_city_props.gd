extends GutTest

func test_private_garden_edge_has_a_supported_storage_pair() -> void:
 var cell:=Vector3i(0,0,0)
 var sites:=SettlementFabricAssembler.maze_garden_planting_sites({cell:true},{},{},{},{})
 var furniture:Array=[]
 for site in sites:
  if site.has("station_part"):furniture.append(site)
 assert_eq(furniture.size(),2,"A private garden edge receives a deliberate storage pair")
 if furniture.size()!=2:return
 assert_eq(furniture[0].asset,SettlementFabricProgram.TERRACE_CRATE)
 assert_eq(furniture[1].asset,SettlementFabricProgram.TERRACE_BAG)
 assert_gt(furniture[1].origin.y,furniture[0].origin.y)
 assert_ne(SettlementFabricAssembler.maze_garden_decor_id(furniture[0]),SettlementFabricAssembler.maze_garden_decor_id(furniture[1]))

func test_public_ground_entries_and_occupied_air_cannot_gain_furniture() -> void:
 var garden:Dictionary={}
 var walked:Dictionary={}
 for x in 6:
  for z in 4:
   garden[Vector3i(x,0,z)]=true
   walked[Vector3i(x,1,z)]=true
 assert_true(SettlementFabricAssembler.maze_garden_planting_sites(garden,garden,{},{},{},{},[] as Array[AABB],walked).is_empty())
 assert_true(SettlementFabricAssembler.maze_garden_planting_sites(garden,{},garden,{},{}).is_empty())
 var blocked:Array[AABB]=[AABB(Vector3(-2,1,-2),Vector3(15,8,15))]
 var sites:=SettlementFabricAssembler.maze_garden_planting_sites(garden,{},{},{},{},{},blocked)
 for site in sites:assert_false(site.has("station_part"))

func test_frozen_towns_add_furniture_without_reusing_public_or_lamp_cells() -> void:
 var program:=SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
 var frozen:=preload("res://tests/fixtures/frozen_maze_source.gd")
 for label in ["east","offset","thin-turf"]:
  var fabric:=frozen.spatial(frozen.read("res://tests/fixtures/september9-%s-source.txt"%label),program).compiled_fabric_cache()
  var payload:=SettlementFabricAssembler.terrace_retaining_payload(fabric)
  var count:=0
  var ids:Dictionary={}
  var public:=SettlementFabricAssembler.walked_floor_cells(fabric.surface_plan)
  for asset:StringName in payload.batches:
   var batch:Dictionary=payload.batches[asset]
   for id in batch.ids:
    if not String(id).contains("/station/"):continue
    count+=1
    assert_false(ids.has(id))
    ids[id]=true
    var parts:=String(id).trim_prefix("maze-garden/").split("/")
    var cell:=Vector3i(int(parts[0]),int(parts[1]),int(parts[2]))
    var step:=Vector3i(int(parts[3]),0,int(parts[4]))
    assert_false(public.has(cell+Vector3i.UP))
    assert_false(public.has(cell+step+Vector3i.UP))
  if label=="thin-turf":assert_eq(count,0,"All its turf is public")
  else:assert_gte(count,2,label+" adds a real furniture group")

func test_sack_resting_height_uses_the_native_lid_not_the_crate_bounds() -> void:
 var sites:=SettlementFabricAssembler.maze_garden_planting_sites({Vector3i.ZERO:true},{},{},{},{})
 var furniture:Array=[]
 for site in sites:
  if site.has("station_part"):furniture.append(site)
 assert_eq(furniture.size(),2)
 if furniture.size()!=2:return
 var rise:float=furniture[1].origin.y-furniture[0].origin.y
 var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://docs/qa/2026-09-09-manual/17-props/native-contact.json"))
 var contact:=INF
 for sample in data.samples:
  var clearance:float=rise+sample.bag_bottom-sample.crate_top
  assert_gte(clearance,-0.001,"The sack cannot penetrate the lid")
  contact=minf(contact,clearance)
 assert_lt(contact,0.001,"The sack must actually rest on the lid")
