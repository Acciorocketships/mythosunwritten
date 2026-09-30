extends RefCounted
## Cliff art direction. Cliffs are dressed by the whole-wall slope sheet
## (`CliffSlopeField.solid`, the rounded terrain envelope of CliffSlopeEnvelope)
## with Meadow rocks at its foot; the native KayKit wall/lip pieces and the
## procedural crag, terrace and ledge styles were retired with the dual-grid
## terrain tiles (September 30). Only the sheet's study variants remain:
##   sheet_study: "" plain rounded sheet | "bedrock" (production: rock exposed
##                in the slope surface itself) | "stamp" / "blend" (studies).
##   moss_texture: raygeas | suntail | angry | polyart (CliffRockCrags.MOSS_TEXTURES).
## Not reloaded by the review harness, so its values survive a hot reload.
const PRODUCTION := "sheet_bedrock"
static var sheet_study := "bedrock"
static var moss_texture := "raygeas"


## `sheet` or `sheet_<study>`. Any other (retired) style name, and the retired
## `+<lip>` suffixes, restore the production style / drop the suffix.
static func apply(name: String) -> void:
	name = name.split("+")[0]
	if not name.begins_with("sheet"):
		name = PRODUCTION
	sheet_study = name.trim_prefix("sheet_") if name.begins_with("sheet_") else ""
	moss_texture = "raygeas"
