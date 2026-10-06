# Compound-house middle-bay openings — October 4

`PureVillageCrossHouse` exposes complete native middle-wall sockets. Choices
replace the solid panel with Window_1_2, Window_12_2 or Door_3_1. End panels,
short returns, attic walls and roof geometry keep their ownership and pose.
Door_3_1 is the native plaster/timber door family present in House_16 and
BigHouse_1; it avoids inserting an unrelated stone facade material. No model
is cut or stretched and no opening is overlaid on a solid wall.

Seeded sampling chooses exactly one door and one window family for the other
eligible bays. Twenty seeds verify deterministic layouts, retained non-socket
parts and unchanged component transforms (1 test / 3841 assertions). The eight
source reconstruction tests remain green (10400 assertions).

Actual-glass outward segment tests against compound roof triangles pass for
both window families at every eligible socket on X-extended and Z-extended
houses (1 test / 8 aggregate assertions). This is facade-to-roof clearance;
it does not prove access from a town lane or clearance from neighbouring houses.
Native samples 7 and 31 were inspected from front/back views: source windows
and door fit below the eaves and retain the outer corner posts.

Remaining limitations: external end panels are still blank, so the pictured
samples are not approved final town architecture. They need compatible corner
facades, foundation/entry support, richer projections, and production access
and envelope integration. The House_5 default stays an exact blank-shell
benchmark; it is not used as the final sampled appearance.
