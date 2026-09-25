# Short inner-corner wall-run study — pass 101

**Rejected art experiment; production remains the verified pass-100 end-cap repair.** Following the complete neighboring run supplies a missing narrow panel, but creates an objectionable flat projection. No change from this study is integrated into production.

The native short turn at `(-421.5, 28, -349.5)` includes an eight-metre-high, three-metre-wide panel along the tall side. Its perpendicular low side has a three-metre panel and a directly adjoining twelve-metre panel with the same four-metre height and datum. The production width filter omits both three-metre panels. The twelve-metre low parent lies just outside the prior 85 m review radius about `(-452, 32, -272)`, which is why it did not participate in the previous local profile diagnosis.

The corrected study centers its review domain on the short turn. It replaces the low parent with the complete fifteen-metre run and continues the tall narrow panel through the backed turn. The latter retains an upper end taper above the actual four-metre neighboring wall. All other visible saved rock keeps its exact geometry; saved corners also restore their native root metadata. This is an isolated art study on frozen terrain, not production admission, grounding, collision or ownership verification.

The low run now has a tread, but its sampled height is 0.54175 m with only 0.2036 m width, versus 1.59025 m and 1.1916 m on the tall parent. The 1.0485 m difference exceeds the existing ledge-matching threshold. The three viewed candidate angles show a broad flat projection and do not achieve the requested continuous natural shape. Increasing a matching threshold alone would not establish a good surface transition.

- [Matched current control](before/short_above.png)
- [Rejected complete-run candidate](complete-study/short_above.png)
- [Candidate side view](complete-study/short_side.png)
- [Measured tread profiles](ledge-levels.json)

All three candidate views and the control above were inspected. The initial `study/` run is invalid: its smaller review domain lacked the low parent, its assertion fired, and its caller continued rendering unchanged geometry. The corrected caller exits on a missing required parent; `complete-study/` and `before/` include both actual runs and exit normally. `native-rows.bin` and `panels.bin` cover only the local inspection radius; their truncated outermost runs must not be used as complete-world construction input.

The next repair should coordinate the actual adjoining cross-sections and supported treads through this height change, rather than independently generating and extending narrow panels. The remaining short seam, lower shelf crossing, broader cliff appearance and original judging register stay open. Production source hashes still match pass 100 exactly, so its 22-test / 133-assertion result and fresh native verification remain applicable without a redundant rerun. This study adds no acceptance claim.
