# Mountain art direction — September 15

The owner rejects the current sparse square stacks as pyramid-like and asks for an asset review and a greener, less flat, less repetitive mountain. This is an art-direction proposal, not acceptance of the current cliff-dressing candidate. The ongoing water, village and landscape issues remain open under their existing records.

## What the asset review establishes

Thirty-six existing source models were rendered from two angles each with their native materials. See [shortlist](shortlist.jpg), full [vines and moss rocks](survey-1.jpg), [plants, larger rocks and roots](survey-2.jpg), and [KayKit forms](survey-3.jpg). These are isolated asset previews, individually framed, not game-scale comparisons or proof of integration. Exact paths and measured source bounds are in [survey.json](survey.json); the reproducible harness is `tests/harness/september15_mountain_asset_survey.gd`.

| Existing source | Observed shape | Proposed role |
| --- | --- | --- |
| Medieval Village MegaKit/glTF/Prop_Vine1, 2, 4 | Thin, green, vertical leaf sprays | Trailing curtains attached below grass lips and fissures |
| Same pack / Prop_Vine5, 6, 9 | Broader spreading foliage; 5 has a deeper over-edge shape | Green shoulders, broken patches descending from wider ledges |
| UltimateNaturePack/FBX/Rock_Moss_1–7 | Angular rocks with green top and intermediate bands | Joined buttresses, irregular shelf ends, grounded rubble at the foot |
| LowPolyFantasyVillage/Models/Nature/BigRock_01, 02 | Tall faceted rock faces | Broad vertical ribs partly embedded into the mountain |
| Same pack / BigRock_03 | Lower broad boulder | Foot-of-cliff rubble and transitions into ground |
| CraftingFBX/.../Nature/SFWC_Root_001–003 | Branching root networks | Roots descending from a real tree or soil pocket into a crack |
| UltimateNaturePack/FBX/Plant_1, 3, 4 | Pointed rosette, upright blades, spreading leafy plant | Small ledge gardens and crevice vegetation; 4 especially suits a lush pocket |
| KayKitNature / Rock_1_Q | Tiered rock stack | Occasional local accent; strongly resembles the stack motif already overused |
| KayKitNature / Hill_Cliff and Hill_Top modules | Repeated short cliff sections and square-edged turf pieces | Structural substrate; repeating these alone cannot supply the desired broad composition |

The green MegaKit vine meshes are distinct from the white FantasyVillage ivy previously removed from town walls. Their thinness makes surface attachment and oblique-view review necessary. Existing LPFV broadleaf habitat restrictions remain in force; the newly surveyed UltimateNature plants are a different family whose mountain use would need its own authored habitat.

## Recommended direction: a green, broken escarpment

Compose an entire visible face around a few connected forms. On a roughly 100 m span, start with two or three uneven shelf runs and several substantial vertical rock ribs. Treat those counts as an initial composition study, not fixed generation spacing.

1. **Long irregular shelves.** Make shallow grassy ledges follow the mountain contour for tens of metres. Let them widen into occasional planted pockets, taper back into the face, and wrap corners. Break the run where the underlying geology changes. Avoid a repeated large/medium/small stack and avoid perfectly level green stripes wrapping the entire mountain. Where a shelf serves as a path, preserve a readable, connected walking surface.
2. **Attached rock ribs and recessed gullies.** Use the tall faceted rocks and angular moss rocks to create broad ribs that span multiple existing storeys. Each group should read as one outcrop emerging from the mountain. Align local rocks to a shared fracture direction, with limited scale and rotation variation. Recesses between ribs provide stronger shadows and places for greenery. Rocks used at large scale need matching physical surfaces; arbitrary embedded decorations must not create invisible ledges or new collision lips.
3. **Greenery that spans the face.** Start vines at soil-bearing upper edges and drape them downward. Combine broad foliage patches with a few narrow strands, leaving irregular openings. Grow leaves and grass in crevices and on shelves, with denser planting near damp recesses. This puts green on vertical surfaces as well as horizontal caps.
4. **Moss and subdued stone colour.** Add broad, irregular moss coverage and restrained stone variation across the underlying cliff material. Let moss follow moisture, exposure and sheltered seams. Keep the existing biome identity, with sage/olive and deeper greens complementing the purple rock. The green should not simply repeat once per mesh or recolour all rock uniformly.
5. **Rooted focal points.** A small tree on a sufficiently wide shelf, roots entering a fissure, a darker fern-like pocket, or a physically connected waterfall can mark occasional memorable places. Keep water-dependent decoration tied to actual coherent water; the outstanding water faults must be repaired first.

A starting visual target for the lush mountain study is roughly one-third to one-half of the face reading green at the normal gameplay camera, through a combination of moss, vines and planted shelves. Preserve exposed rock and quiet areas so the face retains depth. Use local clusters separated by gaps; uniformly raising prop density would keep the same repetition.

## Other viable moods

- **Hanging garden:** more trailing vines, leafy ledges, sheltered grottoes and a few trees. Strongest green treatment; suits forest-facing slopes and wet valleys.
- **Mossy fractured highland:** large angular ribs, green crevice seams, sparse wind-shaped vegetation and more exposed stone near the top. Keeps the Opal Highlands distinct while making the lower mountain much greener.

