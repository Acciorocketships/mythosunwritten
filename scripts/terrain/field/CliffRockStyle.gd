extends RefCounted
## Cliff rock art direction (owner reviews, September 23).
## Not reloaded by the review harness, so its values survive a hot reload.
##   subtle:   compress projection beyond the native attachment, most at the foot.
##   facets:   resample relief as low-poly planar facets with hard edges.
##   chunky:   larger, stepped facet blocks (owner's reference rocks); needs facets.
##   crags:    emit the procedural crag formations at all.
##   terraces: storey-quantised inner-corner terraces of native KayKit pieces.
##   moss:     ground-up moss grading on added rock (and mossy upward facets).
## The owner selected subtle + inner terraces + moss as the default.
static var subtle := true
static var facets := false
static var chunky := false
static var crags := true
static var terraces := true
static var moss := true
## Mossy talus slopes on the lower cliff with rocks protruding (owner trial).
static var slopes := false
## Rock ledges (treads with turf). Off for now: they added glitches (owner,
## September 24); the historical `current` style keeps them.
static var ledges := false
## The slope sheet replaces the crag dressing entirely (`sheet`, owner trial
## September 24): one continuous slope from under the lip to the ground.
static var sheet_only := false
## Moss detail source: raygeas | suntail | angry | polyart (CliffRockCrags.MOSS_TEXTURES).
static var moss_texture := "raygeas"
## Rock/slope study variant under `sheet` (owner, September 25 rethink):
## "" = production, else the suffix of a `sheet_<variant>` style name.
static var sheet_study := ""
## Lip treatment study under `sheet` ("" = slope flush with the plateau;
## `+underlip`: slope leaves the wall below a kept native lip; `+nolip`:
## no native lips, the slope rounds straight off the plateau).
static var lip_mode := ""


static func apply(name: String) -> void:
	subtle = name != "current"
	slopes = name == "slopes" or name.begins_with("sheet")
	sheet_only = name.begins_with("sheet")
	var parts := name.split("+")
	sheet_study = parts[0].trim_prefix("sheet_") if parts[0].begins_with("sheet_") else ""
	lip_mode = parts[1] if parts.size() > 1 else ""
	ledges = name == "current"
	facets = name in ["rocky", "chunky"]
	chunky = name == "chunky"
	crags = name != "kit"
	terraces = name in ["chosen", "chunky", "kit"] or slopes
	moss = name in ["chosen", "chunky"] or slopes or name.begins_with("moss_")
	terraces = terraces or name.begins_with("moss_")
	moss_texture = name.trim_prefix("moss_") if name.begins_with("moss_") else "raygeas"
