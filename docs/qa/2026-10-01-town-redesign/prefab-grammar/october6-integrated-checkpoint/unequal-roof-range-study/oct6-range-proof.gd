extends SceneTree
const Study=preload('/tmp/oct6-roof-ranges.gd')
func _init():
 for axis in 2:
  var mass:=BuildingMass.new()
  var a:=Rect2i(2,14,6,2)
  var b:=Rect2i(0,16,8,2)
  if axis==1:
   a=Rect2i(a.position.y,a.position.x,a.size.y,a.size.x)
   b=Rect2i(b.position.y,b.position.x,b.size.y,b.size.x)
  mass.add_roof(a,axis,4,&'blue')
  mass.add_roof(b,axis,4,&'blue')
  var original:=_coverage(mass)
  var masses:Array[BuildingMass]=[mass]
  assert(Study.combine_parallel(masses,func(_a,_b,_r,_axis,_eave):return false)==0)
  assert(mass.roofs.size()==2)
  assert(Study.combine_parallel(masses,func(_a,_b,_r,_axis,_eave):return true)==1)
  assert(_coverage(mass)==original)
  assert(mass.roofs.size()==2)
  assert(Study.combine_parallel(masses,func(_a,_b,_r,_axis,_eave):return true)==0)
 print('RANGE_PROOF_PASS both axes; exact footprint and multiplicity; refusal; idempotence')
 quit()
func _coverage(mass:BuildingMass)->Dictionary:
 var out:={}
 for roof:Dictionary in mass.roofs:
  for cell:Vector2i in BuildingMass.rect_cells(roof.rect):out[cell]=int(out.get(cell,0))+1
 return out