The recommended blend is fractured highland at the crown and hanging garden in lower, sheltered reaches, driven by actual terrain and biome conditions.

## Assets worth adding or making

The new `assets/StylizedNatureQuaternius` download now supplies a proper fern, textured medium rocks, wispy grass, leafy bushes and twisted trees. Nine actual glTF models were rendered in Godot from two angles, using their native imported materials: see [new kit shortlist](megakit/shortlist.jpg), [source list](megakit/assets.json) and [bounds](megakit/survey.json). These are individually framed asset previews, not a production landscape or equal-scale comparison. The process exited cleanly. The imported twisted trees and bush currently have red foliage; a green material variant is part of the proposed adaptation, not a verified existing green setup. The mossy medium rocks are roughly 3 m across in source units. Enlarging them alone will not create a convincing complete mountain.

The remaining asset gaps are long irregular cliff shelves with tapering ends and corner transitions, tall deeply fractured mountain forms, grass/moss strips curling over lips, and hanging vine curtains with depth. Existing green Medieval Village vines, UltimateNature moss rocks and the new fern can furnish a first study. No further broad nature pack is necessary for that study.

## Pure Nature 2 reference and revised direction

The owner added [Pure Nature 2: Asian Mountains](https://assetstore.unity.com/packages/3d/environments/pure-nature-2-asian-mountains-341972) as the preferred reference. Two publisher gallery views were visually inspected on September 15. Their defining features are tall irregular stone pillars, deep vertical fractures, broad weathered faces, trees and shrubs rooted in crowns and cracks, green valley floors and atmospheric separation between distant peaks. The desired composition is substantially different from the current repeated short horizontal cliff modules.

Build an original stylized interpretation using custom large forms and existing vegetation. A first compact custom kit should contain three complementary pillar silhouettes (slender, broad split, leaning), two attached wall buttresses, and a ledge with tapering end and corner variants. Give forms broad asymmetric planes, occasional recesses and vertical cracks that span several storeys. Avoid equal ring spacing, concentric square layers and arbitrary per-vertex noise. Pillars should emerge from a shared mountain mass and valleys; simply scattering detached pillars would repeat the owner's isolated-stack problem.

The custom models should be real reusable meshes with closed surfaces, stable UV/material coordinates, LODs and matched physical envelopes. Their eventual production integration must use the existing catalog/baker and shared terrain ownership, public-space and wet-ground checks. The vegetation can use the new fern, twisted trees and mossy rocks with existing vines and roots. Moss should also cover broad sheltered areas of the actual cliff surface through a restrained material treatment, rather than relying entirely on small leaf objects.

Composition and terrain profiles must change with the assets: connect vertical ribs, recess gullies, vary ridge heights, and reserve believable soil-bearing ledges. Preserve the traversable terrain contract and settle the outstanding water defects before using cascades as focal points. Lighting should emphasize crevice shadows, soft warm light and cooler distant layers without restoring camera blur. Matching the reference's overall mood is a plausible goal; equivalent finished quality has not been demonstrated. No custom mountain model or production landscape was built in this research pass.

## Cheaper pack comparison

Prices checked on creator pages September 15, 2026, in USD. These are alternatives for components, not complete equivalents to the reference.

| Pack | Listed price | Relevance and limitation |
| --- | --- | --- |
| [Arnklit — Godot Cliffs & Rocks Asset Pack 1](https://arnklit.itch.io/godot-rock-asset-pack1) | $15 | 20 cliff/rock models, moss and rock textures, Godot smart material with triplanar projection and crevice/direction blending. Strongest technical starting point for this Godot project; does not supply the full reference landscape composition. |
| [LottelluStudio — Stylized Rocks and Rockscape](https://lottellustudio.itch.io/stylized-rocks-and-rockscape-pack-low-poly) | $4.99 | 35 rocks including five large cliff faces, spikes and sprawling foundations. Palette-based low-poly forms; would still need our own material, vegetation and terrain composition work. |
| [SimplePolygon — Modular Cliffs](https://simplepolygon.itch.io/modular-cliffs) | Free | Simple palette-based modular cliffs, useful for blockout; attribution required. Not a finished substitute for the detailed reference. |

Recommendation: use the new MegaKit and existing library, then concentrate custom work on the large cliff forms. If purchasing a component pack instead, evaluate Arnklit's models/material in a small target-camera study before committing to a mountain-wide setup.

## How to judge the next prototype

Build one representative mountain-face study with existing assets first. Inspect the original wide gameplay view, two oblique views and a close ledge walk. Require a changed large silhouette and continuous green areas visible at distance before adding small props. Reject repeated pyramid motifs, detached vegetation, horizontal green striping, scaled-up tiny-leaf cards, empty rear surfaces and new collision lips. Only then generalize the composition into terrain-owned rules with shared reservations and native asset preparation. The current hierarchy and ambient-rock tests establish specific physical properties; they do not establish this visual direction.
