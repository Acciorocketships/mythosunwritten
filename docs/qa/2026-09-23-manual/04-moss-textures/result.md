# Joints, flush stepped corners, moss grading and pack textures (September 23)

Owner flags on `03-moss-joints-overhangs`: the crack and the outcrop in
photo 7 remain; a bare joint column in photo 1; moss should blend into the
ground without a colour cutoff, be darker/cooler in the green biome, reach the
top of any wall, and use the mossy textures from the new asset packs.
Images: current / moss_raygeas / moss_suntail / moss_angry / moss_polyart at
the green site (img6, terr2, low, corners) and Amber Heath (img7, img7w).

## Structure

- **Joints.** A panel that meets a collinear neighbour at least as tall now
  continues `JOINT_OVERLAP` (3 m) into it and fades across that overlap
  (`left_extend`/`right_extend`); the taller side keeps a 0.5 m fade. The two
  rocks cross-fade into one surface instead of meeting at a crack.
- **Stepped corners.** A convex corner whose measured lower-tier edge is
  within 2 m keeps only a 0.35 m skin over the native corner; the remaining
  arm read as a slab with a flat end.

## Moss (`cliff_crag.gdshader`)

- UV2 now carries (height above ground, full cliff height). Density is
  graded by the relative height, from full cover at the ground to sparse
  patches (22%) at the crest, on walls of any height.
- The lowest 1.6 m blends into the exact lawn colour, and cover is complete
  below 1.2 m, so rock meets turf without a colour edge.
- Moss shade is darker and cooler (lawn x 0.40/0.58/0.50).
- Pack textures, each reproducing that pack's own rock-moss layer from the
  Unity sources (`~/Setup Guide In-Editor Tutorial/Assets`):
  - `raygeas`: Suntail terrain `Grass_1` leaf grain (current default).
  - `suntail`: Suntail stones' coverage layer, a flat cool green masked by
    the stone texture's cell pattern: moss cells, bare cracks.
  - `angry`: ANGRY MESH summer rocks' top layer, `T_Terrain_Grass_01_A`
    broken by `T_Noise_01_M`.
  - `polyart`: Polyart cliff coverage, the painted `Grass_02_C_Green`.
  Colour textures act relative to their mean, so every biome keeps its tone.
  Copies (512 px) live in `terrain/materials/moss/`;
  `CliffRockCrags.MOSS_TEXTURES` and `CliffRockStyle.moss_texture` select.
