extends GutHookScript
## GUT pre-run hook: replaces script sources from BASELINE_SOURCES
## ("res://path=/abs/file;...") before tests run, so a revision's baseline
## test status is measured in-process without touching the working tree.
func run()->void:
 for pair:String in OS.get_environment("BASELINE_SOURCES").split(";",false):
  var parts:=pair.split("=")
  var script:=load(parts[0]) as GDScript
  script.source_code=FileAccess.get_file_as_string(parts[1])
  assert(script.reload(false)==OK)
  gut.p("[baseline hook] %s <- %s"%[parts[0],parts[1]])
