extends SceneTree
func _init():
 var rows=[]
 for scale in [&"compact",&"standard",&"large",&"grand"]:
  for seed_value in range(1,13):
   var p=WarrenMazeSitePlanner.plan(seed_value,{},WarrenVillageScaleProfile.for_id(scale),&"",false)
   if p==null:
    rows.append({"seed":seed_value,"scale":scale,"failed":WarrenMazeSitePlanner.last_failure})
    continue
   var courts=[]
   for plot in p.plots:
    if plot.kind!=WarrenMazeSourcePlan.PLOT_DECK:continue
    var low=Vector2i(100000,100000)
    var high=-low
    for c in plot.cells:
     low=Vector2i(mini(low.x,c.x),mini(low.y,c.y))
     high=Vector2i(maxi(high.x,c.x),maxi(high.y,c.y))
    var ext=high-low+Vector2i.ONE
    if mini(ext.x,ext.y)<2 or maxi(ext.x,ext.y)>mini(ext.x,ext.y)*2 or ext.x*ext.y!=plot.cells.size():continue
    var raised=true
    for c in plot.cells:
     raised=raised and plot.floor>p.massif.base_at(c)
    courts.append({"id":String(plot.id),"area":plot.cells.size(),"floor":plot.floor,"raised":raised})
   var row={"seed":seed_value,"scale":scale,"courts":courts,"open_ground":p.massif.open_court.size()}
   rows.append(row)
   print("COURT ",JSON.stringify(row))
 print("SURVEY ",JSON.stringify(rows))
 quit()
