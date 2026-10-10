extends SceneTree
const Candidate=preload('/tmp/oct6-range-buildings.gd')
func _init():call_deferred('run')
func run():
 var program:=SettlementFabricProgram.compile(EnvironmentCatalog.load_default())
 var rows:=[]
 for item:Array in [[53,&'grand'],[31,&'large']]:
  var spatial:=WarrenVolumetricSolver.generate(item[0],{},program,WarrenVillageScaleProfile.for_id(item[1]))
  assert(spatial!=null)
  var fabric:=spatial.compiled_fabric_cache()
  var kit:=SuntailBuildingKit.create()
  var built:=Candidate.build(spatial,fabric,kit,true,true)
  var roofs:=preload('res://tests/fixtures/kit_roof_public_air_audit.gd').audit(built,kit)
  var floating:=KitFloatingMassAudit.audit(spatial,fabric,built.masses)
  var row:={"seed":item[0],"profile":item[1],"roof":roofs,"floating":floating,"joins":built.roof_audit.parallel_joins,"valid_payload":built.payload.validate()}
  rows.append(row)
  print('RANGE_AUDIT ',JSON.stringify(row))
  FileAccess.open('/tmp/oct6-range-audit.json',FileAccess.WRITE).store_string(JSON.stringify(rows,'  '))
 quit()
