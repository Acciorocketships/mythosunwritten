# Issue 01 — ordinary terrain joins beside villages

Status: implemented and visually verified at P07, P08 and P09 after the owner rejected candidate 07. This replaces the earlier grass-sheet-only acceptance, archived in [result-candidate07-withdrawn.md](result-candidate07-withdrawn.md). The other September 15 issues remain open.

## Diagnosis and decision

The owner’s [download.png](/Users/ryko/Desktop/download.png) and [download-1.png](/Users/ryko/Desktop/download-1.png) correctly showed that restoring native lips did not restore ordinary terrain topology. The former pipeline selected a cliff/corner from natural 24 m controls, then bent its crown and side faces using a village’s 3 m construction-grade collar. The first new regression reproduced a 2 m height spread across a selected cliff crown.

The repair resolves sealed village construction datums into the ordinary world controls **before** native slope/cliff/corner classification. Ground, rock pieces, grass sampling and collision consume that same completed lattice. The natural planning maps remain immutable. The production view no longer carries a post-classification fine grade warp.

Fixed foundation footprints own complete native cells. Surrounding free controls are raised only when the ordinary reconstructed terrain would leave a reserved footprint unsupported. This is a bounded monotone solve over a finite domain, cached per sealed grade and natural plan. Continuous road samples retain their lineage instead of becoming invented flat foundation pads. Complete canonical input and a two-cell discovery margin make the controls independent of which streaming chunk asks first.

This intentionally changes terrain geometry. At P07 and P09, partly flattened cliff tiles become ordinary ground; their old cliffs are not preserved. P08 retains its exposed cliff, with a horizontal crown, the ordinary rounded corner and a normal neighbouring slope. This is a general field rule with no photographed-coordinate exceptions.

## Iteration and visual judgment

A broad first control projection flattened too much surrounding terrain and was rejected. The selected version reserves additional controls only after a failed pad-support check; that preserves P08’s cliff. Early `topology-game/` comparisons used candidate grass in both phases and let newly raised terrain obstruct the reconstructed camera; they are excluded. Final `native-game/` comparisons independently rebuild the grass and retain the previously saved camera transform.

Nine final before/after pairs were judged: P07/P08/P09 at the reconstructed photograph orientation and ±8 degrees, including every absolute RGB difference panel. P08 no longer has a tilted crown, dipping nonstandard corner or grass slope running down its exposed side. P07 joins the village’s ground through ordinary terrain instead of retaining a partly graded rock block. P09 loses the isolated half-graded cliff and joins the field. All three retain grounded reserved construction footprints. Unfinished roofs and other open issues visible in the context are not credited as repaired.

| Site | Reconstructed photo comparison | Changed pixels, three views |
|---|---|---|
| P07 | [Before / after / difference](native-game/P07/differences/P07_0-comparison.png) | 20.52–21.06% |
| P08 | [Before / after / difference](native-game/P08/differences/P08_0-comparison.png) | 18.35–22.45% |
| P09 | [Before / after / difference](native-game/P09/differences/P09_0-comparison.png) | 38.33–38.62% |

Changed pixels use luma difference >12/255; displayed absolute RGB differences have 3× gain. Large differences are expected because geometry, grass height and sometimes the player’s supported height change. The percentage alone is not evidence of a successful repair.

The original overlays record rounded player/crosshair positions, not exact camera transforms or character facing. These are reproducible reconstructions, not claims of exact historical cameras. Each pair uses the same saved camera and FOV, current feature/building context, materials and frozen clocks. Player X/Z stay fixed; after-state feet are raised to the new ground where needed (P08: 22.3→24 m; P09: 36.6→40 m). Both phase heights and capture caveats are recorded in each `capture-provenance.json`. The old `pivot` field in saved poses was recomputed against candidate collision and is not authoritative; the camera matrix is. The harness now records this distinction directly.

The fixed-pad lineage refinement produces identical controls at all three frozen sites. Final feature-discovery changes affect neighbouring chunk discovery, not the control formula, and were tested separately after the visual captures. The earlier P03 candidate-07 control is not credited as validation of this new topology.

## Physical and automated evidence

Actual native chunk collision was committed in isolated physics worlds. [native-support.json](native-support.json) records 5,325 downward rays across reserved cell centres and four inset corners: 1,745 each at P07 and P08, 1,835 at P09. All hit support at the intended datum; maximum numerical height error is 0.00000133 m. Collision is intentionally changed, so the earlier candidate-07 identical-collision claim does not apply.

- Six new topology tests / 20 assertions pass: flat cliff crowns, photographed footprint support, exact grass control copies, fractional foundation datums, query-window/order independence, continuous-road lineage and neighbouring record discovery.
- Four graded-cliff construction tests / 10 assertions pass. Five hamlet tests / 949 assertions pass.
- The ten-suite terrain run has 145 tests: 139 passing, five historical failures and one pending, with 34,928/35,946 assertions passing. The failures are the three previously documented carved-corner cases and two older native grass-lip ownership/coverage cases. No full-suite acceptance is claimed.
- The additional construction/survey run has 15/16 passing tests, 4,867/4,876 assertions. Its nine house/path-overlap assertions reproduce unchanged with the archived pre-topology entry point; this is not a new passing construction corpus.

Raw logs are in [native-logs](native-logs). The final terrain run uses `tests/harness/september15_gut.gd`, which registers the existing saved terrace material UIDs before loading their meshes. A direct GUT invocation also hit those known unregistered-UID warnings; that earlier log is retained rather than counted as a clean run. No diagnostics were suppressed.

## Limits

Verification covers these three reported sites, the listed native invariants and the measured foundation samples. It does not establish all possible multi-elevation pad layouts, every terrain seam, a full settlement corpus, long-walk streaming behaviour or water acceptance. The terrain solve changes heights around villages; overlapping fixed datums within a single native cell need broader layout validation before claiming universal coverage. Cold graphical starts in these captures took about 334 and 453 seconds; no performance improvement is claimed. Issue 02 and the remaining issue register stay open.
