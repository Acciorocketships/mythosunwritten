# Meadow material selection — September 25

Owner selected Meadow rocks and the green-topped summer treatment in the store screenshot.

Verified against the original Unity package at `~/Setup Guide In-Editor Tutorial/Assets/ANGRY MESH`, not inferred from the marketing image:

- `M_Rock_01_Summer.mat` enables `_ENABLETOPLAYERBLEND_ON`.
- Base: `T_Rock_01_A` plus `T_Rock_01_N` and packed `T_Rock_01_SMA`. Other rock models use their corresponding numbered maps.
- Summer top: `T_Terrain_Grass_01_A`, `T_Terrain_Grass_01_N`, `T_Terrain_Grass_01_S`.
- Autumn replaces top albedo with `T_Terrain_DryGrass_01_A`; winter uses `T_Terrain_Snow_01_A/N/S`.
- `Stylized Pack - Common/Shaders/S_Props.shader` lines 587–623 blend the top layer according to the upward world normal (including the base normal map), using material offset 0.5, contrast 10, intensity 1 and top UV scale 5. These multiply scene-global controls. Noise and vertex-paint masks are disabled on the inspected summer material; detail mapping is also disabled.
- The shader applies overlay tinting rather than simply multiplying the base albedo by a dark color.

All these texture maps already exist in the converted project under `assets/ANGRY MESH/Textures/Stylized_Pack_-_Meadow_Environment/{Rocks,Terrain}`.

The converted pack README explicitly says world-space top moss/snow coverage was omitted. The catalog shows imported materials, so its bare-rock summer/autumn/winter previews omit the source seasonal shader treatment. They are silhouette references, not faithful seasonal material previews.

Next implementation should use original Meadow silhouettes and restore the vendor top-layer treatment. The rejected bent Farmlands faces and dark seam moss are not the selected direction. Broad rolling slope ridges/valleys, cap burial and varied clusters remain outstanding; this investigation does not claim those changes are complete.
