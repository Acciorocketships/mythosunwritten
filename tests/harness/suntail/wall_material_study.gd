extends RefCounted
## Review-only alternatives. Production has no study flag or chosen palette.
static func apply(built: Dictionary, kit: BuildingKit, option: String) -> void:
 assert(option in ["dark-stone","timber","pure-stone"])
 var catalog := EnvironmentCatalog.load_default()
 var source: EnvironmentInstancePayload = built.payload
 var out := KitVillageBuildings.without_prefixes(source,["kit.platform-wall/"] as Array[String])
 var map := KitVillageBuildings.native_to_lattice(kit)
 for part: Dictionary in built.placements:
  if not String(part.stable_id).begins_with("kit.platform-wall/"): continue
  var asset: StringName = part.asset_id
  var transform: Transform3D = part.transform
  var detail := StringName(part.get("fort_detail",&""))
  var tint := Color(0.87,0.88,0.86)
  var replacement := asset
  match option:
   "dark-stone":
    if detail != &"": tint = Color(0.40,0.46,0.53)
   "timber":
    tint = Color(0.93,0.94,0.90)
    if detail != &"":
     replacement = &"suntail.decor.crossbar_2" if detail==&"course" else &"suntail.decor.support_3"
     tint = Color.WHITE
   "pure-stone":
    replacement = &"pure_village.wall.stone.plain" if detail==&"" and part.role==&"wall.fort" else asset
    tint = Color(0.90,0.88,0.82) if detail==&"" else Color(0.55,0.48,0.39)
  if replacement != asset:
   var old_box: AABB = catalog.descriptor(asset).measured_aabb
   var new_box: AABB = catalog.descriptor(replacement).measured_aabb
   var ratio := old_box.size/new_box.size
   transform = transform*Transform3D(Basis.from_scale(ratio),old_box.position-new_box.position*ratio)
  out.add(replacement,map*transform,tint,part.stable_id,bool(part.get("collision",true)))
 built.payload = out
