# October 4 native window-surround clearance

Pure Village's authored surrounds extend beyond the old opening envelopes.
The arched timber head reaches 2.276 m while its opening ends at 2.162 m.
A roof at 2.22 m crosses that head even though the glazing-only check passes.
The rectangular window has sill timber down to 0.518 m, so a floor at 0.6 m
also crosses its surround despite clearing the glazing.

The opening bake now measures connected Wood_1/Wood_2 components on native
Pure Village plaster window panels. Coincident positions are welded at 0.1 mm
across UV seams for measurement only; rendering geometry is unchanged. The
panel's continuous foot beam below 0.1 m is excluded. The measured components
are stored in window_frames.bin. Runtime facade and gable fitting checks each
component against the finished roof/public-floor skins and tries another whole
opening before blanking. Palette variants use their canonical source geometry.

The arch regression failed before this change (1/3 assertions). The floor test
now distinguishes a genuinely clear 0.45 m floor from a 0.6 m floor through the
sill. The latter has its own explicit regression, rather than being called clear.

A reported high-window test initially appeared to regress. Restoring the old
fitter reproduced its failure: its hardcoded house.003 is no longer present.
The baseline probe finds two backed high windows on a Suntail landmark facade.
The test now selects finished Suntail facades with backing requirements and
requires multiple high openings. The old-house test's failure is retained in
baseline-tests.txt; it must not be cited as a new runtime regression.

Matched 103/grand close render inspected: the existing clear arched windows,
roof arrangement and repaired masonry course are preserved. This accepts the
surround-clearance addition, not the previously rejected compact crown packing.
Final facade-contact suite: **17 tests / 296 assertions pass**. Results are
recorded in final-tests.txt.

Scope: native Pure Village plaster-window surrounds. This does not establish
full surround coverage for Suntail, stone-window families, every projecting
assembly, or the wider prefab grammar. Source families need explicit measurement
and review; arbitrary enlargement of glazing bounds is not a substitute.
