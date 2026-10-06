# Fresh holdout review — retained faces

Rendered 41/large and 67/large with dressing, overview and two pedestrian views after the native-turret/direct-street changes. Both native render jobs and the retained-face diagnostic finished successfully. No production behavior was changed in this checkpoint.

The new tower/roof grammar reaches both towns. However, art acceptance fails for remaining large flat faces: 41 has a tall blank central facade; 67 has an extensive blank timber-and-plaster perimeter beneath its elevated garden/deck. The 41 elevated garden pedestrian view confirms the courtyard tree and surrounding raised circulation survive. The 67 ground street view has recessed stone windows and supported upper frontage, but that successful inhabited frontage does not resolve the blank support elsewhere.

Source diagnosis: `KitVillageBuildings._retained_mass` deliberately defaults retained earth to plain panels, and selects timber for tall retained layers. `WarrenWallRooms.place` and `WarrenMazeSourcePlan.wall_room_support_ok` currently admit inhabited frontage only in artificial platform columns. Ordinary retained massif/courtyard supports therefore cannot receive the same inhabited treatment. `KitTownFacadeBays` correctly excludes these non-house masses. Blindly adding windows/bays there would put openings into solid earth.

The reusable `tests/harness/suntail/retained_face_survey.gd` reports layers of the final built masses. Its outline-slot counts include internal/sandwiched edges and are diagnostic topology counts, not exposed-render-area measurements. Native images are the visual evidence. The next repair must address actual retained supports: admit supported, accessible rooms where composition permits, and use complete native retaining details on the remaining exposed earth-backed faces. Preserve courtyard bearing, tunnel ceilings, passage clearance and the distinction between rock support and inhabited rooms.

This checkpoint adds holdout evidence and a reproducible diagnosis. It does not close facade quality, broad regression or performance acceptance. Whole redesign remains active.
