extends RefCounted
static func combine_parallel(masses:Array[BuildingMass],fits:Callable)->int:
 var count:=KitRoofJunctions.combine_parallel(masses,fits)
 if not fits.is_valid():return count
 for mass:BuildingMass in masses:
  if String(mass.stable_id).ends_with(".054"):print("PRE_RANGE ",mass.roofs)
  var changed:=true
  while changed:
   changed=false
   for a:Dictionary in mass.roofs.duplicate():
    for b:Dictionary in mass.roofs.duplicate():
     if is_same(a,b) or a.axis!=b.axis or a.eave_band!=b.eave_band or a.colour!=b.colour:continue
     if a.open_min or a.open_max or b.open_min or b.open_max:continue
     var ar:Rect2i=a.rect
     var br:Rect2i=b.rect
     var axis:=int(a.axis)
     var side:=1-axis
     if ar.end[side]!=br.position[side] and br.end[side]!=ar.position[side]:continue
     var lo:=maxi(ar.position[axis],br.position[axis])
     var hi:=mini(ar.end[axis],br.end[axis])
     if hi-lo<2:continue
     var core:=ar.merge(br)
     core.position[axis]=lo
     core.size[axis]=hi-lo
     var ridge:=0 if core.size.x>=core.size.y else 1
     if core.size[1-ridge]>BuildingDesigner.MAX_ROOF_DEPTH:continue
     var remnants:Array[Dictionary]=[]
     var valid:=true
     for original:Dictionary in [a,b]:
      var rect:Rect2i=original.rect
      for span:Vector2i in [Vector2i(rect.position[axis],lo),Vector2i(hi,rect.end[axis])]:
       if span.x>=span.y:continue
       if span.y-span.x<2:valid=false;break
       var rem:=original.duplicate(true)
       var rr:=rect
       rr.position[axis]=span.x
       rr.size[axis]=span.y-span.x
       rem.rect=rr
       rem.dormers={}
       rem.chimney=false
       remnants.append(rem)
     if not valid or not fits.call(mass,mass,core,ridge,int(a.eave_band)):continue
     var joined:=a.duplicate(true)
     joined.rect=core
     joined.axis=ridge
     joined.dormers={}
     joined.chimney=bool(a.get('chimney',false)) or bool(b.get('chimney',false))
     mass.roofs.erase(a)
     mass.roofs.erase(b)
     mass.roofs.append(joined)
     mass.roofs.append_array(remnants)
     print('RANGE_JOIN ',mass.stable_id,' ',ar,' + ',br,' -> ',core,' axis=',ridge,' remnants=',remnants.size())
     changed=true
     count+=1
     break
    if changed:break
 return count
