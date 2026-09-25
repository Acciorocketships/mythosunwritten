extends RefCounted
# N02's frozen world contains the terrain here but its live grass residency
# ring did not reach N04. Restore the same four real, unchanged baseline
# GrassField payloads in every comparison; do not invent a visual grass fill.
static func add_to(root:Node)->void:
 var catalog:=EnvironmentCatalog.load_default();var cache:=EnvironmentRenderCache.new(catalog)
 var program:=GrassProgram.compile(load("res://terrain/grass/settings.tres"),catalog,cache)
 var streamer:=GrassStreamer.new(program,cache);streamer.begin_frame(Vector2(-519.5,326.4))
 var node:=Node3D.new();root.add_child(node)
 var payloads:Dictionary=FileAccess.open("res://docs/qa/2026-09-19-manual/123-bank-grass/narrow-control/payloads.bin",FileAccess.READ).get_var()
 for tile:Vector2i in payloads:
  for asset:StringName in payloads[tile].before:
   streamer._add_batch(node,asset,payloads[tile].before[asset])
