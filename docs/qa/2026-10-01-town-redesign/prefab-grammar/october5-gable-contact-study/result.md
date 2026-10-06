# Gable contact study — candidate not retained

Previous goal turn was progress: lower roof-wing preservation changed production and passed matched native review. This turn freezes and diagnoses the next finding from the archived interior-square experiment; it does not promote that layout or claim the complete redesign is finished.

## Reproduction

New reusable fixture: `tests/fixtures/october5-interior-court-gable-source.txt`, seed 8/grand from the archived route/frontage/support candidate. The three planner source files and temporary helper were restored after capture. Signature: `122105e454d479464c2c608e56c9a702795ea107a7a2ac20008b397f0276fc57`.

House.027's lower roof is rectangle(-14,8;4,4), axis0, eave band2, union index21. Its positive end loses five audit samples along native x=-20, y=6.113, z=18.367..19.967. The sole cutting roof responsible is index23, rectangle(-10,8;2,2), axis1, eave band4. Removing wall cutters does not change the finding; excluding this roof cutter removes it.

A small isolated mass reproduces the five samples without the town planner. Its red test fails 1/1. The candidate carried the neighbouring attic slope's height at the nominal gable plane across the panel thickness, preserving the gable's outward plaster at the eave contact. The initial isolated test then passed, and live 8's older four-sample contact finding also disappeared; live 9's audit was unchanged.

## Why it is not shipped

Matched native overview and close views are pixel-identical before/after (zero pixels with channel difference >8). The affected surface is around the adjoining attic contact; these views do not establish a visible exterior defect or improvement. Additional rays into the actual neighbouring roof encounter its far side around 3.75–3.93 m away, and downward rays miss that roof. This is insufficient to prove either an exposed exterior hole or complete enclosure by the surrounding roof-and-wall assembly. Do not relabel the finding a proven false positive.

The candidate is archived as `candidate.patch`; production `KitRoofMeshUnion.gd` was restored. The exploratory regression is archived here rather than installed as a new failing acceptance requirement. Its extended pack/direction version initially did not load because of a missing preload; that preload was corrected in the archived source, but the expanded version was not rerun. The 18/18 tests /918 assertions from the two existing roof suites are valid only for those suites, not the missing extended script.

Cameras, FOV55:

- Matched: eye(-28,20,54), target(-42,11,40).
- Additional candidate seam view: eye(-36,12,44), target(-42,12.2,37).

## Next

Retain the frozen fixture and cutter diagnosis for a visibility-aware examination of the complete surrounding assembly. Do not weaken the roof audit or accept this candidate merely to make a count zero. Prioritize the visibly intrusive roof inside frozen 43's enclosed bridge next, then reassess the whole square prototype, including fitting spire supply, changed crossings and search cost. No additional spires, skywalks or squares ship from this study.
