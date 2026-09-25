# Curved ledge lighting — pass 95

The repeated light/dark stripes on curved turf are caused by per-triangle normals in the grass surface. The connected stone already uses shared normals, but its turf did not. Production now gives each connected turf fan shared area-weighted normals while preserving genuinely sharp folds. No triangle, ledge slope, UV, material, tint, collision or support geometry changes.

The four connected walls in the pass-94 photographed fixture expose **1,142 discontinuities across 2,153 gently joined turf edges** before this change and **zero afterward**. The regression verifies the actual production mesh, exact turf vertices, shared material, and preservation of a sharp fold. Two existing stone-normal tests and the physical tread-grade test remain green: **five tests / 25 assertions**. The grade check includes 460 actual treads with none missing or excessively steepened.

[Red control](logs/cliff95-red-final.log) · [Focused green run](logs/cliff95-tests.log) · [Production delta](production.patch).

## Native matched review

A native Metal replay uses the freshly generated pass-94 scene. Across **106 rock meshes**, 68,596 vertex normals change. The replay asserts that the complete stone surface buffers remain identical and that every turf attribute except normals and renderer-generated tangents remains identical. It duplicates the stone surface directly; the first attempted full surface rebuild changed tangent values during renderer encoding and was rejected as a strict unchanged-buffer control. The final replay retains the original stone buffers exactly.

Nine before/after pairs are retained: three original P12 ReviewCam-derived poses, plus six supplementary inner/outer/stepped close cameras. The original pose records compare identically. The original P12 framing remains heavily obstructed and cannot substantiate visual quality; the supplementary close views provide the useful evidence.

The lower inner front/elevated views show the broad curved grass treads without the earlier sampling stripes. The upper inner and outer oblique views likewise retain their silhouettes and genuine sharp ledge boundaries. **The pointed shelf overlaps at the inner junction are still present** and require a geometric repair. Broad/plain stone areas, the remaining short inner connection, broader cliff art and the original judging register remain unfinished.

[Before lower inner](native/before/lower_inner_above.png) · [After lower inner](native/after/lower_inner_above.png) · [After inner](native/after/inner_above.png) · [After outer](native/after/outer_oblique.png) · [Native log](logs/cliff95-native-final.log).

This pass changes display normals only. It does not claim a new fresh-world generation, player traversal, performance improvement, overall corner acceptance or completion of the water/town/streaming/biome issues. The next cliff geometry target is the pointed overlap visible where the lower ledges meet the perpendicular terrace, now distinguishable from the fixed shading bands.
