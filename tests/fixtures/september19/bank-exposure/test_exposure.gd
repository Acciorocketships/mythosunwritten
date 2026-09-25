extends GutTest
const EXPOSE=preload("res://tests/fixtures/september19/bank-exposure/exposure.gd")
const TRACE=preload("res://tests/fixtures/september19/bank-exposure/trace.gd")
var banks:Array=[];var plants:Array=[];var sources:Array=[]
func before_all()->void:
 preload("res://scripts/terrain/field/CliffRockDressing.gd").prepare()
 banks=FileAccess.open("res://docs/qa/2026-09-19-manual/127-bank-preserved-relief/validated-banks.bin",FileAccess.READ).get_var()
 plants=FileAccess.open("res://docs/qa/2026-09-19-manual/127-bank-preserved-relief/plants.bin",FileAccess.READ).get_var()
 sources=FileAccess.open("res://docs/qa/2026-09-19-manual/122-bank-attachments/sources.bin",FileAccess.READ).get_var()
func test_bank_plants_are_exposed_on_the_actual_fitted_surface()->void:
 var result:=EXPOSE.filter(plants,sources,banks)
 var failures:=0
 for plant:Dictionary in result:
  var hit:=TRACE.first_contact(plant,banks)
  if hit.is_empty() or hit.id!=plant.support_id or hit.root_gap>.005:failures+=1
 print("BANK_EXPOSE selected=",result.size()," failures=",failures)
 assert_gt(result.size(),40,"Retain a substantial attached population rather than hiding every plant")
 assert_eq(failures,0,"A nearer fitted formation must not cover the selected plant root")

func test_exposure_does_not_depend_on_owner_partition_or_mutate_plants()->void:
 var original:=var_to_bytes(plants)
 var expected:=EXPOSE.filter(plants,sources,banks)
 var split:Array=[]
 for north:bool in [true,false]:
  var owners:Array=banks.filter(func(b):return (b.anchor.z<288)==north)
  var ids:Dictionary={}
  for bank:Dictionary in owners:ids[bank.id]=true
  var local:Array=plants.filter(func(p):return ids.has(p.support_id))
  split.append_array(EXPOSE.filter(local,sources,owners))
 var a:Dictionary={};var b:Dictionary={}
 for p:Dictionary in expected:a[p.id]=p
 for p:Dictionary in split:b[p.id]=p
 assert_eq(a,b,"An independently published neighbor may use either dry or fitted geometry")
 assert_eq(split.size(),b.size())
 assert_eq(var_to_bytes(plants),original)
