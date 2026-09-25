extends SceneTree
const OUT="res://docs/qa/2026-09-19-manual/125-bank-domains"
func _init()->void:
 var a:Dictionary=FileAccess.open(OUT.path_join("domain-0.bin"),FileAccess.READ).get_var()
 var b:Dictionary=FileAccess.open(OUT.path_join("domain-1.bin"),FileAccess.READ).get_var()
 var rows:Array=[]
 for id:String in a:
  if var_to_bytes(a[id])==var_to_bytes(b[id]):continue
  var keys:Array=[]
  for key in a[id]:
   if var_to_bytes(a[id][key])!=var_to_bytes(b[id].get(key)):keys.append(key)
  var row:={"id":id,"keys":keys,"level_a":a[id].get("replay_recipe",{}).get("shore_level"),"level_b":b[id].get("replay_recipe",{}).get("shore_level"),"green_a":a[id].get("green",[]).size(),"green_b":b[id].get("green",[]).size()}
  var recipe_keys:Array=[]
  for key in a[id].get("replay_recipe",{}):
   var av=a[id].replay_recipe[key];var bv=b[id].replay_recipe.get(key)
   if var_to_bytes(av)!=var_to_bytes(bv):recipe_keys.append({"key":key,"a":av,"b":bv,"delta":av-bv if av is float and bv is float else null})
  row["recipe_difference"]=recipe_keys
  rows.append(row)
 FileAccess.open(OUT.path_join("differences.json"),FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
 print(rows);quit()
