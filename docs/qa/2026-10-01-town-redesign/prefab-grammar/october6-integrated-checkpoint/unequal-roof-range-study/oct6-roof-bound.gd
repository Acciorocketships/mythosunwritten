extends SceneTree
const Union=preload('res://scripts/terrain/features/villages/kit/KitRoofMeshUnion.gd')
func _init():
 var checked:=0
 var misses:=[]
 for kit:BuildingKit in [SuntailBuildingKit.create(),preload('res://scripts/terrain/features/villages/kit/PureVillageBuildingKit.gd').roof_study()]:
  for depth in range(2,5):
   for axis in 2:
    var mass:=BuildingMass.new()
    var rect:=Rect2i(0,0,6,depth) if axis==0 else Rect2i(0,0,depth,6)
    var roof:=mass.add_roof(rect,axis,4,&'red')
    roof.ridge_peaks=true
    var parts:=BuildingKitAssembler.new(kit).assemble(mass)
    var ctx:=Union.prepare(mass.roofs,[],kit)
    var max_error:=-INF
    var example:={}
    for part:Dictionary in parts:
     if not ctx.data.has(part.asset_id):continue
     for surface:Dictionary in ctx.data[part.asset_id]:
      for vertex:Vector3 in surface.vertices:
       var point:Vector3=part.transform*vertex
       var row:=clampi(floori(point[2 if axis==0 else 0]/kit.module_width),0,depth-1)
       var height:=float(kit.roof_profile(depth).height)
       var bound:=minf(height,float(mini(row+1,depth-row))*kit.roof_row_rise)+maxf(0,kit.roof_clearance_height(depth)-height)
       var error:=point.y-4*kit.band_height()-bound
       if error>max_error:max_error=error;example={"asset":part.asset_id,"point":point,"bound":bound}
       checked+=1
    print('BOUND ',kit.kit_id,' depth=',depth,' axis=',axis,' error=',max_error,' example=',example)
    if max_error>0.0001:misses.append(example)
 print('BOUND_DONE vertices=',checked,' misses=',misses.size())
 quit(0 if misses.is_empty() else 1)
