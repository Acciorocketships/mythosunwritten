# October 4: restore the planned support beneath large projecting rooms

The large projecting wing on 7/standard house 004 already had a valid four-corner native timber frame. Kit conversion discarded its `arcade_overhang_support` recipe and attempted cell-based replacement posts. Those replacements were rejected at public walking cells, leaving the wing visually unsupported.

Keep the reserved recipe rather than generating a duplicate support mass. This restores both four-post frames in the reported town. The final kit substitution tiles each native SFV post with three kit timber sections; the combined measured bounds retain the planned foot, top, and lateral clearance. These are timber supports, not the previously rejected stone arch.

Validation:
- Regression: 1 test, 77 assertions pass. Eight original supports survive the final kit substitution, with no duplicate member IDs, collision enabled, and aggregate bounds within 1 mm of the reserved recipe.
- Actual player: published route from the entrance to covered cell (1,6,2), then reverse, both pass. This cell is a destination, not a two-edge through passage; `--covered-access` exercises its published approach.
- Both native context images inspected: the projecting room is carried by visible timber posts, with the public deck passing beneath.

The first test incorrectly assumed a substituted post remained one placement; the renderer correctly tiles three one-metre kit members. The final test checks their aggregate bounds and individual collisions. No production substitution change was needed.

This is a structural rendering repair, not completion of the full prefab-derived grammar or the broader town redesign.

Broader validation: 7/standard; 13,31,58,101/large; 43,103,211/grand all report zero structural floating masses and zero main-roof public-air intrusions. These metrics do not replace the actual-player check for support collisions. Quiet production site test passes 125 assertions. Full-suite green and full artistic acceptance are not claimed.
